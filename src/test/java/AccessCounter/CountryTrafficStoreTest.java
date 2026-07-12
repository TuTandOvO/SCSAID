package AccessCounter;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;

import java.nio.file.Files;
import java.nio.file.Path;
import java.time.LocalDate;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;

class CountryTrafficStoreTest {
    @TempDir
    Path temporaryDirectory;

    @Test
    void persistsOnlyCountryAggregatesAndBuildsRecentSnapshot() throws Exception {
        Path file = temporaryDirectory.resolve("runtime/country-traffic.properties");
        CountryTrafficStore store = new CountryTrafficStore(file, 365);
        store.load();
        store.record(LocalDate.of(2026, 7, 1), "GB");
        store.record(LocalDate.of(2026, 7, 11), "US");
        store.record(LocalDate.of(2026, 7, 11), "US");
        store.record(LocalDate.of(2026, 7, 11), "not-a-country");

        CountryTrafficStore reloaded = new CountryTrafficStore(file, 365);
        reloaded.load();
        CountryTrafficStore.Snapshot snapshot = reloaded.snapshot(LocalDate.of(2026, 7, 11));

        assertEquals(4, snapshot.allTimeTotal);
        assertEquals(4, snapshot.recent30DaysTotal);
        assertEquals("US", snapshot.allTime.get(0).getCountry());
        assertEquals(2, snapshot.allTime.get(0).getVisits());
        String stored = Files.readString(file);
        assertFalse(stored.contains("127.0.0.1"));
        assertFalse(stored.contains("X-Real-IP"));
    }

    @Test
    void prunesOldDailyEntriesButKeepsAllTimeCountryTotals() throws Exception {
        CountryTrafficStore store = new CountryTrafficStore(
                temporaryDirectory.resolve("countries.properties"), 30);
        store.load();
        store.record(LocalDate.of(2026, 5, 1), "GB");
        store.record(LocalDate.of(2026, 7, 1), "US");

        CountryTrafficStore.Snapshot snapshot = store.snapshot(LocalDate.of(2026, 7, 1));
        assertEquals(2, snapshot.allTimeTotal);
        assertEquals(1, snapshot.recent30DaysTotal);
    }
}
