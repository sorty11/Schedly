import os

base_dir = r"C:\Users\ACER\Desktop\schedly\.antigravity"

# Create memory dir
os.makedirs(os.path.join(base_dir, "memory"), exist_ok=True)

files = {
    # ORCHESTRATION
    "orchestration.md": """# Orchestration Flow

This document defines the strict execution order for Claude when processing any UI/UX request. By following this sequential chain, you ensure that all architectural constraints, principles, and cross-linked evaluations are honored.

## The Execution Chain

1. **Request Reception**: Receive the user request.
2. **Read `INDEX.md`**: Understand the total workspace structure.
3. **Load `memory/project_identity.md`**: Understand the core domain and constraints of the specific project.
4. **Load Rules**: Review `rules/non-negotiable.md` and `rules/guardrails.md`.
5. **Load Brain**: Select the relevant principles from `brain/` based on the request (e.g., `brain/typography.md`, `brain/motion.md`).
6. **Select Skill**: Adopt a persona from `skills/` (e.g., `skills/ui-designer.md`). The skill will mandate which workflow to use.
7. **Select Workflow**: Follow the SOP in `workflows/` (e.g., `workflows/generate-ui.md`).
8. **Consult Playbook**: If generating a screen/component, load the blueprint from `playbooks/` (e.g., `playbooks/dashboard.md`).
9. **Consult References**: If utilizing an advanced motion pattern, check `references/lenis.md` or `references/animate-ui.md`.
10. **Use MCP**: If external integration is required (e.g., fetching a complex standard component), use the `mcp/21st_dev` tools.
11. **Generate UI**: Execute the coding task.
12. **Run Critics**: Pass the generated code through relevant critics (e.g., `critics/accessibility-critic.md`).
13. **Run Checklists**: The critic will verify the output against `checklists/production-ui.md`.
14. **Produce Final Output**: Deliver the code to the user.
15. **Update Memory**: If a new lesson is learned or a design pattern is established, update `memory/lessons_learned.md` or `memory/design_decisions.md`.
""",

    # INDEX
    "INDEX.md": """# Antigravity UI/UX Operating System

Welcome to the Antigravity AI UI/UX Workspace. This is not a repository of documents; it is an interconnected AI Operating System optimized for Claude Opus to deliver production-grade UI/UX code.

## Folder Hierarchy & Purpose

- **/memory/**: Stores stateful project context. (Start here to understand the domain).
- **/rules/**: Non-negotiable boundaries.
- **/brain/**: Definitive engineering principles (UI, UX, Accessibility).
- **/design-system/**: Source-of-truth tokens for spacing, typography, and colors.
- **/skills/**: AI personas. Each skill links to specific **/workflows/**.
- **/workflows/**: Standard Operating Procedures (SOPs). Each workflow links to specific **/playbooks/**.
- **/playbooks/**: Design blueprints for standard views. Playbooks link back to the **/brain/**.
- **/critics/**: Specialized AI reviewers. Each critic evaluates against specific **/checklists/**.
- **/checklists/**: Quality assurance lists.
- **/prompts/**: Reusable prompts that trigger specific combinations of skills and workflows.
- **/references/**: Traceability to original open-source knowledge bases.
- **/mcp/**: Model Context Protocol integrations.

**CRITICAL INSTRUCTION**: Always follow the sequence defined in [orchestration.md](orchestration.md).
""",

    # MEMORY
    r"memory\project_identity.md": """# Project Identity
- **Name**: Schedly (Placeholder)
- **Domain**: TBD (Education / Scheduling assumed)
- **Target Audience**: TBD
- **Core Value Proposition**: TBD
*To be populated during runtime as the AI learns about the specific project.*
""",

    r"memory\architecture_decisions.md": """# Architecture Decisions
- **Frontend Framework**: Flutter / TBD
- **Styling Solution**: TBD
- **State Management**: TBD
*Note: As per `rules/non-negotiable.md`, UI tasks must never modify these fundamental architectural choices.*
""",

    r"memory\coding_conventions.md": """# Coding Conventions
- **Component Structure**: Keep components small. Pass data via props.
- **Naming**: Use strict casing (camelCase for variables, PascalCase for components).
- **File Organization**: Group by feature, not by type.
""",

    r"memory\ui_preferences.md": """# UI Preferences
- **Theme**: Light/Dark mode support required.
- **Aesthetic**: Premium SaaS (Glassmorphism, subtle borders, deep shadows).
*Linked to `/playbooks/` and `/brain/premium-saas-design.md`.*
""",

    r"memory\design_decisions.md": """# Design Decisions
*Log of specific UI/UX decisions made during development (e.g., "Chose sidebar over top nav due to high link density").*
""",

    r"memory\mistakes_to_avoid.md": """# Mistakes to Avoid
*Living document of past errors to prevent regression.*
1. Do not use linear easing for standard layout transitions.
""",

    r"memory\lessons_learned.md": """# Lessons Learned
*Living document of insights gained during development.*
""",

    # RULES (Updated with cross-links)
    r"rules\non-negotiable.md": """# Non-Negotiable Rules

1. **NEVER REDESIGN BACKEND**: You are a UI/UX engineer. Do not modify backend architecture, authentication, Firestore, Cloud Functions, or business logic. (See `memory/architecture_decisions.md`).
2. **PRESERVE FUNCTIONALITY**: Visual upgrades must never break existing features or state management.
3. **NEVER WEAKEN ACCESSIBILITY**: All contrast ratios, ARIA labels, and keyboard navigations must be maintained or improved. (Enforced by `critics/accessibility-critic.md`).
4. **NO ARCHITECTURE SHIFTS**: Do not introduce new state management libraries or structural paradigms during a UI task unless explicitly directed.
5. **READ BEFORE WRITING**: Always review the context and existing code before proposing changes. Always consult `orchestration.md`.
""",

    r"rules\guardrails.md": """# Guardrails

1. **Prefer Reusable Components**: Do not build ad-hoc components if a design system token or existing component serves the purpose. (Consult `design-system/`).
2. **Consistency Over Novelty**: Do not invent new UI patterns if an established, recognizable pattern exists. (Follow `playbooks/`).
3. **Animations Must Improve UX**: Do not add motion for the sake of motion. Animations should guide attention, provide feedback, or explain state changes. (See `brain/motion.md`).
4. **Performance Conscious**: Avoid heavy layout thrashing. Prefer CSS transforms (`translate`, `scale`, `opacity`) over expensive properties. (See `brain/performance-conscious-ui.md`).
""",

    r"rules\decision-tree.md": """# Decision Tree

- **Is the request a UI tweak?** -> Use `workflows/component-review.md` -> Verify with `checklists/ui-review.md`.
- **Is the request a new page?** -> Check `playbooks/` -> Use `workflows/generate-ui.md` -> Run past `checklists/ux-review.md`.
- **Is the request adding motion?** -> Check `brain/motion.md` -> Run `workflows/animation-polish.md`.
- **Does it affect data fetching?** -> STOP. Consult `rules/non-negotiable.md` and ensure UI gracefully handles states (`brain/loading-states.md`, `brain/empty-states.md`).
"""
}

for path, content in files.items():
    with open(os.path.join(base_dir, path), "w", encoding="utf-8") as f:
        f.write(content.strip() + "\n")
