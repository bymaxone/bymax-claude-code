# 🤖 Bymax Babysit-PR

> Autonomously shepherds an open pull request to merge-readiness on **any** project, powered by the [`gh`](https://cli.github.com/) CLI. It wakes up at fixed intervals, resolves conflicts, watches CI, fixes real failures (re-running flaky ones), triages bot review comments, and pings you when the PR is green. It **never merges** and **never pushes to the base branch**.

This plugin **depends on** the `gh` CLI but never bundles it — the same "require, don't embed" approach as [`bymax-mobile`](../bymax-mobile) (Xcode / Android SDK) and [`bymax-web-verify`](../bymax-web-verify) (`agent-browser`). Unlike those, the dependency here is checked by a **preflight inside the skill** (not a session hook): `gh` is an execution prerequisite, not a session-wide one, so it's verified only when you actually run the command.

## Install

```bash
claude plugin marketplace add bymaxone/bymax.claude-code
claude plugin install bymax-pr@bymax-claude-code
```

## Prerequisites

- **[`gh` CLI](https://cli.github.com/)** — installed **and** authenticated. The skill's **Phase −1 preflight** verifies both and stops with exact install / `gh auth login` instructions if either is missing. It never runs blind.
  - macOS: `brew install gh` · Linux: [install guide](https://github.com/cli/cli/blob/trunk/docs/install_linux.md) · Windows: `winget install --id GitHub.cli`
  - Then: `gh auth login` (verify with `gh auth status`).
- **`git`** — for commits, rebasing, and pushing.
- An **open PR** on the current branch (or pass a number / URL).

## Usage

```
/bymax-pr:babysit-pr             # babysit the PR on the current branch
/bymax-pr:babysit-pr 123         # babysit PR #123
/bymax-pr:babysit-pr <pr-url>    # babysit a PR by URL
```

## How it works

On **every** wake-up (`ScheduleWakeup`, 270s — inside the prompt-cache TTL), it runs four phases in order:

| Phase | What it does |
| ----- | ------------ |
| **0. Conflict resolution** | Auto-rebases onto the base branch when the PR is `CONFLICTING`; resolves by file pattern (lockfiles / generated output / hand-written source). Pauses only if the rebase can't be resolved. |
| **1. CI monitoring** | Fetches `gh pr checks`, classifies each failure as **real vs flaky**. Flaky → `gh run rerun --failed` (cap 3). Real → reads the log, applies the smallest fix, runs the **local test gate** before committing, then pushes. |
| **2. Bot comment handler** | Triages unhandled **bot** review threads on a 4-tier scale (MUST FIX / SHOULD FIX / SKIP-nitpick / SKIP-rule). Implements or dismisses with reasoning, replies with a `<!-- babysit-reply -->` marker, and resolves the thread via GraphQL. **Human** comments are only surfaced via notification — never auto-acted on. |
| **3. Termination check** | When CI is all-green, the PR is mergeable, all bot threads are resolved, and the loop isn't paused → fires a `PushNotification` ("ready to merge 🎉") and stops scheduling. |

State lives in a single `<!-- babysit-state -->` PR comment (per-check failure counts, processed comment IDs), so the loop is **idempotent across wake-ups and session restarts**.

## Project-agnostic by design

No hardcoded paths or workflow names. On entry it auto-detects:

- **Package manager** by lockfile (`bun` / `pnpm` / `yarn` / `npm`).
- **Lint / test / typecheck / build** commands from `package.json` scripts (uses only what exists).
- Non-JS repos: tries conventional gates (`cargo test`, `go test ./...`, `pytest`, `make test`); if none is detectable it skips the local gate and relies on CI.
- The project's own `CLAUDE.md` / `AGENTS.md` (if present) — respected when fixing code and when dismissing bot comments.

## Hard rules

- **Never merges** the PR and **never pushes to the base/default branch.**
- Never force-greens a check (`--no-verify`, `@ts-ignore`, `any`, `eslint-disable`, skip hooks).
- Never pushes a fix without the local gate passing (when one is detectable).
- Never re-processes an already-handled comment; never auto-acts on human comments (only notifies).
- 3-strike rule: pauses and notifies if the same real failure recurs after 3 fix attempts, or a flaky check fails 3 re-runs.

## License

MIT — see [root LICENSE](../../LICENSE). The `gh` CLI itself is MIT and is installed separately.
