# Design System Enforcement

## Design Tokens

### Colors
- Use semantic color tokens, never hardcoded hex/rgb values
- One primary accent color + semantic colors (success, warning, error, info)
- Dark mode: rebuild grayscale, don't invert; reduce accent intensity

| Token Type | Example | Anti-Pattern |
|-----------|---------|-------------|
| `--color-primary` | Brand accent | `#3b82f6` hardcoded |
| `--color-error` | Error states | `red` or `#ef4444` inline |
| `--color-surface` | Backgrounds | `white` or `#ffffff` |

### Spacing Scale
Use consistent spacing tokens from an 8px base:

| Token | Value | Use |
|-------|-------|-----|
| `--space-1` | 4px | Tight inline spacing |
| `--space-2` | 8px | Default gap |
| `--space-3` | 12px | Compact padding |
| `--space-4` | 16px | Standard padding |
| `--space-6` | 24px | Section spacing |
| `--space-8` | 32px | Large gaps |
| `--space-12` | 48px | Page sections |

Anti-pattern: arbitrary values like `13px`, `17px`, `23px`.

### Typography Scale

| Level | Size | Weight | Use |
|-------|------|--------|-----|
| h1 | 2rem+ | Bold | Page titles |
| h2 | 1.5rem | Semibold | Section headers |
| h3 | 1.25rem | Semibold | Subsection headers |
| body | 1rem | Normal | Body text |
| small | 0.875rem | Normal | Captions, metadata |

Rules:
- Never skip heading levels (h1 → h3 is invalid)
- Line height: 1.5 for body text, 1.2 for headings
- Max line length: 65-75 characters for readability

## Dark Mode

| Rule | Requirement |
|------|------------|
| Grayscale | Rebuild from dark surface, don't invert |
| Accent | Reduce intensity by 10-20% |
| Contrast | Re-verify all contrast ratios in dark mode |
| Borders | Use subtle borders (1px, low-opacity) instead of shadows |
| Images | Consider `filter: brightness(0.9)` for user images |
