---
description: 'Comprehensive security and quality review with selectable depth: mechanical gate (deterministic greps for secrets/suppressions/Tailwind/console), bug hunt (single-pass or parallel finder agents with adversarial verification), and the Bymax convention checklist across CRITICAL (secrets, SQL injection, XSS, suppression comments like @ts-ignore/eslint-disable or Rust #[allow]/unsafe), HIGH (long functions, missing JSDoc on exports, cross-feature imports, swallowed errors, reinvented wheels per the standards §0 simplicity ladder), MEDIUM (mutation patterns, magic numbers, enum usage, non-English comments, copy-pasted logic, speculative generality), and LOW (nits). Every candidate finding is re-verified against the file before it is reported. In full and deep an independent second review runs in parallel through the Codex CLI (optional: absent, logged-out or slow Codex degrades to a one-line status and changes nothing), and the report carries both reviews side by side with a cross-read. Blocks the commit on any CRITICAL or HIGH from the Bymax review. Modes: quick | full (default) | deep. Optional target (branch, ref range, PR#, file), --fix and --no-codex. Run before /bymax-workflow:verify and before any commit. Triggers: "code review", "review changes", "check this code", "is this safe to commit", "revisar código".'
---

# Code Review

Comprehensive security and quality review, structured as a pipeline: a deterministic
mechanical gate, a bug hunt at the requested depth, the Bymax convention checklist,
and a verification pass that filters false positives before anything is reported.

In `full` and `deep`, a **second, independent review runs in parallel** through the Codex
CLI, and the report carries both side by side. The two are kept apart on purpose: Codex
is launched before this command forms any opinion, and its output is not read until this
command's own findings are frozen. When Codex is absent, logged out, rate-limited or slow,
the report says so in one line and nothing else changes.

## Usage

```
/bymax-quality:code-review [quick|full|deep] [target] [--fix] [--no-codex]
```

| Argument | Meaning |
| --- | --- |
| `quick` | Mechanical gate + CRITICAL/HIGH judgment checks on changed lines only. Sanity check before a push. |
| `full` *(default)* | Everything: mechanical gate, single-pass bug hunt, full convention checklist, verification. |
| `deep` | `full`, but the bug hunt fans out to parallel finder sub-agents (stack reviewer + security reviewer) whose candidates are then adversarially verified. Use before merging a feature branch. |
| `target` | Optional. A branch name (`feature-x` → reviews `<default-branch>...feature-x`), a ref range (`main...feature-x`), a PR number (`#123`, checked out locally so `$RANGE` works with `git diff` — see Step 1), or a file path. Without a target: uncommitted changes, plus the branch's commits ahead of upstream when the working tree is clean. |
| `--fix` | After the report, apply the confirmed mechanical MEDIUM fixes (Tailwind renames, canonical tokens) and any finding the user approves. Never commits. |
| `--no-codex` | Skip the independent Codex review (Step 1.5). It is on by default in `full` and `deep`, and never runs in `quick`. |

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

> **The Codex review is optional and self-contained.** It needs only the `codex` binary on
> `PATH` with an active session — not the OpenAI Codex *plugin*, whose `/codex:review` and
> `/codex:adversarial-review` are user-only commands a skill cannot invoke. Run
> **`/bymax-quality:codex-setup`** to install and authenticate it. Without it, this command
> behaves exactly as it did before.

## Step 1 — Resolve the scope

