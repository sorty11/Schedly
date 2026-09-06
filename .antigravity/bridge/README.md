# Antigravity Bridge Quickstart Guide

This guide explains how **ChatGPT** and **Antigravity** collaborate on Schedly development tasks via GitHub.

---

## Architecture

```
┌──────────────┐         Git Commit / Push         ┌───────────────┐
│              │ ─────────────────────────────────> │               │
│   ChatGPT    │                                    │  GitHub Repo  │
│ (Planner &   │ <───────────────────────────────── │ (Control Plane│
│  Reviewer)   │        Diffs & Validation          │  & Single SSOT│
└──────────────┘                                    └───────────────┘
                                                           ▲ │
                                            Pull / Execute │ │ Push / Review
                                                           │ ▼
                                                    ┌───────────────┐
                                                    │               │
                                                    │  Antigravity  │
                                                    │  (Executor &  │
                                                    │   Validator)  │
                                                    └───────────────┘
```

---

## How to Run a New Task

### 1. ChatGPT Prepares the Task
Creates `.antigravity/bridge/tasks/<task-id>.json`:
- Set `"stage": "planned"`
- Define `"task_id"` (e.g. `"PHASE2_LAW_PARSER"`)
- Specify `"scope"`:
  - `"target_files"`: Files allowed to be modified or created.
  - `"frozen_files"`: Files that MUST NOT be changed.
- List strict `"acceptance_criteria"`.
- Provide automated `"validation.commands"`.

ChatGPT also updates `.antigravity/bridge/CURRENT_TASK.md` to point to the new task file.

### 2. Antigravity Executes the Task
When invoked:
1. Antigravity reads `CURRENT_TASK.md`, loads `tasks/<task-id>.json`, and transitions `"stage": "executing"`.
2. Antigravity modifies code only within the defined scope.
3. Antigravity executes each command in `"validation.commands"`:
   - `flutter test`
   - `flutter analyze`
4. When all checks pass:
   - Antigravity updates `"stage": "review"` in `tasks/<task-id>.json` (awaiting review).
   - Records latest commit in `"git.current_commit"`.
   - Antigravity commits and pushes to `main`.

### 3. ChatGPT Reviews the Output
1. ChatGPT inspects the commit diff on GitHub.
2. ChatGPT inspects the test run summaries in `tasks/<task-id>.json`.
3. If approved:
   - Sets `"stage": "done"` with sign-off notes in `"review.notes"`. (**Antigravity never sets done**).
4. If issues remain:
   - Sets `"stage": "fix"` with remediation instructions.
   - Antigravity automatically addresses the feedback and re-validates.
   - Antigravity automatically addresses the feedback and re-validates.

---

## Core Safety Rules
1. **Never Blindly Execute Destructive Changes**: No DB drops, no mass deletions, no force pushes.
2. **Feature Freeze Respect**: Frozen files must never be altered.
3. **No Secrets**: Never commit passwords, tokens, or credentials to Git.
