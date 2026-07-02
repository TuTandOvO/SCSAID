package AccessCounter;

import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.nio.file.AtomicMoveNotSupportedException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardCopyOption;
import java.time.LocalDate;
import java.util.Properties;

/** Durable, atomic file storage for the site visit counter. */
final class CounterStore {
    private final Path path;

    CounterStore(Path path) {
        this.path = path;
    }

    Snapshot load(LocalDate today) throws IOException {
        if (!Files.isRegularFile(path)) {
            return new Snapshot(0, 0, today);
        }

        Properties properties = new Properties();
        try (InputStream input = Files.newInputStream(path)) {
            properties.load(input);
        }

        long total = parseNonNegative(properties.getProperty("totalCount"));
        long daily = parseNonNegative(properties.getProperty("dailyCount"));
        LocalDate savedDate = parseDate(properties.getProperty("currentDate"), today);
        if (!today.equals(savedDate)) {
            daily = 0;
            savedDate = today;
        }
        return new Snapshot(total, daily, savedDate);
    }

    void save(long total, long daily, LocalDate date) throws IOException {
        Path parent = path.toAbsolutePath().getParent();
        if (parent != null) {
            Files.createDirectories(parent);
        }

        Properties properties = new Properties();
        properties.setProperty("totalCount", Long.toString(Math.max(0, total)));
        properties.setProperty("dailyCount", Long.toString(Math.max(0, daily)));
        properties.setProperty("currentDate", date.toString());

        Path directory = parent == null ? path.toAbsolutePath().getParent() : parent;
        if (directory == null) {
            directory = Path.of(".").toAbsolutePath();
        }
        Path temporary = Files.createTempFile(directory, "access-counter-", ".tmp");
        try {
            try (OutputStream output = Files.newOutputStream(temporary)) {
                properties.store(output, "scSAID access counter");
            }
            try {
                Files.move(temporary, path, StandardCopyOption.ATOMIC_MOVE, StandardCopyOption.REPLACE_EXISTING);
            } catch (AtomicMoveNotSupportedException ignored) {
                Files.move(temporary, path, StandardCopyOption.REPLACE_EXISTING);
            }
        } finally {
            Files.deleteIfExists(temporary);
        }
    }

    Path getPath() {
        return path;
    }

    private static long parseNonNegative(String value) {
        if (value == null) return 0;
        try {
            return Math.max(0, Long.parseLong(value.trim()));
        } catch (NumberFormatException ignored) {
            return 0;
        }
    }

    private static LocalDate parseDate(String value, LocalDate fallback) {
        if (value == null) return fallback;
        try {
            return LocalDate.parse(value.trim());
        } catch (RuntimeException ignored) {
            return fallback;
        }
    }

    static final class Snapshot {
        final long total;
        final long daily;
        final LocalDate date;

        Snapshot(long total, long daily, LocalDate date) {
            this.total = total;
            this.daily = daily;
            this.date = date;
        }
    }
}
