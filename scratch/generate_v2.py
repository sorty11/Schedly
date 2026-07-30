import os
import json

base_dir = r"C:\Users\ACER\.gemini\config\plugins\ui-ux-os"

files = {
    # PHASE 1: Modern Neumorphism
    r"brain\neumorphism.md": """# Modern Neumorphism Theory
- **Design Philosophy**: Emulates physical surfaces extruding from the background using double-shadow math (light source top-left, shadow bottom-right).
- **Anti-patterns**: Never use neumorphism for primary CTAs (lacks contrast), text inputs (poor accessibility), or dense data tables.
- **Surface Hierarchy**: Base background, Extruded (Cards), Depressed (Inner shadow, track backgrounds).
- **Accessibility**: Fails WCAG contrast if the background and element are the exact same hex without proper border definitions. Always supply a 1px solid border at 5% opacity for edge definition.
""",
    r"design-system\neumorphism_tokens.md": """# Neumorphism Tokens
- **Light Source**: Assume `-45deg` angle (top-left).
- **Outer Shadow (Extruded)**: `-6px -6px 12px rgba(255,255,255,0.8), 6px 6px 12px rgba(0,0,0,0.1)`
- **Inner Shadow (Depressed)**: `inset -4px -4px 8px rgba(255,255,255,0.8), inset 4px 4px 8px rgba(0,0,0,0.1)`
- **Surface**: Background color MUST match the element color perfectly (e.g., `#E0E5EC`).
- **Dark Mode Adjustment**: Pure white shadows look toxic in dark mode. Use `rgba(255,255,255,0.05)` for the light edge.
""",
    r"playbooks\neumorphic-dashboard.md": """# Neumorphic Dashboard Blueprint
- **Structure**: High-level KPI widgets use extruded surfaces. Progress bars use depressed tracks with vibrant, solid-color fills.
- **Constraints**: Apply neumorphism sparingly. Use it for the structural shell (sidebar, topbar) but revert to flat, high-contrast design for the actual data charts.
- **Required Tokens**: `design-system/neumorphism_tokens.md`
""",
    r"critics\neumorphism-critic.md": """# Neumorphism Critic
- **Evaluation Criteria**: Checks against `checklists/production-ui.md` and WCAG AA.
- **Enforcement**: If the element relies PURELY on shadow for definition, reject it and demand a subtle 1px border stroke for accessibility.
""",
    r"skills\neumorphism-designer\SKILL.md": """---
name: neumorphism-designer
description: Specialized persona for rendering accessible, modern neumorphic layouts.
---
# Neumorphism Designer Persona
- **Mission**: Create extruded, physical-feeling interfaces without sacrificing accessibility.
- **Decision Process**: Only apply neumorphism to large structural components or decorative elements. Ensure text contrast is independent of shadow logic.
- **Required Workflows**: `workflows/generate-ui.md`
""",

    # PHASE 2: Flutter UI Intelligence
    r"brain\flutter-ui.md": """# Flutter Layout Architecture
- **Widget Hierarchy**: Keep trees shallow. Extract complex localized state into separate `StatelessWidget` or `StatefulWidget` classes rather than helper methods.
- **Responsive Layouts**: Prefer `LayoutBuilder` and `MediaQuery` for breakpoint routing.
- **Adaptive Layouts**: Abstract platform-specific logic. Render Material on Android, Cupertino on iOS.
- **Component Architecture**: Build dumb, stateless presentational components that receive callbacks.
""",
    r"brain\flutter-animation.md": """# Flutter Motion Engineering
- **Implicit Animations**: Prefer `AnimatedContainer`, `AnimatedOpacity` for simple state changes.
- **Explicit Animations**: Use `AnimationController` with `CurveTween` for complex, staged choreography.
- **Performance**: Never animate layout properties (width, height) in a list. Animate Transforms and Opacity to avoid layout thrashing.
""",
    r"brain\flutter-performance.md": """# Flutter Performance
- **Golden Testing**: Abstract UI components to be testable without the full backend provider scope.
- **Slivers**: Always use `CustomScrollView` and Slivers for heterogenous scrolling lists. Never nest `ListView` inside `SingleChildScrollView`.
- **CustomPainter**: Isolate `CustomPainter` behind `RepaintBoundary` to prevent full-screen redraws.
""",
    r"design-system\flutter_tokens.md": """# Flutter ThemeData Mapping
- **Philosophy**: Define tokens abstractly so they can be injected into `ThemeExtension`.
- **Typography**: Map semantic tokens to `TextTheme` (e.g., `displayLarge`, `bodyMedium`).
- **Spacing**: Do not hardcode `SizedBox(height: 16)`. Use a global spacing extension `context.spacing.md`.
""",
    r"playbooks\flutter-dashboard.md": """# Flutter Dashboard Blueprint
- **Structure**: Utilize `Scaffold` with adaptive `NavigationRail` (desktop) or `BottomNavigationBar` (mobile).
- **Scrolling**: Use `SliverGrid` for KPI widgets to ensure smooth 60fps scrolling on heavy data loads.
""",
    r"workflows\flutter-ui-generation.md": """# Workflow: Flutter UI Generation
1. **Goal**: Scaffold a production-grade Flutter screen.
2. **Analysis**: Define state requirements (Ephemeral vs App State).
3. **Planning**: Route breakpoints (Mobile, Tablet, Desktop).
4. **Implementation**: Build utilizing `brain/flutter-ui.md` constraints.
5. **Verification**: Audit against `critics/flutter-ui-reviewer.md`.
""",
    r"critics\flutter-ui-reviewer.md": """# Flutter UI Reviewer
- **Evaluation Criteria**: Rejects deeply nested `Builder` logic, missing `const` constructors, and layout-thrashing animations.
- **Enforcement**: Demands `RepaintBoundary` on heavy painters.
""",
    r"skills\flutter-ui-designer\SKILL.md": """---
name: flutter-ui-designer
description: Expert Flutter architect focused on performance, Slivers, and declarative UI.
---
# Flutter UI Designer Persona
- **Mission**: Engineer 60fps, jank-free, adaptive Flutter interfaces.
- **Decision Process**: Default to `const`. Prefer Composition over complex state nesting.
- **Required Workflows**: `workflows/flutter-ui-generation.md`
""",

    # PHASE 3: Mobile Design & Schedly Playbooks (Phases 3 & 6 merged for playbooks)
    r"brain\mobile-patterns.md": """# Mobile UX Patterns
- **Apple HIG**: Emphasize translucency, deep navigation stacks, and bottom-heavy interaction.
- **Android M3**: Emphasize dynamic color, prominent FABs, and tonal elevation.
- **Bottom Navigation**: Maximum 5 destinations. Always preserve state between tabs.
- **Sheets & Dialogs**: Prefer bottom sheets for complex interactions (reachable by thumb) over center dialogs.
""",
    r"playbooks\student-home.md": """# Student Home Blueprint
- **Structure**: Focus purely on the immediate present. 
- **Hierarchy**: 1. Current/Next Class (Hero Card). 2. Today's remaining schedule. 3. Upcoming critical deadlines.
- **Mobile First**: FAB for "Quick Add Task".
""",
    r"playbooks\faculty-home.md": """# Faculty Home Blueprint
- **Structure**: Focus on action items and class overviews.
- **Hierarchy**: 1. Next Lecture. 2. Pending Attendance/Grades. 3. Department Announcements.
""",
    r"playbooks\attendance.md": """# Attendance Blueprint
- **Structure**: Dense list optimized for rapid tapping.
- **Interaction**: Swipes or large toggle buttons for Present/Absent. Default to Present to save clicks.
""",
    r"playbooks\weekly-timetable.md": """# Weekly Timetable Blueprint
- **Structure**: Horizontal infinite scroll or snap-to-day logic.
- **Visuals**: Color-code by subject or lecture type (Lab vs Theory).
""",

    # PHASE 4: Motion Expanded
    r"brain\advanced-motion.md": """# Advanced Motion & Physics
- **Spring Physics**: Use critically damped springs for UI elements to prevent rubber-banding unless intended (e.g., Apple-style overscroll).
- **Micro-interactions**: Button down-states should shrink slightly (`scale: 0.98`) to mimic physical compression.
- **Skeletons**: Shimmer effects should move left-to-right, matching reading direction. Keep skeleton shapes generic, not overly detailed.
""",

    # PHASE 5: Expanded Tokens
    r"design-system\glass_tokens.md": """# Glassmorphism Tokens
- **Backdrop Blur**: `12px` to `24px` for modals, `8px` for navbars.
- **Surface**: White at `10% - 40%` opacity (Light mode) or Black at `40% - 60%` opacity (Dark mode).
- **Border**: Essential! `1px solid rgba(255,255,255, 0.2)` on top and left edges to simulate light reflection.
"""
}

