package AccessCounter;

import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.nio.file.AtomicMoveNotSupportedException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardCopyOption;
import java.time.LocalDate;
import java.time.format.DateTimeFormatter;
import java.util.ArrayList;
import java.util.Collections;
import java.util.Comparator;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Properties;

/**
 * Stores country-level traffic aggregates only. IP addresses, user agents,
 * request paths, and other per-visitor identifiers are deliberately excluded.
 */
final class CountryTrafficStore {
    private static final String TOTAL_PREFIX = "total.country.";
    private static final String DAILY_PREFIX = "day.country.";
    private static final DateTimeFormatter DAY_KEY = DateTimeFormatter.BASIC_ISO_DATE;

    private final Path path;
    private final int dailyRetentionDays;
    private final Map<String, Long> allTime = new LinkedHashMap<>();
    private final Map<String, Long> daily = new LinkedHashMap<>();

    CountryTrafficStore(Path path, int dailyRetentionDays) {
        this.path = path;
        this.dailyRetentionDays = Math.max(30, dailyRetentionDays);
    }

    synchronized void load() throws IOException {
        allTime.clear();
        daily.clear();
        if (!Files.isRegularFile(path)) return;

        Properties properties = new Properties();
        try (InputStream input = Files.newInputStream(path)) {
            properties.load(input);
        }
        for (String key : properties.stringPropertyNames()) {
            long value = parseNonNegative(properties.getProperty(key));
            if (value == 0) continue;
            if (key.startsWith(TOTAL_PREFIX)) {
                String country = normalizeCountry(key.substring(TOTAL_PREFIX.length()));
                allTime.put(country, value);
            } else if (key.startsWith(DAILY_PREFIX)) {
                String suffix = key.substring(DAILY_PREFIX.length());
                int separator = suffix.indexOf('.');
                if (separator != 8) continue;
                String day = suffix.substring(0, separator);
                String country = normalizeCountry(suffix.substring(separator + 1));
                if (isDay(day)) daily.put(dailyKey(day, country), value);
            }
        }
        prune(LocalDate.now());
    }

    synchronized void record(LocalDate day, String country) throws IOException {
        String normalizedCountry = normalizeCountry(country);
        String dayKey = DAY_KEY.format(day);
        allTime.put(normalizedCountry, allTime.getOrDefault(normalizedCountry, 0L) + 1L);
        String aggregateKey = dailyKey(dayKey, normalizedCountry);
        daily.put(aggregateKey, daily.getOrDefault(aggregateKey, 0L) + 1L);
        prune(day);
        save();
    }

    synchronized Snapshot snapshot(LocalDate today) {
        LocalDate cutoff = today.minusDays(29);
        Map<String, Long> recent = new LinkedHashMap<>();
        for (Map.Entry<String, Long> entry : daily.entrySet()) {
            String key = entry.getKey();
            LocalDate day = LocalDate.parse(key.substring(0, 8), DAY_KEY);
            if (!day.isBefore(cutoff) && !day.isAfter(today)) {
                String country = key.substring(9);
                recent.put(country, recent.getOrDefault(country, 0L) + entry.getValue());
            }
        }
        return new Snapshot(sortedRows(allTime), sortedRows(recent),
                sum(allTime), sum(recent), cutoff, today);
    }

    Path getPath() {
        return path;
    }

    private void prune(LocalDate today) {
        LocalDate oldest = today.minusDays(dailyRetentionDays - 1L);
        daily.entrySet().removeIf(entry -> {
            String key = entry.getKey();
            LocalDate day = LocalDate.parse(key.substring(0, 8), DAY_KEY);
            return day.isBefore(oldest);
        });
    }

    private void save() throws IOException {
        Path parent = path.toAbsolutePath().getParent();
        if (parent != null) Files.createDirectories(parent);
        Properties properties = new Properties();
        for (Map.Entry<String, Long> entry : allTime.entrySet()) {
            properties.setProperty(TOTAL_PREFIX + entry.getKey(), Long.toString(entry.getValue()));
        }
        for (Map.Entry<String, Long> entry : daily.entrySet()) {
            properties.setProperty(DAILY_PREFIX + entry.getKey(), Long.toString(entry.getValue()));
        }

        Path directory = parent == null ? Path.of(".").toAbsolutePath() : parent;
        Path temporary = Files.createTempFile(directory, "country-traffic-", ".tmp");
        try {
            try (OutputStream output = Files.newOutputStream(temporary)) {
                properties.store(output, "scSAID country-level aggregate traffic; no IP addresses");
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

    private static List<CountryRow> sortedRows(Map<String, Long> values) {
        List<CountryRow> rows = new ArrayList<>();
        for (Map.Entry<String, Long> entry : values.entrySet()) {
            rows.add(new CountryRow(entry.getKey(), displayName(entry.getKey()), entry.getValue()));
        }
        rows.sort(Comparator.comparingLong(CountryRow::getVisits).reversed()
                .thenComparing(CountryRow::getCountry));
        return Collections.unmodifiableList(rows);
    }

    private static long sum(Map<String, Long> values) {
        long total = 0;
        for (long value : values.values()) total += value;
        return total;
    }

    private static String dailyKey(String day, String country) {
        return day + "." + country;
    }

    private static boolean isDay(String value) {
        try {
            LocalDate.parse(value, DAY_KEY);
            return true;
        } catch (RuntimeException ignored) {
            return false;
        }
    }

    static String normalizeCountry(String value) {
        if (value == null) return "ZZ";
        String normalized = value.trim().toUpperCase(Locale.ROOT);
        return normalized.matches("[A-Z]{2}") ? normalized : "ZZ";
    }

    private static String displayName(String country) {
        if ("ZZ".equals(country)) return "Unknown / unavailable";
        String name = new Locale("", country).getDisplayCountry(Locale.ENGLISH);
        return name == null || name.isBlank() ? country : name;
    }

    private static long parseNonNegative(String value) {
        try {
            return Math.max(0, Long.parseLong(value == null ? "" : value.trim()));
        } catch (NumberFormatException ignored) {
            return 0;
        }
    }

    static final class Snapshot {
        final List<CountryRow> allTime;
        final List<CountryRow> recent30Days;
        final long allTimeTotal;
        final long recent30DaysTotal;
        final LocalDate recentStart;
        final LocalDate recentEnd;

        Snapshot(List<CountryRow> allTime, List<CountryRow> recent30Days,
                 long allTimeTotal, long recent30DaysTotal,
                 LocalDate recentStart, LocalDate recentEnd) {
            this.allTime = allTime;
            this.recent30Days = recent30Days;
            this.allTimeTotal = allTimeTotal;
            this.recent30DaysTotal = recent30DaysTotal;
            this.recentStart = recentStart;
            this.recentEnd = recentEnd;
        }
    }

    static final class CountryRow {
        private final String country;
        private final String label;
        private final long visits;

        CountryRow(String country, String label, long visits) {
            this.country = country;
            this.label = label;
            this.visits = visits;
        }

        String getCountry() { return country; }
        String getLabel() { return label; }
        long getVisits() { return visits; }
    }
}
