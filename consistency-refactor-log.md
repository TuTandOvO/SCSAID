# Consistency Refactor Log

Design-consistency pass to make every page a natural extension of the home page. Scope:
visual/style only — **no layout, content, behavior, data, API, or biological-analysis code
was changed**. All edits are in `src/main/webapp/` (source of truth; `target/` is build output).

Approach: **Moderate** — align values to the existing `design-system.css` tokens, consolidate
the button system, and de-hardcode color/font in page CSS and inline `<style>` blocks.
Headers were left as-is (already visually consistent via shared `header.css`). Build verified
with `./mvnw -DskipTests package` (exit 0, WAR produced).

## Foundation
**`CSS/design-system.css`**
- Added status/semantic tokens: `--color-danger`, `--color-danger-dark`, `--color-success`,
  `--color-info`, `--color-warning-bg/-border/-text`.
- Added `--radius-control: 10px` (global token mirroring the compact analysis-control radius).

**`CSS/buttons.css`** (new)
- Canonical, **token-only** compact button system: `.btn-primary`, `.btn-secondary`,
  `.btn-ghost`, `.btn-outline`, `.export-btn`, and new `.btn-danger`. Mirrors the proven
  grammar already in `details.css` so the analysis pages stay byte-for-byte consistent while
  pages that previously rolled their own buttons can share one definition. Linked where needed.
- Note: `details.css`'s existing (already token-based, correct) button block was **intentionally
  left in place** to avoid disturbing the recently-restored analysis pages; `buttons.css` mirrors
  it rather than replacing it.

## browse  (`browse.jsp`, `CSS/browse.css`)
- Linked `CSS/buttons.css`.
- Sortable-header interactive states `#3498db` (blue) → `var(--color-secondary)`; sorted label
  `#2c3e50` → `var(--text-primary)`; thead `#1a2332` → `var(--color-primary)`.
- Error/warning box inline `#fff3cd/#ffc107/#856404` → warning tokens; `.error-message` `#dc3545`
  → `var(--color-danger)`; filter-bar `#f5f3f0` → `var(--bg-muted)`.
- JS-built selection badge `#3498db` → navy pill (`--color-primary`/`--text-inverse`);
  "Clear All" button `#e74c3c` inline → `class="btn-danger"` (tokenized danger button).
- `browse.css`: title/link/card/species colors → tokens (`--text-primary`, `--bg-surface`,
  `--shadow-md`, `--color-secondary`/`-dark`). Mouse species `#b8864a` kept (data encoding).

## gene-details  (`CSS/gene-details.css`)
- Biggest offender — fully tokenized. Hero gradient `#1a2332→#2a3f5f` →
  `var(--color-primary)→var(--color-primary-light)`. `.gene-name` `#d4a574`/3rem/700 →
  `var(--color-accent)` with fluid `clamp()`/weight 500 (aligned to hero scale).
- **Fixed primary button**: `.btn-primary` was gold `#d4a574` → now coral `var(--color-secondary)`
  with `var(--color-secondary-dark)` hover (the one genuinely-wrong primary on the site).
- All grays/borders/backgrounds → tokens (`#666→--text-secondary`, `#e5e5e5→--border-light`,
  `#f5f5f5→--bg-muted`, `#f8f9fa/#e9ecef` gradient → `--bg-muted/--border-light`, footer
  `#1a2332→--color-primary`). `@media print` `#333` kept.

## visualization  (`CSS/visualization.css`)
- Full color tokenization. `#666→--text-secondary`, `#999→--text-muted`, brand hexes → tokens.
- Error banner gradient `#ef4444→#dc2626` → `var(--color-danger)→var(--color-danger-dark)`.
- `.page-title` fixed `2.5rem` → fluid `clamp(2rem,4vw,2.5rem)`. `.toolbar-btn` tokenized.

## details  (`details.jsp`)  — minimal touch (recently restored, highest risk)
- Body inline `background:#faf8f5` → `var(--bg-body)`.
- Left untouched (intentional): Plotly data-viz color scales (expression heatmaps, NES up/down,
  categorical cell-type palette), page-scoped feedback-status badge palettes, and the already
  token-based `.btn-*` block. These are data encodings / a coherent restored system.

## download / feedback / featureplot  (inline `<style>` blocks)
- `download.jsp`: full block tokenized (header, cards, details, info section, loading shimmer);
  `.download-card__btn` coral → tokens, radius → `--radius-control`, disabled → tokens.
- `feedback.jsp`: brand hexes → tokens; error `#b91c1c` → `var(--color-danger)`; `#6b7280` →
  `var(--text-secondary)`; fonts → `var(--font-*)`.
- `featureplot.jsp`: block tokenized; **fixed** search button hover `#d47b64` →
  `var(--color-secondary-dark)`; example-link inline `#d4a574` → `var(--color-accent)`.

## help / 404  (`CSS/help.css`, `CSS/404.css`)
- `help.css`: full tokenization; generic gray ramp (`#1f2937/#374151/#4b5563/#6b7280/#9aa1ad`)
  mapped onto warm text tokens; fonts/shadows/borders/backgrounds → tokens.
- `404.css`: footer `#8b95a5` → `var(--text-muted)`. Illustration `#f2b5a5` kept.

## Left as-is (with rationale)
- `gene-search.jsp`, `compare.jsp`, `compare.css`, `search.css`, `help.jsp`, `404.jsp`: already
  clean (link `design-system.css`/`details.css`). `search.css` up/down badges are data encoding.
- `error.jsp`: self-contained fallback — literals kept so it renders without external CSS.
- `index.css` / home page: the reference, untouched.
- Legacy/unused `test.css`, `degtest.css`, `table1.css`: out of scope (not linked by in-scope pages).
- `construction-modal*.css`: already use `var(--token, #fallback)` (good practice).

## Verification
- `grep` for hex across page CSS / inline JSP styles: no rogue UI-chrome hex remain on
  refactored pages (only intentional data/illustration/print/fallback values, documented above).
- Every button maps to a named variant (`.btn--*` hero family or `.btn-*` compact family).
- `./mvnw -DskipTests package` → exit 0.
