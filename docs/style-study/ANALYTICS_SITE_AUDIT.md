# Site Audit — scSAID private visitor analytics

## Stack and styling layer

- Server-rendered JSP backed by Java analytics stores and a protected JSON servlet.
- Dashboard markup is isolated in `developer-traffic.jsp`; presentation and behavior are isolated in `developer-traffic.css` and `country-traffic.js`.
- Leaflet, TopoJSON, and all map boundaries are self-hosted.

## Existing behavior and defects

- The API retains UTC `Instant` values, while the browser currently formats them back to UTC with milliseconds.
- Returning visitor rows are summaries for every visitor and do not expose numbered event histories.
- Country and region placement relies on a partial coordinate table; `HK` falls through to the generic `[20, 0]` marker.
- Aggregate map information is duplicated in a click popup and a permanent side panel.

## Protected equity and constraints

- Retain scSAID blue, Nunito/system sans typography, Basic Auth protection, routes, metrics, and first-party data collection.
- Do not add third-party maps, analytics, city coordinates, ASN, or ISP storage.
- Preserve keyboard and touch access, live 30-second refreshes, and reduced-motion support.
