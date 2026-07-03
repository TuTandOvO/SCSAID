# Style Translation — HumanBase-inspired scSAID navigation and tables

## Direction

Adopt HumanBase's restrained scientific interface grammar—flat grey tabs, compact white dropdown cards, and dense hairline tables—while retaining scSAID's name, blue accent, routes, analysis behavior, and responsive adaptations.

## Token map (before → after)

| Header token or pattern | Before | After | Reference signal |
| --- | --- | --- | --- |
| Tab hover surface | Transparent | `#f5f5f5` | HumanBase active/hover tab |
| Navigation text | `#777777` | Retained | HumanBase neutral navigation |
| Dropdown radius | 12px | 4px | Compact Bootstrap-like card |
| Dropdown border | Very light 8% border | `rgba(0,0,0,.15)` | Defined reference edge |
| Dropdown shadow | `0 12px 24px rgba(...,.2)` | `0 6px 12px rgba(0,0,0,.175)` | Reference elevation |
| Dropdown vertical gap | 0.4rem | Attached at `top: 100%` | Reference tab/card connection |
| Dropdown item height | 44px | Compact 34–38px | Reference information density |
| Search width | 17rem | 12rem desktop; 12.5rem tablet max | Requested ~30% reduction |
| Brand accent | `#337ab7` | Retained | Protected scSAID equity |
| Typography | Nunito | Retained | Already matches reference family |
| Table base size | 12.6–14px depending on page | 13px | HumanBase 13px root / 1rem table text |
| Table cell padding | 12–16px | 8px | HumanBase Tissue Networks table |
| Table header | Uppercase light labels on varied muted fills | `#e9ecef`, normal case, 600 weight | HumanBase Tissue Networks table |
| Table body rules | Per-row dividers | Alternating white / `#f9f9f9`, no body gridlines | HumanBase Tissue Networks table |
| Table frame | Rounded/bordered on Details | Flat, square, borderless | HumanBase Tissue Networks table |

## New patterns

- Reusable navigation menu button with a CSS caret and `aria-expanded` state.
- Desktop dropdown cards that open by hover, focus, or click.
- Navigate menu containing Search DEGs and Compare conditions.
- About menu containing How to Cite and What's New.
- Original monochrome cut-out glyphs identify every top-level scSAID destination and inherit each tab's state color.
- Mobile drawer keeps submenu destinations visible and touch-friendly.
- `humanbase-tables.css` provides one reusable `hb-table` / `hb-table-shell` layer for static and DataTables-driven results.
- Wide Gene Search and Browse results retain accessible mobile record layouts, restyled with the same compact neutral vocabulary.

## Fonts

Nunito remains the only family. The affected table pages now request its open 600 face in addition to 300 so header weight matches the reference without synthetic bolding.

## Decisions

- Brand color: keep scSAID blue as the accent.
- Boldness: faithful but restrained; transfer menu geometry, density, and interaction—not HumanBase assets or exact feature content.
- Scope: header/navigation plus Gene Search and Details DEG tables. Browse retains its original dataset-table treatment.

## IP cleanliness

No HumanBase logo, icon, image, copy, class name, framework code, or licensed asset will be imported. All markup, CSS, and interaction code will be authored for scSAID.
