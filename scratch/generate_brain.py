import os

base_dir = r"C:\Users\ACER\Desktop\schedly\.antigravity"

brain_files = {
    "ui-principles.md": """# UI Principles
1. **Clarity**: The interface must be completely unambiguous. Users should immediately understand what every element does.
2. **Hierarchy**: Use size, color, and spacing to guide the eye. The most important action should be the most visually prominent.
3. **Familiarity**: Leverage established patterns. Don't reinvent the wheel for standard interactions (e.g., standard play buttons, standard navigation bars).
4. **Efficiency**: Minimize the physical and cognitive load required to accomplish tasks.
5. **Aesthetics**: A beautiful interface increases perceived usability and trust. Premium UI is clean, deliberate, and mathematically aligned.
""",

    "ux-principles.md": """# UX Principles
1. **User-Centricity**: Design for the user's mental model, not the system's underlying architecture.
2. **Feedback**: Every action must have immediate and clear feedback (hover states, active states, loading indicators, success toasts).
3. **Forgiveness**: Users make mistakes. Provide undo capabilities, clear error messages, and easy recovery paths.
4. **Predictability**: The system should behave exactly as the user expects.
5. **Accessibility**: Good UX is inclusive. Do not rely solely on color to convey meaning. Ensure high contrast and keyboard navigability.
""",

    "typography.md": """# Typography
- **Hierarchy**: Use 4-5 distinct type scales (Display, H1-H6, Body, Caption).
- **Legibility**: Body text should ideally be 16px. Line height for body text should be around 1.5. For headings, use a tighter line-height (1.1 to 1.2).
- **Contrast**: Text must meet WCAG AA standards (4.5:1 for normal text).
- **Weights**: Use Font Weights deliberately. Bold (700) or Semibold (600) for emphasis. Regular (400) for readability. Do not use extremely thin fonts for small text.
""",

    "spacing.md": """# Spacing
- **8pt Grid System**: All margins and padding should be multiples of 8 (8, 16, 24, 32, 48, 64). For micro-adjustments, use multiples of 4 (4, 12, 20).
- **Proximity**: Elements that are related should be grouped closer together than elements that are unrelated. (Gestalt principle of proximity).
- **Whitespace**: Do not fear empty space. It provides breathing room, reduces cognitive load, and elevates the perceived quality of the design.
""",

    "color-theory.md": """# Color Theory
- **Primary Color**: The brand color, used for primary actions.
- **Surface Colors**: Backgrounds and cards (e.g., White, Off-white, extremely dark grays for Dark Mode).
- **Semantic Colors**: Green for Success, Red for Destructive/Error, Yellow/Orange for Warning, Blue for Info.
- **Contrast**: Adhere to accessibility contrast standards. Use highly saturated colors sparingly.
- **Dark Mode**: Do not just invert colors. Backgrounds should be dark gray (not pure #000), text should be off-white (to reduce eye strain).
""",
    
    "layout-systems.md": """# Layout Systems
- **Grids**: Use a 12-column grid for standard web layouts to allow for divisible flexibility (halves, thirds, quarters).
- **Max-width**: Do not let text lines span the entire width of an ultrawide monitor. Cap readable content at ~65-75 characters per line (approx. 600-800px max width).
- **Alignment**: Left-align text for readability (in LTR languages). Center alignment should be reserved for short headers or specific isolated elements.
""",

    "responsive-design.md": """# Responsive Design
- **Mobile First**: Design for the smallest screen first, then progressively enhance for larger screens.
- **Fluidity**: Use relative units (%, vw, rem) for scalable layouts.
- **Breakpoints**: Standard breakpoints (sm: 640px, md: 768px, lg: 1024px, xl: 1280px). Layouts should adapt gracefully between these jumps.
- **Touch Targets**: Interactive elements on mobile must be at least 44x44px.
""",

    "accessibility.md": """# Accessibility (a11y)
- **Keyboard Navigation**: The entire app must be navigable via the Tab key. Focus states must be highly visible.
- **ARIA**: Use semantic HTML first. Use ARIA attributes only when semantic HTML falls short.
- **Color Independence**: Never use color alone to communicate state (e.g., a red error border should also have an error icon or text).
- **Screen Readers**: Ensure images have alt text, inputs have labels, and dynamic content changes are announced.
""",

    "motion.md": """# Motion
- **Purposeful**: Motion should serve a purpose: indicating state change, drawing attention, or establishing spatial relationships.
- **Duration**: Fast enough to not feel sluggish, slow enough to be noticed. (Typically 150ms-300ms for micro-interactions, up to 500ms for large page transitions).
- **Easing**: Never use linear easing. Use ease-out for elements entering the screen, ease-in for elements exiting, and ease-in-out for elements moving across the screen.
""",

    "animation.md": """# Animation Integration
Extracted from `animate-ui` and `lenis`.
- **Spring Physics**: For natural feeling UI (like popovers or drag elements), prefer spring-based animations over rigid durations.
- **Scroll Syncing**: Parallax or scroll-triggered animations should be buttery smooth. Utilize a single `requestAnimationFrame` loop.
- **Performance**: Only animate `transform` and `opacity`. Animating `width`, `height`, or `box-shadow` causes layout thrashing.
- **Reduced Motion**: Always respect `prefers-reduced-motion` media queries. Disable heavy animations if the user requests it.
""",

    "micro-interactions.md": """# Micro Interactions
- Small, subtle animations that provide immediate feedback (e.g., a button slightly scaling down on click, a heart icon bursting on like).
- They enhance the "feel" of an app, moving it from functional to premium.
- Keep them under 200ms.
""",

    "navigation.md": """# Navigation
- **Clarity**: The user should always know where they are.
- **Patterns**: Top app bars, side navigation drawers, bottom navigation (mobile).
- **Breadcrumbs**: Use breadcrumbs for deep hierarchies.
- **Active State**: The currently active navigation item must be distinctly styled.
""",

    "forms.md": """# Forms
- **Single Column**: Prefer single-column forms for easier scanning.
- **Inline Validation**: Validate fields immediately as the user types or leaves the field (on blur), rather than waiting for form submission.
- **Clear Labels**: Labels should be permanently visible (avoid placeholder-only forms).
- **Action Buttons**: The primary action (e.g., "Submit") should be distinct from secondary actions ("Cancel").
""",

    "dashboards.md": """# Dashboards
- **Overview First**: The top of the dashboard should provide a high-level summary (KPI cards).
- **Visual Hierarchy**: Use widgets and cards to compartmentalize data.
- **Customizability**: Allow users to filter or rearrange data if appropriate.
- **Data Density**: Balance white space with information density depending on the target user (pro users prefer high density; casual users prefer high white space).
""",

    "cards.md": """# Cards
- Self-contained units of information.
- Should have clear boundaries (subtle border or soft shadow).
- Avoid putting too much actionable content inside a single card to prevent cognitive overload.
- Make the entire card clickable if it represents a single entity.
""",

    "charts.md": """# Charts
- **Simplicity**: Remove unnecessary grid lines and borders. Let the data stand out.
- **Tooltips**: Use interactive tooltips to show exact values on hover.
- **Colors**: Use categorical color palettes for different data series. Ensure color-blind friendly contrast.
- **Empty States**: If there is no data to chart, display a friendly empty state instead of a broken graph.
""",

    "loading-states.md": """# Loading States
- **Skeleton Screens**: Prefer skeleton screens that mimic the layout of the loaded content over infinite spinners.
- **Progressive Loading**: Load text first, then images/heavy content.
- **Feedback**: If an action takes longer than 1 second, provide a loading state. Over 10 seconds, provide a progress bar or text update.
""",

    "empty-states.md": """# Empty States
- Never show a blank screen.
- An empty state should explain *why* it's empty (e.g., "No projects found") and provide a clear Call to Action (CTA) (e.g., "Create your first project").
- Incorporate subtle illustrations or icons to make the state feel intentional and premium.
""",

    "premium-saas-design.md": """# Premium SaaS Design
- **Glassmorphism**: Subtle blurs (`backdrop-filter`) for floating elements like navbars and command palettes.
- **Gradients**: Use highly tailored, multi-stop mesh gradients for marketing sections or subtle backgrounds.
- **Borders**: 1px subtle borders (e.g., `rgba(255,255,255,0.1)`) on dark mode cards.
- **Typography**: Inter, Geist, or custom geometric sans-serif fonts. Tight tracking on headings.
""",

    "material-3.md": """# Material 3 Integration
- **Dynamic Color**: Utilize tonal palettes derived from a single seed color.
- **Elevation**: M3 uses color overlays and subtle shadows for elevation, rather than heavy drop shadows.
- **Shapes**: High use of rounded corners (e.g., fully rounded buttons, rounded cards).
- **Tokens**: Stick to standard M3 tokens (`md.sys.color.primary`, `md.sys.typescale.body-large`) when M3 is requested.
""",

    "component-architecture.md": """# Component Architecture
- **Atomic Design**: Build small, single-purpose components (Atoms) and compose them into complex structures (Organisms).
- **Headless UI**: Where possible, separate the logic (state management, accessibility) from the styling (Tailwind/CSS).
- **Props**: Use typed interfaces for component props. Avoid prop drilling by using Context or state managers when deeply nested.
""",

    "visual-hierarchy.md": """# Visual Hierarchy
- The order in which the human eye perceives what it sees.
- Control it using:
  1. **Size**: Larger elements are noticed first.
  2. **Color/Contrast**: Bright, saturated colors draw the eye against muted backgrounds.
  3. **Spacing**: Elements surrounded by negative space stand out.
  4. **Typography**: Weight and scale define reading order.
""",

    "performance-conscious-ui.md": """# Performance-Conscious UI
- **DOM Size**: Keep the DOM tree shallow. Deep nesting causes rendering lag.
- **Image Optimization**: Always lazy-load images and use modern formats (WebP). Define explicit width/height to prevent Cumulative Layout Shift (CLS).
- **CSS**: Avoid complex CSS selectors (`*`, heavily nested descendants). Utilize utility classes (like Tailwind) to keep stylesheet size minimal.
- **Hydration**: For SSR apps, ensure client-side hydration doesn't block the main thread.
"""
}

for filename, content in brain_files.items():
    path = os.path.join(base_dir, "brain", filename)
    with open(path, "w", encoding="utf-8") as f:
        f.write(content.strip() + "\n")
