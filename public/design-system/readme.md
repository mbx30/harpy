# Harpy Design System

Harpy is an educational, single-node proof-of-work blockchain written in [Crystal](https://crystal-lang.org/) — blocks linked by SHA-256, mined with simple PoW, exposed over an HTTP JSON API. It is a tutorial project, not production blockchain software.

The name comes from **Harpocrates**, the Greek god of silence, derived from an Egyptian deity symbolizing **hope, the newborn sun, and a child**. The brand mark encodes this: two charcoal pillars (silence, restraint) with an amber arc rising between them (the newborn sun).

## Sources

- **Codebase:** `harpy/` (local mount) and https://github.com/mbx30/harpy — Crystal + Kemal backend; `src/harpy/{block,chain,server,types}.cr`. Backend-only: it contains **no frontend, UI code, or product copy**. Explore the repo for deeper product context.
- **Logo assets (supplied by user):** `assets/harpy-logo.svg`, `assets/harpy-logo-dark.svg`, `assets/harpy-mark.svg`.
- **Project tracking:** [Linear — Harpy](https://linear.app/mbx2/project/harpy-16c5704dd57d/overview) (not accessed).

Because the source is backend-only, everything beyond the logo, its two colors, and the naming story was **authored for this system** (per user direction): one strong direction — quiet/understated tone, clean geometric developer-tool typography, charcoal + amber + muted supporting colors, Lucide icons. **No UI kits** were built — no product UI exists to recreate.

## Content fundamentals

Voice: **quiet and confident** — a nod to the god of silence. The chain speaks only when it has something verified to say.

- **Plain, precise, technical.** Say exactly what happened: "Block mined", "Chain valid", "3 leading zeros required". No hype, no exclamation points.
- **Short sentences. Few words.** Prefer "Mining…" over "We're mining your block now!". If a word can be removed, remove it.
- **Sentence case everywhere** — headings, buttons, labels ("Mine block", not "Mine Block" or "MINE BLOCK"). All-caps only for tiny metadata labels (HASH, NONCE), tracked wide.
- **Second person, sparingly.** "Your block was added." Never "we" as marketing voice; the system is the actor: "Harpy validates every block."
- **No emoji.** Ever. Status is conveyed with color + icon.
- **Data speaks in mono.** Hashes, nonces, timestamps, indices render in Geist Mono, muted, often truncated with `…` (`000a4f…9c2e`).
- Example microcopy: "Genesis block" / "Mine block" / "Invalid: hash does not meet difficulty" / "Copied to clipboard" / "Nothing here yet. Mine the first block."

## Visual foundations

**Colors** — warm charcoal + amber, both from the logo. Neutrals are *warm* grays (`--ink-*`, #FAF9F7 paper → #191918). One accent: amber (`--sun-*`, #E8A33D). Semantic hues (green/red/blue) are muted and warm-leaning so they never shout louder than the accent. Light surfaces by default; `--surface-inverse` charcoal for footers/hero moments. Text on amber is charcoal, never white.

**Typography** — Geist (variable) for everything; Geist Mono for code/hashes/data. Body 14px/1.5. Headings semibold (600), tracked -0.01 to -0.02em (echoing the logo lockup). Caps labels 12px, +0.08em, `--text-muted`. No serif, no display face.

**Spacing** — 4px grid (`--space-*`), controls padded 8/12, cards 20–24, sections 48–64. Max content width 680px prose / 1080px layout.

**Backgrounds** — flat, solid colors only. No gradients, no textures, no patterns, no imagery (none exists in the brand). Occasional `--surface-accent-subtle` (#FCF5E8) wash for callouts.

**Borders & shadows** — hairline 1px `--border-default` does most separation work. Shadows are soft, warm-black and low-alpha (`--shadow-sm/md/lg`); overlays get `--shadow-overlay`. Never hard or colored shadows.

**Corner radii** — 6px controls, 10px cards/dialogs, 4px small chips inside things, **pill** (999px) for badges/tags — the pill echoes the rounded pillars of the mark.

**Cards** — white surface, 1px `--border-default`, 10px radius, `--shadow-sm`, 20px padding. Hover (when interactive): border darkens to `--border-strong`, shadow to `--shadow-md`.

**Motion** — fast, quiet fades and eases: 120–260ms, `--ease-out`. Opacity/transform only. No bounces, no springs, no infinite loops (exception: the loader spin).

**Hover/press states** — hover darkens one step (amber → `--sun-500`; ghost controls gain `--ink-100` wash). Press darkens a further step (`--sun-600`); no scale/shrink effects. Focus is a 2px offset amber ring (`--focus-ring`).

**Transparency & blur** — essentially unused; dialogs scrim with `rgba(25,25,24,0.4)`, no backdrop blur.

**Imagery** — none. The brand has no photography or illustration. Use the mark, type, and data itself as the visual material.

## Iconography

- **Lucide** (line icons, 2px stroke, 24px grid) — chosen substitute; the source has no icon system. 16 common glyphs are vendored as SVG in `assets/icons/` (check, x, chevron-down, chevron-right, plus, search, copy, settings, info, triangle-alert, circle-check, circle-alert, external-link, loader-circle, trash-2, arrow-right). Pull more from https://lucide.dev / `lucide-icons/lucide` as needed — never hand-draw icons.
- Icons render at 16px inside controls, 20px standalone, stroke `currentColor`.
- No icon font, no emoji, no unicode-as-icon.
- Logo usage: full lockup on light (`harpy-logo.svg`) / dark (`harpy-logo-dark.svg`); square mark (`harpy-mark.svg`) at 24–48px for favicons/avatars. Don't recolor the amber arc.

## Intentional additions

- **Icon** component — thin wrapper that inlines the vendored Lucide SVGs at token sizes (source has no icon system).
- Everything under `components/` — the source defines no component inventory (backend-only), so a standard primitive set was authored per user direction.

## Index

- `styles.css` — global entry; imports everything under `tokens/` (fonts, colors, typography, spacing, effects, base).
- `assets/` — logos (`harpy-logo.svg`, `harpy-logo-dark.svg`, `harpy-mark.svg`), `fonts/` (Geist + Geist Mono variable woff2), `icons/` (Lucide SVGs).
- `guidelines/` — foundation specimen cards (Design System tab).
- `components/core/` — Button, IconButton, Icon, Badge, Tag, Card, Callout, Spinner.
- `components/forms/` — Input, Select, Checkbox, Radio, Switch, Field.
- `components/navigation/` — Tabs.
- `components/overlay/` — Dialog, Tooltip, Toast.
- `SKILL.md` — agent-facing entry point.

## Caveats

- **Font substitution:** no brand font files were supplied (logo uses Helvetica Neue). Geist / Geist Mono (vercel/geist-font) were substituted for the developer-tool feel. Supply real brand fonts to replace them in `tokens/fonts.css`.
- No UI kits, by user direction — there is no product UI to recreate.
