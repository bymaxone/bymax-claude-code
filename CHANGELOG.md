# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [Unreleased]

_No changes yet._

## [1.7.0] — 2026-07-17

### Changed — `/bymax-quality:code-review` v2: mechanical gate, verified bug hunt, selectable depth

The command graduates from a single-pass checklist to a pipeline that borrows the architecture of Claude Code's built-in review engine (finders → adversarial verification) while keeping what only this gate does: enforce the Bymax conventions and **block** on CRITICAL/HIGH — the built-in engine never blocks.

- **Modes**: `quick` (mechanical gate + CRITICAL/HIGH on changed lines — pre-push sanity check), `full` (default — everything, single-pass bug hunt), `deep` (bug hunt fans out to the `typescript-reviewer`/`rust-reviewer` + `security-reviewer` sub-agents in parallel as finders; read-only, never test-running).
- **Flexible targets**: branch (`main...feature-x`), explicit ref range, PR number (checked out locally so the range works with `git diff`), or single file — previously only `git diff HEAD` (uncommitted work). With a clean working tree it now reviews the branch's commits ahead of upstream instead of finding nothing.
- **Mechanical gate (Step 2)**: the regex-shaped checklist items (suppression comments, CLI bypasses, raw `console.*`, TODO without issue link, files > 800 lines, every Tailwind v4 canonical-form and v3-rename rule, hex in `className`, JIT-invisible dynamic classes) are now executed as concrete `git diff -U0 | grep` commands over added lines — findings are exact `file:line` facts instead of model impressions, faster and immune to hallucinated locations.
- **Adversarial verification (Step 5)**: candidate ≠ finding. Every non-mechanical candidate — the main agent's or a finder's — is re-checked against the file at the cited line, behavior claims must survive a call-path trace (naming-based inference is dropped), duplicates are consolidated, and the report states how many candidates were dropped. Mechanical findings skip verification because they are already exact.
- **`--fix`**: applies the deterministic mechanical MEDIUM rewrites (Tailwind renames/canonical tokens) plus any user-approved finding after the report, then re-runs the gate; never commits.
- Checklist content is otherwise preserved (zero-tolerance suppression policy, standards §0 simplicity ladder, JSDoc/rustdoc, cross-feature imports, timeless comments), reorganized into mechanical vs judgment items.

### Added — `/bymax-quality:review-md`: REVIEW.md generator for Anthropic's cloud Code Review

Anthropic's Code Review (cloud `@claude review` on PRs, `/code-review ultra`) reads a repo-root `REVIEW.md` and injects it verbatim into every review agent as the highest-priority instruction block — but it knows nothing about Bymax conventions out of the box. The new command distills the `/bymax-quality:code-review` checklist plus the project's `CLAUDE.md` invariants into that file: suppressions/secrets escalated to 🔴 Important, nit cap with re-review convergence, skip rules (generated files, lockfiles, CI-enforced checks), and a per-repo "Always check" list. Constraints are enforced by the command: self-contained (no `@` imports — the file is pasted verbatim), ≤ ~100 lines, refreshed rather than duplicated when one already exists. Division of labor stays explicit: the local command is the blocking gate; `REVIEW.md` is the projection of the same rules onto the cloud engine.

### Added — `/bymax-pr:push`: ship work safely, with an explicit PR opt-in

The user-scope `/push` skill graduates into the `bymax-pr` plugin (versioned, installable on any machine) and gains a PR mode. The flow: inspect (read-only) → branch (**a commit never lands on the default branch** — create `<type>/<slug>` when on it, reuse the current feature branch otherwise, always `git switch -c`) → stage (respect a pre-staged index; `git add -A` only when the index is empty) → commit (complete Conventional-Commits message: title ≤ 72 chars validated before committing, body bullets carrying the what + why) → push with upstream.

- **`pr` token = explicit opt-in.** `/bymax-pr:push` alone never opens a PR (it prints the compare URL); `/bymax-pr:push pr` also creates the GitHub PR via `gh` with a complete body (Summary / Changes / How to verify / Notes) authored from the **entire** `default..HEAD` range, not just the last commit. An existing PR for the branch is detected and reported, not duplicated.
- **Ship-what's-committed**: a clean tree with commits ahead of upstream skips straight to push/PR instead of reporting "nothing to do".
- Safety rails: never force-push, never `--no-verify`, no AI-attribution trailers in commits or PR bodies, timeless messages (no plan-phase refs), `gh auth` preflight when `pr` is requested, one verified git mutation per step.
- README reframed: the plugin now covers the PR lifecycle end to end — `/bymax-pr:push pr` → `/bymax-pr:babysit-pr <PR#>`.

### Added — `/bymax-web-verify:test`: assisted UI testing in the Claude Desktop preview

