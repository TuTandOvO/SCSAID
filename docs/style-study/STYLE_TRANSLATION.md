# Style Translation — HumanBase-inspired scSAID navigation

## Direction

Adopt HumanBase's restrained scientific navigation grammar—flat grey tabs and compact white dropdown cards—while retaining scSAID's name, blue accent, routes, search behavior, and responsive drawer.

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

## New patterns

- Reusable navigation menu button with a CSS caret and `aria-expanded` state.
- Desktop dropdown cards that open by hover, focus, or click.
- Navigate menu containing Search DEGs and Compare conditions.
- About menu containing How to Cite and What's New.
- Mobile drawer keeps submenu destinations visible and touch-friendly.

## Fonts

No font is added. scSAID already uses the open Nunito family that matches the reference's navigation personality.

## Decisions

- Brand color: keep scSAID blue as the accent.
- Boldness: faithful but restrained; transfer menu geometry, density, and interaction—not HumanBase assets or exact feature content.
- Scope: header/navigation only.

## IP cleanliness

No HumanBase logo, icon, image, copy, class name, framework code, or licensed asset will be imported. All markup, CSS, and interaction code will be authored for scSAID.
