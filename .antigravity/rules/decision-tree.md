# Decision Tree

- **Is the request a UI tweak?** -> Use `workflows/component-review.md` -> Verify with `checklists/ui-review.md`.
- **Is the request a new page?** -> Check `playbooks/` -> Use `workflows/generate-ui.md` -> Run past `checklists/ux-review.md`.
- **Is the request adding motion?** -> Check `brain/motion.md` -> Run `workflows/animation-polish.md`.
- **Does it affect data fetching?** -> STOP. Consult `rules/non-negotiable.md` and ensure UI gracefully handles states (`brain/loading-states.md`, `brain/empty-states.md`).
