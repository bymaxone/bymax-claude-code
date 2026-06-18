---
description: Prove a change actually works before declaring it done. Runs the project's verification gates, exercises the affected paths, and checks the root cause was fixed — not just the symptom. Use after implementation, before /bymax-quality:code-review or commit.
---

# Verify Command

Post-implementation discipline. Inspired by the `verification-before-completion` skill from the Superpowers framework.

The rule: **"compiles" is not "works".** A green type-check, a passing lint, and a happy test runner are necessary but not sufficient. This command forces an honest check before anything is reported as done.

## When to Use

Use `/bymax-workflow:verify` immediately after finishing an implementation, and before:

- Saying "done" to the user.
- Running `/bymax-quality:code-review`.
- Preparing a commit or PR.

Use it especially when:

- The change touches a code path that's hard to exercise from a unit test (UI, navigation, animations, native modules, background tasks, notifications).
- A bug fix — to prove the bug is actually gone, and the fix targets the root cause.
- Anything where "looks right" has burned us before.

## The verification gates

Walk these in order. Do not skip. If a gate fails, fix the underlying cause — never bypass.

### Gate 1 — Static checks

Run the project's standard quality gates. Adapt to the stack — examples:

- **TypeScript projects**: `pnpm type-check` / `npm run type-check` / `tsc --noEmit`
- **Lint**: `pnpm lint` / `eslint .` / `ruff check`
- **Format**: `pnpm format:check` / `prettier --check`
- **Tests**: `pnpm test` / `npm test` / `pytest`
- **Rust projects** (`Cargo.toml`): `cargo fmt --all --check` (format) · `cargo clippy --workspace --all-targets --all-features -- -D warnings` (lint) · `cargo build --workspace --all-features --locked` (compile) · `cargo test --workspace` (tests) · `cargo llvm-cov` (coverage) · `cargo deny check` + `cargo audit` (supply chain) · `cargo build -p <wasm-crate> --target wasm32-unknown-unknown` (if the project ships a wasm binding)

All must be 0 errors. No exceptions.

**Suppression comments are equivalent to a failing gate.** If the diff introduces or keeps any of the following, treat it as a Gate 1 failure even if the linter passes:

- `// eslint-disable*`, `/* eslint-disable */` blocks
- `// @ts-ignore`, `// @ts-expect-error`, `// @ts-nocheck`
- `as any`, `as unknown as <T>` used to launder a real type error
- `// prettier-ignore` (unless preserving a deliberately-formatted table)
- `# noqa`, `# type: ignore`, `# pylint: disable=...`, `@SuppressWarnings`
- Rust: `#[allow(...)]` / `#![allow(...)]` added to dodge a clippy/rustc gate without a user-accepted justification; an `unsafe` block in a crate that should `#![forbid(unsafe_code)]`; `#[ignore]` to hide a failing test; `unwrap()` / `expect()` / `panic!` newly introduced on a library path
- CLI bypasses: `--no-verify`, `--force` on protected branches, `--skip-checks`, hook disabling

Run a quick scan of the diff for these patterns:

```bash
git diff HEAD | grep -nE '(eslint-disable|@ts-ignore|@ts-expect-error|@ts-nocheck|as any|as unknown as|prettier-ignore|noqa|type: ignore|SuppressWarnings|--no-verify|#!?\[allow\(|#\[ignore\])'
```

The grep covers the *mechanical* suppressions. The Rust `unsafe` / `unwrap()` / `expect()` / `panic!` items from the list above are intentionally **not** in it — they legitimately appear in test code and the wasm binding, so they're judged in context (review), not auto-flagged by this quick scan.

If any new occurrence exists, **stop and fix the root cause**. Never silence the messenger. The only acceptable exception is a suppression that references a specific issue and has a time-bounded reason — and even then, the user must explicitly accept it.

### Gate 2 — Exercise the change

Don't trust unit tests alone. Actually run the path:

- **CLI / script**: invoke it with realistic input and a degenerate input (empty, null, max size).
- **Backend route**: hit it with a real request (curl / httpie / a test client). Check status, body, and side effects (DB row, queue message, log line).
- **UI / frontend**: open the dev server, navigate to the changed screen, perform the user action, and observe the result. For React Native / Expo projects, run the simulator. For web, drive the preview tools or a headless browser.
- **Background job / cron**: trigger it manually and inspect the output.

If you genuinely cannot run the path in this environment, **say so explicitly**. Do not claim it works.

### Gate 3 — Root cause check (for bug fixes)

For any fix, answer in writing:

1. **What was the actual cause?** (one sentence, mechanical — e.g. "off-by-one in pagination offset", not "it didn't work")
2. **What did the fix change?**
3. **Why does that change resolve the cause?** (the chain of reasoning)
4. **What other places could have the same bug?** (defense-in-depth — search for the pattern)

If you can't answer all four, you patched a symptom. Go back.

### Gate 4 — Regression scan

Look at what else might break:

- Files imported by the changed file: did their assumptions still hold?
- Callers of any function whose behavior changed: did contracts change?
- Tests that touched adjacent code: do they still cover what they used to?
- Any feature flag, env var, or migration that depends on this code path.

If unsure, grep for usages and read the call sites.

### Gate 5 — Acceptance criteria

Re-read the original spec / `/bymax-workflow:brainstorm` output / issue description. For each acceptance criterion, mark it:

- ✅ Met and verified (which gate proved it)
- ⚠️ Partially met (what's missing)
- ❌ Not met (why)

Don't be generous. "Probably works" = ❌.

## Output

End with a short report — example shape:

```
## Verification report

Static gates:
- type-check: PASS
- lint: PASS
- format: PASS
- tests: 248 PASS, 0 fail

Exercised:
- ran <command / interaction> → <observed result>
- did NOT exercise <path> because <reason>

Root cause (for bug fixes):
- cause: ...
- fix: ...
- other risk sites checked: ...

Regression scan:
- callers checked: <list>
- adjacent tests still cover: <yes/no>

Acceptance criteria:
- ✅ <criterion 1> — proven by <evidence>
- ⚠️ <criterion 2> — only partially, <gap>

Verdict: READY / NOT READY / NEEDS USER INPUT
```

## Hard rules

- **Never claim "verified" for a path you didn't actually run.** Saying "I cannot verify this in the current environment" is honest and useful. Saying "looks good" when you didn't run it is a lie that costs the user trust.
- **Never bypass a failing gate** with `--force`, `--no-verify`, or by deleting/skipping the failing test. Fix the underlying issue.
- **Do not edit code in this command.** If verification finds a problem, report it and let the user decide whether to loop back to `/bymax-quality:tdd` or `/bymax-workflow:plan`.

## Integration with other commands

```
/bymax-workflow:brainstorm  →  spec
    ↓
/bymax-workflow:plan        →  step-by-step plan (waits for confirm)
    ↓
/bymax-quality:tdd         →  red-green-refactor implementation
    ↓
/bymax-workflow:verify      →  ← you are here
    ↓
/bymax-quality:code-review →  final review
    ↓
commit / PR
```
