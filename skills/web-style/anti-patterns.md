# Web Anti-Patterns

## CSS Smells

| Smell | Why It's Bad | Fix |
|-------|-------------|-----|
| Hardcoded colors (`#3b82f6`) | Breaks theming, dark mode | Use design tokens |
| Arbitrary spacing (`margin: 13px`) | Inconsistent rhythm | Use spacing scale |
| `!important` | Specificity war | Fix selector specificity |
| `margin` between flex children | Use `gap` instead | `display: flex; gap: 8px;` |
| `position: absolute` for layout | Fragile, breaks on resize | Use flexbox/grid |
| Magic numbers | Unexplained values | Use tokens or named constants |

## HTML Smells

| Smell | Why It's Bad | Fix |
|-------|-------------|-----|
| `<div role="button">` | Missing keyboard support | Use `<button>` |
| `<span>` as heading | Not in heading hierarchy | Use `<h1>`–`<h6>` |
| Skipped heading levels | Breaks screen reader navigation | Use sequential levels |
| `<input>` without `<label>` | Inaccessible | Add `<label for="id">` or `aria-label` |
| `<a>` without `href` | Not keyboard-focusable | Add `href` or use `<button>` |
| `<img>` without `alt` | Inaccessible | Add descriptive `alt` text |

## Animation Smells

| Smell | Why It's Bad | Fix |
|-------|-------------|-----|
| `outline: none` without replacement | Removes focus indicator | Add custom focus style |
| No `prefers-reduced-motion` | Motion sickness risk | Wrap in `@media (prefers-reduced-motion: no-preference)` |
| Layout-triggering animations | Janky, expensive | Animate `transform` and `opacity` only |
| Animations > 300ms | Feels sluggish | Keep under 300ms for UI, 500ms for transitions |
| Auto-playing animations | Distracting | Respect user preference |