# 1. Write the new files
for path, content in files.items():
    full_path = os.path.join(base_dir, path)
    os.makedirs(os.path.dirname(full_path), exist_ok=True)
    with open(full_path, "w", encoding="utf-8") as f:
        f.write(content.strip() + "\n")

# 2. Update plugin.json
plugin_json_path = os.path.join(base_dir, "plugin.json")
with open(plugin_json_path, "r", encoding="utf-8") as f:
    plugin_data = json.load(f)

plugin_data["version"] = "2.0.0"
if "flutter" not in plugin_data["keywords"]:
    plugin_data["keywords"].extend(["flutter", "neumorphism", "mobile", "motion"])

with open(plugin_json_path, "w", encoding="utf-8") as f:
    json.dump(plugin_data, f, indent=2)

# 3. Update README manifests to prevent orphans
dirs = [
    "brain", "references", "skills", "workflows",
    "playbooks", "critics", "templates", "prompts",
    "rules", "checklists", "design-system", "memory", "mcp/21st_dev"
]

for d in dirs:
    dir_path = os.path.join(base_dir, d)
    if not os.path.exists(dir_path):
        continue
    
    files_in_dir = [f for f in os.listdir(dir_path) if f.endswith(".md") and f != "README.md"]
    
    # Sort for consistency
    files_in_dir.sort()
    
    readme_content = f"# {d.capitalize()} Directory Manifest\n\n"
    for f in files_in_dir:
        readme_content += f"- [{f}]({f})\n"
        
    with open(os.path.join(dir_path, "README.md"), "w", encoding="utf-8") as f_out:
        f_out.write(readme_content)

print("v2 Upgrade Generated successfully.")
