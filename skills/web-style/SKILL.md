---
name: devline-web-style
description: Web styling enforcement — accessibility, design tokens, responsive design, anti-patterns
requires: []
triggers_on_complete: []
---

# /web-style — Web Styling & Accessibility Enforcement

Audit a page or component against 6 quality dimensions for web styling, accessibility, and design system compliance.

**Invoked as:** `/web-style <path>` or auto-triggered when dl-feature detects a web stack.

---

## Iron Law

<iron-law>
NO SHIPPING WITHOUT WCAG 2.1 AA COMPLIANCE.
COLOR ALONE MUST NEVER COMMUNICATE STATUS.
</iron-law>

---

## When to Use

| Situation | Trigger |
|-----------|---------|
| dl-feature detects `stack.frontend` is set | Auto-suggest after Phase 5 review |
| User invokes `/web-style <path>` | Manual audit |
| PR touches `.svelte`, `.tsx`, `.vue`, `.css`, `.scss` files | Auto-suggest in dl-review |
| DEFAULT | Manual invocation only |

---

## Pre-Flight (T1 Silent)

1. Check `stack.frontend` in `.devline/config.json`
2. Identify target files: if `<path>` is a directory, find all component/page files
3. Read `.devline/memory.md` for design system conventions

---

## 6-Dimension Audit

For each target file, evaluate against these 6 dimensions. Read the reference file for each dimension.

| Dimension | Reference File | Key Check |
|-----------|---------------|-----------|
| 1. Design Tokens | `design-system.md` | No hardcoded colors/spacing — use tokens |
| 2. Accessibility | `accessibility-wcag-aa.md` | WCAG 2.1 AA contrast, ARIA, keyboard, focus |
| 3. Responsive | `responsive-design.md` | Mobile-first, touch targets, breakpoints |
| 4. Design System | `design-system.md` | Spacing rhythm, typography scale, dark mode |
| 5. Quality & Polish | (inline) | Visual alignment, interaction states, micro-interactions |
| 6. Anti-Patterns | `anti-patterns.md` | CSS/HTML/animation smells |

---

## Output Format

```
## Web Style Audit: <path>

| Dimension | Status | Findings |
|-----------|--------|----------|
| Design Tokens | PASS / NEEDS WORK | <count> issues |
| Accessibility | PASS / NEEDS WORK | <count> issues |
| Responsive | PASS / NEEDS WORK | <count> issues |
| Design System | PASS / NEEDS WORK | <count> issues |
| Quality & Polish | PASS / NEEDS WORK | <count> issues |
| Anti-Patterns | PASS / NEEDS WORK | <count> issues |

### Top 3 Priority Fixes

1. **[Dimension]** <description> — <file:line>
   ```diff
   - <current code>
   + <fixed code>
   ```

2. ...

### All Findings

#### Design Tokens
- ...

#### Accessibility
- ...
```

---

## Rationalization Prevention

| Excuse | Reality |
|--------|---------|
| "Accessibility is a nice-to-have" | It's a legal requirement in many jurisdictions. Always enforce. |
| "We'll add ARIA labels later" | Later never comes. Add them now. |
| "This is an internal tool" | Internal users deserve accessible software too. |
| "Dark mode is optional" | If the design system supports it, enforce it. |
| "Touch targets are fine at 36px" | 44px minimum. No exceptions. |

## Red Flags — STOP

- `div` with `role="button"` instead of `<button>`
- `outline: none` without a replacement focus indicator
- Color as the only differentiator for status
- Hardcoded hex/rgb values instead of design tokens
- Skipped heading levels (h1 → h3)
- Inputs without associated labels
- Animations without `prefers-reduced-motion` check

**Stop. Fix accessibility first. Ship quality.**

---

## Error Reference

| Code | Trigger | Action |
|------|---------|--------|
| E01 | No web stack detected | T2 Inform: "No frontend stack detected. Skipping web-style audit." |
| E02 | No files found at path | HALT — "No component files found at <path>" |
| E03 | Design system not defined in memory | T2 Inform: "No design system conventions found — using WCAG defaults only" |
