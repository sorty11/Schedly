# Animation Integration
Extracted from `animate-ui` and `lenis`.
- **Spring Physics**: For natural feeling UI (like popovers or drag elements), prefer spring-based animations over rigid durations.
- **Scroll Syncing**: Parallax or scroll-triggered animations should be buttery smooth. Utilize a single `requestAnimationFrame` loop.
- **Performance**: Only animate `transform` and `opacity`. Animating `width`, `height`, or `box-shadow` causes layout thrashing.
- **Reduced Motion**: Always respect `prefers-reduced-motion` media queries. Disable heavy animations if the user requests it.
