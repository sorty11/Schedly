# Bridge Operational Workflow

This document explains step-by-step how **ChatGPT** and **Antigravity** collaborate on any task using the Git repository.

---

## Workflow Diagram

```
ChatGPT                              GitHub                              Antigravity
   │                                    │                                     │
   │ 1. Draft Task (TASK.json)          │                                     │
   │───────────────────────────────────>│                                     │
   │    stage: "planned"                │                                     │
   │                                    │ 2. Pull / Read TASK.json            │
   │                                    │<────────────────────────────────────│
   │                                    │    stage: "executing"               │
   │                                    │                                     │
   │                                    │ 3. Implement & Test locally         │
   │                                    │    (flutter test / analyze)         │
   │                                    │                                     │
   │                                    │ 4. Push branch/main                 │
   │                                    │    stage: "review"                  │
   │                                    │<────────────────────────────────────│
   │                                    │                                     │
   │ 5. Audit Diff & Tests              │                                     │
   │<───────────────────────────────────│                                     │
   │                                    │                                     │
   │ 6a. Approve (stage: "done")        │                                     │
   │───────────────────────────────────>│                                     │
   │                                    │                                     │
   │ [OR] 6b. Request Fixes             │                                     │
   │     (stage: "fix")                 │                                     │
   │───────────────────────────────────>│ 7. Remediate & Re-verify            │
   │                                    │<────────────────────────────────────│
```

---

## Step-by-Step Instructions

### Phase A: Task Creation (ChatGPT)
1. ChatGPT defines the task scope, acceptance criteria, non-negotiable guardrails, and validation commands.
2. Creates `.antigravity/bridge/tasks/<task-id>.json` with:
   - `stage`: `"planned"`
   - `task_id`: Unique identifier (e.g. `"PHASE2_LAW_PARSER"`)
   - `acceptance_criteria`: Array of actionable requirements
   - `scope.target_files` and `scope.frozen_files`
   - `validation.commands`: Array of commands (e.g., `["flutter test test/law_parser_test.dart", "flutter analyze"]`)
3. Updates `.antigravity/bridge/CURRENT_TASK.md` to point to the new task file for human readability.
4. Tells the user or commits to GitHub: *"Task [ID] is planned in `.antigravity/bridge/tasks/<task-id>.json`. Ready for Antigravity."*

### Phase B: Execution & Verification (Antigravity)
1. Antigravity reads `CURRENT_TASK.md` to locate `.antigravity/bridge/tasks/<task-id>.json` and consults `.antigravity/orchestration.md`.
2. Antigravity sets `stage: "executing"` in `tasks/<task-id>.json`.
3. Antigravity inspects target files, applies code changes adhering strictly to `rules/non-negotiable.md`.
4. Antigravity runs all commands in `validation.commands`.
   - If tests or analysis fail, Antigravity diagnoses and fixes until all are green.
5. Antigravity updates `tasks/<task-id>.json`:
   - `stage`: `"review"`
   - `validation.status`: `"PASSED"`
   - `git.current_commit`: Latest commit SHA.
6. Antigravity updates `CURRENT_TASK.md` status to `review` (awaiting human/ChatGPT review).
7. Antigravity commits and pushes to `origin`.

### Phase C: Review & Sign-Off (ChatGPT / Human)
1. ChatGPT inspects the commit diff on GitHub (`git diff`, commit SHA, modified files).
2. ChatGPT checks the `validation.status` in `tasks/<task-id>.json`.
3. If criteria are satisfied:
   - Sets `stage: "done"` in `tasks/<task-id>.json` and updates `CURRENT_TASK.md`.
   - Records approval notes in `review.notes`.
4. If issues or regressions are discovered:
   - Sets `stage: "fix"` in `tasks/<task-id>.json`.
   - Adds concrete feedback in `CURRENT_TASK.md`.
   - Instructs Antigravity to address the findings.

---

## Safety Rules
- **No Background Services**: The bridge is pure Git; no webhooks, daemons, or open ports.
- **No Credentials**: Never commit passwords, tokens, or private endpoints.
- **Immutable Freezes**: Anything listed under `scope.frozen_files` must never be touched.
