package AccessCounter;

import java.io.BufferedReader;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardOpenOption;
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneOffset;
import java.time.format.DateTimeFormatter;
import java.util.ArrayList;
import java.util.Base64;
import java.util.Collections;
import java.util.Comparator;
import java.util.LinkedHashMap;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.TreeMap;

/**
 * Append-only, developer-only ledger of counted page visits. The file is never
 * served by the application; its only reader is the Basic-Auth protected
 * analytics servlet. A malformed trailing line is ignored so an interrupted
 * append cannot damage historical data.
 */
final class DeveloperVisitEventStore {
    private static final DateTimeFormatter DAY_FORMAT = DateTimeFormatter.ISO_LOCAL_DATE;
    private final Path path;

    DeveloperVisitEventStore(Path path) {
        this.path = path;
    }

    synchronized void record(CountryResolver.VisitorLocation location, Instant timestamp, String requestPath)
            throws IOException {
        if (location == null || !location.hasPublicAddress()) return;
        Path parent = path.toAbsolutePath().getParent();
        if (parent != null) Files.createDirectories(parent);
        String line = timestamp.toString() + "\t" + encode(location.getAddress()) + "\t"
                + CountryTrafficStore.normalizeCountry(location.getCountry()) + "\t"
                + encode(normalizePath(requestPath)) + "\n";
        Files.writeString(path, line, StandardCharsets.UTF_8,
                StandardOpenOption.CREATE, StandardOpenOption.WRITE, StandardOpenOption.APPEND);
    }

    synchronized Snapshot snapshot(Instant now, int mapEventLimit) throws IOException {
        List<Event> events = readEvents();
        events.sort(Comparator.comparing(Event::getTimestamp));
        LocalDate today = now.atZone(ZoneOffset.UTC).toLocalDate();
        LocalDate cutoff = today.minusDays(29);
        Instant last24Cutoff = now.minusSeconds(24 * 60 * 60L);

        Map<String, Long> perAddress = new LinkedHashMap<>();
        Map<String, Long> allPages = new LinkedHashMap<>();
        Map<String, Long> recentPages = new LinkedHashMap<>();
        Map<LocalDate, Long> daily = new TreeMap<>();
        Map<String, Long> hourly = new TreeMap<>();
        Set<String> recentAddresses = new LinkedHashSet<>();
        List<Event> numbered = new ArrayList<>(events.size());
        long recentVisits = 0;

        for (Event event : events) {
            long visitNumber = perAddress.getOrDefault(event.address, 0L) + 1L;
            perAddress.put(event.address, visitNumber);
            numbered.add(event.withVisitNumber(visitNumber));
            allPages.put(event.path, allPages.getOrDefault(event.path, 0L) + 1L);
            LocalDate day = event.timestamp.atZone(ZoneOffset.UTC).toLocalDate();
            daily.put(day, daily.getOrDefault(day, 0L) + 1L);
            if (!day.isBefore(cutoff) && !day.isAfter(today)) {
                recentVisits++;
                recentAddresses.add(event.address);
                recentPages.put(event.path, recentPages.getOrDefault(event.path, 0L) + 1L);
            }
            if (!event.timestamp.isBefore(last24Cutoff) && !event.timestamp.isAfter(now)) {
                String hour = event.timestamp.atZone(ZoneOffset.UTC)
                        .withMinute(0).withSecond(0).withNano(0).toInstant().toString();
                hourly.put(hour, hourly.getOrDefault(hour, 0L) + 1L);
            }
        }

        long returningVisitors = perAddress.values().stream().filter(count -> count > 1).count();
        long returnVisits = perAddress.values().stream().mapToLong(count -> Math.max(0L, count - 1L)).sum();
        List<Event> newestFirst = new ArrayList<>(numbered);
        newestFirst.sort(Comparator.comparing(Event::getTimestamp).reversed());
        int limit = Math.max(1, mapEventLimit);
        boolean truncated = newestFirst.size() > limit;
        if (truncated) newestFirst = new ArrayList<>(newestFirst.subList(0, limit));

        return new Snapshot(events.size(), perAddress.size(), returningVisitors, returnVisits,
                recentVisits, recentAddresses.size(), dailySeries(daily, cutoff, today),
                hourlySeries(hourly, now), topRows(allPages, 8), topRows(recentPages, 8),
                Collections.unmodifiableList(newestFirst), truncated,
                visitors(perAddress, numbered, 200));
    }

