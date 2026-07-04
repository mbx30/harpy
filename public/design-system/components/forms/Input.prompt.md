Single-line text input; amber focus ring, red when `invalid`.

```jsx
<Input placeholder="Block data" />
<Input icon={<Icon name="search" size={16} />} placeholder="Search blocks" />
<Input mono defaultValue="000a4f2c81d6…" readOnly />
<Input invalid defaultValue="bad value" />
```

Use `mono` for hashes/nonces. Wrap in `<Field>` for label + hint.
