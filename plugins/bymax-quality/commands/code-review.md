---
description: 'Comprehensive security and quality review with selectable depth: mechanical gate (deterministic greps for secrets/suppressions/Tailwind/console), bug hunt (single-pass or parallel finder agents with adversarial verification), and the Bymax convention checklist across CRITICAL (secrets, SQL injection, XSS, suppression comments like @ts-ignore/eslint-disable or Rust #[allow]/unsafe), HIGH (long functions, missing JSDoc on exports, cross-feature imports, swallowed errors, reinvented wheels per the standards §0 simplicity ladder), MEDIUM (mutation patterns, magic numbers, enum usage, non-English comments, copy-pasted logic, speculative generality), and LOW (nits). Every candidate finding is re-verified against the file before it is reported. Blocks the commit on any CRITICAL or HIGH. Modes: quick | full (default) | deep. Optional target (branch, ref range, PR#, file) and --fix. Run before /bymax-workflow:verify and before any commit. Triggers: "code review", "review changes", "check this code", "is this safe to commit", "revisar código".'
---

# Code Review

Comprehensive security and quality review, structured as a pipeline: a deterministic
mechanical gate, a bug hunt at the requested depth, the Bymax convention checklist,
and a verification pass that filters false positives before anything is reported.

## Usage

```
/bymax-quality:code-review [quick|full|deep] [target] [--fix]
```

| Argument | Meaning |
| --- | --- |
| `quick` | Mechanical gate + CRITICAL/HIGH judgment checks on changed lines only. Sanity check before a push. |
| `full` *(default)* | Everything: mechanical gate, single-pass bug hunt, full convention checklist, verification. |
| `deep` | `full`, but the bug hunt fans out to parallel finder sub-agents (stack reviewer + security reviewer) whose candidates are then adversarially verified. Use before merging a feature branch. |
| `target` | Optional. A branch name (`feature-x` → reviews `main...feature-x`), a ref range (`main...feature-x`), a PR number (`#123`, uses `gh pr diff`), or a file path. Without a target: uncommitted changes, plus the branch's commits ahead of upstream when the working tree is clean. |
| `--fix` | After the report, apply the confirmed mechanical MEDIUM fixes (Tailwind renames, canonical tokens) and any finding the user approves. Never commits. |

> **Stack-adaptive.** Detect the stack first. On a **Rust** project (`Cargo.toml`), apply the
> **Rust checks** flagged in each section below and **skip** the TypeScript/Tailwind-specific ones
> (`any`/`enum`/`interface vs type`/JSDoc/`../../../` aliases/Tailwind rules). On a **TypeScript**
> project (`package.json`), apply the TS checks as written. The CRITICAL security and suppression
> rules apply to both.

> **Composes with the built-in engine.** Claude Code ships its own multi-agent bug-hunting review
> (`/code-review <effort>`, `/code-review ultra` for the cloud run) — it finds logic bugs but knows
> nothing about Bymax conventions and never blocks. This command is the convention gate that does
> block. For the heaviest bug pass, run the built-in `/code-review high` (or `ultra`) alongside this
> command; `deep` mode approximates its finder→verify architecture locally with this plugin's agents.

## Step 1 — Resolve the scope

```bash
# Default: uncommitted work first…
git diff --name-only HEAD
# …and if the working tree is clean, review the branch's committed work instead:
git diff --name-only @{upstream}...HEAD   # fallback: main...HEAD
```

- Branch target → `git diff main...<branch>` (fetch from origin if the branch is only remote).
- Ref range target → use it verbatim.
- PR target → `gh pr diff <N> --patch`.
- File target → limit every step below to that file.

Record the resolved diff range once and reuse it in every command below as `$RANGE`
(for uncommitted work, `HEAD`).

## Step 2 — Mechanical gate (deterministic)

Run these greps over the diff so findings are exact facts, not model impressions. The `^\+`
anchor keeps **added lines only** — removed lines never match. Map each match back to its
`file:line` via the `@@` hunk headers (or re-grep the file). Anything matched here is a
finding — no judgment call, no verification needed.

