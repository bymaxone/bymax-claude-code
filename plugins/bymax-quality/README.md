# 🛡️ Bymax Quality

> Strict quality gates and specialist reviewers for Claude Code (TypeScript and Rust). Code-review with severity blocking, red-green-refactor TDD, multi-stack tester, seven sub-agents (incl. a Rust reviewer), and a credential-blocking pre-write hook.

## Install

```bash
claude plugin marketplace add bymaxone/bymax-claude-code
claude plugin install bymax-quality@bymax-claude-code
```

## What you get

### Slash commands

| Command         | Purpose                                                                                                                                                  |
| --------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `/bymax-quality:code-review`  | CRITICAL → HIGH → MEDIUM → LOW review (TypeScript and Rust). Blocks suppression comments (`@ts-ignore`, `eslint-disable`, `as any`, Rust `#[allow]`/`unsafe`). Reports JSDoc/rustdoc gaps, cross-feature imports, swallowed errors. |
| `/bymax-quality:tdd`          | Strict red-green-refactor cycle (Jest/Vitest or Rust `#[test]`/`cargo test`). Forces failing test before implementation. 80%+ coverage minimum (100% on critical paths). Every `it()` / `#[test]` carries a block comment. |

### Skill

- **`tester`** — Multi-stack test writer. Detects Jest / Vitest / RN / pure logic / Node backend / Rust `cargo test`. Enforces 100% file coverage, every `it()` has a block comment, no fake classNames, no snapshots of arbitrary objects. Auto-runs and verifies coverage on completion.

### Specialist sub-agents

| Agent                   | Model      | Specialty                                                              |
| ----------------------- | ---------- | ---------------------------------------------------------------------- |
| `architect`             | opus       | System design, scalability, technical decisions.                       |
| `code-reviewer`         | sonnet     | Quality + security + maintainability review (proactive after edits).   |
| `database-reviewer`     | sonnet     | PostgreSQL: query optimization, schema design, security.               |
| `planner`               | opus       | Complex feature and refactor planning.                                 |
| `security-reviewer`     | sonnet     | OWASP Top 10, secrets, SSRF, injection, unsafe crypto.                 |
| `typescript-reviewer`   | sonnet     | Type safety, async correctness, idiomatic patterns. |
| `rust-reviewer`         | sonnet     | Ownership/borrow correctness, typed errors, async/Tokio soundness, `unsafe` discipline, idiomatic crate design.                    |

### Hooks

| Hook                       | Trigger                       | What it does                                                                                                                                                                            |
| -------------------------- | ----------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `secret-scanner.sh`        | `PreToolUse` Write/Edit/MultiEdit | **Blocks** the write if the new content matches AWS keys, GitHub PATs, OpenAI/Anthropic/Stripe/Slack/Google tokens, JWTs, or PEM private keys. Returns exit code 2 + JSON systemMessage. |
| `console-log-scan.sh`      | `Stop`                        | Warns on stray `console.log/warn/error/debug/info` in modified TS/JS files (early-exit if not in git or no JS files modified).                                                          |

## The chain

Designed to be invoked one after another (or via `/bymax-workflow:task` which orchestrates them):

```
implementation
   ↓
/bymax-workflow:verify          (5 gates: static checks, exercise, root-cause, regression scan, acceptance criteria)
   ↓
/security-review (apply every finding)
   ↓
/bymax-quality:code-review     (apply CRITICAL + HIGH + MEDIUM)
   ↓
ready for commit
```

If any of `/bymax-workflow:verify`, `/security-review`, `/bymax-quality:code-review` finds something and fixes it, the flow loops back to `/bymax-workflow:verify`.

## Banned suppression patterns

`/bymax-quality:code-review` flags any of these as **CRITICAL** (blocks commit):

- `// eslint-disable*`, `// @ts-ignore`, `// @ts-expect-error`, `// @ts-nocheck`
- `as any`, `as unknown as <T>` (used to launder errors)
- `// prettier-ignore` (unless preserving a formatted table)
- `# noqa`, `# type: ignore`, `# pylint: disable=`, `@SuppressWarnings`
- Rust: `#[allow(...)]` / `#![allow(...)]` to dodge a gate, an `unsafe` block in a `#![forbid(unsafe_code)]` crate, `#[ignore]` to hide a failing test
- CLI bypasses: `--no-verify`, `--force` on protected branch, `--skip-checks`

## License

MIT — see [root LICENSE](../../LICENSE).