A new command in `bymax-web-verify` that brings the project's full stack up and tests the UI **while the user watches**. Mode is detected from the session's toolset, no argument needed: when the Claude Desktop Browser-pane tools are present it runs PREVIEW mode (the primary target — `.claude/launch.json` + `preview_start`, the user sees every click); in a plain terminal it falls back to the `agent-browser` CLI (with the plugin's existing setup pre-flight).

- **Backend orchestration**: discovers the layout (single app or `frontend/`+`backend/` monorepo), and an instance already running on the device is **reused** (port + health check probe) — never duplicated, never killed; only when nothing is running does it start the dev script in the background and wait for health before touching the frontend.
- **Assisted loop**: the flow argument (free text, e.g. `"login"`) becomes a numbered test script; each step is announced, executed via page refs (click/type/forms), and verified against **four evidence sources** — UI state, console (an error fails the step), network calls (an unexpected 4xx/5xx fails the step even when the UI looks fine), and server logs — with screenshots as proof. No argument = smoke test. `browser` forces the external browser; `mobile`/`dark` set the viewport.
- **Safety rails**: never real credentials (seeded/test users only), never destructive actions unasked, created test data is named `test-…` and listed in the report. Servers are left running at the end — the user keeps interacting with the preview — with exact stop instructions for whatever the command itself started.
- Positioning vs `verify`: `verify` confirms one change, pointed and browser-only; `test` walks a flow with the stack up, preview-first. `bymax-web-verify` bumped to `1.1.0`.

### Changed — toolkit-wide sync with recent Claude Code capabilities

An audit of every plugin against the Claude Code `2.1.174`–`2.1.212` changelog range produced four more updates:

- **`bymax-pr` / babysit-pr — CI-duration-driven pacing.** The fixed 270 s wake-up was justified by the old 5-minute prompt-cache TTL; the TTL is now one hour, so cache pressure no longer dictates cadence. The delay is now chosen from what the loop is actually waiting for — remaining CI time estimated from the workflow's recent run durations, 900–1800 s when waiting on a review bot or human — with 270 s kept as the floor. Fewer wake-ups, same responsiveness.
- **`bymax-workflow` / autopilot — unattended-session hardening (new precondition 6).** Three launch checks matching how Claude Code now treats unattended sessions: recommend `CLAUDE_CODE_RETRY_WATCHDOG` (the supported retry mechanism now that `CLAUDE_CODE_MAX_RETRIES` caps at 15), confirm the login will not expire mid-chain (an expiring login interrupts background sessions), and pre-approve implementer permissions — background sub-agents no longer auto-deny on a permission prompt; they surface it in the main session and wait, which would stall the chain.
- **`personal/settings.template.json` — attribution off at the harness level.** New `attribution: { coAuthoredBy: false, sessionUrl: false }` block: the no-AI-attribution rule is now enforced by Claude Code itself (no `Co-Authored-By` trailer, no claude.ai session link on commits/PRs) instead of relying on prompt instructions.
- **`personal/settings.template.json` — `Notification` hook.** macOS notification on `Notification` events, which since 2.1.198 include background-agent signals (`agent_needs_input` / `agent_completed`) — a stalled babysit-pr or autopilot chain waiting on input now pings the operator instead of being discovered hours later.
- **`bymax-bootstrap` — seeds `REVIEW.md`.** Bootstrap now runs `/bymax-quality:review-md` after writing `CLAUDE.md`, so every new project starts with the cloud review calibrated; `claude-md.template.md` gained the pointer line.
- **`bymax-workflow` — explicit review depth at the two decision points.** Bare `/bymax-quality:code-review` calls stay backward compatible (no argument = `full`), but the two places where depth matters are now explicit: `/bymax-workflow:task` §2.3 (the phase-closing, pre-PR pass) runs `deep` — finder fan-out + adversarial verification — while the per-task Gate 3 keeps the cheaper `full`; and the autopilot implementer prompt pins `full` with a rationale — `deep` spawns finder sub-agents and implementers are sub-agents that never spawn (the orchestrator's merge gate is the deeper second opinion).

- `bymax-quality` bumped to `1.4.0`, `bymax-pr` to `1.1.0`, `bymax-workflow` to `1.4.2`, `bymax-bootstrap` to `1.1.3`, `bymax-web-verify` to `1.1.0`; `marketplace.json` to `1.7.0`. Toolkit totals: **19 slash commands**, 4 skills, 7 sub-agents, 3 hooks, 20 templates.

## [1.6.1] — 2026-07-08

### Fixed — autopilot: unresponsive review bot could hold the merge gate forever

The merge gate's "no pending review request" term had no time bound: if the config named a review bot and the `--add-reviewer` request was **accepted** but the bot never submitted a review (bot not enabled on the org, quota, outage), `reviewRequests` never emptied and the chain waited indefinitely — alive (the wake-up fallback kept re-invoking the orchestrator) but never merging. Repos with `Review bot: none` and rejected-slug requests were already handled; this closes the third path.

- **New `BOT_TIMEOUT` watcher verdict** (SKILL.md STEP 2/3 + playbook): a review request pending longer than the config's **review-bot timeout** (default 15 min, measured from the request or the latest push, whichever is later) triggers the unresponsive-bot procedure — confirm with a fresh read that no review arrived, remove the stale request (`gh pr edit --remove-reviewer`), leave one factual PR comment as the audit trail (a declared reviewer is never dropped silently), then re-evaluate the gate CI-only.
- **Safety rationale documented**: the review floor already ran before the PR opened (the implementer iterates `/bymax-quality:code-review` + `/security-review` to zero findings); the bot is a second opinion, and a dead second opinion must not become an infinite wait. If the bot reviews after the timeout cleared it, the normal rules resume — its threads must still be resolved before the merge executes.
- **`references/config-template.md`** — new "Review-bot timeout" field in the Review bot and Merge policy sections.
- `bymax-workflow` bumped to `1.4.1`; `marketplace.json` to `1.6.1`.

## [1.6.0] — 2026-07-08

### Added — `/bymax-workflow:autopilot` (loop-engineering executor)

A new skill in `bymax-workflow` that autonomously drives an **approved roadmap from first phase to done, one merge-gated PR per phase, with zero human interaction after launch** — the toolkit's [loop-engineering](https://addyosmani.com/blog/loop-engineering/) layer. It generalizes a per-project orchestration runbook proven on real multi-phase autonomous builds (10-phase / 50+-task library and application roadmaps) into a reusable skill: the invariant operational knowledge lives in the skill, and everything project-specific collapses into one reviewable config file.

- **`skills/autopilot/SKILL.md`** — the orchestrator. Three modes: `init` (generate `docs/AUTOPILOT.md` from the existing roadmap + task files, propose a per-phase model policy, **stop for user review** — init never chains into run), `run` (drive the chain: pick next phase → spawn implementer → background CI/review watch → fix findings → merge gate + grace window → squash-merge + branch deletion with proof → dashboard updates → next phase), and `status` (read-only chain report).
- **`references/operational-playbook.md`** — the architecture and battle-tested procedures, each rule annotated with the real failure it prevents: the orchestrator/implementer role split (the naive single-agent design **deadlocked** waiting for the review bot — background sub-agents die on long waits), one-implementer/one-suite memory safety (fanned-out test agents crashed a 36 GB machine past 70 GB), the merge-gate conjunction + grace window (a second bot review lands ~90 s after a push), fresh-thread-ID resolution (stale GraphQL IDs masquerade as permission errors), anti-hallucination verification (agents confabulate SHAs and merges — verify via `git`/`gh`, never narration), and the autonomy backbone (never end a turn without a pending background job or an armed wake-up).
- **`references/implementer-prompt.md`** — the rendered-per-phase prompt template. Implementers run in isolated git worktrees, execute the phase's task files with `/bymax-workflow:standards` + `/bymax-quality:tdd`, iterate `/bymax-quality:code-review` and `/security-review` **to zero findings**, open the PR, request the review bot, return the PR number, and STOP — they never wait, never merge, never spawn.
- **`references/config-template.md`** — the `docs/AUTOPILOT.md` per-project config: identity, external preconditions (e.g. Docker up, a dependency resolvable on a registry), a per-phase **model policy** with rationale (strong tier for first-contact/security-sensitive/final-hardening phases, cheaper tier where the merge gate catches everything), gates that grow by phase, invariant greps, security invariants and review focus, review bot, and merge policy (squash, grace window, stall limit).
- **README** — new "Loop Engineering: the Autopilot" section: the term's origin (Addy Osmani's June 2026 essay, synthesizing Peter Steinberger and Boris Cherny), the full loop diagram, the failure-per-rule authority table, the mapping of Osmani's five loop components (state & memory, sub-agents, worktrees, skills, automations) onto the toolkit's plugins, and the honest constraints (it merges; it is token-intensive by design; it requires the planning chain).
- `bymax-workflow` bumped to `1.4.0`; `marketplace.json` to `1.6.0`. Toolkit totals: 16 slash commands, **4 skills**, 7 sub-agents, 3 hooks, 20 templates.

## [1.5.0] — 2026-07-06

### Added — Simplicity ladder (§0) across `bymax-workflow` + `bymax-quality`

A reuse-first decision ladder — inspired by the ladder in [DietrichGebert/ponytail](https://github.com/DietrichGebert/ponytail) (MIT), adapted to the Bymax reality (`@bymax-one/*` libs, sibling projects, the `shared/` layer, and the vault's stack patterns) — now runs **before code is written** and is **enforced after**, at every stage of the pipeline:

- **`/bymax-workflow:standards`** — new stack-neutral **§0 Simplicity ladder**: before writing code, stop at the first rung that holds — (1) YAGNI, (2) reuse from this codebase, (3) reuse a `@bymax-one/*` lib / promote sibling-project code instead of copy-pasting, (4) stdlib/native platform (`Intl`, `crypto.randomUUID()`, `URL`, `structuredClone`, native `<input>` types; `std`/`core` on Rust), (5) installed dependency (a NEW dep needs justification), (6) build once as a reusable unit in `shared/` or `@bymax-one/*` when a second feature/project needs it, (7) only then the minimum that works. Carve-outs are explicit: trust-boundary validation, error handling, the security baseline, accessibility, and mandatory docs/tests are never on the chopping block. Output economy (fewer generated tokens) is documented as a side effect, not the goal.
- **`planner` sub-agent** — new mandatory **Reuse Scan (2b)** planning step: every proposed new file/component/dependency is walked down the ladder, and the plan's Architecture Changes section must justify each new file with "no existing code covers this because …".
- **`/bymax-workflow:plan`** — the reuse scan added as step 3 of the command flow (search codebase → `@bymax-one/*` → sibling projects → stdlib → installed deps before proposing new files).
- **`/bymax-quality:code-review`** — new **HIGH** checks: *reinvented wheel* (new code reimplementing an existing repo symbol, `@bymax-one/*` lib, stdlib/platform API, or installed dependency) and *new dependency for something already covered*. New **MEDIUM** checks: copy-pasted logic that should be one shared unit, and speculative generality (YAGNI).
- **`/bymax-quality:tdd`** — GREEN phase now runs the ladder before writing the body: an existing util, lib, or stdlib call may already BE the green; never add a dependency just to pass a test.
- `bymax-workflow` and `bymax-quality` bumped to `1.3.0`; `marketplace.json` to `1.5.0`. Additive only — no existing rule was weakened. The ponytail plugin itself was evaluated and **not** vendored: its always-on hooks and prompt overhead are redundant with the existing gates; only the ladder concept was adopted, Bymax-adapted.

### Added — "External tools & MCP servers" README guide

- New README section documenting every external tool the plugins consult at runtime ("require, don't embed"): the CLI toolchain per plugin (Node.js, `gh`, `agent-browser`, pnpm, Xcode/simctl, Android SDK, Rust + cargo extras) and the three optional MCP servers with install commands — **context7** (`@upstash/context7-mcp`, current official docs for the §0 docs-first rule), **obsidian vault** (`@bitbonsai/mcpvault`, per-stack `Patterns.md`/`Gotchas.md` consulted by the §0 reuse ladder), and **sequential-thinking**.
- `/bymax-workflow:standards` §0 hardened for portability: the knowledge-vault and Context7 references now degrade gracefully when the MCP is absent, and a new **"official docs beat trained memory"** rule verifies library/platform APIs against current docs before writing the call.
- `personal/README.md` documents the obsidian MCP restore command (registered via `claude mcp add` — machine-specific vault path, so it stays out of `mcp.template.json`).

### Added — graphify integration (graph-first reuse scan, opt-in)

Evaluated [Graphify-Labs/graphify](https://github.com/Graphify-Labs/graphify) (MIT) and adopted it the same way as ponytail: the capability, not the always-on mode.

- **`/bymax-workflow:standards` §0 rung 2** — when a project has a `graphify-out/` knowledge graph, the reuse scan goes **graph-first** (`graphify query` / `explain` / `path`) instead of grepping: scoped subgraph answers at a fraction of the tokens, with cross-file/cross-package edges resolved by tree-sitter AST. Grep remains the fallback when no graph exists and the authority for code changed since the last graph build.
- **`planner` sub-agent (Reuse Scan 2b)** and **`/bymax-workflow:plan` step 3** — same graph-first rule while planning.
- **`bymax-bootstrap`** — `gitignore.universal` now excludes `graphify-out/` (local, regenerable output); bumped to `1.1.2`.
- **README** — new "Code knowledge graph" section: how graphify works (local AST build, zero LLM tokens for code, SHA256-incremental, post-commit hook), how the toolkit consumes it (presence-gated, zero cost when absent), setup commands, and the explicit recommendation **against** `graphify claude install` (its always-on `PreToolUse` hooks add per-prompt overhead and conflict with the `bymax-quality` hooks).

### Changed — branding + contact unification

- Author/owner across `LICENSE`, README, all seven `plugin.json` files, and `marketplace.json` is now **Bymax One** (`support@bymax.one`), matching the `@bymax-one/*` library repos. All contact emails (`security@`, `conduct@`) consolidated to **support@bymax.one**.

### Added — `llms-install.md` (AI-agent installation runbook)

- New machine-oriented runbook at the repo root (the location AI agents like Cline probe for): idempotent steps with a verification command after each, decision points with defaults (core pair vs project-type plugins), explicit **HUMAN HANDOFF** markers for interactive steps (session restart, `gh auth login` OAuth, App Store/GUI installers), a DO-NOT list (never `scripts/install.sh`, never `bymax-all`-as-plugins, never `graphify claude install`, never a GitHub MCP), and per-symptom failure guidance. Linked from the README Quick Start.

### Fixed — full-repo audit (three independent review passes)

- **`/bymax-web-verify:verify` now actually exists** — the command file was `web-verify.md` (registering as `:web-verify`) while every documented invocation across 12 files said `:verify`; renamed the file to `verify.md`. `bymax-web-verify` bumped to `1.0.1`.
- **Canonical repo slug** — replaced the legacy dotted slug `bymaxone/bymax.claude-code` (alive only via GitHub's rename redirect) with `bymaxone/bymax-claude-code` across 24 files (badges, plugin.json homepages, marketplace.json, CHANGELOG links, CONTRIBUTING, install.sh, templates, vendor attribution).
- **Stale ECC-era references scrubbed** — `tdd.md` no longer claims a nonexistent `tdd-guide` agent or points to `/build-fix`, `/test-coverage`, `/e2e`; `plan.md` now correctly credits the `planner` sub-agent to the `bymax-quality` plugin; dead "Related Agents" ECC sections removed.
- **Portability** — `standards` §0 no longer hard-codes the author's machine layout (`~/Documents/MyApps/...`) or dangling "see the README" pointers inside the installable skill; org lib scope and sibling-repo locations are now declared per-project in `CLAUDE.md`.
- **Docs accuracy** — CHANGELOG compare links completed (1.1.1→1.5.0, Unreleased repointed); broken VS16-emoji anchors fixed (`## 🧱 Architecture`, `## 🔖 Versioning`); `brew install claude` corrected to the real Claude Code install command; the unsupported `--scope` flag claim replaced with the `enabledPlugins` mechanism; `/security-review` labeled as the Claude Code built-in; CONTRIBUTING's dead Discussions link → Issues and its local-dev install list completed (6/6 plugins); SECURITY.md hook-wiring and `scripts/install.sh` path corrected; vendor README gained the missing `marketplace add` line and a current ECC star count; tester skill report now includes Profile F; `bymax-all` description names the `bymax-pr` plugin correctly.

### Removed — github MCP from the restore flow

- The restore path (README step 6, `scripts/install.sh` hints, `personal/settings.template.json`, `personal/README.md`) no longer recommends the `@modelcontextprotocol/server-github` MCP. GitHub access is **`gh` CLI only** (`brew install gh && gh auth login`) — the same tool `bymax-pr:babysit-pr` requires. Rationale: `gh` uses a short-lived OAuth token that works across orgs whose token policies reject long-lived fine-grained PATs, which is what broke the MCP setup.

## [1.4.0] — 2026-06-17

### Added — Rust support across `bymax-workflow` + `bymax-quality`

The workflow and quality plugins are now **language-detecting**: TypeScript/JS behavior is unchanged, and a parallel **Rust track** activates when a `Cargo.toml` is present. This makes the full `spec → … → task` quality cycle usable on Rust projects (first consumer: the `rust-auth` library).

- **`/bymax-workflow:standards`** — new **§15 Rust track** (edition/MSRV pinning, `cargo clippy -- -D warnings` + `cargo fmt`, no `unwrap`/`expect`/`panic!` on lib paths, typed `thiserror` errors, `#![forbid(unsafe_code)]`, rustdoc `//!`/`///` + `#![deny(missing_docs)]`, `#[test]` discipline, `cargo deny`/`audit`/`vet` supply chain, RustCrypto/`subtle`/`secrecy` security baseline) + a "which track applies" detector and a TS→Rust tooling map.
- **`/bymax-workflow:verify`** — Rust gate set (`fmt`/`clippy`/`build`/`test`/`llvm-cov`/`deny`/`audit` + wasm build) and Rust suppressions (`#[allow]`-to-dodge, `unsafe`, `#[ignore]`, `unwrap`-in-lib) added to the scan.
- **`/bymax-workflow:task`** — stack detection in Step 0, `rust-reviewer` dispatch, and a stack-adaptive close-phase audit.
- **`/bymax-quality:code-review`** — Rust CRITICAL/HIGH/MEDIUM checks; the Tailwind/TS-syntax checks are skipped on Rust.
- **`/bymax-quality:tdd`** + the **`tester`** skill — a Rust variant of the red-green-refactor cycle and a new **Profile F (Rust)** (`#[cfg(test)] mod tests` + `cargo test` + `cargo llvm-cov`).
- **New `rust-reviewer` sub-agent** (ownership/borrow, typed errors, async/Tokio soundness, `unsafe` discipline, idiomatic crate design); **`code-reviewer`** and **`security-reviewer`** made Rust-aware.
- `bymax-workflow` and `bymax-quality` bumped to `1.2.0`; `marketplace.json` to `1.4.0`. TypeScript/JS behavior is fully preserved (additive only).

### Changed — `bymax-pr` review-thread resolution

- **`/bymax-pr:babysit-pr`** — hardened the GraphQL review-thread resolution: re-fetch thread IDs fresh each turn, match every thread to its comment by `databaseId`, check `viewerCanResolve`, and verify `isResolved` before reporting; added anti-stale-ID / anti-hallucination rules so a `FORBIDDEN` / `NOT_FOUND` is treated as a stale-ID symptom, not a permission wall. `bymax-pr` bumped to `1.0.1`.

## [1.3.0] — 2026-05-22

### Added — `bymax-pr` plugin (autonomous PR babysitting)

A new optional plugin that autonomously drives an open pull request to merge-readiness on **any** project, powered by the [`gh`](https://cli.github.com/) CLI. Like `bymax-mobile` and `bymax-web-verify`, it follows the "require, don't embed" pattern — it depends on `gh` + `git` but never bundles them.

- **`/bymax-pr:babysit-pr`** — wakes up every 270s (`ScheduleWakeup`, inside the prompt-cache TTL) and runs four phases per pass: conflict auto-rebase → CI monitoring (classifies failures **real vs flaky**, re-running flaky checks up to 3× via `gh run rerun --failed`) → bot-comment triage (4-tier, resolves threads via GraphQL) → termination check (fires a `PushNotification` when green). State persists in a `<!-- babysit-state -->` PR comment, so the loop is idempotent across wake-ups and session restarts.
- **Phase −1 preflight** — verifies the `gh` CLI is installed **and** authenticated, stopping with exact install / `gh auth login` instructions if not. `gh` is an execution prerequisite, so it's checked inside the skill (no SessionStart hook).
- **Project-agnostic** — auto-detects the package manager and lint/test/typecheck/build scripts, and respects the project's own `CLAUDE.md` / `AGENTS.md`. **Never merges**, never pushes to the base branch, never force-greens a check.
- **`marketplace.json`** bumped to `1.3.0`; new `bymax-pr` entry added (category `workflow`); `bymax-all` reference (manifest + README) updated to list all six functional plugins.

### Added — third-party design skills fetched on restore

`scripts/install.sh` now optionally fetches three third-party **design** skills from their upstream repos via the `skills` CLI (`npx skills add … --global`) — **not** vendored, for licensing + freshness:

- **[Emil Design Engineering](https://github.com/emilkowalski/skill)** (Emil Kowalski), **[Impeccable](https://github.com/pbakaus/impeccable)** (Paul Bakaus, Apache-2.0), and a **[Taste-Skill](https://github.com/Leonxlnx/taste-skill)** subset (Leonxlnx, MIT: `design-taste-frontend`, `redesign-existing-projects`, `minimalist-ui`, `industrial-brutalist-ui`, `high-end-visual-design`).
- New `--no-design-skills` flag skips the fetch. Documented in `vendor/README.md` and the README restore table.

### Fixed — docs caught up with `bymax-web-verify`

The `1.2.0` plugin was missing from the README plugin list, repo tree, install blocks, and `bymax-all`. All are now complete and consistent (6 installable plugins, 16 slash commands, 3 skills, 6 sub-agents, 3 hooks).

## [1.2.0] — 2026-05-20

### Added — `bymax-web-verify` plugin (real-browser verification)

A new optional plugin that brings real-browser verification to the toolkit via the [`agent-browser`](https://github.com/vercel-labs/agent-browser) CLI (Vercel Labs, Apache-2.0). It follows the same "require, don't embed" pattern as `bymax-mobile`: it depends on the external CLI rather than bundling it, so the CLI's own version-matched skills never drift.

- **`/bymax-web-verify:setup`** — one-shot, idempotent installer for the `agent-browser` CLI **and** its Chrome for Testing engine, finished with a live smoke test. Designed as a portable backup step after a fresh macOS install. Refuses `sudo`; points at `nvm` on `EACCES`.
- **`/bymax-web-verify:verify`** — drives a real browser to confirm a web change works: opens a URL (auto-probes local dev ports `3000, 5173, 8080, 4321, 3001`), exercises the path using snapshot refs, and reports PASS/FAIL with a screenshot plus console/page errors. Read-only by default.
- **`SessionStart` hook** (`check-agent-browser.sh`) — silent when the CLI is present; when missing, injects `additionalContext` so Claude can proactively offer `/bymax-web-verify:setup`. Never installs unprompted, never blocks the session.
- **`marketplace.json`** bumped to `1.2.0`; new `bymax-web-verify` entry added (category `quality`); `bymax-all` reference updated to list the fifth plugin.

## [1.1.1] — 2026-05-08

### Changed — qualified plugin slash references for namespace correctness

Per the official Claude Code [Plugins reference](https://code.claude.com/docs/en/plugins), plugin skills and commands are always namespaced as `/<plugin>:<skill>` to prevent conflicts when other marketplaces ship a command with the same short name (e.g., `engineering:code-review`, `product-management:brainstorm`). Internal cross-references inside bymax plugin files were using bare names (`/tdd`, `/verify`, `/code-review`), which would silently resolve to the wrong plugin in users' multi-marketplace setups.

- **All cross-references qualified** with the `bymax-<plugin>:` prefix in 35 files (`commands/*.md`, `skills/*/SKILL.md`, `agents/*.md`, plugin `README.md`, and bootstrap `templates/`). 232 references in total.
- **Marketplace + plugin manifest descriptions** also qualified — the `description` field of `marketplace.json` plugin entries and each `<plugin>/.claude-plugin/plugin.json` now show the canonical `/bymax-quality:tdd` form instead of bare `/tdd`. Display-only field, but consistency matters in the plugin browser UI.
- **`/security-review` left bare** — it is the user-level vendor skill / built-in Claude Code command, not a bymax plugin command.
- **No double-prefix and no mangled command arguments** (verified: `/bymax-workflow:checkpoint verify "core-done"` still parses with `verify` as an arg, not as a slash command).
- **`claude plugin validate` passes** on the marketplace and on all five plugin manifests.

## [1.1.0] — 2026-05-08

### Changed — schema migration to Claude Code v2.1.x plugin marketplace

Claude Code's plugin marketplace tightened the schema between v2.1.128 and v2.1.133. The bymax repo has been migrated so `claude plugin validate` passes on every plugin and `claude plugin install` works out of the box.

- **`marketplace.json`** moved to the new schema: now requires `owner` (object); each plugin entry uses `source` (relative path string `./plugins/<name>` for in-repo plugins) instead of the old `path` field; the obsolete root-level fields (`displayName`, `homepage`, `repository`, `author`, `license`, `keywords`) have been removed.
- **`plugin.json`** moved from `<plugin>/plugin.json` to **`<plugin>/.claude-plugin/plugin.json`** for all five plugins. The old root-level `plugin.json` files were removed.
- **Hooks config** moved from inside `bymax-quality/plugin.json` to **`bymax-quality/hooks/hooks.json`** (the convention used by official marketplace plugins).
- **YAML frontmatter** in 10 command files (`bootstrap`, `upgrade-standards`, `code-review`, `tdd`, `checkpoint`, `phase-tasks`, `plan`, `roadmap`, `spec`, `task`) had unquoted `description:` values containing inline `Triggers:`, `Modes:`, or `Args:` substrings — Claude Code's stricter YAML parser silently dropped the entire frontmatter. The descriptions are now wrapped in YAML single quotes.
- **`bymax-all`** demoted from "auto-install everything" meta-plugin to a docs-only reference index. Claude Code's plugin manifest does not support cross-plugin `dependencies`, so the previous `bymax-all` install command was a no-op. Users now install the four real plugins individually.
- **`install.sh`** dropped the plugin-symlinking section. Plugins are installed via `claude plugin install` against the marketplace; the script keeps its vendor / personal / MCP backup logic.
- **`validate.sh`** rewritten on top of `claude plugin validate` so it stays aligned with whatever schema the installed Claude Code expects.

## [1.0.0] — 2026-04-25

Initial public release of the toolkit. Five composable plugins, six specialist sub-agents, two pre/post hooks, twenty stack-aware project templates, a phased planning workflow with explicit user-approval gates, and a strict-quality `/standards` skill referenced by every other command.

### Added

#### `bymax-workflow` — phased planning + execution

- **`/spec`** — Layer 1 of the feature workflow. Drafts a complete technical spec (goal, scope, user stories, success criteria, technical approach, constraints, risks, open questions). Asks clarifying questions if the request is vague.
- **`/roadmap`** — Layer 2. Takes an approved spec and produces a phased master plan with a status dashboard, dependency DAG, and definition-of-done per phase.
- **`/phase-tasks`** — Layer 3. Takes an approved roadmap and scaffolds JIRA-style task files with verbose self-contained agent prompts (Role / PROJECT / PRECONDITIONS / REQUIRED READING / TASK / DELIVERABLES / Constraints / Verification / Completion Protocol).
- **`/task`** — End-to-end executor with `/verify` → `/security-review` → `/code-review` chain and a completion-protocol that closes the phase by auditing every acceptance criterion. Modes: `/task phase <N>` runs all tasks in a phase; `/task <task-id>` runs one task only. Never auto-commits.
- **`/brainstorm`** — Pre-spec idea refinement: clarifying questions, alternatives, tradeoffs. Hands off to `/spec` only after explicit user approval.
- **`/plan`** — Lightweight single-PR planning command for small tasks that don't need the full spec → roadmap → phase-tasks chain.
- **`/verify`** — Five-gate post-implementation verification (static checks, exercise the change, root-cause vs. symptom, regression scan, acceptance criteria audit).
- **`/checkpoint`** — Named SHA + tests + coverage snapshots so you can compare against a baseline later (e.g., "did this refactor regress tests?"). Logs to `.claude/checkpoints.log`.
- **`/standards` skill** — universal coding rules referenced by every other command. **14 sections**: 1. TypeScript discipline (strict + `noUncheckedIndexedAccess`, zero `any`, banned `// @ts-ignore`); 2. Naming conventions; 3. Code documentation (JSDoc on every export); 4. Test documentation (mandatory `it()` block comments); 5. Layered architecture (`app` → `features` → `shared`, no cross-feature imports); 6. Imports (alphabetical, alias-only); 7. Error handling (validate at boundaries, never swallow); 8. Suppression comments — zero tolerance; 9. Conventional Commits; 10. Performance; 11. Accessibility (WCAG AA); 12. Tailwind CSS conventions (full v3 vs v4 split, canonical-class shortcuts, default scale, ARIA boolean variants, renamed utilities, type scale, filter px scale, z-index integers, negative zero); 13. Security baseline (banned imports — `crypto` → `node:crypto`, `bcrypt` → `argon2`, `crypto-js`/`md5`/`uuid`/`nanoid` → `crypto.randomUUID`); 14. Conflict-resolution rules.

#### `bymax-quality` — review + testing + agents + hooks

- **`/code-review`** — CRITICAL → HIGH → MEDIUM → LOW severity review with **hard ban on suppression comments** (`@ts-ignore`, `eslint-disable`, `as any`, `--no-verify`), and **30+ Tailwind v4 canonical-class patterns** flagged on Tailwind 4 projects (skipped on v3 / NativeWind 4): CSS variable shorthand (`[var(--x)]` → `(--x)`), ARIA boolean variants (`aria-[invalid=true]:` → `aria-invalid:`), on-scale `rem` values (`[8rem]` → `32`), gradient renames (`bg-gradient-to-r` → `bg-linear-to-r`), scale shifts (`shadow` → `shadow-sm`, `rounded` → `rounded-sm`, etc.), individual renames (`outline-none` → `outline-hidden`, `flex-shrink-*` → `shrink-*`, etc.), opacity-modifier deprecation (`bg-opacity-50` → `bg-blue-500/50`), arbitrary z-index integers (`z-[200]` → `z-200`), on-scale filter px (`backdrop-blur-[12px]` → `backdrop-blur-md`), and negative zero (`-bottom-0` → `bottom-0`).
- **`/tdd`** — Strict red-green-refactor cycle. Forces failing test before implementation. 80%+ coverage minimum (100% on critical paths). Every `it()` carries a block comment per `/standards` § 4.
- **`tester` skill** — Multi-stack test writer that auto-detects the project's stack (Jest / Vitest / React Native / React DOM / pure logic). 100% file coverage. Every `it()` carries a scenario + rule-it-protects comment. No fake `className`s, no fake branches.
- **6 specialist sub-agents** — `architect` (system design, scalability), `code-reviewer` (quality + security + maintainability), `database-reviewer` (PostgreSQL + Supabase patterns), `planner` (complex-feature planning), `security-reviewer` (OWASP Top 10, SSRF, injection, unsafe crypto), `typescript-reviewer` (type safety, async correctness, idiomatic patterns). All Sonnet/Opus, never Haiku.
- **`secret-scanner` hook** (PreToolUse Write/Edit/MultiEdit) — **blocks** the write if the new content contains a plausible credential: AWS keys, GitHub PATs, OpenAI / Anthropic / Stripe / Slack tokens, JWTs, or PEM private keys. Allowlists test fixtures, examples, docs, and `node_modules`. Exit 2 on block.
- **`console-log-scan` hook** (Stop) — warns on stray `console.log/warn/error/debug/info` in git-modified TS/JS files at session end. Cheap exits (skips silently if not in a git repo or no JS/TS modified).

#### `bymax-bootstrap` — project scaffolding

- **`/bootstrap`** — Scaffold a new project with all the standards wired in one shot. Detects the stack and picks the right ESLint preset. Detects Tailwind major version and recommends the right plugin set (`prettier-plugin-tailwindcss` for v3+v4, plus `eslint-plugin-tailwindcss` and the new overlay for v4). Writes `.vscode/`, `tsconfig.json`, `.prettierrc.json`, `.editorconfig`, `.gitignore`, `commitlint.config.cjs`, `lint-staged.config.cjs`, `.husky/{pre-commit,commit-msg}`, and a `CLAUDE.md` filled with the detected stack.
- **`/upgrade-standards`** — Non-destructive incremental upgrade for existing projects: adds what's missing (`.vscode`, Prettier, Husky, EditorConfig, CLAUDE.md), proposes strengthening tsconfig and ESLint with explicit user confirmation per change. Never overwrites existing configs silently.
- **20 templates**:
  - **6 ESLint flat-configs** — `eslint.config.universal.cjs` (base: `eslint-plugin-security`, import-order, suppression bans, risky-import bans), `eslint.config.next.cjs` (Next 15+/16, App Router or Pages), `eslint.config.expo-rn.cjs` (Expo / React Native), `eslint.config.vite-react.cjs` (Vite + React, SPA or library), `eslint.config.node.cjs` (Express / Fastify / Hono / NestJS / plain Node), `eslint.config.tailwind.cjs` (overlay — auto-detects v3/v4 and applies the right rule set; canonical-class warnings on v4 only).
  - **Strict TypeScript** — `tsconfig.universal.json`.
  - **Formatting** — `prettier.universal.json`, `editorconfig.universal`.
  - **Git hygiene** — `gitignore.universal`, `husky-pre-commit`, `husky-commit-msg`, `commitlint.universal.cjs`, `lint-staged.universal.cjs`.
  - **VS Code** — `vscode-settings.json` (format-on-save), `vscode-extensions.json`.
  - **Project docs** — `claude-md.template.md` (lean per-project `CLAUDE.md`).
  - **Workflow docs** — `spec.template.md`, `roadmap.template.md`, `phase-tasks.template.md`.

#### `bymax-mobile` — iOS Simulator + Android Emulator

- **`/sim-ios`** — Boots the iOS Simulator (default `iPhone 17`, override via `$BYMAX_SIM_IOS`) and runs the current Expo / React Native project. Auto-detects whether `expo start` (Metro reattach — fast) or `expo run:ios` (full rebuild + install + launch — slow) is the right call, using a build-artifact heuristic on `ios/build` and `ios/Pods`. macOS only.
- **`/sim-android`** — Boots an Android emulator (first AVD listed by `emulator -list-avds`, override via `$BYMAX_SIM_ANDROID`) and runs the current Expo project. Same start-vs-run heuristic on `android/app/build/outputs`. macOS / Linux. Prints exact install steps if the Android SDK or AVDs are missing.
- Both commands: auto-detect the package manager (`pnpm` if `pnpm-lock.yaml`, else `yarn`, else `npm`), honor `$APP_VARIANT` for Expo build flavors, and pre-flight tooling + project shape with actionable error messages.

#### `bymax-all` — meta-plugin

- Pulls in `bymax-workflow` + `bymax-quality` + `bymax-bootstrap` + `bymax-mobile` in one shot. Recommended starting point.

#### Repo

- **`README.md`** — badges (Node 24+, TypeScript strict, React 19, Next 16, Expo 55, RN 0.85, Vite 7, Express 5, Fastify 5, Hono 4, NestJS 11, Tailwind 4, NativeWind 4, ESLint 9, Prettier 3, Jest 30, Vitest 3, Husky 9, commitlint 19, lint-staged 15), tables, and emoji-rich sections grouped by category. Quick Start with à-la-carte plugin install. Personal Restore section with full step-by-step for restoring the toolkit on a new Mac (clone → dry-run → install.sh → settings → MCPs → marketplace plugins → github MCP → restart).
- **`LICENSE`** (MIT), **`CONTRIBUTING.md`**, **`CHANGELOG.md`**, **`SECURITY.md`**, **`CODE_OF_CONDUCT.md`**, **`.gitignore`**.
- **`.github/`** — `workflows/validate.yml` (runs `scripts/validate.sh` on every push and PR), `ISSUE_TEMPLATE/{bug_report,feature_request}.md`, `PULL_REQUEST_TEMPLATE.md`.
- **`templates/`** — reusable `CLAUDE.md`, `AGENTS.md`, and `README.md` starters distilled from real production projects.
- **`vendor/`** — MIT-licensed third-party skills bundled as personal backup with original `LICENSE` and `ATTRIBUTION.md` preserved per upstream MIT terms (**not** redistributed via the marketplace):
  - **`vendor/ecc-skills/`** — seven domain-knowledge skills extracted from [Everything Claude Code](https://github.com/affaan-m/everything-claude-code) by Affaan Mustafa: `api-design`, `backend-patterns`, `coding-standards`, `database-migrations`, `frontend-patterns`, `postgres-patterns`, `security-review`.
  - **`vendor/ui-ux-pro-max/`** — full UI/UX design intelligence skill from [ui-ux-pro-max-skill](https://github.com/nextlevelbuilder/ui-ux-pro-max-skill) by nextlevelbuilder.
- **`personal/`** — author's project-specific extras (sanitized; safe to publish): `settings.template.json` (with `{{PLACEHOLDERS}}` and inline `_comment_*` keys documenting the full restore flow), `mcp.template.json` (`context7` + `sequential-thinking` user-scope MCPs), `prettier-format.sh` (PostToolUse Write/Edit hook).
- **`scripts/install.sh`** — symlinks every plugin's `commands/`, `agents/`, `skills/`, `hooks/`, and `templates/` into `~/.claude/`; symlinks `vendor/ecc-skills/*.md` and `vendor/ui-ux-pro-max/` too; symlinks `personal/prettier-format.sh`; copies (not symlinks) `personal/mcp.template.json` to `~/.mcp.json` (no-clobber). Idempotent. Flags: `--dry-run` (preview without writing), `--no-vendor`, `--no-personal`, `--no-mcp`, `--plugins-only`, `--write-mcp-enabled` (also writes `~/.claude/settings.local.json` with `enabledMcpjsonServers`).
- **`scripts/validate.sh`** — validates `marketplace.json` and every `plugin.json` (valid JSON, required fields, every command/agent/skill path exists, every command file has a YAML frontmatter `description`, every agent file has `name` + `description` + `tools`, every shell hook is `chmod +x`, shellcheck on every shell script when installed, every required project-level file is present). Used by CI and locally before pushing.
- **`docs/PROPOSAL.md`** — original design proposal preserved for context.

[Unreleased]: https://github.com/bymaxone/bymax-claude-code/compare/v1.6.1...HEAD
[1.6.1]: https://github.com/bymaxone/bymax-claude-code/compare/v1.6.0...v1.6.1
[1.6.0]: https://github.com/bymaxone/bymax-claude-code/compare/v1.5.0...v1.6.0
[1.5.0]: https://github.com/bymaxone/bymax-claude-code/compare/v1.4.0...v1.5.0
[1.4.0]: https://github.com/bymaxone/bymax-claude-code/compare/v1.3.0...v1.4.0
[1.3.0]: https://github.com/bymaxone/bymax-claude-code/compare/v1.2.0...v1.3.0
[1.2.0]: https://github.com/bymaxone/bymax-claude-code/compare/v1.1.1...v1.2.0
[1.1.1]: https://github.com/bymaxone/bymax-claude-code/compare/v1.1.0...v1.1.1
[1.1.0]: https://github.com/bymaxone/bymax-claude-code/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/bymaxone/bymax-claude-code/releases/tag/v1.0.0