    Path getPath() { return path; }

    private List<Event> readEvents() throws IOException {
        if (!Files.isRegularFile(path)) return new ArrayList<>();
        List<Event> events = new ArrayList<>();
        try (BufferedReader reader = Files.newBufferedReader(path, StandardCharsets.UTF_8)) {
            String line;
            while ((line = reader.readLine()) != null) {
                Event event = parse(line);
                if (event != null) events.add(event);
            }
        }
        return events;
    }

    private static List<SeriesRow> dailySeries(Map<LocalDate, Long> values, LocalDate start, LocalDate end) {
        List<SeriesRow> rows = new ArrayList<>();
        for (LocalDate day = start; !day.isAfter(end); day = day.plusDays(1)) {
            rows.add(new SeriesRow(DAY_FORMAT.format(day), values.getOrDefault(day, 0L)));
        }
        return rows;
    }

    private static List<SeriesRow> hourlySeries(Map<String, Long> values, Instant now) {
        List<SeriesRow> rows = new ArrayList<>();
        Instant hour = now.atZone(ZoneOffset.UTC).withMinute(0).withSecond(0).withNano(0).toInstant();
        for (int offset = 23; offset >= 0; offset--) {
            Instant point = hour.minusSeconds(offset * 3600L);
            rows.add(new SeriesRow(point.toString(), values.getOrDefault(point.toString(), 0L)));
        }
        return rows;
    }

    private static List<PageRow> topRows(Map<String, Long> pages, int limit) {
        List<PageRow> rows = new ArrayList<>();
        for (Map.Entry<String, Long> entry : pages.entrySet()) rows.add(new PageRow(entry.getKey(), entry.getValue()));
        rows.sort(Comparator.comparingLong(PageRow::getVisits).reversed().thenComparing(PageRow::getPath));
        return Collections.unmodifiableList(rows.subList(0, Math.min(limit, rows.size())));
    }

    private static List<VisitorSummary> visitors(Map<String, Long> perAddress, List<Event> events, int limit) {
        Map<String, Event> first = new LinkedHashMap<>();
        Map<String, Event> last = new LinkedHashMap<>();
        for (Event event : events) {
            first.putIfAbsent(event.address, event);
            last.put(event.address, event);
        }
        List<VisitorSummary> rows = new ArrayList<>();
        for (Map.Entry<String, Long> entry : perAddress.entrySet()) {
            Event firstEvent = first.get(entry.getKey());
            Event lastEvent = last.get(entry.getKey());
            rows.add(new VisitorSummary(entry.getKey(), lastEvent.country, entry.getValue(),
                    firstEvent.timestamp, lastEvent.timestamp, lastEvent.path));
        }
        rows.sort(Comparator.comparingLong(VisitorSummary::getVisits).reversed()
                .thenComparing(VisitorSummary::getLastSeen, Comparator.reverseOrder()));
        return Collections.unmodifiableList(rows.subList(0, Math.min(limit, rows.size())));
    }

    private static Event parse(String line) {
        String[] fields = line.split("\\t", -1);
        if (fields.length != 4) return null;
        try {
            Instant timestamp = Instant.parse(fields[0]);
            String address = decode(fields[1]);
            String path = decode(fields[3]);
            if (address == null || path == null || address.length() > 64 || path.length() > 160) return null;
            return new Event(timestamp, address, CountryTrafficStore.normalizeCountry(fields[2]), path, 0L);
        } catch (RuntimeException ignored) {
            return null;
        }
    }

