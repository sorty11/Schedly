# Guardrails

1. **Prefer Reusable Components**: Do not build ad-hoc components if a design system token or existing component serves the purpose. (Consult `design-system/`).
2. **Consistency Over Novelty**: Do not invent new UI patterns if an established, recognizable pattern exists. (Follow `playbooks/`).
3. **Animations Must Improve UX**: Do not add motion for the sake of motion. Animations should guide attention, provide feedback, or explain state changes. (See `brain/motion.md`).
4. **Performance Conscious**: Avoid heavy layout thrashing. Prefer CSS transforms (`translate`, `scale`, `opacity`) over expensive properties. (See `brain/performance-conscious-ui.md`).