```bash
# Resolve the repository's default branch once — never assume `main`.
DEFAULT_BRANCH=$(git symbolic-ref --quiet refs/remotes/origin/HEAD \
  | sed 's@^refs/remotes/origin/@@')
# origin/HEAD is unset on many clones — ask the remote, the only way to learn a
# default that is neither `main` nor `master` (e.g. `develop`).
# The probe is forced non-interactive: `2>/dev/null` hides a credential
# prompt's output but does not stop it from blocking, so disable both the
# HTTPS and the SSH prompt paths outright.
[ -n "${DEFAULT_BRANCH}" ] || DEFAULT_BRANCH=$(
  GIT_TERMINAL_PROMPT=0 GIT_SSH_COMMAND='ssh -oBatchMode=yes' \
  git ls-remote --symref origin HEAD 2>/dev/null \
    | sed -n 's@^ref: refs/heads/\(.*\)[[:space:]]HEAD$@\1@p')

# A DETECTED default must resolve to that branch and no other. Falling through
# to another conventional name would silently compare against an unrelated one:
# in a `--branch develop --single-branch` clone whose remote default is `main`,
# that is exactly how `origin/develop` gets chosen to stand in for `main`.
DEFAULT_REF=""
if [ -n "${DEFAULT_BRANCH}" ]; then
  for candidate in "origin/${DEFAULT_BRANCH}" "${DEFAULT_BRANCH}"; do
    git rev-parse --verify -q "${candidate}" >/dev/null 2>&1 \
      && DEFAULT_REF="${candidate}" && break
  done
  # Detected but never fetched (single-branch clone). Fetch just that one ref,
  # non-interactively — it creates a remote-tracking ref and touches nothing in
  # the working tree. If it fails, leave DEFAULT_REF empty — every use below
  # checks for that. Never substitute a different branch.
  [ -n "${DEFAULT_REF}" ] || {
    GIT_TERMINAL_PROMPT=0 GIT_SSH_COMMAND='ssh -oBatchMode=yes' \
      git fetch --quiet origin \
        "refs/heads/${DEFAULT_BRANCH}:refs/remotes/origin/${DEFAULT_BRANCH}" 2>/dev/null \
      && git rev-parse --verify -q "origin/${DEFAULT_BRANCH}" >/dev/null 2>&1 \
      && DEFAULT_REF="origin/${DEFAULT_BRANCH}"
  }
else
  # No default could be detected at all — only here is a conventional name a
  # reasonable guess, and only one that actually exists.
  for candidate in origin/main main origin/master master \
                   origin/develop develop origin/trunk trunk; do
    git rev-parse --verify -q "${candidate}" >/dev/null 2>&1 \
      && DEFAULT_REF="${candidate}" && break
  done
  DEFAULT_BRANCH="${DEFAULT_REF#origin/}"
fi

# Default: uncommitted work first — tracked changes AND untracked new files
# (a brand-new file with a secret or suppression must not slip the gate)…
git diff --name-only HEAD
git ls-files --others --exclude-standard          # untracked files, add to the set

# …and ONLY if the working tree is clean, review the branch's committed work
# instead. A base is needed just for this path — an uncommitted-changes review
# is scoped to HEAD and must still work in a repository that has no resolvable
# default branch at all.
if git diff --quiet HEAD && [ -z "$(git ls-files --others --exclude-standard)" ]; then
  # A branch that was never pushed has no `@{upstream}`: using it bare makes git
  # fail instead of reporting the commits, so resolve the base first.
  BASE=$(git rev-parse --abbrev-ref --symbolic-full-name '@{upstream}' 2>/dev/null) \
    || BASE="${DEFAULT_REF}"
  # An empty base does not make git fail: it reads `"...HEAD"` as `HEAD...HEAD`,
  # an empty diff reported as a clean review. Every use of a base checks this.
  [ -n "${BASE}" ] || { echo "cannot resolve a comparison base — pass an explicit ref range" >&2; exit 1; }
  git diff --name-only "${BASE}...HEAD"
fi
```

For the mechanical gate, include untracked files by intent-to-add them first
(`git add -N .`) so `git diff` surfaces their added lines, or grep them directly.

- Branch target → stop unless the base resolved (stated inline because this runs in a
  later block than Step 1: `[ -n "$DEFAULT_REF" ] || exit 1`), then
  `git diff "$DEFAULT_REF"...<branch>` (fetch from origin if the branch is only remote).
  Without the guard an empty `$DEFAULT_REF` turns this into `HEAD...<branch>` — the target
  compared against whatever happens to be checked out, or `HEAD...HEAD` when it *is* the
  checkout: an empty diff reported as a clean review.
- Ref range target → use it verbatim.
- PR target → check it out locally so the range works with `git diff`:
  `gh pr checkout <N>`, then `$RANGE` = `<base-branch>...HEAD`. When checkout
  isn't possible, `git fetch origin pull/<N>/head` and use
  `<base-branch>...FETCH_HEAD`. The PR's own base branch comes from
  `gh pr view <N> --json baseRefName`, so it is always non-empty — but check it the same
  way if you derived it any other way.
- File target → limit every step below to that file.

Record the resolved diff range once and reuse it in every command below as `$RANGE`
(for uncommitted work, `HEAD`).

## Step 1.5 — Launch the independent Codex review (optional, non-blocking)

Skipped in `quick` mode, and whenever `--no-codex` is passed.

A second model reading the same diff catches what a grep and a convention checklist
structurally cannot — and, more usefully, what **you** miss. This is a second opinion,
never a gate: the verdict in Step 6 is computed from your findings alone, so it stays
identical whether or not Codex was reachable.

Map the scope resolved in Step 1 onto the one flag Codex understands:

| Resolved scope | Script arguments |
| --- | --- |
| uncommitted work (dirty tree) | `--target uncommitted` |
| branch vs upstream (clean tree) | `--target base --ref "$BASE"` |
| branch target **that is the current HEAD** | `--target base --ref "$DEFAULT_REF"` |
| PR target, **after `gh pr checkout` made it HEAD** | `--target base --ref <pr base branch>` |
| a single commit | `--target commit --ref <sha>` |
| a branch target that is **not** checked out | **skip Codex** (see below) |
| a file path, or a ref range not ending at HEAD | **no equivalent — skip Codex** |

> **Codex always reviews the current checkout.** `codex exec review` takes a base
> (`--base`) but has no head-ref argument, so passing a base while HEAD is some other
> branch makes it review *your checkout* against that base — a different diff from the
> one Review A examined, quite possibly an empty one, presented in the report as a
> second opinion on the requested branch. That is the same false-clean failure the
> empty-base guard exists to prevent. So: only send Codex a base when the head it will
> compare **is** the scope you resolved in Step 1. Never switch branches to make it fit —
> a review command must not mutate the working tree. Skip Codex and say so in Review B.

Launch it with `run_in_background: true` so it runs while you do Steps 2–4, and note
the shell id for Step 5.5:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/codex-review.sh" \
  --target <target> [--ref <ref>] --budget <180 in full | 600 in deep>
```

The script always exits 0 and never prompts. A missing CLI, an expired session, a rate
limit, a timeout and a parse failure all come back as a status line — none of them can
stall this command.

> **Do not read its output yet.** Reading it before your own findings are frozen anchors
> Steps 2–5 on what Codex saw, which destroys the independence that makes the second
> review worth running at all. Harvest it in Step 5.5.

## Step 2 — Mechanical gate (deterministic)

Run these greps over the diff so findings are exact facts, not model impressions. The
`added()` helper isolates **added content lines** by re-marking them with `>` via
`--output-indicator-new` — this leaves the `+++ b/path` file header untouched (so a
filename containing a flagged token can't false-positive) and, unlike a `^\+` /
`grep -v '^+++'` filter, never drops a real content line that happens to start with
`++` (which would otherwise collide with the header prefix). Match the token anywhere on
the line — never fold an anchor and the token into one pattern like `^\+[^+].*TOKEN`,
because `[^+]` eats the first character of a token sitting at column 0 (`+console.log`,
`+#[allow(...)]`) and misses it. The `added()` output is content only — to get the
`file:line` of a hit, re-grep the working tree for it (`git grep -n '<pattern>'`), since
these are exact string matches. Anything matched here is a finding — no judgment call, no
verification needed.

