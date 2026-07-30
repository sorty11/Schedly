# Component Architecture
- **Atomic Design**: Build small, single-purpose components (Atoms) and compose them into complex structures (Organisms).
- **Headless UI**: Where possible, separate the logic (state management, accessibility) from the styling (Tailwind/CSS).
- **Props**: Use typed interfaces for component props. Avoid prop drilling by using Context or state managers when deeply nested.
