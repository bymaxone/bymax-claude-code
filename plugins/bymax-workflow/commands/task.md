---
description: 'Execute a phase or a single task end-to-end with all quality gates wired in. Loads /bymax-workflow:standards + project docs, runs the embedded agent prompt (using /bymax-quality:tdd for new code or `tester` for adding tests), then enforces /bymax-workflow:verify → /security-review → /bymax-quality:code-review with apply-all-findings on each, with re-verification after every fix. Closes the phase by auditing every acceptance criterion, updating dashboards (task status, completion log, master roadmap progress), and STOPS — never auto-commits, never skips a gate, never bypasses with --no-verify or @ts-ignore. Modes: `/bymax-workflow:task phase <N>` runs all tasks in a phase + close-phase audit; `/bymax-workflow:task <task-id>` runs one task only. Triggers: "executar task", "executar fase", "rodar task", "run task", "run phase", "task <id>", "fase <N>", "execute phase".'
---

# Task Command — Execute Phase / Task with Full Quality Gates

End-to-end runner for tasks scaffolded by `/bymax-workflow:phase-tasks`. Treats every task as the embedded agent prompt + a strict review-and-verify cycle. Designed so that when execution returns control to you, the diff is **production-ready** — no errors, all tests green, lint and format clean, comments rich and English, dashboards up to date.

---

## Invocation

```
/bymax-workflow:task phase <N>     # execute every task in phase N, then close-phase audit
/bymax-workflow:task <task-id>     # execute a single task (e.g., 3.2 or P0-1) — no phase close
/bymax-workflow:task               # ask the user which
```

---

## Step 0 — Load context (once per invocation)

1. **Apply `/bymax-workflow:standards` rules from memory** — TS strict + zero `any`, JSDoc on file headers and exports, English-only comments, naming conventions, layered architecture, no cross-feature imports, no suppression comments, Conventional Commits. Do **not** load the full `/bymax-workflow:standards` skill body — these rules are already internalized. Only invoke `/bymax-workflow:standards` (read the skill) when:
   - You hit a rule conflict and need to confirm the source of truth.
   - The task touches an area covered by a specific section (e.g., security baseline §12 for auth code).
2. Read `CLAUDE.md` and `AGENTS.md` of the current project — these override `/bymax-workflow:standards` where they conflict.
3. Read `docs/tasks/phase-<NN>-*.md` for the phase being worked on.
4. For each task that will be executed, read the **REQUIRED READING** listed inside its embedded agent prompt — do not load more than that (preserves context budget).
5. Confirm in one line: *"About to execute <N tasks of phase <X>> following the protocol below. Proceed?"*
   - If the user's invocation was explicit (`/bymax-workflow:task phase 3`), proceed without asking.
   - If ambiguous, ⏸ wait for confirmation.

---

## Step 1 — Per task, in order

For each task in the phase (or for the single task requested):

### 1.1 — Read the task block

- Description
- Acceptance criteria
- Files to create / modify
- The embedded agent prompt (Role / PROJECT / PRECONDITIONS / REQUIRED READING / TASK / DELIVERABLES / Constraints / Verification / Completion Protocol)

### 1.2 — Execute the task

Treat the embedded agent prompt as your spec. Execute it as the engineer described in the Role.

- **For new code** — drive a `/bymax-quality:tdd` cycle (RED → GREEN → REFACTOR).
- **For adding tests to existing code without changing behavior** — use the `tester` skill.
- **For specialized concerns** — dispatch a sub-agent when there's a strong fit:
  - `typescript-reviewer` for heavy TS changes
  - `database-reviewer` for schema/migrations/SQL
  - `security-reviewer` for auth, sessions, crypto, secret handling
  - `Explore` for cross-codebase searches
  - `Plan` only when the task itself is too vague to execute (rare — escalate to user instead)

Respect every constraint from the prompt **and** `/bymax-workflow:standards`:

- TypeScript strict, zero `any`, zero suppression comments
- File-header JSDoc on every non-trivial new file
- JSDoc on every export (`@param`, `@returns`, `@throws`)
- Every new `it()` / `test()` carries a block comment (scenario + rule it protects)
- English-only comments, naming conventions, no cross-feature imports
- Conventional Commits format prepared but **do not commit**

### 1.3 — Gate 1: `/bymax-workflow:verify`

Run the 5 verification gates: static checks → exercise → root-cause → regression scan → acceptance criteria.

- `type-check`, `lint`, `format`, `tests` must be 0 errors / 0 new warnings on touched files.
- Coverage minimum: 100% on critical paths, 80%+ otherwise (match project threshold).
- If any gate fails: **fix the root cause**. Never `--no-verify`, never `// @ts-ignore`, never `// eslint-disable`. Then re-run `/bymax-workflow:verify`.

### 1.4 — Gate 2: `/security-review`

- Apply **every** finding (fix root cause, not the symptom).
- If code changed during the fix → return to **1.3** (re-run `/bymax-workflow:verify`).

### 1.5 — Gate 3: `/bymax-quality:code-review` (CRITICAL → HIGH → MEDIUM → LOW)

- Apply **every** CRITICAL and HIGH finding.
- Apply MEDIUM findings — especially: missing JSDoc, non-English comments, magic numbers, `enum` instead of union literal, cross-feature imports, swallowed errors.
- LOW: apply if trivial; otherwise note in the final report.
- If code changed during the fix → return to **1.3**.

### 1.6 — Completion Protocol (from the task template)

In this exact order:

1. Update task status to ✅ Done in the phase task file.
2. Tick all acceptance-criteria checkboxes.
3. Update the task row in the task index table (status column).
4. Increment progress counter (`N/M tasks`) in the file header.
5. Update the phase row in the master roadmap (status, progress, last-updated).
6. Recompute the overall progress percentage in the roadmap.
7. Append a completion log entry to the phase file:
   `- <task-id> ✅ YYYY-MM-DD — <one-line summary>`

### 1.7 — Report and continue

Print one line: `✅ Task <id> done. Next: <id>` and proceed to the next task.

---

## Step 2 — Phase finalization (only when running `/bymax-workflow:task phase <N>`)

After every task is ✅ Done:

### 2.1 Final `/bymax-workflow:verify`

Run on the full scope of the phase (every file the phase touched).

### 2.2 Final `/security-review`

Run against the full phase diff. Apply every finding.

### 2.3 Final `/bymax-quality:code-review`

Run against the full phase diff. Apply every CRITICAL/HIGH/MEDIUM finding.

### 2.4 Re-verify

If code changed during 2.2 or 2.3 → return to **2.1**.

---

## Step 3 — Phase-completion audit

Walk every checkbox below. If any fails, fix it and return to **Step 2**.

- [ ] Every task in the phase shows ✅ Done
- [ ] Every acceptance criterion is checked
- [ ] Every file listed under "Files to create / modify" exists and was modified
- [ ] `pnpm type-check` (or equivalent) — 0 errors
- [ ] `pnpm lint` — 0 errors, 0 new warnings on touched files
- [ ] `pnpm format:check` — clean
- [ ] `pnpm test` (or `test:ci`) — all green, 0 new `.skip()` / `.todo()`
- [ ] Coverage thresholds met (100% pure services / 80%+ otherwise per project config)
- [ ] Zero new suppression comments (`eslint-disable*`, `@ts-ignore`, `@ts-expect-error`, `@ts-nocheck`, `as any`, `as unknown as <T>`)
- [ ] File-header JSDoc on every new non-trivial file
- [ ] JSDoc on every new export (`@param`, `@returns`, `@throws` where applicable)
- [ ] Block comment on every new `it()` / `test()` (English, scenario + rule)
- [ ] All comments in English
- [ ] No new cross-feature imports
- [ ] Conventional Commits message drafted but **not committed**

---

## Step 4 — Update documentation and stop

### 4.1 Update phase task file header

- Status → ✅ Done
- Progress → `N / N tasks done`
- Last updated → today's date

### 4.2 Update master roadmap

- Phase row: Status ✅ Done, Progress `N/N`, last-updated today
- Recompute overall progress percentage
- Update "Active phase" and "Blocked" lines at the top
- Append final entry to the roadmap completion log:
  `- YYYY-MM-DD — Phase N ✅ <title>: <one-line summary>`

### 4.3 Print the final report (use this exact format)

```
✅ Phase <N> — <title> COMPLETE

Tasks executed: <count>
  - <id> ✅ <title>
  - <id> ✅ <title>
  ...

Verification gates (final):
  type-check:       PASS (0 errors)
  lint:             PASS (0 errors, 0 new warnings)
  format:           PASS
  tests:            <X passing> (<coverage>% on touched files)
  /security-review: 0 CRITICAL, 0 HIGH
  /bymax-quality:code-review:     0 CRITICAL, 0 HIGH (LOW deferred: <count>)

Files touched: <count>
Lines: +<adds> / -<dels>

Documentation updated:
  - docs/tasks/phase-<NN>-*.md ........ ✅ all tasks ✅, completion log appended
  - docs/plans/<feature>-plan.md ...... ✅ phase row + overall %

Pending (if any, otherwise "none"):
  - <LOW finding deferred>: <why>
  - <follow-up suggestion>

Suggested commit message (Conventional Commits):
  <type>(<scope>): <subject>

Next:
  - Review the diff
  - When approved, ask me to commit
  - Or run the next phase: /bymax-workflow:task phase <N+1>
```

### 4.4 Stop

**Do not commit. Do not continue to the next phase. Wait for explicit user direction.**

---

## Hard rules (apply across every step)

- **Never skip a gate.** Not even "I'll fix it later". The gate either passes or you fix the root cause.
- **Never bypass.** No `--no-verify`, `--force` on a protected branch, `@ts-ignore`, `eslint-disable*`, `as any`, `// @ts-expect-error` without an issue link, or test `.skip()` / `.todo()` to silence failures.
- **Never commit.** Always prepare the commit message and wait for the user to confirm.
- **Never invent file paths.** Verify with Read or `grep` before referencing in deliverables.
- **English everywhere** — code, JSDoc, inline comments, completion-log entries, the final report.
- **Mode discipline.** If the user requested a single task, run **only that task** — execute Step 1 and Step 1.6, skip Step 2, Step 3, and Step 4. Phase-level audit and roadmap update only happen when the whole phase ran.
- **If a task gets stuck**, stop and report: what was tried, what failed, what is recommended. Never break a constraint to "unblock". Escalate to the user.

---

## Integration with the rest of the workflow

```
/bymax-workflow:spec → /bymax-workflow:roadmap → /bymax-workflow:phase-tasks   (planning, already done before /bymax-workflow:task runs)
   ↓
/bymax-workflow:task phase <N>                   ← you are here
   ⏸ user reviews
commit (Conventional Commits)     ← only after explicit approval
   ↓
/bymax-workflow:task phase <N+1>
```

`/bymax-workflow:task` is the executor. `/bymax-workflow:spec`, `/bymax-workflow:roadmap`, `/bymax-workflow:phase-tasks` are the planners. `/bymax-workflow:standards`, `/bymax-workflow:verify`, `/security-review`, `/bymax-quality:code-review`, `/bymax-quality:tdd`, `tester` are the building blocks `/bymax-workflow:task` orchestrates.
