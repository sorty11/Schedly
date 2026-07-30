import os

base_dir = r"C:\Users\ACER\Desktop\schedly\.antigravity"

files = {
    # PHASE C: SKILLS
    r"skills\motion-designer.md": """# Motion Designer Persona
- **Mission**: Elevate the UI with fluid, physics-based motion.
- **Responsibilities**: Design transition states, route animations, and loading physics.
- **Decision Process**: Never use linear easing. Respect `prefers-reduced-motion`. 
- **Required Workflows**: `workflows/animation-polish.md`
""",

    r"skills\dashboard-designer.md": """# Dashboard Designer Persona
- **Mission**: Organize high-density data into actionable overviews.
- **Responsibilities**: Define KPI widget layouts, table structures, and filtering patterns.
- **Decision Process**: Maximize data-ink ratio. Prioritize essential actions.
- **Required Workflows**: `workflows/generate-ui.md`, `workflows/redesign-ui.md`
""",

    r"skills\premium-ui-reviewer.md": """# Premium UI Reviewer Persona
- **Mission**: Guarantee SaaS-level visual quality.
- **Responsibilities**: Enforce 8pt grid, subtle elevations, typography hierarchy.
- **Decision Process**: Reject any UI that feels "default" or "cheap".
- **Required Workflows**: `workflows/visual-qa.md`
""",

    r"skills\mobile-ui-reviewer.md": """# Mobile UI Reviewer Persona
- **Mission**: Ensure flawless mobile-first usability.
- **Responsibilities**: Enforce 44x44px touch targets, bottom-heavy interaction patterns.
- **Decision Process**: Assume the user is operating the app one-handed.
- **Required Workflows**: `workflows/review-ui.md`
""",

    r"skills\design-system-reviewer.md": """# Design System Reviewer Persona
- **Mission**: Enforce absolute strictness to Design System Tokens.
- **Responsibilities**: Reject hardcoded colors, arbitrary pixel values, and unique fonts.
- **Decision Process**: Must map 1:1 to `/design-system/tokens.md`.
- **Required Workflows**: `workflows/component-review.md`
""",

    r"skills\accessibility-reviewer.md": """# Accessibility Reviewer Persona
- **Mission**: Ensure WCAG 2.1 AA compliance.
- **Responsibilities**: Audit contrast, ARIA labels, tab indexing, and screen reader announcements.
- **Decision Process**: If a visually impaired user cannot use it, it fails.
- **Required Workflows**: `workflows/accessibility-audit.md`
""",

    r"skills\loading-state-optimizer.md": """# Loading State Optimizer Persona
- **Mission**: Make loading feel instantaneous.
- **Responsibilities**: Replace spinners with Skeleton screens, optimize progressive loading.
- **Decision Process**: Predict what the data will look like and render the shape before the data arrives.
- **Required Workflows**: `workflows/performance-improvement.md`
""",

    r"skills\empty-state-generator.md": """# Empty State Generator Persona
- **Mission**: Turn dead ends into opportunities.
- **Responsibilities**: Design friendly placeholders with clear CTAs for empty data views.
- **Decision Process**: Never show a blank white screen.
- **Required Workflows**: `workflows/generate-ui.md`
""",

    r"skills\design-critic.md": """# Design Critic Persona
- **Mission**: Provide harsh, constructive feedback on proposed UI.
- **Responsibilities**: Find edge cases where the UI breaks (long text, translated text, weird viewport sizes).
- **Decision Process**: Try to break the design.
- **Required Workflows**: `workflows/review-ui.md`
""",

    # PHASE D: WORKFLOWS
    r"workflows\redesign-ui.md": """# Workflow: Redesign UI
1. **Goal**: Modernize an existing UI component.
2. **Analysis**: Audit current flaws (Check `checklists/ux-review.md`).
3. **Planning**: Consult `playbooks/` for the ideal standard.
4. **Implementation**: Rewrite layout applying `/design-system/`.
5. **Verification**: Run `workflows/visual-qa.md`.
""",

    r"workflows\audit-ux.md": """# Workflow: Audit UX
1. **Goal**: Identify friction points in user journeys.
2. **Analysis**: Trace the user steps. Are there unnecessary clicks?
3. **Verification**: Consult `checklists/ux-review.md`.
4. **Output**: Deliver a prioritized list of fixes.
""",

    r"workflows\accessibility-audit.md": """# Workflow: Accessibility Audit
1. **Goal**: Ensure total inclusivity.
2. **Analysis**: Scan DOM for missing ARIA, alt text, and low contrast.
3. **Verification**: Cross-reference with `checklists/accessibility.md`.
4. **Output**: Provide code modifications.
""",

    r"workflows\performance-improvement.md": """# Workflow: Performance Improvement
1. **Goal**: Reduce layout shift and main thread blocking.
2. **Analysis**: Identify heavy CSS properties or deep DOM nesting.
3. **Verification**: Check `checklists/performance.md`.
4. **Output**: Optimized code.
""",

    r"workflows\animation-polish.md": """# Workflow: Animation Polish
1. **Goal**: Add premium feel via motion.
2. **Planning**: Review `/brain/animation.md`.
3. **Implementation**: Inject spring physics or optimized CSS transitions.
4. **Verification**: Check `checklists/animation.md`.
""",

    r"workflows\visual-qa.md": """# Workflow: Visual QA
1. **Goal**: Ensure pixel perfection.
2. **Verification**: Compare output against `/design-system/` and `checklists/production-ui.md`.
3. **Output**: Approve or reject with exact pixel correction demands.
""",

    r"workflows\component-review.md": """# Workflow: Component Review
1. **Goal**: Validate atomic component structure.
2. **Analysis**: Check for hardcoded values.
3. **Verification**: Consult `checklists/components.md`.
4. **Output**: Refactored component matching the design system.
""",

    r"workflows\design-system-creation.md": """# Workflow: Design System Creation
1. **Goal**: Extract recurring patterns into reusable tokens.
2. **Analysis**: Scan existing codebase for magic numbers.
3. **Implementation**: Define centralized tokens in `/design-system/`.
""",

    # PHASE E: PLAYBOOKS
    r"playbooks\landing-page.md": """# Landing Page Blueprint
- **Structure**: Hero -> Social Proof -> Features (Bento Grid) -> Pricing -> CTA -> Footer.
- **Principles**: `/brain/visual-hierarchy.md`, `/brain/premium-saas-design.md`.
""",

    r"playbooks\analytics.md": """# Analytics Blueprint
- **Structure**: High-level KPIs at top -> Detail charts below.
- **Principles**: `/brain/charts.md`, `/brain/dashboards.md`.
""",

    r"playbooks\settings.md": """# Settings Blueprint
- **Structure**: Sidebar nav (sections) + Main content (forms).
- **Principles**: `/brain/forms.md`, `/brain/layout-systems.md`.
""",

    r"playbooks\profile.md": """# Profile Blueprint
- **Structure**: Cover image + Avatar -> User metadata -> Recent activity feed.
- **Principles**: `/brain/cards.md`.
""",

    r"playbooks\tables.md": """# Tables Blueprint
- **Structure**: Header with global search/filter -> Column headers (sortable) -> Paginated rows.
- **Principles**: Limit borders. Use zebra striping subtly if at all.
""",

    r"playbooks\authentication.md": """# Authentication Blueprint
- **Structure**: Split screen (left: branding/illustration, right: login form) OR centered card.
- **Principles**: `/brain/forms.md`.
""",

    r"playbooks\onboarding.md": """# Onboarding Blueprint
- **Structure**: Stepper/Wizard. 1 concept per screen.
- **Principles**: `/brain/ux-principles.md` (Minimize cognitive load).
""",

    r"playbooks\mobile.md": """# Mobile Blueprint
- **Structure**: Bottom navigation. Floating action buttons.
- **Principles**: `/brain/responsive-design.md`.
""",

    r"playbooks\desktop.md": """# Desktop Blueprint
- **Structure**: Sidebar navigation. Multi-column layouts.
- **Principles**: Limit line lengths to 70 chars.
""",

    r"playbooks\admin-panel.md": """# Admin Panel Blueprint
- **Structure**: Dense data tables, complex filtering, highly functional.
- **Principles**: `/brain/dashboards.md`.
""",

    r"playbooks\faculty-dashboard.md": """# Faculty Dashboard Blueprint
- **Structure**: Focus on schedule, class lists, and grading tasks.
- **Principles**: `/brain/cards.md`.
""",

    r"playbooks\student-dashboard.md": """# Student Dashboard Blueprint
- **Structure**: Focus on upcoming assignments, schedule, and grades.
- **Principles**: Mobile-first approach heavily prioritized.
""",

    # PHASE F: CRITICS
    r"critics\material-3-critic.md": """# Material 3 Critic
- **Evaluation Criteria**: Checks against `checklists/production-ui.md`. Enforces Dynamic Color and elevation.
- **Common Mistakes**: Using M2 harsh drop shadows instead of M3 tonal elevation.
""",

    r"critics\linear-critic.md": """# Linear Design Critic
- **Evaluation Criteria**: Checks against `checklists/production-ui.md`. Enforces dark mode, high-contrast borders, monochromatic styling, extreme minimalism.
- **Common Mistakes**: Using bright, saturated backgrounds instead of near-blacks.
""",

    r"critics\stripe-critic.md": """# Stripe Design Critic
- **Evaluation Criteria**: Checks against `checklists/production-ui.md`. Enforces diagonal elements, vibrant subtle gradients, crisp typography.
""",

    r"critics\vercel-critic.md": """# Vercel Design Critic
- **Evaluation Criteria**: Checks against `checklists/production-ui.md`. Enforces Geist font, 1px subtle borders, extreme monochrome focus with single pop colors.
""",

    r"critics\premium-saas-critic.md": """# Premium SaaS Critic
- **Evaluation Criteria**: Checks against `checklists/production-ui.md`. Glassmorphism, smooth animations.
""",

    r"critics\motion-critic.md": """# Motion Critic
- **Evaluation Criteria**: Checks against `checklists/animation.md`. Ensures no layout thrashing.
""",

    # PHASE G: PROMPTS
    r"prompts\generate-ui.md": """# Prompt: Generate UI
"Act as `skills/ui-designer.md`. Use `workflows/generate-ui.md`. Create a [INSERT] following `playbooks/[INSERT].md`. Verify with `critics/premium-saas-critic.md`."
""",

    r"prompts\review-ui.md": """# Prompt: Review UI
"Act as `skills/ux-reviewer.md`. Execute `workflows/review-ui.md` on the following code. Use `critics/design-critic.md`."
""",

    r"prompts\redesign-ui.md": """# Prompt: Redesign UI
"Act as `skills/ui-designer.md`. Execute `workflows/redesign-ui.md` to modernize this code."
""",

    r"prompts\dashboard.md": """# Prompt: Dashboard Design
"Act as `skills/dashboard-designer.md`. Follow `playbooks/dashboard.md`."
""",

    r"prompts\accessibility.md": """# Prompt: Accessibility Audit
"Act as `skills/accessibility-reviewer.md`. Execute `workflows/accessibility-audit.md`."
""",

    r"prompts\animation.md": """# Prompt: Animation Polish
"Act as `skills/animation-engineer.md`. Execute `workflows/animation-polish.md`. Audit with `critics/motion-critic.md`."
""",

    r"prompts\premium-polish.md": """# Prompt: Premium Polish
"Act as `skills/premium-ui-reviewer.md`. Audit this against `checklists/production-ui.md`."
""",

    # PHASE H: CHECKLISTS
    r"checklists\ui-review.md": """# UI Review Checklist
- [ ] 8pt grid respected?
- [ ] Hierarchy clear?
- Referenced by: `workflows/review-ui.md`
""",

    r"checklists\ux-review.md": """# UX Review Checklist
- [ ] Number of clicks minimized?
- [ ] Error states friendly?
- Referenced by: `workflows/audit-ux.md`
""",

    r"checklists\accessibility.md": """# Accessibility Checklist
- [ ] Contrast 4.5:1?
- [ ] Keyboard accessible?
- Referenced by: `critics/accessibility-critic.md`
""",

    r"checklists\performance.md": """# Performance Checklist
- [ ] No layout shift?
- [ ] Deep nesting avoided?
- Referenced by: `workflows/performance-improvement.md`
""",

    r"checklists\animation.md": """# Animation Checklist
- [ ] Prefers-reduced-motion respected?
- [ ] Only transform/opacity animated?
- Referenced by: `critics/motion-critic.md`
""",

    r"checklists\components.md": """# Components Checklist
- [ ] Props fully typed?
- [ ] Logic decoupled from styling?
- Referenced by: `workflows/component-review.md`
"""
}

# Write files
for path, content in files.items():
    full_path = os.path.join(base_dir, path)
    os.makedirs(os.path.dirname(full_path), exist_ok=True)
    with open(full_path, "w", encoding="utf-8") as f:
        f.write(content.strip() + "\n")

print("Generated phases C-H successfully.")
