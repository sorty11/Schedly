import os

base_dir = r"C:\Users\ACER\Desktop\schedly\.antigravity"

# Directories to process
dirs = [
    "brain", "references", "skills", "workflows",
    "playbooks", "critics", "templates", "prompts",
    "rules", "checklists", "design-system", "memory", "mcp/21st_dev"
]

# 1. Generate Folder READMEs
for d in dirs:
    dir_path = os.path.join(base_dir, d)
    if not os.path.exists(dir_path):
        continue
    
    files_in_dir = [f for f in os.listdir(dir_path) if f.endswith(".md") and f != "README.md"]
    
    readme_content = f"# {d.capitalize()} Directory Manifest\n\n"
    for f in files_in_dir:
        readme_content += f"- [{f}]({f})\n"
        
    with open(os.path.join(dir_path, "README.md"), "w", encoding="utf-8") as f_out:
        f_out.write(readme_content)

# 2. Update INDEX.md to point to READMEs
index_path = os.path.join(base_dir, "INDEX.md")
index_content = """# Antigravity UI/UX Operating System

Welcome to the Antigravity AI UI/UX Workspace. This is not a repository of documents; it is an interconnected AI Operating System optimized for Claude Opus to deliver production-grade UI/UX code.

## Master Directory Registry

- [Memory](memory/README.md)
- [Rules](rules/README.md)
- [Brain](brain/README.md)
- [Design System](design-system/README.md)
- [Skills](skills/README.md)
- [Workflows](workflows/README.md)
- [Playbooks](playbooks/README.md)
- [Critics](critics/README.md)
- [Checklists](checklists/README.md)
- [Prompts](prompts/README.md)
- [References](references/README.md)
- [MCP](mcp/21st_dev/README.md)

**CRITICAL INSTRUCTION**: Always follow the sequence defined in [orchestration.md](orchestration.md).
"""
with open(index_path, "w", encoding="utf-8") as f:
    f.write(index_content)

# 3. Fix Broken Link
prompt_review_path = os.path.join(base_dir, r"prompts\review-ui.md")
if os.path.exists(prompt_review_path):
    with open(prompt_review_path, "r", encoding="utf-8") as f:
        content = f.read()
    content = content.replace("critics/design-critic.md", "skills/design-critic.md")
    with open(prompt_review_path, "w", encoding="utf-8") as f:
        f.write(content)

# 4. Refine Orchestration
orchestration_path = os.path.join(base_dir, "orchestration.md")
orchestration_content = """# Orchestration Flow

This document defines the strict execution order for Claude when processing any UI/UX request. By following this sequential chain, you ensure that all architectural constraints, principles, and cross-linked evaluations are honored.

## Dynamic Skill Selection Logic
- **UI Generation**: Invoke `skills/ui-designer.md`
- **Data Rendering**: Invoke `skills/dashboard-designer.md`
- **Accessibility Check**: Invoke `skills/accessibility-reviewer.md`
- **Motion/Interaction**: Invoke `skills/animation-engineer.md` or `skills/motion-designer.md`
- **Quality Assurance**: Invoke `skills/premium-ui-reviewer.md` or `skills/design-critic.md`

## The Execution Chain
1. **Request Reception**: Receive the user request.
2. **Read `INDEX.md`**: Understand the total workspace structure.
3. **Load Memory**: Review `memory/README.md`.
4. **Load Rules**: Review `rules/README.md`.
5. **Select Skill**: Adopt a persona from `skills/README.md` using the dynamic logic above.
6. **Select Workflow**: Follow the SOP in `workflows/README.md` dictated by the skill.
7. **Consult Playbook**: Load blueprints from `playbooks/README.md` based on metadata tags.
8. **Consult Design System**: Load tokens from `design-system/README.md`.
9. **Use MCP**: If external integration is required, consult `mcp/21st_dev/README.md`.
10. **Generate Output**: Execute the coding task.
11. **Run Critics**: Evaluate against `critics/README.md`.
12. **Run Checklists**: Verify against `checklists/README.md`.
13. **Update Memory**: Update `memory/lessons_learned.md` if needed.
"""
with open(orchestration_path, "w", encoding="utf-8") as f:
    f.write(orchestration_content)

print("Final polish complete.")
