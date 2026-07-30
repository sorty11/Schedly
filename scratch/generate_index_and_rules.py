import os

base_dir = r"C:\Users\ACER\Desktop\schedly\.antigravity"

files = {
    "INDEX.md": """# Antigravity UI/UX Operating System

Welcome to the Antigravity AI UI/UX Workspace. This environment is designed to optimize Claude Opus for producing high-quality, maintainable, accessible, and production-ready UI/UX work without compromising existing project architecture.

## Folder Hierarchy & Purpose

- **/brain/**: The core engineering knowledge base. Contains definitive guidelines on UI/UX principles, design systems, layouts, motion, and accessibility.
- **/references/**: Source traceability. Contains extracted intelligence from open-source repositories (e.g., `inspira-ui`, `animate-ui`, `lenis`).
- **/skills/**: AI personas. Contains specialized role definitions (e.g., `ui-designer`, `ux-reviewer`) defining mission, responsibilities, and decision matrices.
- **/workflows/**: Standard Operating Procedures (SOPs). Step-by-step guides for executing specific tasks like generating UI, auditing UX, or polishing animations.
- **/playbooks/**: Design blueprints. Architectural standards for specific layouts like Dashboards, Landing Pages, or Settings screens.
- **/critics/**: Specialized AI reviewers. Personas that critique designs based on strict paradigms (e.g., Apple Design Critic, Accessibility Critic).
- **/templates/**: Reusable code and structural templates.
- **/prompts/**: Reusable prompts for specific contexts and generations.
- **/rules/**: Non-negotiable constraints and guardrails for the AI.
- **/checklists/**: Quality assurance lists for verification before final output.
- **/design-system/**: Global design tokens (Spacing, Typography, Radius, Colors).
- **/mcp/**: Model Context Protocol integrations (e.g., `21st_dev`).

## Loading Order & Usage Guidelines

1. **Rules First**: Always respect the constraints in `/rules/non-negotiable.md` and `/rules/guardrails.md`.
2. **Assign Skills**: When a user makes a request, assume the relevant persona from `/skills/`.
3. **Select Playbook**: If building a new screen, consult the corresponding blueprint in `/playbooks/`.
4. **Follow Workflows**: Execute the task using the exact SOP mapped in `/workflows/`.
5. **Summon Critics**: Before presenting the final output, run it past the relevant critics in `/critics/` and verify against `/checklists/`.
""",
    
    r"rules\non-negotiable.md": """# Non-Negotiable Rules

1. **NEVER REDESIGN BACKEND**: You are a UI/UX engineer. Do not modify backend architecture, authentication, Firestore, Cloud Functions, or business logic.
2. **PRESERVE FUNCTIONALITY**: Visual upgrades must never break existing features or state management.
3. **NEVER WEAKEN ACCESSIBILITY**: All contrast ratios, ARIA labels, and keyboard navigations must be maintained or improved.
4. **NO ARCHITECTURE SHIFTS**: Do not introduce new state management libraries or structural paradigms during a UI task unless explicitly directed.
5. **READ BEFORE WRITING**: Always review the context and existing code before proposing changes.
""",

    r"rules\guardrails.md": """# Guardrails

1. **Prefer Reusable Components**: Do not build ad-hoc components if a design system token or existing component serves the purpose.
2. **Consistency Over Novelty**: Do not invent new UI patterns if an established, recognizable pattern exists.
3. **Animations Must Improve UX**: Do not add motion for the sake of motion. Animations should guide attention, provide feedback, or explain state changes.
4. **Performance Conscious**: Avoid heavy layout thrashing. Prefer CSS transforms (`translate`, `scale`, `opacity`) over expensive properties.
""",

    r"rules\decision-tree.md": """# Decision Tree

- **Is the request a UI tweak?** -> Use `Component Review` workflow -> Verify with `UI Review Checklist`.
- **Is the request a new page?** -> Check `/playbooks/` -> Use `Generate UI` workflow -> Run past `UX Review Checklist`.
- **Is the request adding motion?** -> Check `/brain/motion.md` -> Run `Improve Animations` workflow.
- **Does it affect data fetching?** -> STOP. Consult backend rules and ensure UI gracefully handles Loading/Empty/Error states.
"""
}

for path, content in files.items():
    with open(os.path.join(base_dir, path), "w", encoding="utf-8") as f:
        f.write(content.strip() + "\n")