```bash
# Added content lines only: git marks them '>' instead of '+', leaving the
# '+++ b/path' header as-is — no header collision, no lost '++'-prefixed content.
added() { git diff --output-indicator-new='>' -U0 "$@" | grep '^>'; }

# CRITICAL — suppression comments (zero tolerance, see policy below)
added $RANGE | grep -E 'eslint-disable|@ts-ignore|@ts-expect-error|@ts-nocheck|prettier-ignore|as any|as unknown as|#\[allow\(|#!\[allow\(|# noqa|# type: ignore|@SuppressWarnings'

# CRITICAL — CLI bypasses committed in scripts or hooks
added $RANGE | grep -E -- '--no-verify|--skip-checks|--no-gpg-sign'

# HIGH — raw console in production code (frontend must use the project logger).
# Exclude test files by the `.test.`/`.spec.` convention — matched as a substring so
# `latest.ts`/`contest.ts` are NOT excluded (a bare `*test*` would wrongly drop them).
added $RANGE -- '*.ts' '*.tsx' ':!*.test.*' ':!*.spec.*' | grep -E 'console\.(log|warn|error|debug|info)'

# HIGH — TODO/FIXME without an issue link
added $RANGE | grep -E '(^|[^A-Za-z])(TODO|FIXME|XXX|HACK)([^A-Za-z]|$)' | grep -vE '#[0-9]+|issues/'

# HIGH — file over 800 lines (NUL-delimited so paths with spaces survive)
git diff --name-only -z $RANGE | while IFS= read -r -d '' f; do [ -f "$f" ] && wc -l "$f"; done | awk '$1 > 800'

# MEDIUM — Tailwind v4 non-canonical forms (skip on Tailwind v3 / NativeWind projects)
added $RANGE -- '*.tsx' '*.jsx' | grep -E '\[var\(--|aria-\[(invalid|disabled|pressed|expanded|hidden|selected|checked|busy|modal|required|readonly)=(true|false)\]|z-\[[0-9]+\]|-(bottom|top|left|right|m)-0([^.0-9]|$)'

# MEDIUM — Tailwind v3 utilities renamed in v4
added $RANGE -- '*.tsx' '*.jsx' | grep -E 'bg-gradient-to-|outline-none|decoration-(clone|slice)|overflow-ellipsis|flex-(shrink|grow)-|(bg|text|border|divide|placeholder|ring)-opacity-[0-9]'

# MEDIUM — hardcoded hex colors in className (use design tokens)
added $RANGE -- '*.tsx' '*.jsx' | grep -E 'className=.*#[0-9a-fA-F]{3,8}'

# MEDIUM — dynamic Tailwind class strings the JIT cannot see
added $RANGE -- '*.tsx' '*.jsx' | grep -E 'className=\{`[^`]*\$\{'
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

**Your findings are now frozen.** Do not revise them after reading Step 5.5.

## Step 5.5 — Harvest the Codex review

Only now, with your own findings frozen, read the background shell's output.

Its first line is `CODEX_STATUS: <status>`. Branch on it deterministically — never on
the prose that follows:

| Status | Meaning | What to do |
| --- | --- | --- |
| `ok` | the review follows the status line | report it in Step 6 |
| `absent` | Codex CLI not installed | report the status, change nothing else |
| `unauthenticated` | logged out or session expired | idem |
| `unsupported-target` | the scope has no Codex equivalent | idem |
| `timeout` | exceeded the budget | idem |
| `failed` | non-zero exit, or no readable output | idem |

If the shell has not finished, wait up to the remaining budget, then treat it as
`timeout`. Never hold the report for it.

On `absent` or `unauthenticated`, add one line to Review B offering
`/bymax-quality:codex-setup`, which installs and authenticates the CLI. Offer it once,
and only in the report — never interrupt the review to ask, and never install anything
on the user's behalf mid-review.

### The four independence rules

They exist because the dangerous failure here is not Codex being wrong. It is you
quietly making Codex agree with you.

1. **Never read it early.** If you did read it before Step 5 finished, say so in the
   report instead of pretending the reviews were independent.
2. **Never delete one of its findings.** You may *annotate* one you believe is wrong
   — "checked `foo.ts:41`, the guard is three lines up" — and that annotation is itself
   auditable. Silently dropping it is not. Your Step 5 verification applies to *your*
   candidates, not to Codex's.
3. **Never rewrite its severity.** Report Codex's own `P0`–`P3` labels. Show the reader
   the mapping (`P0`→CRITICAL, `P1`→HIGH, `P2`→MEDIUM, `P3`→LOW) but keep the original
   label visible next to it.
4. **Never let it move the verdict.** BLOCK/APPROVE comes from your findings alone.
   Codex-only findings go to the disposition list in Step 6, which is what gives them
   teeth without making the gate depend on a network call.

> **It is a sample, not a measurement.** Three runs over the same commit returned
> overlapping but different findings, and the same issue came back as `P1` in one run and
> `P2` in another. An empty Codex review is not evidence the diff is clean.

## Step 6 — Report and verdict

```
## Code Review Report  (mode: <quick|full|deep> · scope: <range>)

### Review A — Bymax checklist (Claude)

#### CRITICAL (n)
- <file>:<line> — <issue> — <suggested fix>

#### HIGH (n)
- <file>:<line> — <issue> — <suggested fix>

#### MEDIUM (n)
- ...

#### LOW (n)
- ...

Candidates dropped in verification: <n>
Verdict: BLOCK / APPROVE WITH CHANGES / APPROVE

### Review B — Codex (independent)

Status: ok
- [P1 → HIGH] <file>:<lines> — <title>
  <body, verbatim>
  <optional annotation, clearly marked as yours>

### Cross-read

- **Both found:** <issue> — highest confidence, fix first.
- **Only A:** <issue> — the convention and mechanical axes Codex does not cover.
- **Only B — needs your disposition:** <issue>
```

When Codex did not run, Review B is a single line and nothing else changes:

```
### Review B — Codex (independent)

Status: unauthenticated — no second opinion in this report.
Run /bymax-quality:codex-setup to enable it.
```

**Never approve code with security vulnerabilities or new suppression comments.**
Any CRITICAL or HIGH in Review A ⇒ verdict is BLOCK.

**Every Codex-only P0/P1 needs an explicit disposition** — fixed, or refused with a
stated reason — before this review counts as done. This is the same rule the project
already applies to a reviewer's comment on a PR: a finding you choose not to fix needs
a justification on the record, not silence. It is what gives Review B teeth while
keeping the automated verdict independent of whether Codex was reachable.

With `--fix`: after the report, apply the mechanical MEDIUM fixes (Tailwind renames and canonical
tokens are deterministic rewrites) and any other finding the user approves, then re-run Step 2 to
confirm the gate is clean. Never commit — the user commits.