```bash
# CRITICAL — suppression comments (zero tolerance, see policy below)
git diff -U0 $RANGE | grep -E '^\+.*(eslint-disable|@ts-ignore|@ts-expect-error|@ts-nocheck|prettier-ignore|as any|as unknown as|#\[allow\(|#!\[allow\(|# noqa|# type: ignore|@SuppressWarnings)'

# CRITICAL — CLI bypasses committed in scripts or hooks
git diff -U0 $RANGE | grep -E '^\+.*(--no-verify|--skip-checks|--no-gpg-sign)'

# HIGH — raw console in production code (frontend must use the project logger)
git diff -U0 $RANGE -- '*.ts' '*.tsx' ':!*test*' ':!*spec*' | grep -E '^\+.*console\.(log|warn|error|debug|info)'

# HIGH — TODO/FIXME without an issue link
git diff -U0 $RANGE | grep -E '^\+.*(TODO|FIXME|XXX|HACK)' | grep -vE '#[0-9]+|issues/'

# HIGH — file over 800 lines (list changed files, then measure them)
git diff --name-only $RANGE | xargs -I{} sh -c 'test -f "{}" && wc -l "{}"' | awk '$1 > 800'

# MEDIUM — Tailwind v4 non-canonical forms (skip on Tailwind v3 / NativeWind projects)
git diff -U0 $RANGE -- '*.tsx' '*.jsx' | grep -E '^\+.*(\[var\(--|aria-\[(invalid|disabled|pressed|expanded|hidden|selected|checked|busy|modal|required|readonly)=(true|false)\]|z-\[[0-9]+\]|-(bottom|top|left|right|m)-0([^.0-9]|$))'

# MEDIUM — Tailwind v3 utilities renamed in v4
git diff -U0 $RANGE -- '*.tsx' '*.jsx' | grep -E '^\+.*(bg-gradient-to-|outline-none|decoration-(clone|slice)|overflow-ellipsis|flex-(shrink|grow)-|(bg|text|border|divide|placeholder|ring)-opacity-[0-9])'

# MEDIUM — hardcoded hex colors in className (use design tokens)
git diff -U0 $RANGE -- '*.tsx' '*.jsx' | grep -E '^\+.*className=.*#[0-9a-fA-F]{3,8}'

# MEDIUM — dynamic Tailwind class strings the JIT cannot see
git diff -U0 $RANGE -- '*.tsx' '*.jsx' | grep -E '^\+.*className=\{`[^`]*\$\{'
```

Severity mapping for Tailwind canonical forms (flag → suggest): `[var(--x)]` → `(--x)` ·
`aria-[invalid=true]:` → `aria-invalid:` · `z-[200]` → `z-200` · `-bottom-0` → `bottom-0` ·
`bg-gradient-to-r` → `bg-linear-to-r` · `outline-none` → `outline-hidden` ·
`bg-opacity-50` → `bg-blue-500/50` form · on-scale arbitrary rem (`p-[1rem]` → `p-4`,
`min-w-[8rem]` → `min-w-32`; token = rem × 4, off-scale values stay arbitrary) · filter px
(`backdrop-blur-[12px]` → `backdrop-blur-md`: 4=xs 8=sm 12=md 16=lg 24=xl 40=2xl 64=3xl) ·
v3 scale shifts (`shadow`→`shadow-sm`, `rounded`→`rounded-sm`, `blur`→`blur-sm`,
`ring`→`ring-3`). Full table: `/bymax-workflow:standards` §12.

Also scan added lines for secrets (AWS keys, GitHub PATs, JWTs, PEM blocks, provider tokens) —
the `secret-scanner` hook blocks writes, but the diff may predate the hook.

## Step 3 — Bug hunt

Skipped in `quick` mode.

**`full` (default):** hunt logic bugs yourself, single pass. For each changed file, read the whole
file plus its call sites — never review a hunk in isolation. Hunt specifically for: broken edge
cases (empty/null/zero/unicode), off-by-one and boundary errors, async races and unawaited
promises, error paths that leave state inconsistent, wrong operator or inverted condition,
regressions in callers the diff didn't touch. Report only what you are >80% confident is real.

**`deep`:** spawn two finder sub-agents **in parallel** on the resolved diff and collect their
candidates:

1. The stack reviewer (`typescript-reviewer` on TS projects, `rust-reviewer` on Rust) — logic and
   type-level bugs.
2. `security-reviewer` — injection, SSRF, authz gaps, unsafe crypto, PII leaks.

Finder output is **candidates, not findings** — every one of them goes through Step 5 before it
can be reported. Never spawn agents that run test suites; finders read code only.

## Step 4 — Convention checklist (judgment)

The mechanical patterns already ran in Step 2; this step covers what needs reading comprehension.
In `quick` mode, check only CRITICAL and HIGH.

### CRITICAL — block on sight

- SQL injection (string-built queries), XSS (unsafe `dangerouslySetInnerHTML`, unescaped user
  input), path traversal (user input feeding `fs`/`path.join`).
- Missing input validation on a public boundary (HTTP handler, IPC, file parser).
- Logging or analytics that include PII, credentials, medical data, or other sensitive fields.
- Insecure dependencies (known CVEs, abandoned packages).

### Suppression policy — zero tolerance

Any suppression matched in Step 2 (or spotted while reading) is a CRITICAL block:
`eslint-disable` in any form, `@ts-ignore`/`@ts-expect-error`/`@ts-nocheck`, `as any`,
`as unknown as <T>` laundering a real type error, `prettier-ignore` (unless preserving a
deliberately-formatted table), cross-language suppressions (`# noqa`, `# type: ignore`,
`@SuppressWarnings`), and in Rust: `#[allow(...)]` silencing a clippy/rustc gate without a
user-accepted justification, `unsafe` without a `// SAFETY:` comment or inside a
`#![forbid(unsafe_code)]` crate, `#[ignore]` hiding a failing test.

**The rule:** fix the underlying cause. A failing lint or type error means the code is wrong, the
type is wrong, or the rule is wrong — choose one and fix it. Never silence the messenger.

**The only acceptable exception:** a suppression that (1) references a specific issue or PR
(`// eslint-disable-next-line no-unused-vars -- see #1234, follow-up tracked`) AND (2) has a
clear, time-bounded reason. Even then, flag it as HIGH so the reviewer accepts it explicitly.
If the user is fighting a wrong rule, change the rule config with justification — never scatter
`disable` comments through the code.

### HIGH — must fix before merge

- Functions > 50 lines; nesting depth > 4.
- **Docs (per `/bymax-workflow:standards`):** non-trivial source file missing the file-header
  JSDoc (Purpose + Layer); exported function/hook/component/service/store missing JSDoc with
  `@param`/`@returns`/`@throws`; test `it`/`test` block without a comment naming the scenario
  and the rule it protects. **Rust:** public item missing rustdoc (`///`, crate `//!`,
  `# Errors` on fallible items, `# Safety` on `unsafe fn`).
- **Architecture:** cross-feature import (`features/X/` importing `features/Y/` — orchestrate one
  level up); domain import inside `shared/ui/`; internal export leaked through a feature barrel.
- **Reinvented wheel (standards §0 simplicity ladder):** new code reimplements something that
  exists in this repo, in a `@bymax-one/*` lib, in the stdlib/platform (`Intl`,
  `crypto.randomUUID()`, `URL`, `structuredClone`, native `<input>` types, `std`/`core`), or in
  an installed dependency — point to the existing symbol. A new dependency for something already
  covered must be justified.
- **Error handling:** empty `catch`, `catch` that only logs without surfacing, ignored rejected
  promises, missing boundary validation (Zod or equivalent). **Rust:** `unwrap()`/`expect()`/
  `panic!`/`todo!()` on a library path (tests exempt); stringly-typed errors instead of a
  `thiserror` enum; `anyhow` in a library's public API; `let _ =` discarding a `Result`.
- **TS discipline:** `any` introduced (use `unknown` + guard, a generic, or the upstream type);
  non-null assertion `!` without a comment proving the invariant.
- An existing suppression retained without an issue-link justification (see policy above).

### MEDIUM — should fix

- Mutation where immutable would do; magic numbers without a named constant; emoji in code.
- Missing tests for new code.
- Copy-pasted logic across ≥ 2 places that belongs in `shared/` or a `@bymax-one/*` lib.
- Speculative generality (YAGNI) — options/params/abstractions with no current caller.
- Accessibility: missing labels, keyboard traps, color contrast.
- `enum` instead of a string-literal union; `interface` for a union/utility type or `type` for an
  entity shape (standards §1); boolean not prefixed `is/has/should/can`; `../../../` where a path
  alias exists.
- Comment not in English; plan phase/task references in committed comments (timeless-comments
  rule). **Rust:** avoidable `.clone()`/`format!` in a hot path; blocking work in an `async fn`
  without `spawn_blocking`; internal type leaked through the public API; missing `#[must_use]`;
  a dependency not cleared by `cargo deny`.

### LOW — nit

- Inconsistent naming with surrounding code; unnecessary re-exports; comments restating the code.

## Step 5 — Verify before reporting

Candidate ≠ finding. For **every** non-mechanical candidate (yours or a finder agent's):

1. Re-open the file at the cited line and confirm the claim against the actual code — the guard
   the finder "missed" is often three lines up.
2. For behavior claims, trace the call path; a claim that survives only as an inference from
   naming is dropped.
3. Consolidate duplicates ("5 functions missing JSDoc" is one finding with five locations).
4. Drop everything unconfirmed. Track the dropped count for the report.

Step 2 (mechanical) findings skip verification — they are already exact.

## Step 6 — Report and verdict

```
## Code Review Report  (mode: <quick|full|deep> · scope: <range>)

### CRITICAL (n)
- <file>:<line> — <issue> — <suggested fix>

### HIGH (n)
- <file>:<line> — <issue> — <suggested fix>

### MEDIUM (n)
- ...

### LOW (n)
- ...

Candidates dropped in verification: <n>
Verdict: BLOCK / APPROVE WITH CHANGES / APPROVE
```

**Never approve code with security vulnerabilities or new suppression comments.**
Any CRITICAL or HIGH ⇒ verdict is BLOCK.

With `--fix`: after the report, apply the mechanical MEDIUM fixes (Tailwind renames and canonical
tokens are deterministic rewrites) and any other finding the user approves, then re-run Step 2 to
confirm the gate is clean. Never commit — the user commits.
