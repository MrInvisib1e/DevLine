# Responsive Design Reference

## Mobile-First

Design for 320px viewport first, then enhance for larger screens.

## Breakpoints

| Name | Width | Target |
|------|-------|--------|
| Mobile | 320px | Phones (portrait) |
| Tablet | 640px | Tablets, large phones (landscape) |
| Desktop | 1024px | Laptops, desktops |

## Touch Targets

| Rule | Requirement |
|------|------------|
| Minimum size | 44×44px (48×48px recommended) |
| Spacing between targets | 8px minimum |
| Padding over size | Use padding to increase hit area, not visual size |

## Responsive Rules

| Rule | Requirement |
|------|------------|
| No horizontal scroll | Content must fit viewport at every breakpoint |
| Flexible images | `max-width: 100%; height: auto;` |
| Readable text | 16px minimum on mobile (prevents iOS zoom) |
| Stack on mobile | Multi-column layouts stack to single column |
| Hide non-essential | Use `display: none` for non-critical elements on mobile |
