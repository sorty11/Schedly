import os
import json

base_dir = r"C:\Users\ACER\.gemini\config\plugins\ui-ux-os"

files = {
    # Brain Documents
    r"brain\perceived-performance.md": """# Perceived Performance & Latency
- **Philosophy**: If a UI responds instantly, users perceive it as fast, even if the backend is slow.
- **Optimistic UI**: Immediately update the visual state (e.g., toggling a switch) before the network request completes. If the request fails, revert the state gracefully. *(Note: Do not alter existing state management architectures to achieve this; implement locally within the widget if possible).*
- **Touch Latency**: Tap targets must respond within 50ms with a ripple or scale effect.
- **Instant Feedback**: Never leave a user wondering if their tap registered.
""",
    r"brain\rendering-performance.md": """# Rendering Efficiency & Jank Prevention
- **60/120 FPS Target**: Maintain a strict 16ms (or 8ms) frame budget.
- **Widget Composition**: Avoid deep widget nesting purely for styling. Use composition and semantic layout widgets.
- **Memory & Battery**: Overusing blurs (`BackdropFilter`) forces the GPU to recalculate every frame if the background changes. Use blurs sparingly to preserve battery life.
- **Chart Rendering**: For dashboards, limit the number of active chart nodes. 
- *Architectural Note*: If rendering massive data sets fundamentally bottlenecks the UI, consider server-side pagination, but **do not** rewrite backend APIs or state schemas to fix this without explicit authorization.
""",
    r"brain\loading-strategies.md": """# Loading Strategies
- **Skeleton Loading**: Display the shape of the data before it arrives. Ensure the skeleton shimmer matches the application's read direction.
- **Progressive Loading**: Load text and structure first, then high-res images.
- **Infinite Scrolling vs Pagination**: Utilize lazy loading for infinite lists.
- **Image Loading**: Always cache images and provide low-res placeholders. *(Note: Do not alter existing backend services or CDN architectures to achieve this).*
""",
    r"brain\animation-performance.md": """# Animation Smoothness
- **Jank Prevention**: Only animate properties that do not trigger layout recalculations (e.g., Opacity, Transform). Animating `width` or `height` is strictly prohibited in heavy layouts.
- **Transition Smoothness**: Hero animations and page transitions must not block the main thread.
- **Gesture Responsiveness**: Scroll velocity should map 1:1 to finger movement (zero input lag).
""",

    # Playbooks & Checklists
    r"playbooks\performance-first-ui.md": """# Performance-First UI Blueprint
- **Design Philosophy**: Performance *is* Design. Aesthetic complexity must yield to responsiveness.
- **Structure**: Flat UI hierarchies. 
- **Constraints**: 
  - Maximum 1 `BackdropFilter` (glass effect) visible on screen at any time.
  - No complex layered shadows on scrollable list items.
  - *(Note: Maintain all existing Schedly authentication flows, Firestore schemas, and navigation routes. This playbook only governs how widgets are painted, not how they are wired).*
""",
    r"checklists\performance-checklist.md": """# UI Performance Checklist
- [ ] Tap targets respond visually within 50ms?
- [ ] No layout properties (`width`, `height`) are animated?
- [ ] Skeletons provided for async data?
- [ ] Lists use lazy rendering (e.g., `SliverList`)?
- [ ] Glassmorphism/blur effects limited to static elements?
- **Referenced by**: `critics/performance-critic.md`
""",

    # Critic & Skill
    r"critics\performance-critic.md": """# Performance Critic Persona
- **Evaluation Criteria**: Checks against `checklists/performance-checklist.md`.
- **Enforcement**: Ruthlessly reject any design that introduces unnecessary rendering work, overuses shadows/blurs, or feels sluggish. If visual effects reduce responsiveness, demand a lighter alternative.
- **Architectural Boundary**: Do not demand changes to backend logic, API contracts, or state management paradigms to solve performance issues. Focus purely on presentation layer efficiency.
""",
    r"skills\performance-architect\SKILL.md": """---
name: performance-architect
description: Persona dedicated to guaranteeing 60fps rendering, low latency, and battery-efficient UI composition.
---
# Performance Architect Persona
- **Mission**: Ensure every UI prioritizes responsiveness, smooth animations, and rendering efficiency.
- **Decision Process**: Performance must be treated as part of design. If a premium aesthetic causes jank, degrade gracefully to a performant alternative.
- **Required Workflows**: Consult `playbooks/performance-first-ui.md`.
"""
}

# 1. Write the new files
for path, content in files.items():
    full_path = os.path.join(base_dir, path)
    os.makedirs(os.path.dirname(full_path), exist_ok=True)
    with open(full_path, "w", encoding="utf-8") as f:
        f.write(content.strip() + "\n")

# 2. Update rules/non-negotiable.md
rules_path = os.path.join(base_dir, r"rules\non-negotiable.md")
with open(rules_path, "a", encoding="utf-8") as f:
    f.write("\n## 4. Performance is Design\nPerformance is a non-negotiable aspect of design. If visual effects significantly reduce responsiveness, prefer a lighter alternative while maintaining a premium appearance. Do not alter backend architecture to achieve this.\n")

# 3. Update plugin.json to v2.1.0
plugin_json_path = os.path.join(base_dir, "plugin.json")
with open(plugin_json_path, "r", encoding="utf-8") as f:
    plugin_data = json.load(f)

plugin_data["version"] = "2.1.0"
if "performance" not in plugin_data["keywords"]:
    plugin_data["keywords"].append("performance")

with open(plugin_json_path, "w", encoding="utf-8") as f:
    json.dump(plugin_data, f, indent=2)

# 4. Regenerate README manifests to prevent orphans
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
    files_in_dir.sort()
    
    readme_content = f"# {d.capitalize()} Directory Manifest\n\n"
    for f in files_in_dir:
        readme_content += f"- [{f}]({f})\n"
        
    with open(os.path.join(dir_path, "README.md"), "w", encoding="utf-8") as f_out:
        f_out.write(readme_content)

print("v2.1 Upgrade Generated successfully.")
