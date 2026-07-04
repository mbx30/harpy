Renders a vendored Lucide icon (assets/icons/*.svg) tinted with currentColor — use inside buttons, callouts, inputs.

```jsx
<Icon name="check" size={16} />
<Icon name="search" size={20} style={{ color: "var(--text-muted)" }} />
```

- 16px inside controls, 20px standalone.
- If the page isn't at the project root, set `window.HARPY_ICON_BASE = "../assets/icons"` (or pass `base`).
- Available: check, x, plus, search, copy, settings, info, circle-check, circle-alert, triangle-alert, chevron-down, chevron-right, arrow-right, external-link, loader-circle, trash-2.
