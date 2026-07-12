package AccessCounter;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;

import java.nio.file.Path;
import java.time.Instant;

import static org.junit.jupiter.api.Assertions.assertEquals;

class TrafficHistoryStoreTest {
    @TempDir
    Path temporaryDirectory;

    @Test
    void persistsHourlyBucketsAndBuildsRollingAndAverageSeries() throws Exception {
        Path file = temporaryDirectory.resolve("runtime/traffic-history.properties");
        TrafficHistoryStore store = new TrafficHistoryStore(file);
        store.load();

        store.record(Instant.parse("2026-07-10T10:05:00Z"));
        store.record(Instant.parse("2026-07-10T10:55:00Z"));
        store.record(Instant.parse("2026-07-11T10:10:00Z"));
        store.record(Instant.parse("2026-07-11T14:01:00Z"));
        store.record(Instant.parse("2026-07-11T14:59:00Z"));

        TrafficHistoryStore reloaded = new TrafficHistoryStore(file);
        reloaded.load();
        TrafficHistoryStore.Snapshot snapshot =
                reloaded.snapshot(Instant.parse("2026-07-11T14:59:30Z"));

        assertEquals("2026-07-10", snapshot.historyStart.toString());
        assertEquals(2, snapshot.daysIncluded);
        assertEquals(24, snapshot.last24Labels.size());
        assertEquals(24, snapshot.last24Values.size());
        assertEquals(3, snapshot.last24Total);
        assertEquals(1.5, snapshot.averageValues.get(10), 0.0001);
        assertEquals(1.0, snapshot.averageValues.get(14), 0.0001);
        assertEquals(2.5, snapshot.averageDaily, 0.0001);
    }

    @Test
    void emptyHistoryReturnsCompleteZeroFilledSeries() throws Exception {
        TrafficHistoryStore store = new TrafficHistoryStore(
                temporaryDirectory.resolve("empty.properties"));
        store.load();
        TrafficHistoryStore.Snapshot snapshot =
                store.snapshot(Instant.parse("2026-07-11T14:00:00Z"));

        assertEquals(0, snapshot.daysIncluded);
        assertEquals(24, snapshot.last24Values.size());
        assertEquals(24, snapshot.averageValues.size());
        assertEquals(0, snapshot.last24Total);
        assertEquals(0.0, snapshot.averageDaily, 0.0);
    }
}
