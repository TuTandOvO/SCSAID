# Style Profile — hb.flatironinstitute.org

## Study scope and evidence

This profile covers HumanBase's global navigation and the Tissue Networks table on the public download page. It is based on the user-provided navigation screenshot and HumanBase's public server-rendered HTML/CSS. Browser automation was unavailable, so computed-style sampling and new desktop/mobile screenshots could not be captured.

## One-line vibe

Quiet scientific utility: translucent white navigation, neutral grey labels, compact Bootstrap-like dropdown cards, and restrained blue interaction states.

## Palette (with roles)

- Canvas: `#ffffff` — navigation and dropdown surface.
- Ink: `#333333` to `#444444` — menu entries and primary copy.
- Muted navigation text: `#777777`.
- Hover surface: approximately `#f5f5f5`.
- Border: `#dddddd` / `rgba(0, 0, 0, 0.15)`.
- Accent: `#337ab7` — links and interaction emphasis; used sparingly.
- Temperature and saturation: neutral, low saturation, with one familiar scientific blue.

## Typography

- Family: Nunito, sans-serif.
- Navigation: approximately 14px, regular weight, normal case.
- Dropdown: approximately 14px with compact line height; feature names use stronger emphasis where descriptions follow.
- Scale: tight product-interface scale rather than display typography.

## Spacing and density

- Feel: balanced and compact.
- Header height: approximately 50px.
- Top-level navigation padding: approximately 15px vertically and 20px horizontally.
- Dropdown item padding: compact vertical rhythm with approximately 20px left inset.
- Tissue Networks table: 13px base text with 8px cell padding and a 1rem bottom margin.

## Shape language

- Dropdown radius: 4px.
- Border: 1px neutral hairline.
- Tabs: rectangular, with a light-grey hover/active surface rather than pills.
- Tables: square and flat, with collapsed borders, no enclosing radius, no body gridlines, and one header separator.

## Table vocabulary

- Table text: `#212529` on white, left aligned and vertically centered.
- Header: `#e9ecef`, 600 weight, normal case, with a `1px solid #dee2e6` bottom rule.
- Body: white rows without horizontal or vertical borders.
- Exact measurements: `padding: 8px`, `font-size: 1rem` against HumanBase's 13px root size.
- Adaptation for scSAID: preserve quiet row hover, selection, sorting, pagination, and narrow-screen label/value presentation where functionality requires them.

## Elevation

- Conventional utility elevation: `0 6px 12px rgba(0, 0, 0, 0.175)`.
- Header itself remains visually flat.

## Motion vocabulary

- Restrained and functional.
- Short hover/focus transitions; no decorative choreography.

## Texture and effects

- Header uses translucent white over the page.
- Dropdowns are opaque white cards with a border and modest shadow.

## Imagery treatment

Not applicable to the navigation and table transfer.

## Microcopy tone

Direct scientific labels in title case; short, descriptive menu names.

## Do-not-copy list

- HumanBase logo and wordmark.
- HumanBase/Font Awesome menu icons.
- HumanBase feature names, descriptions, routes, and menu contents.
- Reference-specific imagery and branded assets.
