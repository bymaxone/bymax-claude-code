# 🧭 Bymax Workflow

> Phased planning + execution workflow for Claude Code, with explicit user-approval gates and JIRA-style task dashboards.

## Install

```bash
claude plugin marketplace add bymaxone/bymax.claude-code
claude plugin install bymax-workflow@bymax-claude-code
```

## What you get

### Slash commands

| Command         | Layer | Purpose                                                                                         |
| --------------- | ----- | ----------------------------------------------------------------------------------------------- |
| `/spec`         | 1     | Draft a complete technical spec — goal, scope, user stories, success criteria, risks.            |
| `/roadmap`      | 2     | Take an approved spec → phased plan with status dashboard, dependency DAG, definition-of-done. |
| `/phase-tasks`  | 3     | Take an approved roadmap → JIRA-style task files with self-contained agent prompts per task.   |
| `/task`         | exec  | Execute a phase or single task with `/verify` → `/security-review` → `/code-review` chain.     |
| `/brainstorm`   | pre   | Refine vague ideas, explore alternatives, surface tradeoffs.                                    |
| `/plan`         | mini  | Lightweight plan for single-PR work that doesn't need the full chain.                           |
| `/verify`       | post  | 5-gate verification: static checks, exercise, root-cause, regression scan, acceptance criteria. |
| `/checkpoint`   | util  | Snapshot SHA + tests + coverage for later comparison.                                            |

### Skill

- **`standards`** — universal coding rules (TypeScript discipline, JSDoc policy, naming, layered architecture, English-only comments, suppression bans, conventional commits). Loaded on demand by `/plan`, `/tdd`, `/code-review`, `/bootstrap`, etc.

## The flow

```
/spec         →  docs/specs/<feature>.md         (the WHAT and WHY)
   ⏸ user approval
/roadmap      →  docs/plans/<feature>-plan.md    (phased master plan + dashboard + DAG)
   ⏸ user approval
/phase-tasks  →  docs/tasks/phase-NN-*.md        (per-phase task files)
   ⏸ user approval per phase
/task         →  /verify → /security-review → /code-review → completion-protocol
   ⏸ user reviews diff
commit (Conventional Commits — never auto-committed)
```

Each layer **stops and waits** — you review, modify, or approve. Nothing auto-chains.

## Status legend (used in every roadmap and task file)

| Emoji | Meaning      |
| ----- | ------------ |
| 📋    | ToDo         |
| 🔄    | In Progress  |
| 👀    | Review       |
| ✅    | Done         |
| ⛔    | Blocked      |
| 🟡    | Partial      |

## When to use this vs `/plan` alone

- **Big feature, multi-phase, multiple PRs** → use the chain (`/spec` → `/roadmap` → `/phase-tasks` → `/task`).
- **Small task, single PR, clear scope** → just use `/plan` → `/tdd` → `/verify` → `/code-review`.

## License

MIT — see [root LICENSE](../../LICENSE).
