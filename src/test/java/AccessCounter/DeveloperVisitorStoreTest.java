package AccessCounter;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;

import java.nio.file.Path;
import java.time.Instant;
import java.util.List;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

class DeveloperVisitorStoreTest {
    @TempDir
    Path temporaryDirectory;

    @Test
    void persistsProtectedAddressHistoryAndAggregatesRepeatVisits() throws Exception {
        Path file = temporaryDirectory.resolve("runtime/developer-visitors.properties");
        DeveloperVisitorStore store = new DeveloperVisitorStore(file, 90);
        store.load();
        CountryResolver.VisitorLocation location =
                new CountryResolver.VisitorLocation("8.8.8.8", "US");
        store.record(location, Instant.parse("2026-07-13T12:00:00Z"));
        store.record(location, Instant.parse("2026-07-13T13:00:00Z"));

        DeveloperVisitorStore reloaded = new DeveloperVisitorStore(file, 90);
        reloaded.load();
        List<DeveloperVisitorStore.Visitor> visitors = reloaded.recent(10);

        assertEquals(1, visitors.size());
        DeveloperVisitorStore.Visitor visitor = visitors.get(0);
        assertEquals("8.8.8.8", visitor.getAddress());
        assertEquals("US", visitor.getCountry());
        assertEquals(2, visitor.getVisits());
        assertEquals(Instant.parse("2026-07-13T12:00:00Z"), visitor.getFirstSeen());
        assertEquals(Instant.parse("2026-07-13T13:00:00Z"), visitor.getLastSeen());
        assertTrue(file.toFile().isFile());
    }

    @Test
    void ignoresLocationsWithoutAPublicAddress() throws Exception {
        DeveloperVisitorStore store = new DeveloperVisitorStore(
                temporaryDirectory.resolve("developer-visitors.properties"), 90);
        store.record(CountryResolver.VisitorLocation.unavailable(), Instant.now());
        assertTrue(store.recent(10).isEmpty());
    }
}
