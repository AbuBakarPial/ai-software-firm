# SKILL: Web Design System · v2026.10
> Load when: building UI for web. Works with Tailwind, CSS Modules, Vanilla Extract, CSS-in-JS, shadcn/ui.

## STEP 0 — DETECT FIRST
```bash
# Detect which CSS approach the project uses
cat tailwind.config.ts 2>/dev/null && echo "TAILWIND"
ls *.css 2>/dev/null | head -5
grep -r "vanilla-extract\|@vanilla-extract" package.json 2>/dev/null && echo "VANILLA_EXTRACT"
grep -r "styled-components\|emotion\|@emotion" package.json 2>/dev/null && echo "CSS_IN_JS"
grep -r "\.module\.css" src/ --include="*.tsx" -l 2>/dev/null | head -3 && echo "CSS_MODULES"
ls components/ui/ 2>/dev/null | head -10
```
Match what exists. Never add a second CSS system.

## CSS APPROACH REFERENCE

### Tailwind CSS (utility-first)
```tsx
// cn() helper — mandatory for conditional classes
import { clsx } from 'clsx'
import { twMerge } from 'tailwind-merge'
const cn = (...inputs: ClassValue[]) => twMerge(clsx(inputs))

// Usage
<div className={cn('flex items-center gap-2 p-4 rounded-lg', isActive && 'bg-brand-500', className)}>
  <span className="text-sm font-medium text-text-primary">Hello</span>
</div>
```

### CSS Modules (colocated, zero runtime)
```css
/* Component.module.css — scoped by default */
.root { display: flex; align-items: center; gap: 8px; padding: 16px; }
.title { font-size: 14px; font-weight: 500; color: var(--text-primary); }
```
```tsx
import styles from './Component.module.css';
<div className={styles.root}>
  <span className={styles.title}>Hello</span>
</div>
```

### Vanilla Extract (zero-runtime CSS-in-JS)
```typescript
import { style, createThemeContract } from '@vanilla-extract/css';
export const tokens = createThemeContract({
  color: { brand: null, surface: null, text: null },
  space: { sm: null, md: null, lg: null },
});
export const root = style({
  display: 'flex', alignItems: 'center', gap: tokens.space.md,
  padding: tokens.space.lg, backgroundColor: tokens.color.surface,
});
```

### CSS-in-JS (styled-components / Emotion)
```typescript
import styled from 'styled-components';
const Button = styled.button<{ $variant: 'primary' | 'ghost' }>`
  display: inline-flex; align-items: center; padding: 8px 16px;
  background: ${p => p.$variant === 'primary' ? 'var(--color-brand)' : 'transparent'};
  border-radius: 8px;
`;
```

## DESIGN TOKENS (tailwind.config.ts)
```typescript
theme: { extend: {
  colors: {
    brand: { 50:'#eff6ff', 500:'#3b82f6', 900:'#1e3a5f' },
    surface: { DEFAULT:'#ffffff', subtle:'#f8fafc', muted:'#f1f5f9' },
    text: { primary:'#0f172a', secondary:'#475569', muted:'#94a3b8' },
  },
  fontFamily: { sans: ['Inter','system-ui','sans-serif'] },
}}
```

## CORE COMPONENTS
```tsx
const btn = cva('inline-flex items-center font-medium transition-colors disabled:opacity-50', {
  variants: {
    variant: {
      default: 'bg-brand-500 text-white hover:bg-brand-600',
      outline: 'border border-brand-500 text-brand-500',
      ghost: 'hover:bg-surface-subtle',
      danger: 'bg-red-500 text-white hover:bg-red-600',
    },
    size: { sm:'h-8 px-3 text-sm', md:'h-10 px-4', lg:'h-12 px-6' },
  },
  defaultVariants: { variant:'default', size:'md' },
});

export const Skeleton = ({ className }: { className?: string }) =>
  <div className={cn('animate-pulse rounded bg-surface-muted', className)} />;

export function EmptyState({ icon, title, description, action }: EmptyStateProps) {
  return (
    <div className="flex flex-col items-center justify-center py-12 text-center">
      <div className="text-text-muted mb-4 text-4xl">{icon}</div>
      <h3 className="font-semibold mb-1">{title}</h3>
      <p className="text-text-secondary text-sm mb-4">{description}</p>
      {action}
    </div>
  );
}
```

## ACCESSIBILITY (non-negotiable)
- `alt` on every `<img>` / `aria-label` on icon-only buttons
- Color contrast ≥ 4.5:1 (WCAG AA)
- Keyboard nav with visible focus ring
- `prefers-reduced-motion` respected

## RESPONSIVE (mobile-first)
```tsx
<div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
```

## RULES
- Skeleton for async loading, never bare spinner
- Error states have retry action; empty states have CTA
- Spacing: 4/8/12/16/24/32/48px only
- Typography: 12/14/16/18/20/24/32px only
- Dark mode: CSS variables OR Tailwind `dark:` — never both
