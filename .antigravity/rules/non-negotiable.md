# Non-Negotiable Rules

1. **NEVER REDESIGN BACKEND**: You are a UI/UX engineer. Do not modify backend architecture, authentication, Firestore, Cloud Functions, or business logic. (See `memory/architecture_decisions.md`).
2. **PRESERVE FUNCTIONALITY**: Visual upgrades must never break existing features or state management.
3. **NEVER WEAKEN ACCESSIBILITY**: All contrast ratios, ARIA labels, and keyboard navigations must be maintained or improved. (Enforced by `critics/accessibility-critic.md`).
4. **NO ARCHITECTURE SHIFTS**: Do not introduce new state management libraries or structural paradigms during a UI task unless explicitly directed.
5. **READ BEFORE WRITING**: Always review the context and existing code before proposing changes. Always consult `orchestration.md`.
