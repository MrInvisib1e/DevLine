# Accessibility — WCAG 2.1 AA Reference

## Contrast Ratios

| Element | Minimum Ratio | Tool |
|---------|--------------|------|
| Normal text (< 18px) | 4.5:1 | WebAIM Contrast Checker |
| Large text (≥ 18px or ≥ 14px bold) | 3:1 | WebAIM Contrast Checker |
| UI components & graphical objects | 3:1 | WebAIM Contrast Checker |

## Essential ARIA Patterns

| Pattern | When | Example |
|---------|------|---------|
| `aria-label` | Icon-only buttons | `<button aria-label="Close dialog">✕</button>` |
| `aria-hidden="true"` | Decorative icons | `<Icon aria-hidden="true" />` |
| `aria-live="polite"` | Dynamic content updates | `<div aria-live="polite">{status}</div>` |
| `role="alert"` | Error messages | `<p role="alert">{error}</p>` |
| `aria-invalid` | Form validation | `<input aria-invalid={hasError} />` |
| `aria-describedby` | Help text for inputs | `<input aria-describedby="help-text" />` |
| `aria-expanded` | Collapsible sections | `<button aria-expanded={isOpen}>` |
| `aria-current="page"` | Active navigation | `<a aria-current="page" href="/home">` |

## Focus Management

| Rule | Requirement |
|------|------------|
| Focus indicator | 2px solid outline, 4px offset minimum |
| Focus trap | Modals/dialogs must trap focus inside |
| Focus restore | After modal close, return focus to trigger element |
| Skip link | "Skip to main content" link as first focusable element |
| Tab order | Logical, follows visual order |

## Keyboard Navigation

| Key | Expected Behavior |
|-----|-------------------|
| Tab / Shift+Tab | Move between focusable elements |
| Enter / Space | Activate buttons, links, checkboxes |
| Arrow keys | Navigate within groups (tabs, menus, radio buttons) |
| Escape | Close modals, dropdowns, popovers |
| Home / End | Jump to first/last item in a list |

## Color-Not-Alone Rule

Status must ALWAYS be communicated with color + icon + text:

```html
<!-- BAD: color alone -->
<span class="text-red-500">Error</span>

<!-- GOOD: color + icon + text -->
<span class="text-red-500">
  <Icon name="alert-circle" aria-hidden="true" />
  Error: Email is required
</span>
```

## Automated Testing

Run `axe-core` or Lighthouse accessibility audit as part of CI:
```bash
npx @axe-core/cli <url>
```
