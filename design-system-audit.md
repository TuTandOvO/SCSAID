# scSAID Design-System Audit

Single source of truth for the visual language of **skin-scsaid.com**, extracted from the
home page (`src/main/webapp/index.jsp`) and the canonical token file
`src/main/webapp/CSS/design-system.css`. Every other page should resolve its colors,
typography, spacing, radii and buttons to these tokens so it reads as a natural extension
of the home page.

> Stack: Java/Maven **WAR** JSP app. Source of truth is `src/main/webapp/`; `target/` is
> build output. CSS tokens live in `:root` of `CSS/design-system.css` and are loaded on
> every page (each page links `design-system.css` first).

## 1. Color palette (tokens)

| Token | Value | Role |
|---|---|---|
| `--color-primary` | `#1a2332` | Dark navy — headers, dark sections, primary text |
| `--color-primary-light` | `#2d3a4f` | Lighter navy (gradients) |
| `--color-secondary` | `#e8927c` | Coral — primary action / interactive accent |
| `--color-secondary-dark` | `#d4755d` | Coral hover/active |
| `--color-accent` | `#d4a574` | Warm tan/gold — logo, eyebrows, accents |
| `--color-accent-light` | `#e8c9a8` | Light tan |
| `--bg-body` | `#faf8f5` | Warm off-white page background |
| `--bg-surface` / `--bg-elevated` | `#ffffff` | Cards / surfaces |
| `--bg-muted` | `#f5f2ed` | Subtle warm gray (hover, code, panels) |
| `--bg-dark` | `#1a2332` | Dark sections |
| `--text-primary` | `#1a2332` | Primary text |
| `--text-secondary` | `#5a6473` | Body text |
| `--text-muted` | `#8b95a5` | Helper/subtle text |
| `--text-inverse` | `#ffffff` | Text on dark |
| `--text-link` | `#c4725e` | Links |
| `--border-light` | `#e5e0d8` | Light warm border |
| `--border-medium` | `#d1c9bd` | Medium border |
| `--border-dark` | `#1a2332` | Dark border |

### Status / semantic colors (added in this refactor)
Previously these states were hardcoded ad-hoc per page (Bootstrap reds/blues). Now centralized:

| Token | Value | Role |
|---|---|---|
| `--color-danger` | `#c0392b` | Destructive / error (warm red) |
| `--color-danger-dark` | `#a93226` | Danger hover |
| `--color-success` | `#2e7d52` | Success |
| `--color-info` | `#3498db` | Informational |
| `--color-warning-bg` | `#fff3cd` | Warning background |
| `--color-warning-border` | `#ffc107` | Warning border |
| `--color-warning-text` | `#856404` | Warning text |

## 2. Typography
- `--font-display: 'Cormorant Garamond', Georgia, serif` (headings/hero)
- `--font-body: 'Montserrat', -apple-system, …, sans-serif` (body/UI)
- `--font-mono: 'JetBrains Mono', 'Fira Code', monospace` (IDs, code, genomic values)
- Base body: 16px / line-height 1.6 / weight 400.
- Heading scale (`design-system.css`): `h1 clamp(2.5rem,5vw,4rem)` w500 · `h2 clamp(1.75rem,3vw,2.5rem)`
  w600 · `h3 clamp(1.25rem,2vw,1.75rem)` w600 · h4 1.25rem · h5 1.1rem · h6 1rem.
- Hero/section titles use `clamp()` (fluid) — fixed `2.5rem` titles were normalized to `clamp()`.

## 3. Spacing, radius, shadow, motion
- Spacing (8px base): `--space-xs .25rem`, `sm .5`, `md 1`, `lg 1.5`, `xl 2`, `2xl 3`, `3xl 4`, `4xl 6rem`.
- Radius: `--radius-sm 4px`, `md 8px`, `lg 12px`, `xl 20px`, `full 9999px`,
  **`--radius-control 10px`** (added — compact analysis-tool controls).
- Shadows: `--shadow-sm/md/lg/xl` (navy-tinted `rgba(26,35,50,…)`).
- Transitions: `--transition-fast 150ms ease`, `--transition-base 250ms ease`,
  `--transition-slow 400ms cubic-bezier(.4,0,.2,1)`.

## 4. Buttons
Two intentional families, both token-based:

- **Hero / CTA** (`design-system.css`): `.btn`, `.btn--primary`, `.btn--outline`, `.btn--ghost`.
  Uppercase, `--radius-sm`, padding `--space-md --space-xl`, coral `--color-secondary`.
  Used on the home page.
- **Compact controls** (`details.css` + new shared `CSS/buttons.css`): `.btn-primary`,
  `.btn-secondary`, `.btn-ghost`, `.btn-outline`, `.export-btn`, **`.btn-danger`** (new).
  Smaller padding (`0.6rem 1.15rem`), `--radius-control`, coral primary, used across the
  analysis/utility pages. `buttons.css` is the canonical token-only definition; link it after
  `design-system.css` on pages that don't inherit `details.css`.

Both resolve to the same tokens, so primary buttons are coral `--color-secondary` everywhere.

## 5. Forms, cards, header, data components
- **Forms** (`.form-input/.form-select`): white bg, `--border-light`, `--radius-sm`, focus ring
  `0 0 0 3px rgba(232,146,124,.15)` + coral border.
- **Cards** (`.card`, page card wrappers): white surface, `--border-light`, `--radius-lg`, `--shadow-sm`.
- **Header** (`header.css`, shared CSS, per-page markup): fixed 72px, navy gradient, gold logo
  `--color-accent`, pill nav links, white dropdown.
- **Data components**: `.data-table` (navy `thead`, coral links); species badges use brand-derived
  chips (human coral, **mouse `#b8864a`** — intentional data encoding, kept); gene-expression
  up/down badges (`search.css`) and Plotly color scales in `details.jsp` are **data encodings**,
  intentionally left untouched.

## 6. What is intentionally NOT tokenized
- Plotly/ECharts color scales and categorical palettes (biological/data encoding).
- `search.css` expression up/down badge colors (`#167d3d` / `#b91c1c`).
- Mouse species chip `#b8864a`.
- `404.css` `#f2b5a5` illustration fill; `@media print` `#333`.
- `error.jsp` inline literals (self-contained fallback that must render without external CSS).
- `details.css` feedback-status badge palettes (info/warn/error/success) — a coherent page-scoped set.
- The home page `index.css` itself (it is the reference).
