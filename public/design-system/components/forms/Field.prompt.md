Wraps any control with a label and hint/error line.

```jsx
<Field label="Block data" hint="Stored as a UTF-8 string." htmlFor="data">
  <Input id="data" placeholder="e.g. genesis" />
</Field>
<Field label="Difficulty" error="Must be between 1 and 6." htmlFor="d">
  <Input id="d" invalid defaultValue="9" />
</Field>
```
