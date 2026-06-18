# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [Unreleased]

_No changes yet._

## [1.4.0] — 2026-06-17

### Added — Rust support across `bymax-workflow` + `bymax-quality`

The workflow and quality plugins are now **language-detecting**: TypeScript/JS behavior is unchanged, and a parallel **Rust track** activates when a `Cargo.toml` is present. This makes the full `spec → … → task` quality cycle usable on Rust projects (first consumer: the `rust-auth` library).

- **`/bymax-workflow:standards`** — new **§15 Rust track** (edition/MSRV pinning, `clippy -D warnings` + `cargo fmt`, no `unwrap`/`expect`/`panic!` on lib paths, typed `thiserror` errors, `#![forbid(unsafe_code)]`, rustdoc `//!`/`///` + `#![deny(missing_docs)]`, `#[test]` discipline, `cargo-deny`/`-audit`/`-vet` supply chain, RustCrypto/`subtle`/`secrecy` security baseline) + a "which track applies" detector and a TS→Rust tooling map.
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

[Unreleased]: https://github.com/bymaxone/bymax.claude-code/compare/v1.1.0...HEAD
[1.1.0]: https://github.com/bymaxone/bymax.claude-code/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/bymaxone/bymax.claude-code/releases/tag/v1.0.0
