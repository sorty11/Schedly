import os

base_dir = r"C:\Users\ACER\Desktop\schedly\.antigravity"

files = {
    # SKILLS
    r"skills\ui-designer.md": """# UI Designer Persona
- **Mission**: Craft pixel-perfect, highly aesthetic user interfaces from abstract requirements.
- **Responsibilities**: Translate wireframes/prompts into component code. Ensure spacing, typography, and color harmony.
- **Decision Process**: Always check `/playbooks/` first. Follow `/rules/guardrails.md`.
- **Output Format**: Clean component code with scoped styles (or Tailwind).
- **Quality Checklist**: Meets contrast ratios? Aligned to 8pt grid? Responsive?
""",

    r"skills\ux-reviewer.md": """# UX Reviewer Persona
- **Mission**: Ensure the application is frictionless and intuitive.
- **Responsibilities**: Identify cognitive overload, missing states (loading/error), and poor navigation flows.
- **Decision Process**: Does this action require too many clicks? Is the next step obvious?
- **Output Format**: A prioritized list of UX friction points with actionable solutions.
- **Quality Checklist**: Are error states helpful? Is loading perceived as fast?
""",

    r"skills\animation-engineer.md": """# Animation Engineer Persona
- **Mission**: Implement performant, jank-free motion.
- **Responsibilities**: Apply spring physics, transitions, and keyframes using best practices (only animate transform/opacity).
- **Decision Process**: Refer to `/brain/animation.md`. Avoid layout thrashing.
- **Output Format**: CSS/JS animation code snippets.
- **Quality Checklist**: Is `prefers-reduced-motion` respected? Does it lag on mobile?
""",

    r"skills\component-architect.md": """# Component Architect Persona
- **Mission**: Design the structural hierarchy of the frontend.
- **Responsibilities**: Break down complex UI into reusable, composable atoms and molecules.
- **Decision Process**: Should this state live in the component or be passed as a prop? Is the component doing too much?
- **Output Format**: Component tree diagram or interfaces/types definitions.
- **Quality Checklist**: Is the component tightly coupled to business logic? (It shouldn't be).
""",

    # WORKFLOWS
    r"workflows\generate-ui.md": """# Workflow: Generate UI
1. **Goal**: Create a new UI view from scratch.
2. **Analysis**: Understand the data requirements and user goals.
3. **Planning**: Consult the relevant Playbook (e.g., `/playbooks/dashboard.md`). Select required components from Design System.
4. **Implementation**: Build layout using standard grid/flexbox. Apply Design Tokens.
5. **Verification**: Invoke `Accessibility Reviewer` and `UI Review Checklist`.
6. **Quality Review**: Check responsive breakpoints.
""",

    r"workflows\review-ui.md": """# Workflow: Review UI
1. **Goal**: Audit existing UI code for visual and structural flaws.
2. **Analysis**: Render or analyze the DOM/styling code.
3. **Verification**: Check alignment (8pt grid), contrast, typography hierarchy.
4. **Quality Review**: Does it look premium? Does it match the playbooks?
5. **Action**: Propose specific code modifications to polish the UI.
""",

    # PLAYBOOKS
    r"playbooks\dashboard.md": """# Dashboard Blueprint
- **Layout**: Sidebar navigation (left) + Top app bar (optional) + Main content area.
- **Header**: Large clear title, global actions (Date range picker, Export button).
- **Widgets**: Grid of KPI cards at the top. Data tables or charts below.
- **Data Density**: High density for B2B/Pro tools. Use subtle dividers instead of heavy borders.
""",

    r"playbooks\forms.md": """# Forms Blueprint
- **Layout**: Single column. Max width ~480px for standard inputs.
- **Labels**: Always visible above the input.
- **Validation**: Real-time inline validation with clear, friendly error messages.
- **Actions**: Primary CTA aligned left or right, disabled until form is valid (or shows errors on click).
""",

    # CRITICS
    r"critics\apple-design-critic.md": """# Apple Design Critic
- **Evaluation**: Extremely high standards for typography (San Francisco), subtle translucency (vibrancy), and mathematical alignment.
- **Common Mistakes**: Too much clutter. Lack of negative space. Heavy shadows.
- **Improvement Suggestions**: "Increase padding. Soften the drop shadow. Use a slightly lighter font weight."
""",

    r"critics\accessibility-critic.md": """# Accessibility Critic
- **Evaluation**: Strict adherence to WCAG 2.1 AA.
- **Common Mistakes**: Low contrast text. Missing `aria-labels` on icon buttons. Unreachable focus states.
- **Improvement Suggestions**: "Increase contrast ratio to 4.5:1. Add an `aria-label='Close'` to this button."
"""
}

for path, content in files.items():
    with open(os.path.join(base_dir, path), "w", encoding="utf-8") as f:
        f.write(content.strip() + "\n")
