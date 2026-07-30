import os
import shutil
import re

source_dir = r"C:\Users\ACER\Desktop\schedly\.antigravity"
target_dir = r"C:\Users\ACER\.gemini\config\plugins\ui-ux-os"

if os.path.exists(target_dir):
    shutil.rmtree(target_dir)

# 1. Copy the entire OS to the plugins directory
shutil.copytree(source_dir, target_dir)
print(f"Copied OS to {target_dir}")

# 2. Create plugin.json
plugin_json = """{
  "name": "ui-ux-os",
  "version": "1.0.0",
  "description": "Premium UI/UX Operating System providing design principles, critics, and workflows for Claude.",
  "author": {
    "name": "Antigravity Engineering"
  },
  "license": "Internal",
  "keywords": [
    "ui",
    "ux",
    "design",
    "frontend",
    "accessibility"
  ]
}
"""
with open(os.path.join(target_dir, "plugin.json"), "w", encoding="utf-8") as f:
    f.write(plugin_json)

# 3. Restructure Skills
skills_dir = os.path.join(target_dir, "skills")
md_files = [f for f in os.listdir(skills_dir) if f.endswith(".md") and f != "README.md"]

for md_file in md_files:
    skill_name = md_file.replace(".md", "")
    skill_folder = os.path.join(skills_dir, skill_name)
    os.makedirs(skill_folder, exist_ok=True)
    
    old_file_path = os.path.join(skills_dir, md_file)
    with open(old_file_path, "r", encoding="utf-8") as f:
        content = f.read()
    
    # Extract mission or first bullet point for description
    description = f"Specialized AI persona for {skill_name} tasks."
    match = re.search(r'\*\*Mission\*\*: (.*)', content)
    if match:
        description = match.group(1).strip()
    
    yaml_frontmatter = f"""---
name: {skill_name}
description: {description}
---

"""
    new_content = yaml_frontmatter + content
    
    with open(os.path.join(skill_folder, "SKILL.md"), "w", encoding="utf-8") as f:
        f.write(new_content)
        
    os.remove(old_file_path)

# Update skills/README.md
skills_readme = os.path.join(skills_dir, "README.md")
with open(skills_readme, "r", encoding="utf-8") as f:
    readme_content = f.read()

# Replace links like [ui-designer.md](ui-designer.md) with [ui-designer/SKILL.md](ui-designer/SKILL.md)
for md_file in md_files:
    skill_name = md_file.replace(".md", "")
    readme_content = readme_content.replace(f"[{md_file}]({md_file})", f"[{skill_name}/SKILL.md]({skill_name}/SKILL.md)")

with open(skills_readme, "w", encoding="utf-8") as f:
    f.write(readme_content)

print("Restructured skills into SKILL.md format with YAML frontmatter.")

# Update Orchestration logic
orch_path = os.path.join(target_dir, "orchestration.md")
with open(orch_path, "r", encoding="utf-8") as f:
    orch_content = f.read()

orch_content = orch_content.replace("Adopt a persona from `skills/README.md`", "Invoke the globally registered skill (e.g. `ui-designer`) exposed by the `ui-ux-os` plugin.")

with open(orch_path, "w", encoding="utf-8") as f:
    f.write(orch_content)

print("Migration completed successfully.")
