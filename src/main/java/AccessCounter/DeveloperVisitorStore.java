package AccessCounter;

import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.nio.charset.StandardCharsets;
import java.nio.file.AtomicMoveNotSupportedException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardCopyOption;
import java.time.Instant;
import java.util.ArrayList;
import java.util.Base64;
import java.util.Comparator;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Properties;

/**
 * Developer-only visitor-address history. This is never mapped publicly: the
 * sole JSON reader is protected by DeveloperAnalyticsFilter.
 */
final class DeveloperVisitorStore {
    private static final String COUNT = "count.";
    private static final String FIRST = "first.";
    private static final String LAST = "last.";
    private static final String COUNTRY = "country.";

    private final Path path;
    /** A non-positive value retains the protected address aggregate indefinitely. */
    private final int retentionDays;
    private final Map<String, Visitor> visitors = new LinkedHashMap<>();

    DeveloperVisitorStore(Path path, int retentionDays) {
        this.path = path;
        this.retentionDays = retentionDays;
    }

    synchronized void load() throws IOException {
        visitors.clear();
        if (!Files.isRegularFile(path)) return;
        Properties properties = new Properties();
        try (InputStream input = Files.newInputStream(path)) {
            properties.load(input);
        }
        for (String key : properties.stringPropertyNames()) {
            if (!key.startsWith(COUNT)) continue;
            String id = key.substring(COUNT.length());
            String address = decode(id);
            if (address == null) continue;
            long count = parseNonNegative(properties.getProperty(key));
            Instant first = parseInstant(properties.getProperty(FIRST + id));
            Instant last = parseInstant(properties.getProperty(LAST + id));
            if (count == 0 || first == null || last == null) continue;
            visitors.put(address, new Visitor(address,
                    CountryTrafficStore.normalizeCountry(properties.getProperty(COUNTRY + id)),
                    count, first, last));
        }
        prune(Instant.now());
    }

    synchronized void record(CountryResolver.VisitorLocation location, Instant now) throws IOException {
        if (location == null || !location.hasPublicAddress()) return;
        Visitor prior = visitors.get(location.getAddress());
        Visitor updated = prior == null
                ? new Visitor(location.getAddress(), location.getCountry(), 1, now, now)
                : new Visitor(location.getAddress(), location.getCountry(), prior.visits + 1,
                        prior.firstSeen, now);
        visitors.put(updated.address, updated);
        prune(now);
        save();
    }

    synchronized List<Visitor> recent(int limit) {
        List<Visitor> rows = new ArrayList<>(visitors.values());
        rows.sort(Comparator.comparing(Visitor::getLastSeen).reversed()
                .thenComparing(Visitor::getAddress));
        return rows.subList(0, Math.min(Math.max(0, limit), rows.size()));
    }

    Path getPath() { return path; }

    private void prune(Instant now) {
        if (retentionDays <= 0) return;
        Instant cutoff = now.minus(retentionDays, java.time.temporal.ChronoUnit.DAYS);
        visitors.entrySet().removeIf(entry -> entry.getValue().lastSeen.isBefore(cutoff));
    }

    private void save() throws IOException {
        Path parent = path.toAbsolutePath().getParent();
        if (parent != null) Files.createDirectories(parent);
        Properties properties = new Properties();
        for (Visitor visitor : visitors.values()) {
            String id = encode(visitor.address);
            properties.setProperty(COUNT + id, Long.toString(visitor.visits));
            properties.setProperty(FIRST + id, visitor.firstSeen.toString());
            properties.setProperty(LAST + id, visitor.lastSeen.toString());
            properties.setProperty(COUNTRY + id, visitor.country);
        }
        Path directory = parent == null ? Path.of(".").toAbsolutePath() : parent;
        Path temporary = Files.createTempFile(directory, "developer-visitor-", ".tmp");
        try {
            try (OutputStream output = Files.newOutputStream(temporary)) {
                properties.store(output, "scSAID developer-only visitor address history");
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

    private static String encode(String value) {
        return Base64.getUrlEncoder().withoutPadding()
                .encodeToString(value.getBytes(StandardCharsets.UTF_8));
    }

    private static String decode(String value) {
        try {
            return new String(Base64.getUrlDecoder().decode(value), StandardCharsets.UTF_8);
        } catch (IllegalArgumentException ignored) {
            return null;
        }
    }

    private static long parseNonNegative(String value) {
        try { return Math.max(0, Long.parseLong(value == null ? "" : value.trim())); }
        catch (NumberFormatException ignored) { return 0; }
    }

    private static Instant parseInstant(String value) {
        try { return Instant.parse(value); }
        catch (RuntimeException ignored) { return null; }
    }

    static final class Visitor {
        private final String address;
        private final String country;
        private final long visits;
        private final Instant firstSeen;
        private final Instant lastSeen;

        Visitor(String address, String country, long visits, Instant firstSeen, Instant lastSeen) {
            this.address = address;
            this.country = country;
            this.visits = visits;
            this.firstSeen = firstSeen;
            this.lastSeen = lastSeen;
        }

        String getAddress() { return address; }
        String getCountry() { return country; }
        long getVisits() { return visits; }
        Instant getFirstSeen() { return firstSeen; }
        Instant getLastSeen() { return lastSeen; }
    }
}
