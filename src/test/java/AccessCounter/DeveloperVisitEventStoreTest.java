package AccessCounter;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;

import java.nio.file.Path;
import java.time.Instant;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;

class DeveloperVisitEventStoreTest {
    @TempDir
    Path temporaryDirectory;

    @Test
    void retainsAllTimeEventsAndBuildsRecurrencePageAndTimeAnalytics() throws Exception {
        DeveloperVisitEventStore store = new DeveloperVisitEventStore(
                temporaryDirectory.resolve("developer-visit-events.tsv"));
        CountryResolver.VisitorLocation uk = new CountryResolver.VisitorLocation("8.8.8.8", "GB");
        CountryResolver.VisitorLocation us = new CountryResolver.VisitorLocation("1.1.1.1", "US");
        store.record(uk, Instant.parse("2026-06-01T09:10:00Z"), "/browse.jsp");
        store.record(uk, Instant.parse("2026-07-12T12:10:00Z"), "/details.jsp");
        store.record(us, Instant.parse("2026-07-13T12:45:00Z"), "/browse.jsp");

        DeveloperVisitEventStore.Snapshot snapshot = store.snapshot(
                Instant.parse("2026-07-13T13:00:00Z"), 100);

        assertEquals(3, snapshot.allTimeVisits);
        assertEquals(2, snapshot.uniqueVisitors);
        assertEquals(1, snapshot.returningVisitors);
        assertEquals(1, snapshot.returnVisits);
        assertEquals(2, snapshot.recent30Visits);
        assertEquals(2, snapshot.recent30UniqueVisitors);
        assertEquals("/browse.jsp", snapshot.topPages.get(0).getPath());
        assertEquals(2, snapshot.topPages.get(0).getVisits());
        assertEquals(30, snapshot.daily30.size());
        assertEquals(24, snapshot.hourly24.size());
        assertEquals(3, snapshot.mapEvents.size());
        assertEquals(2, snapshot.returningVisitorRows.get(0).getVisits());
        assertEquals(2, snapshot.mapEvents.stream().filter(event -> event.getAddress().equals("8.8.8.8"))
                .mapToLong(DeveloperVisitEventStore.Event::getVisitNumber).max().orElse(0));
    }

    @Test
    void ignoresUnavailableAddressesAndCapsOnlyTheDisplayedMapEvents() throws Exception {
        DeveloperVisitEventStore store = new DeveloperVisitEventStore(
                temporaryDirectory.resolve("events.tsv"));
        store.record(CountryResolver.VisitorLocation.unavailable(), Instant.now(), "/");
        store.record(new CountryResolver.VisitorLocation("9.9.9.9", "US"),
                Instant.parse("2026-07-13T12:00:00Z"), "/");
        store.record(new CountryResolver.VisitorLocation("8.8.4.4", "GB"),
                Instant.parse("2026-07-13T12:01:00Z"), "/");

        DeveloperVisitEventStore.Snapshot snapshot = store.snapshot(
                Instant.parse("2026-07-13T12:02:00Z"), 1);
        assertEquals(2, snapshot.allTimeVisits);
        assertEquals(1, snapshot.mapEvents.size());
        assertFalse(snapshot.mapEvents.isEmpty());
        assertEquals(true, snapshot.mapEventsTruncated);
    }
}
