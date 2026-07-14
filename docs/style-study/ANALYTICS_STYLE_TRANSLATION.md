# Style Translation — scSAID visitor analytics

## Direction

Translate the reference's compact operational rhythm into the existing scSAID dashboard: flat bordered sections, concise metrics, a full-width map with hover detail, and expandable visitor timelines. The result remains visibly scSAID and does not import reference assets.

## Token map

| Role | Before | After |
| --- | --- | --- |
| Canvas | `#fff` | `#f7f8fa` with white working surfaces |
| Ink | `#323232` | `#2f3438` |
| Muted text | `#777` / `#888` | `#66727a` with AA contrast |
| Border | `#dedede` | `#dde2e6` hairlines |
| Accent | `#337ab7` | retained scSAID blue |
| Corners | mostly square | 2–6px functional radii |
| Elevation | small shadow on every panel | borders for panels; short shadow only for floating tooltips |
| Density | roomy headings and cards | 10–20px product spacing and compact tables |

## New patterns

- Local-time label derived from the administrator's browser timezone.
- Expandable returning-visitor summary rows with numbered visit histories.
- Leaflet hover/focus tooltip with aggregated visit facts and touch fallback.
- Boundary-derived country/region centroids with explicit Hong Kong and Macao aliases and no geographic default fallback.

## Decisions

- Keep scSAID blue and the existing type family.
- Apply the compact treatment to the full protected dashboard.
- Keep geographic detail region-level and self-hosted.
- Use faithful information density and disclosure patterns without copying the reference's branding, assets, or implementation.
