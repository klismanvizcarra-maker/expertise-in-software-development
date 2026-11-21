# Multi-Agent System Global Rules (Master Agent Governance)

> **Golden Rule**: This document governs the behavior of all artificial intelligence agents working on this project. Every agent must unconditionally and strictly adhere to these directives.

---

## 1. Session Start Protocol (Mandatory Reading)

Before processing any requirement that will **modify files**, the agent's mandatory first step is:
1. Read `GLOBAL_STATE.md` in the project root: metadata, current phase, active contracts, and master task board (`TASK-XXX`).
2. If `GLOBAL_STATE.md` does not exist, load the `orchestrator-agent` skill and initialize it from `.agents/templates/GLOBAL_STATE_TEMPLATE.md` (or `.en.md`).
3. Before designing, refactoring, or fixing a bug, review `BRAIN.md` (lessons learned `LL-XXX`, *gotchas*, and preferences) to prevent repeating anti-patterns.

> Questions, architectural explanations, and read-only inspections do not require a task or prior state reading.

---

## 2. Roles, Skills and Entry Point

1. **One Agent = One Skill**: each role (`orchestrator-agent`, `backend-agent`, etc.) is encapsulated as a skill under `.agents/skills/`. It activates automatically when a user request matches its description, or explicitly via `/<skill-name>`.
2. **Explicit Role Switching**: if a single agent chains roles, it must declare the switch (`→ Acting as qa-security-agent`) and load the respective skill before continuing.
3. **Single Entry Point**: every new requirement or scope change must be routed through the `orchestrator-agent`. If the idea is still unrefined, it routes first to `product-manager-agent` (or `research-agent`).
4. **Zero Code Without Active Task**: no agent creates or modifies code without a registered `TASK-XXX` containing verifiable Acceptance Criteria in `GLOBAL_STATE.md`. In Claude Code, this is enforced by `.agents/scripts/require-active-task.sh`. In Antigravity, the agent executes `./.agents/scripts/task.sh check <paths>` before editing.
5. **Workflow Skills**: standard lifecycle actions have dedicated skills: `/iniciar-proyecto`, `/adoptar-proyecto`, `/crear-plan`, `/estado`, `/nueva-tarea`, `/probar-usuario`, `/bugfix`, `/hotfix`, `/incidente`, `/refactor`, `/pr-review`, `/onboarding`, `/explain-codebase`, `/aprobar`, `/handoff`, `/qa-review`, `/aprender`, `/cerrar-fase`, and `/release`.
6. **Stack & Domain Skills**: when a project uses a defined stack (`stack-angular-express-postgres`, `stack-nextjs-tailwind-prisma`, etc.) or specialized domains (payments, SEO, performance, a11y, observability), the agent loads the relevant companion skills.

---

## 3. Task Lifecycle (Single Source of Truth)

All task state transitions are performed **exclusively** through `./.agents/scripts/task.sh`:

| Transition | Command | Executed By |
| :--- | :--- | :--- |
| Create task (`TODO`) | `task.sh add "<desc>" "<agent>" "<criteria>"` | `orchestrator-agent` |
| `TODO` → `IN_PROGRESS` (+ Git branch) | `task.sh start TASK-XXX` | Assigned Specialist |
| Hold for human approval (`AWAITING_HUMAN_APPROVAL`) | `task.sh hold TASK-XXX ["reason"]` | Orchestrator / Specialist |
| Approve checkpoint (`→ TODO` or `IN_PROGRESS`) | `task.sh approve TASK-XXX [--status S] [--comment C]` | Human / Orchestrator |
| `IN_PROGRESS` → `IN_REVIEW_QA` | `task.sh handoff TASK-XXX` | Assigned Specialist |
| `IN_REVIEW_QA` → `IN_PROGRESS` (rejection, +1 iteration) | `task.sh reject TASK-XXX "<reason>"` | `qa-security-agent` |
| Resume after rejection | `task.sh start TASK-XXX` | Assigned Specialist |
| `IN_REVIEW_QA` → `DONE` | `task.sh close TASK-XXX [--lesson LL-XXX \| --no-lesson "<reason>"]` | `qa-security-agent` |
| Exit `BLOCKED` (resets to 0/3) | `task.sh move TASK-XXX <STATE>` | `orchestrator-agent` (human decision) |
| Reprioritize (`TODO` or `BACKLOG`) | `task.sh move TASK-XXX <STATE>` | `orchestrator-agent` |