    private static String normalizePath(String value) {
        if (value == null || value.isBlank()) return "/";
        String path = value.trim().replaceAll("[\\r\\n\\t]", "");
        if (!path.startsWith("/")) path = "/" + path;
        return path.length() > 160 ? path.substring(0, 160) : path;
    }

    private static String encode(String value) {
        return Base64.getUrlEncoder().withoutPadding().encodeToString(value.getBytes(StandardCharsets.UTF_8));
    }

    private static String decode(String value) {
        try { return new String(Base64.getUrlDecoder().decode(value), StandardCharsets.UTF_8); }
        catch (IllegalArgumentException ignored) { return null; }
    }

    static final class Snapshot {
        final long allTimeVisits;
        final long uniqueVisitors;
        final long returningVisitors;
        final long returnVisits;
        final long recent30Visits;
        final long recent30UniqueVisitors;
        final List<SeriesRow> daily30;
        final List<SeriesRow> hourly24;
        final List<PageRow> topPages;
        final List<PageRow> recentTopPages;
        final List<Event> mapEvents;
        final boolean mapEventsTruncated;
        final List<VisitorSummary> returningVisitorRows;

        Snapshot(long allTimeVisits, long uniqueVisitors, long returningVisitors, long returnVisits,
                 long recent30Visits, long recent30UniqueVisitors, List<SeriesRow> daily30,
                 List<SeriesRow> hourly24, List<PageRow> topPages, List<PageRow> recentTopPages,
                 List<Event> mapEvents, boolean mapEventsTruncated,
                 List<VisitorSummary> returningVisitorRows) {
            this.allTimeVisits = allTimeVisits;
            this.uniqueVisitors = uniqueVisitors;
            this.returningVisitors = returningVisitors;
            this.returnVisits = returnVisits;
            this.recent30Visits = recent30Visits;
            this.recent30UniqueVisitors = recent30UniqueVisitors;
            this.daily30 = daily30;
            this.hourly24 = hourly24;
            this.topPages = topPages;
            this.recentTopPages = recentTopPages;
            this.mapEvents = mapEvents;
            this.mapEventsTruncated = mapEventsTruncated;
            this.returningVisitorRows = returningVisitorRows;
        }
    }

    static final class Event {
        private final Instant timestamp;
        private final String address;
        private final String country;
        private final String path;
        private final long visitNumber;

        Event(Instant timestamp, String address, String country, String path, long visitNumber) {
            this.timestamp = timestamp;
            this.address = address;
            this.country = country;
            this.path = path;
            this.visitNumber = visitNumber;
        }
        Event withVisitNumber(long value) { return new Event(timestamp, address, country, path, value); }
        Instant getTimestamp() { return timestamp; }
        String getAddress() { return address; }
        String getCountry() { return country; }
        String getPath() { return path; }
        long getVisitNumber() { return visitNumber; }
    }

    static final class SeriesRow {
        private final String label;
        private final long visits;
        SeriesRow(String label, long visits) { this.label = label; this.visits = visits; }
        String getLabel() { return label; }
        long getVisits() { return visits; }
    }

    static final class PageRow {
        private final String path;
        private final long visits;
        PageRow(String path, long visits) { this.path = path; this.visits = visits; }
        String getPath() { return path; }
        long getVisits() { return visits; }
    }

    static final class VisitorSummary {
        private final String address;
        private final String country;
        private final long visits;
        private final Instant firstSeen;
        private final Instant lastSeen;
        private final String lastPath;
        VisitorSummary(String address, String country, long visits, Instant firstSeen, Instant lastSeen, String lastPath) {
            this.address = address; this.country = country; this.visits = visits;
            this.firstSeen = firstSeen; this.lastSeen = lastSeen; this.lastPath = lastPath;
        }
        String getAddress() { return address; }
        String getCountry() { return country; }
        long getVisits() { return visits; }
        Instant getFirstSeen() { return firstSeen; }
        Instant getLastSeen() { return lastSeen; }
        String getLastPath() { return lastPath; }
    }
}
