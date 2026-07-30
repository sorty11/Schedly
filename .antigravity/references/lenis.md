# Lenis Reference
- **Summary**: Lightweight, robust, performant smooth scroll library.
- **Purpose**: Replaces janky native scroll with smooth interpolation for parallax and WebGL syncing.
- **Important Concepts**: `requestAnimationFrame` syncing, scroll snapping without fighting physics.
- **Best Practices**: Do not hijack scroll natively; wrap the browser's own scroll so accessibility (sticky, anchors) keeps working.
- **Implementation Ideas**: Use for premium landing pages requiring scroll-linked animations.
- **Ignored**: Framework wrappers. We focus on the core mathematics of the lerp function.
- **Licensing**: MIT.
