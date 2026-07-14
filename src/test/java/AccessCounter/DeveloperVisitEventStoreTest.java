package AccessCounter;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;

import java.nio.file.Path;
import java.time.Instant;
import java.util.List;
import java.util.stream.Collectors;

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
        CountryResolver.VisitorLocation us = new CountryResolver.VisitorLocation(
                "1.1.1.1", "US", "CA", "California");
        DeveloperVisitEventStore.UserContext returning = new DeveloperVisitEventStore.UserContext(
                "visitor-alpha", "agent-a", "Chrome", "macOS", "en-GB");
        DeveloperVisitEventStore.UserContext another = new DeveloperVisitEventStore.UserContext(
                "visitor-beta", "agent-b", "Safari", "iOS", "en-US");
        store.record(uk, returning, Instant.parse("2026-06-01T09:10:00Z"), "/browse.jsp");
        store.record(uk, returning, Instant.parse("2026-07-12T12:10:00Z"), "/details.jsp");
        store.record(us, another, Instant.parse("2026-07-13T12:45:00Z"), "/browse.jsp");

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
        assertEquals("visitor-alpha", snapshot.returningVisitorRows.get(0).getVisitorId());
        assertEquals("Chrome", snapshot.returningVisitorRows.get(0).getBrowser());
        assertEquals(1, snapshot.returningVisitorRows.size());
        assertEquals(List.of(2L, 1L), snapshot.returningVisitorRows.get(0).getHistory().stream()
                .map(DeveloperVisitEventStore.VisitRecord::getVisitNumber).collect(Collectors.toList()));
        assertEquals("/details.jsp", snapshot.returningVisitorRows.get(0).getHistory().get(0).getPath());
        assertFalse(snapshot.returningVisitorRows.get(0).isHistoryTruncated());
        assertEquals("CA", snapshot.mapEvents.stream().filter(event -> "US".equals(event.getCountry()))
                .findFirst().orElseThrow().getRegionCode());
        assertEquals("California", snapshot.mapEvents.stream().filter(event -> "US".equals(event.getCountry()))
                .findFirst().orElseThrow().getRegionName());
        assertEquals(2, snapshot.mapEvents.stream().filter(event -> event.getVisitorId().equals("visitor-alpha"))
                .mapToLong(DeveloperVisitEventStore.Event::getVisitNumber).max().orElse(0));
    }

    @Test
    void returningHistoryFollowsVisitorAcrossAddressesAndCapsTheDisplayedTimeline() throws Exception {
        DeveloperVisitEventStore store = new DeveloperVisitEventStore(
                temporaryDirectory.resolve("return-history.tsv"));
        DeveloperVisitEventStore.UserContext visitor = new DeveloperVisitEventStore.UserContext(
                "travelling-visitor", "agent", "Safari", "macOS", "en-GB");
        Instant start = Instant.parse("2026-01-01T00:00:00Z");
        for (int index = 0; index < 105; index++) {
            CountryResolver.VisitorLocation location = index < 50
                    ? new CountryResolver.VisitorLocation("8.8.8.8", "GB", "ENG", "England")
                    : new CountryResolver.VisitorLocation("1.1.1.1", "US", "CA", "California");
            store.record(location, visitor, start.plusSeconds(index * 60L), "/details.jsp?visit=" + index);
        }

        DeveloperVisitEventStore.Snapshot snapshot = store.snapshot(start.plusSeconds(106 * 60L), 500);
        DeveloperVisitEventStore.VisitorSummary summary = snapshot.returningVisitorRows.get(0);

        assertEquals(105, summary.getVisits());
        assertEquals(100, summary.getHistory().size());
        assertEquals(105, summary.getHistory().get(0).getVisitNumber());
        assertEquals(6, summary.getHistory().get(99).getVisitNumber());
        assertEquals("1.1.1.1", summary.getHistory().get(0).getAddress());
        assertEquals("California", summary.getHistory().get(0).getRegionName());
        assertEquals(true, summary.isHistoryTruncated());
    }

    @Test
    void ignoresUnavailableAddressesAndCapsOnlyTheDisplayedMapEvents() throws Exception {
        DeveloperVisitEventStore store = new DeveloperVisitEventStore(
                temporaryDirectory.resolve("events.tsv"));
        store.record(CountryResolver.VisitorLocation.unavailable(), DeveloperVisitEventStore.UserContext.legacy(),
                Instant.now(), "/");
        store.record(new CountryResolver.VisitorLocation("9.9.9.9", "US"), new DeveloperVisitEventStore.UserContext(
                        "visitor-a", "agent-a", "Chrome", "Linux", "en"),
                Instant.parse("2026-07-13T12:00:00Z"), "/");
        store.record(new CountryResolver.VisitorLocation("8.8.4.4", "GB"), new DeveloperVisitEventStore.UserContext(
                        "visitor-b", "agent-b", "Firefox", "Windows", "en"),
                Instant.parse("2026-07-13T12:01:00Z"), "/");

        DeveloperVisitEventStore.Snapshot snapshot = store.snapshot(
                Instant.parse("2026-07-13T12:02:00Z"), 1);
        assertEquals(2, snapshot.allTimeVisits);
        assertEquals(1, snapshot.mapEvents.size());
        assertFalse(snapshot.mapEvents.isEmpty());
        assertEquals(true, snapshot.mapEventsTruncated);
    }

    @Test
    void filtersProbePathsAndUnknownCountriesFromDashboardAggregates() throws Exception {
        DeveloperVisitEventStore store = new DeveloperVisitEventStore(
                temporaryDirectory.resolve("filtered.tsv"));
        DeveloperVisitEventStore.UserContext context = new DeveloperVisitEventStore.UserContext(
                "visitor-filter", "agent", "Chrome", "macOS", "en");
        store.record(new CountryResolver.VisitorLocation("9.9.9.9", "US"), context,
                Instant.parse("2026-07-13T12:00:00Z"), "/browse.jsp");
        store.record(new CountryResolver.VisitorLocation("9.9.9.9", "US"), context,
                Instant.parse("2026-07-13T12:01:00Z"), "/wp-admin/install.php");
        store.record(new CountryResolver.VisitorLocation("8.8.8.8", "ZZ"),
                new DeveloperVisitEventStore.UserContext("visitor-unknown", "agent", "Chrome", "macOS", "en"),
                Instant.parse("2026-07-13T12:02:00Z"), "/details.jsp");

        DeveloperVisitEventStore.Snapshot snapshot = store.snapshot(
                Instant.parse("2026-07-13T12:05:00Z"), 100);

        assertEquals(2, snapshot.topPages.size());
        assertEquals("/browse.jsp", snapshot.topPages.get(0).getPath());
        assertEquals(0, snapshot.topPages.stream()
                .filter(row -> row.getPath().contains("wp-admin")).count());
        assertEquals(2, snapshot.mapEvents.size());
        assertEquals(0, snapshot.mapEvents.stream().filter(event -> "ZZ".equals(event.getCountry())).count());
    }
}
