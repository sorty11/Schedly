# Orchestration Flow

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
