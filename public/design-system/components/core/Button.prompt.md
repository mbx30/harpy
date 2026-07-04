The standard Harpy button — use `primary` (amber) at most once per view; everything else is secondary or ghost.

```jsx
<Button variant="primary">Mine block</Button>
<Button variant="secondary" icon={<Icon name="copy" size={16} />}>Copy hash</Button>
<Button variant="ghost" size="sm">Cancel</Button>
<Button variant="danger">Delete chain</Button>
```

- Sizes: `sm` 28px, `md` 36px (default), `lg` 44px.
- Text is sentence case, verb-first ("Mine block", never "MINE BLOCK").
- `danger` is the only white-text button; primary uses charcoal text on amber.
