# Harpy brand & design system

The Harpy identity — quiet, factual, developer-tool restraint. Named after
Harpocrates, the god of silence, so the voice stays terse and the palette calm.

Brand tokens are vendored as CSS in [`assets/tokens/`](../assets/tokens/); the
logos live in [`assets/`](../assets/). The **full** design system (React
component kit, icon set, Geist web fonts, and HTML guidelines) ships separately
as the `harpy-design` skill package — pull that in when building a web UI or
dashboard. This repo (a backend node) vendors only the brand identity.

## Logo

| Asset | File | Use |
|-------|------|-----|
| Wordmark (light bg) | [`assets/harpy-logo.svg`](../assets/harpy-logo.svg) | READMEs, light surfaces |
| Wordmark (dark bg) | [`assets/harpy-logo-dark.svg`](../assets/harpy-logo-dark.svg) | dark mode |
| Mark only | [`assets/harpy-mark.svg`](../assets/harpy-mark.svg) | avatars, favicons, tight spaces |

The mark is two charcoal pillars with a rising amber arc — an "H" and a sunrise.
Prefer the `<picture>` element so the logo follows the reader's color scheme:

```html
<picture>
  <source media="(prefers-color-scheme: dark)" srcset="assets/harpy-logo-dark.svg">
  <img alt="Harpy" src="assets/harpy-logo.svg" width="300">
</picture>
```

## Color

Seeded from the logo: charcoal pillars, an amber sun, warm-gray neutrals. Full
scale in [`assets/tokens/colors.css`](../assets/tokens/colors.css).

| Role | Token | Hex |
|------|-------|-----|
| Brand charcoal (ink) | `--ink-900` | `#2C2C2B` |
| Brand amber (accent) | `--sun-400` | `#E8A33D` |
| Page background | `--ink-50` | `#FAF9F7` |
| Body text | `--ink-900` | `#2C2C2B` |
| Link / accent text | `--sun-600` | `#B0741C` |
| Success · Error · Info | `--green-500` · `--red-500` · `--blue-500` | `#4C8A5C` · `#C4553D` · `#4A7296` |

Semantic hues are deliberately muted and warm-leaning to keep the understated
voice. Use `--accent` (amber) sparingly — one clear call to action per view.

## Type

Geist for UI, **Geist Mono** for code, hashes, and chain data. Scale and tracking
in [`assets/tokens/typography.css`](../assets/tokens/typography.css). Display type
is tracked slightly tight (`-0.02em`) to echo the logo lockup. (The logo wordmark
itself uses Helvetica Neue; Geist is the UI substitute — no brand font was cut.)

## Voice

Terse, factual, no exclamation-mark cheer. State what happened.

| Say | Not |
|-----|-----|
| `Block mined.` | `Awesome! Your block was mined successfully! 🎉` |
| `Invalid: hash does not meet difficulty.` | `Oops! Something went wrong…` |
| `Nothing here yet. Mine the first block.` | `Welcome to your blockchain journey!` |

This maps directly onto the node's existing log/error style (see
[`src/harpy/server.cr`](../src/harpy/server.cr)) and CLI output.
