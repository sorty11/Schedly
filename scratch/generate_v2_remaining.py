import os
import json

base_dir = r"C:\Users\ACER\.gemini\config\plugins\ui-ux-os"

files = {
    # Missing Mobile Brain
    r"brain\financial-apps.md": """# Financial App Patterns
- **Information Architecture**: Balance visibility is paramount. Use clear typography with monospace numbers for tabular data to prevent horizontal jumping.
- **UX Goals**: Trust and security. Use calm, authoritative colors.
- **Constraints**: Actions like 'Transfer' or 'Pay' must have explicit confirmation barriers to prevent accidental state changes.
""",
    r"brain\education-apps.md": """# Education App Patterns
- **Information Architecture**: Focus on progressive disclosure. Do not overwhelm the user with all curriculum at once.
- **UX Goals**: Motivation and clarity. Use gamification subtly (progress bars, milestone checks).
- **Constraints**: Heavy focus on accessibility and readability for dense reading materials.
""",

    # Missing Schedly Playbooks
    r"playbooks\cr-panel.md": """# CR Panel (Class Representative) Blueprint
- **UX Goals**: Rapid communication broadcasting and schedule override control.
- **Information Architecture**: 1. Urgent Broadcasts. 2. Schedule Adjustment Form. 3. Class feedback inbox.
- **User Journeys**: CR logs in -> taps 'Broadcast' -> selects audience -> writes message -> sends.
- **Design Decisions**: FAB for 'New Broadcast' should be prominent.
""",
    r"playbooks\notifications.md": """# Notifications Blueprint
- **UX Goals**: Zero cognitive overload. Easily distinguish urgent (class cancelled) vs passive (assignment due next week) alerts.
- **Information Architecture**: Segmented control for 'All', 'Unread', 'Urgent'.
- **Design Decisions**: Unread indicators should use the primary brand color. Swipe-to-dismiss behavior is mandatory.
""",
    r"playbooks\analytics.md": """# Analytics Blueprint
- **UX Goals**: At-a-glance comprehension of attendance/performance metrics.
- **Information Architecture**: Top-level summary cards -> Time-series charts -> Detailed breakdown tables.
- **Design Decisions**: Avoid 3D charts. Use simple, high-contrast bar and line charts.
""",
    r"playbooks\profile.md": """# Profile Blueprint
- **UX Goals**: Easy access to academic standing and personal information.
- **Information Architecture**: User Avatar/Header -> Academic details (ID, Course, Year) -> Achievements.
- **Constraints**: Profile edits might require backend synchronization, show loading states explicitly.
""",
    r"playbooks\settings.md": """# Settings Blueprint
- **UX Goals**: Discoverability. 
- **Information Architecture**: Grouped list items (Account, Notifications, Theme, About).
- **Design Decisions**: Use standard platform switches. Deeply nested settings should use a new navigation route, not a dialog.
""",
    r"playbooks\authentication.md": """# Authentication Blueprint
- **UX Goals**: Frictionless entry.
- **Information Architecture**: Social Login -> Or Email/Password -> Forgot Password.
- **User Journeys**: Biometric auto-login is preferred if tokens exist.
- **Constraints**: Must handle network failure states gracefully without losing user input.
"""
}

# Write missing files
for path, content in files.items():
    full_path = os.path.join(base_dir, path)
    os.makedirs(os.path.dirname(full_path), exist_ok=True)
    with open(full_path, "w", encoding="utf-8") as f:
        f.write(content.strip() + "\n")

# Re-generate README manifests to prevent orphans
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

print("Remaining playbooks and mobile patterns generated successfully.")
