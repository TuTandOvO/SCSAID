package AccessCounter;

import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.nio.file.AtomicMoveNotSupportedException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardCopyOption;
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneOffset;
import java.time.ZonedDateTime;
import java.time.temporal.ChronoUnit;
import java.time.format.DateTimeFormatter;
import java.util.ArrayList;
import java.util.Collections;
import java.util.List;
import java.util.Map;
import java.util.Properties;
import java.util.TreeMap;

/** Durable UTC-hour buckets for the public traffic charts. */
final class TrafficHistoryStore {
    private static final DateTimeFormatter HOUR_KEY = DateTimeFormatter.ofPattern("yyyyMMddHH");
    private static final String HOUR_PREFIX = "hour.";

    private final Path path;
    private final TreeMap<String, Long> hourly = new TreeMap<>();
    private LocalDate historyStart;

    TrafficHistoryStore(Path path) {
        this.path = path;
    }

    synchronized void load() throws IOException {
        hourly.clear();
        historyStart = null;
        if (!Files.isRegularFile(path)) return;

        Properties properties = new Properties();
        try (InputStream input = Files.newInputStream(path)) {
            properties.load(input);
        }
        String start = properties.getProperty("historyStart");
        if (start != null) {
            try { historyStart = LocalDate.parse(start.trim()); }
            catch (RuntimeException ignored) { historyStart = null; }
        }
        for (String key : properties.stringPropertyNames()) {
            if (!key.startsWith(HOUR_PREFIX)) continue;
            String hour = key.substring(HOUR_PREFIX.length());
            if (!hour.matches("\\d{10}")) continue;
            long value = parseNonNegative(properties.getProperty(key));
            if (value > 0) hourly.put(hour, value);
        }
        if (historyStart == null && !hourly.isEmpty()) {
            historyStart = parseHour(hourly.firstKey()).toLocalDate();
        }
    }

    synchronized void record(Instant instant) throws IOException {
        ZonedDateTime hour = utcHour(instant);
        String key = HOUR_KEY.format(hour);
        hourly.put(key, hourly.getOrDefault(key, 0L) + 1L);
        if (historyStart == null || hour.toLocalDate().isBefore(historyStart)) {
            historyStart = hour.toLocalDate();
        }
        save();
    }

    synchronized Snapshot snapshot(Instant instant) {
        ZonedDateTime currentHour = utcHour(instant);
        List<String> last24Labels = new ArrayList<>(24);
        List<Long> last24Values = new ArrayList<>(24);
        long last24Total = 0;
        for (int offset = 23; offset >= 0; offset--) {
            ZonedDateTime hour = currentHour.minusHours(offset);
            long value = hourly.getOrDefault(HOUR_KEY.format(hour), 0L);
            last24Labels.add(hour.toInstant().toString());
            last24Values.add(value);
            last24Total += value;
        }

        LocalDate today = currentHour.toLocalDate();
        long days = historyStart == null ? 0
                : ChronoUnit.DAYS.between(historyStart, today) + 1;
        long[] sums = new long[24];
        long recordedTotal = 0;
        for (Map.Entry<String, Long> entry : hourly.entrySet()) {
            ZonedDateTime hour = parseHour(entry.getKey());
            if (hour.isAfter(currentHour)) continue;
            sums[hour.getHour()] += entry.getValue();
            recordedTotal += entry.getValue();
        }
        List<String> averageLabels = new ArrayList<>(24);
        List<Double> averageValues = new ArrayList<>(24);
        for (int hour = 0; hour < 24; hour++) {
            averageLabels.add(String.format("%02d:00", hour));
            averageValues.add(days == 0 ? 0.0 : sums[hour] / (double) days);
        }

        return new Snapshot(
                historyStart, days, last24Labels, last24Values, last24Total,
                averageLabels, averageValues,
                days == 0 ? 0.0 : recordedTotal / (double) days);
    }

    Path getPath() { return path; }

    private void save() throws IOException {
        Path parent = path.toAbsolutePath().getParent();
        if (parent != null) Files.createDirectories(parent);
        Properties properties = new Properties();
        if (historyStart != null) properties.setProperty("historyStart", historyStart.toString());
        for (Map.Entry<String, Long> entry : hourly.entrySet()) {
            properties.setProperty(HOUR_PREFIX + entry.getKey(), Long.toString(entry.getValue()));
        }

        Path directory = parent == null ? Path.of(".").toAbsolutePath() : parent;
        Path temporary = Files.createTempFile(directory, "traffic-history-", ".tmp");
        try {
            try (OutputStream output = Files.newOutputStream(temporary)) {
                properties.store(output, "scSAID UTC hourly traffic history");
            }
            try {
                Files.move(temporary, path, StandardCopyOption.ATOMIC_MOVE,
                        StandardCopyOption.REPLACE_EXISTING);
            } catch (AtomicMoveNotSupportedException ignored) {
                Files.move(temporary, path, StandardCopyOption.REPLACE_EXISTING);
            }
        } finally {
            Files.deleteIfExists(temporary);
        }
    }

    private static ZonedDateTime utcHour(Instant instant) {
        return instant.atZone(ZoneOffset.UTC).truncatedTo(ChronoUnit.HOURS);
    }

    private static ZonedDateTime parseHour(String key) {
        return ZonedDateTime.of(
                java.time.LocalDateTime.parse(key, HOUR_KEY), ZoneOffset.UTC);
    }

    private static long parseNonNegative(String value) {
        try { return Math.max(0, Long.parseLong(value == null ? "" : value.trim())); }
        catch (NumberFormatException ignored) { return 0; }
    }

    static final class Snapshot {
        final LocalDate historyStart;
        final long daysIncluded;
        final List<String> last24Labels;
        final List<Long> last24Values;
        final long last24Total;
        final List<String> averageLabels;
        final List<Double> averageValues;
        final double averageDaily;

        Snapshot(LocalDate historyStart, long daysIncluded,
                 List<String> last24Labels, List<Long> last24Values, long last24Total,
                 List<String> averageLabels, List<Double> averageValues,
                 double averageDaily) {
            this.historyStart = historyStart;
            this.daysIncluded = daysIncluded;
            this.last24Labels = Collections.unmodifiableList(last24Labels);
            this.last24Values = Collections.unmodifiableList(last24Values);
            this.last24Total = last24Total;
            this.averageLabels = Collections.unmodifiableList(averageLabels);
            this.averageValues = Collections.unmodifiableList(averageValues);
            this.averageDaily = averageDaily;
        }
    }
}