```text
TODO ──start──> IN_PROGRESS ──handoff──> IN_REVIEW_QA ──close──> DONE
  │                  ▲                        │
  │                  └────── reject (n/3) ────┘   reject at 3/3 ──> BLOCKED ──> ESCALATION TO HUMAN
  │                  ▲
  └── hold ──> AWAITING_HUMAN_APPROVAL ──approve──> TODO / IN_PROGRESS
```

**Git Merge & Branch Cleanup**: Once QA approves (`task.sh close TASK-XXX`), the assigned specialist or Orchestrator merges the branch to `main` with `git checkout main && git merge --no-ff <branch>` to preserve commit history, followed immediately by `git branch -d <branch>` to delete the local branch.

---

## 4. Integration Contracts & QA Veto Power

1. **Mandatory Contract-First**: When a feature requires new or updated endpoints, `backend-agent` defines or updates `contracts.json` before or in parallel with implementation. Validate with `./.agents/scripts/task.sh contracts validate [path]`.
2. **QA Veto Power**: `qa-security-agent` rejects any delivery that fails even 1 Acceptance Criterion, breaks tests, violates contracts, or exposes security flaws.
3. **Anti-Deadlock Rule (3 Iterations Limit)**: Each rejection increments `n/3`. At **3/3**, the task transitions to `BLOCKED`, and the Orchestrator escalates to the human user with actionable resolution options.

---

## 5. Version Control Conventions (Git)

1. **Branches per Task**: Worked on dedicated branches (`feature/TASK-XXX-...`, `fix/TASK-XXX-...`, `refactor/TASK-XXX-...`).
2. **Conventional Commits**: Format `type(TASK-XXX): imperative summary`. Applied automatically via `./.agents/scripts/task.sh commit TASK-XXX "<desc>" [type]`.
3. **No-Fast-Forward Merge**: Merged to `main` using `git merge --no-ff <branch>` followed by deleting the local branch.

---

## 6. Security & Data Protection

1. **Zero Secrets in Repo**: API keys, credentials, and tokens must always be loaded via environment variables (`.env`).
2. **Destructive Commands Prohibited**: No agent is permitted to execute `rm -rf`, `DROP TABLE`, `DROP DATABASE`, or `git push --force` without explicit human authorization.
3. **Secure Error Handling**: Never leak internal database errors or stack traces to clients.

---

## 7. Project Brain & Persistent Memory

1. **Prior Brain Consultation**: Before complex refactoring or bug fixing, inspect `BRAIN.md` or `.agents/brain/lessons_learned.md`. Directed lookup: `./.agents/scripts/task.sh brain for TASK-XXX [paths...]`.
2. **Mandatory Lesson Registration**: Any task with a QA rejection or fixing a bug must register a lesson with `task.sh learn` (or provide `--no-lesson`) before closing.
3. **Binding User Preferences**: `.agents/brain/preferences.md` is strictly binding for all agents.

---

## 8. Code Ownership Matrix

Each agent operates within its defined domain to avoid file collisions:
- `orchestrator-agent`: `GLOBAL_STATE.md`, `BRAIN.md`, `docs/plan/`.
- `product-manager-agent`: `docs/product/`, `specs/`.
- `backend-agent`: Server, controllers, services, APIs, DTOs.
- `frontend-agent`: Web UI components, views, client styles.
- `mobile-agent`: Mobile apps (`mobile/`, screens, navigation).
- `database-architect-agent`: Migrations, schemas, seed scripts.
- `qa-security-agent`: Tests (`tests/`, `*.spec.*`, `*.test.*`), audit reports.
- `devops-cloud-agent`: Docker, CI/CD pipelines, build configurations.
