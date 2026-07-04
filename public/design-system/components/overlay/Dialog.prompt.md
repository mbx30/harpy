Modal over a charcoal scrim (no backdrop blur). One primary action max.

```jsx
<Dialog
  open={open}
  onClose={() => setOpen(false)}
  title="Delete chain"
  footer={<>
    <Button variant="ghost" onClick={() => setOpen(false)}>Cancel</Button>
    <Button variant="danger" onClick={confirm}>Delete</Button>
  </>}
>
  This removes all 12 blocks. It cannot be undone.
</Dialog>
```
