import os

base_dir = r"C:\Users\ACER\Desktop\schedly\.antigravity"

files = {
    # DESIGN SYSTEM SPLIT
    r"design-system\spacing.md": """# Spacing Tokens
- **Core System**: 8pt grid (`4px`, `8px`, `12px`, `16px`, `24px`, `32px`, `48px`, `64px`, `96px`, `128px`).
- **Application**: 
  - `4px` - `8px`: Micro adjustments (icons to text).
  - `16px`: Standard inner padding for cards and buttons.
  - `24px` - `32px`: Section spacing and outer margins.
- **Reference**: `/brain/spacing.md`
""",

    r"design-system\typography.md": """# Typography Tokens
- **Font Family**: Primary: Inter / San Francisco. Monospace: JetBrains Mono / SF Mono.
- **Scale**:
  - `xs`: 12px, line-height 1.5
  - `sm`: 14px, line-height 1.5
  - `base`: 16px, line-height 1.5
  - `lg`: 18px, line-height 1.5
  - `xl`: 20px, line-height 1.2
  - `2xl`: 24px, line-height 1.2
  - `3xl`: 30px, line-height 1.2
- **Reference**: `/brain/typography.md`
""",

    r"design-system\colors.md": """# Color Tokens
- **Primary**: Brand-specific blue/purple (`#3b82f6` or similar).
- **Surface**:
  - `surface-100`: `#ffffff` (Light) / `#121212` (Dark)
  - `surface-200`: `#f3f4f6` (Light) / `#1e1e1e` (Dark)
- **Text**:
  - `text-primary`: `#111827` (Light) / `#f9fafb` (Dark)
  - `text-secondary`: `#6b7280` (Light) / `#9ca3af` (Dark)
- **Reference**: `/brain/color-theory.md`
""",

    r"design-system\radius.md": """# Radius Tokens
- **none**: `0px`
- **sm**: `4px` (Small inputs, checkboxes)
- **md**: `8px` (Standard buttons, dropdowns)
- **lg**: `12px` (Cards, modals)
- **full**: `9999px` (Pills, avatars)
- **Reference**: `/brain/material-3.md`
""",

    r"design-system\elevation.md": """# Elevation Tokens
- **sm**: `0 1px 2px 0 rgba(0, 0, 0, 0.05)` (Buttons, subtle lifts)
- **md**: `0 4px 6px -1px rgba(0, 0, 0, 0.1)` (Dropdowns, standard cards)
- **lg**: `0 10px 15px -3px rgba(0, 0, 0, 0.1)` (Modals, popovers)
- **Dark Mode**: Elevation should primarily be achieved by lightening the surface color, not just increasing shadow opacity.
- **Reference**: `/brain/visual-hierarchy.md`
""",

    r"design-system\icons.md": """# Icon Tokens
- **Library**: Lucide Icons or Material Symbols (Rounded).
- **Sizes**: `sm: 16px`, `md: 20px`, `lg: 24px`.
- **Stroke**: Consistently 2px stroke width.
- **Reference**: `/brain/ui-principles.md`
""",

    r"design-system\animations.md": """# Animation Tokens
- **Durations**: 
  - `fast`: 150ms (micro-interactions)
  - `normal`: 300ms (page transitions, modal opens)
  - `slow`: 500ms (complex staggered reveals)
- **Easings**:
  - `ease-out`: `cubic-bezier(0.0, 0.0, 0.2, 1)` (Entering screen)
  - `ease-in`: `cubic-bezier(0.4, 0.0, 1, 1)` (Exiting screen)
  - `ease-in-out`: `cubic-bezier(0.4, 0.0, 0.2, 1)` (On screen movement)
- **Reference**: `/brain/animation.md`, `/brain/motion.md`
""",

    r"design-system\components.md": """# Component Definitions
*List of core atomic components mapped to tokens.*
- **Button**: `md` radius, `base` typography, `normal` animation on active state.
- **Card**: `lg` radius, `surface-100` background, `md` elevation.
- **Reference**: `/brain/component-architecture.md`
""",

    r"design-system\naming-conventions.md": """# Naming Conventions
- **Tokens**: Semantic naming (`text-primary`, `bg-error`) over literal naming (`text-gray-900`, `bg-red-500`).
- **Components**: PascalCase (`PrimaryButton`, `UserProfileCard`).
- **Files**: kebab-case (`primary-button.tsx`, `user-profile-card.vue`).
- **Reference**: `/memory/coding_conventions.md`
"""
}

# Write DS files
for path, content in files.items():
    with open(os.path.join(base_dir, path), "w", encoding="utf-8") as f:
        f.write(content.strip() + "\n")

# Update task.md
with open(os.path.join(base_dir, r"..\artifacts\task.md"), "r") as f:
    task_content = f.read()

task_content = task_content.replace("- [ ] Create `memory/` folder & files", "- [x] Create `memory/` folder & files")
task_content = task_content.replace("- [ ] Update `rules/`", "- [x] Update `rules/`")
task_content = task_content.replace("- [ ] Create `orchestration.md`", "- [x] Create `orchestration.md`")
task_content = task_content.replace("- [ ] Update `INDEX.md`", "- [x] Update `INDEX.md`")
task_content = task_content.replace("- [ ] Verify cross-links", "- [x] Verify cross-links")
task_content = task_content.replace("- [ ] Enhance `brain/` files", "- [x] Enhance `brain/` files")
task_content = task_content.replace("- [ ] Create `design-system/` files (spacing, typography, colors, etc.)", "- [x] Create `design-system/` files (spacing, typography, colors, etc.)")
task_content = task_content.replace("- [ ] Verify terminology", "- [x] Verify terminology")

with open(os.path.join(base_dir, r"..\artifacts\task.md"), "w") as f:
    f.write(task_content)
