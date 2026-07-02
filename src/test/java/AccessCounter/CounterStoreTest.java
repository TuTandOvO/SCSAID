package AccessCounter;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;

import java.nio.file.Files;
import java.nio.file.Path;
import java.time.LocalDate;

import static org.junit.jupiter.api.Assertions.assertEquals;

class CounterStoreTest {
    @TempDir
    Path temporaryDirectory;

    @Test
    void persistsCountsAcrossStoreInstances() throws Exception {
        Path file = temporaryDirectory.resolve("runtime/access-counter.properties");
        LocalDate date = LocalDate.of(2026, 7, 2);

        new CounterStore(file).save(1842, 37, date);
        CounterStore.Snapshot loaded = new CounterStore(file).load(date);

        assertEquals(1842, loaded.total);
        assertEquals(37, loaded.daily);
        assertEquals(date, loaded.date);
    }

    @Test
    void dateRolloverResetsOnlyDailyCount() throws Exception {
        Path file = temporaryDirectory.resolve("access-counter.properties");
        LocalDate yesterday = LocalDate.of(2026, 7, 1);
        LocalDate today = yesterday.plusDays(1);

        new CounterStore(file).save(1842, 37, yesterday);
        CounterStore.Snapshot loaded = new CounterStore(file).load(today);

        assertEquals(1842, loaded.total);
        assertEquals(0, loaded.daily);
        assertEquals(today, loaded.date);
    }

    @Test
    void malformedValuesCannotCreateNegativeOrBrokenCounts() throws Exception {
        Path file = temporaryDirectory.resolve("access-counter.properties");
        Files.writeString(file, "totalCount=broken\ndailyCount=-9\ncurrentDate=not-a-date\n");
        LocalDate today = LocalDate.of(2026, 7, 2);

        CounterStore.Snapshot loaded = new CounterStore(file).load(today);

        assertEquals(0, loaded.total);
        assertEquals(0, loaded.daily);
        assertEquals(today, loaded.date);
    }
}
