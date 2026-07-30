# Performance-Conscious UI
- **DOM Size**: Keep the DOM tree shallow. Deep nesting causes rendering lag.
- **Image Optimization**: Always lazy-load images and use modern formats (WebP). Define explicit width/height to prevent Cumulative Layout Shift (CLS).
- **CSS**: Avoid complex CSS selectors (`*`, heavily nested descendants). Utilize utility classes (like Tailwind) to keep stylesheet size minimal.
- **Hydration**: For SSR apps, ensure client-side hydration doesn't block the main thread.
