# SKILL: High-Fidelity UI Design Playbook · v2026.10
> Load when: designing user interfaces, creating wireframes, polishing dark/light modes, setting up responsive grids, or adding micro-animations.
> Purpose: Bypasses generic "AI bootstrap design" to output startup-level, premium visual aesthetics.

---

## 🎨 CORE VISUAL PRINCIPLES

1. **Colors over Browser Defaults:** Avoid generic colors. Use curated HSL palette maps.
2. **Subtle Boundaries:** Use `0.5px` borders with a soft opacity (`border: 0.5px solid rgba(var(--border), 0.08)`) instead of harsh black or grey borders.
3. **Layering (Glassmorphism):** Use `backdrop-filter: blur(12px)` and layered box shadows to create high-end tactile depth.
4. **Modern Typography:** Pair high-performance Google Fonts:
   *   *Headers:* Outfit, Plus Jakarta Sans, Cl clash.
   *   *Body/UI:* Inter, Geist Sans, Instrument Sans.
5. **Micro-Animations:** Enhance active and hover states with:
   *   `transition: all 0.2s cubic-bezier(0.16, 1, 0.3, 1)`

---

## THE 9 PREMIUM UI PROMPTING ALGORITHMS

When building or updating UI features, strictly follow these precise prompt layout structures:

### 1. Premium SaaS Dashboard Layout
```
PROMPT: Build a premium SaaS dashboard featuring a double-sidebar layout. 
- Left Sidebar: Slim navigation bar with modern icons, active state highlighted with a soft gradient pill, and user profile at the bottom.
- Main Section: A 3-column responsive metric grid with skeleton loader states on start.
- Metric Cards: Features currency/number values, a tiny sparkline trend chart, and a colored positive/negative trend badge.
- Main Workspace: A tabbed area with animated active indicators showing a list of recent transactions with subtle 0.5px divider lines.
```

### 2. The Glassmorphic Landing Page Hero
```
PROMPT: Create an immersive, glassmorphic hero section for a startup landing page.
- Background: A sleek dark background with two glowing, semi-opaque HSL abstract gradient blobs drifting slowly behind.
- Hero Card: A centered card with backdrop-filter: blur(20px), border: 0.5px solid rgba(255,255,255,0.1), and an inner-shadow highlight.
- Typography: Headline is massive, Outfit font, featuring a dual-gradient text clip (e.g., from deep purple to soft pink).
- CTA Buttons: Primary button is an interactive gradient pill with an overlay shine effect on hover. Secondary is an outline glass button.
```

### 3. Polished Light/Dark Mode Toggle
```
PROMPT: Implement an accessible, smooth-transition light/dark mode switch.
- Transition: Use transition: background-color 0.4s ease, color 0.4s ease across the entire HTML root.
- Color Tokens:
  * Light: --bg: #fbf9f6 (warm cream), --text: #1a1918, --accent: #ff6600
  * Dark: --bg: #0d0c0b (deep obsidian), --text: #f5f4f0, --accent: #ff6600
- Toggle Switch: A sliding track with spring/bounce animation containing sun and moon icons that rotate into view dynamically on toggle.
```

### 4. Mobile App Navigation & Sheet Patterns
```
PROMPT: Design a premium bottom navigation bar and bottom drawer sheet for a mobile view.
- Bottom Nav: A floating pill shape near the bottom of the viewport with a soft backdrop blur and an elevated shadow. Active icon animates with a tiny micro-bounce.
- Bottom Sheet: An interactive, swipeable drawer sheet that slides up smoothly from the bottom with a rounded "drag handle" pill at the top.
```

### 5. Interactive Data Table with Filters
```
PROMPT: Build an advanced data table structure.
- Filter Bar: Inline search input with clear-icon, active dropdown selectors for category/status, and a "reset filters" button that shows only when active.
- Headers: Clean, sortable column headers with miniature up/down chevron indicators showing active sorting state.
- Empty State: If no data, render a beautifully illustrated glass empty card with a clear, concise Call-to-Action button.
```

### 6. Modern Multi-Step Form Wizard
```
PROMPT: Create a multi-step form wizard layout.
- Progress Tracker: A step-indicator pill bar at the top displaying completed (check icon), active (pulse glow), and upcoming (grey outline) steps.
- Form Body: Clean inputs with floating labels that shrink and move to the top-left on focus. Active input has a glowing border shadow.
- Error Handling: Interactive shake animation on submit fail, displaying red warnings with absolute line-heights.
```

### 7. Responsive Pricing Grid with Interactive Toggles
```
PROMPT: Build a responsive 3-column pricing comparison section.
- Toggle: A pill switch to toggle between Monthly and Yearly pricing, triggering a smooth counter-roll animation on the currency numbers.
- Featured Card: Highlight the middle card with a tiny absolute "Most Popular" floating tag, an active gradient border, and an elevated shadow.
```

### 8. Rich Notifications & Toast Systems
```
PROMPT: Design a state-driven notification toast system.
- Layout: Absolute positioned in the top-right or bottom-right corner, stacking toasts vertically with spring-animations.
- States:
  * Success: Emerald green outline, check icon, subtle glow.
  * Warning: Warm amber outline, alert icon.
  * Error: Crimson red outline, close icon.
- Progress Indicator: A tiny linear countdown bar at the bottom of the toast showing time remaining before auto-dismissal.
```

### 9. Skeleton Loaders & Optimistic States
```
PROMPT: Create skeleton loader structures for async data.
- Animation: A linear pulsing gradient keyframe sweep across a greyish-beige background color block.
- Shapes: Match exact card layouts: circle skeletons for avatars, rounded rectangles for headers and action buttons.
```

---

## CSS TYPOGRAPHY & SPACING SYSTEM

To keep perfect alignment, always enforce these mathematical design scales:

```css
/* Typography Scale (Minor Third) */
--text-xs:   0.8rem;    /* 12.8px */
--text-sm:   0.88rem;   /* 14px */
--text-base: 1rem;      /* 16px */
--text-md:   1.2rem;    /* 19.2px */
--text-lg:   1.44rem;   /* 23px */
--text-xl:   1.728rem;  /* 27.6px */
--text-xxl:  2.074rem;  /* 33.2px */

/* Spacing Scale (4px Base / Geometric) */
--space-xxs: 0.25rem;  /* 4px */
--space-xs:  0.5rem;   /* 8px */
--space-sm:  0.75rem;  /* 12px */
--space-md:  1rem;     /* 16px */
--space-lg:  1.5rem;   /* 24px */
--space-xl:  2rem;     /* 32px */
--space-xxl: 3rem;     /* 48px */
```
