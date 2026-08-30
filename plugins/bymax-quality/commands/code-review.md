---
description: 'Comprehensive security and quality review with selectable depth: mechanical gate (deterministic greps for secrets/suppressions/Tailwind/console), bug hunt (single-pass or parallel finder agents with adversarial verification), and the Bymax convention checklist across CRITICAL (secrets, SQL injection, XSS, suppression comments like @ts-ignore/eslint-disable or Rust #[allow]/unsafe), HIGH (long functions, missing JSDoc on exports, cross-feature imports, swallowed errors, reinvented wheels per the standards §0 simplicity ladder), MEDIUM (mutation patterns, magic numbers, enum usage, non-English comments, copy-pasted logic, speculative generality), and LOW (nits). Every candidate finding is re-verified against the file before it is reported. In every mode, quick included, two independent Codex reviews run in parallel background shells — a standard one (is this correct?) and an adversarial one (is this the right approach?) — and full and deep additionally run Claude''s own built-in review (high in full, max in deep); the report carries every review side by side with a cross-read. All of it is optional: absent, logged-out or slow Codex degrades to a one-line status and changes nothing, and the adversarial review additionally needs the openai-codex plugin. Blocks the commit on any CRITICAL or HIGH from the Bymax review. Modes: quick | full (default) | deep. Optional target (branch, ref range, PR#, file), --fix, --no-codex and --no-builtin. Run before /bymax-workflow:verify and before any commit. Triggers: "code review", "review changes", "check this code", "is this safe to commit", "revisar código".'
argument-hint: "[quick|full|deep] [target] [--fix] [--no-codex] [--no-builtin]"
---

# Code Review

Comprehensive security and quality review, structured as a pipeline: a deterministic
mechanical gate, a bug hunt at the requested depth, the Bymax convention checklist,
and a verification pass that filters false positives before anything is reported.

In **every** mode, **two independent Codex reviews run in parallel** background shells —
a standard one (is this correct?) and an adversarial one (is this the right approach?) —
and in `full` and `deep` Claude's own built-in review runs alongside them as Review D.
Every review is reported side by side with a cross-read. The Codex pair is kept apart from
this command's own judgment on purpose: both are launched before it forms any opinion, and
neither output is read until its own findings are frozen. When a review is absent, logged
out, rate-limited or slow, the report says so in one line and nothing else changes.

## Usage

```
/bymax-quality:code-review [quick|full|deep] [target] [--fix] [--no-codex] [--no-builtin]
```

| Argument | Meaning |
| --- | --- |
| `quick` | Mechanical gate + CRITICAL/HIGH judgment checks on changed lines only, plus both Codex reviews. Sanity check before a push. |
| `full` *(default)* | Everything: mechanical gate, single-pass bug hunt, full convention checklist, verification, both Codex reviews, and Claude's built-in `/code-review high` as Review D. |
| `deep` | `full`, but the bug hunt additionally fans out to parallel finder sub-agents (stack reviewer + security reviewer) whose candidates are then adversarially verified, and Review D runs at `max` instead of `high`. Use before merging a feature branch. |
| `target` | Optional. A branch name (`feature-x` → reviews `<default-branch>...feature-x`), a ref range (`main...feature-x`), a PR number (`#123`, checked out locally so `$RANGE` works with `git diff` — see Step 1), or a file path. Without a target: uncommitted changes, plus the branch's commits ahead of upstream when the working tree is clean. |
| `--fix` | After the report, apply the confirmed mechanical MEDIUM fixes (Tailwind renames, canonical tokens) and any finding the user approves. Never commits. |
| `--no-codex` | Skip **both** Codex reviews (Steps 1.5). They run in **every** mode otherwise, `quick` included — they cost background wall-clock, not session time, and a second opinion is worth as much before a quick push as before a merge. |
| `--no-builtin` | Skip Review D (Step 1.6). Its cost is tokens, and a three-line diff does not need a multi-agent bug hunt; without this flag there is no way to decline the most expensive reviewer in the set. |

> **Stack-adaptive.** Detect the stack first. On a **Rust** project (`Cargo.toml`), apply the
> **Rust checks** flagged in each section below and **skip** the TypeScript/Tailwind-specific ones
> (`any`/`enum`/`interface vs type`/JSDoc/`../../../` aliases/Tailwind rules). On a **TypeScript**
> project (`package.json`), apply the TS checks as written. The CRITICAL security and suppression
> rules apply to both.

> **Composes with the built-in engine.** Claude Code ships its own multi-agent bug-hunting review
> (`/code-review <effort>`, `/code-review ultra` for the cloud run) — it finds logic bugs but knows
> nothing about Bymax conventions and never blocks. This command is the convention gate that does
> block. `full` and `deep` now invoke the built-in review for you (Step 1.6), so there is nothing
> to run alongside them; only `quick` leaves the bug hunt to you. `ultra` is always the user's to
> launch — it is billed, and a skill must not trigger it.

> **Both Codex reviews are optional; only the standard one is self-contained.** Review B needs
> only the `codex` binary on `PATH` with an active session — run **`/bymax-quality:codex-setup`**
> to install and authenticate it. Review C needs the OpenAI Codex *plugin* on top of that, because
> the adversarial stance lives in that plugin's prompt.
>
> Note what is and is not being invoked there. That plugin's `/codex:review` and
> `/codex:adversarial-review` are marked `disable-model-invocation: true` — user-only by design,
> and a skill must not route around that by pretending to be the user. What Review C drives is the
> plugin's `codex-companion.mjs` runtime directly, by absolute path: a plain Node script with no
> such gate, which locates its own prompts relative to itself. Reusing it is what keeps the
> adversarial prompt tracking upstream instead of drifting in a copy here.
>
> Without either, this command behaves exactly as it did before.

> **Invoking this command is not the same as running its steps.** Some environments gate
> `git push` on a marker that a hook records when *this command* runs — running the greps
> and the checklist by hand records nothing, however faithfully. Measured: a session that
> ran Step 2 manually twice and then pushed was blocked with "No review recorded". In `quick`
> and `full` alike, the marker comes from the invocation, not from the work.

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

## Step 1.5 — Launch the independent Codex reviews (optional, non-blocking)

Runs in every mode, `quick` included. Skipped only when `--no-codex` is passed.

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
| PR target, **after `gh pr checkout` made it HEAD** | `--target base --ref origin/<pr base branch>` — the `origin/` prefix, because the base may exist only as a remote-tracking ref (worktrees, `--single-branch` clones) |
| a single commit | `--target commit --ref <sha>` — Review B only; Review C reports `unsupported-target`, the runtime has no per-commit scope |
| a branch target that is **not** checked out | **skip Codex** (see below) |
| a file path, or a ref range not ending at HEAD | **no equivalent — skip Codex** |

> **Codex always reviews the current checkout.** `codex exec review` takes a base
> (`--base`) but has no head-ref argument, so passing a base while HEAD is some other
> branch makes it review *your checkout* against that base — a different diff from the
> one Review A examined, quite possibly an empty one, presented in the report as a
> second opinion on the requested branch. That is the same false-clean failure the
> empty-base guard exists to prevent. So: only send Codex a base when the head it will
> compare **is** the scope you resolved in Step 1. Never switch branches to make it fit —
> a review command must not mutate the working tree. Skip both Codex reviews and say so
> in Review B and in Review C.

Launch **both** Codex reviews with `run_in_background: true`, in the same message so
they run concurrently, and note each shell id for Step 5.5. They ask different
questions of the same diff, so neither substitutes for the other:

```bash
# Review B — standard: is this change correct?
bash "${CLAUDE_PLUGIN_ROOT}/scripts/codex-review.sh" \
  --target <target> [--ref <ref>] --budget <180 in quick and full | 600 in deep>

# Review C — adversarial: is this the right approach at all?
bash "${CLAUDE_PLUGIN_ROOT}/scripts/codex-review.sh" --mode adversarial \
  --target <target> [--ref <ref>] --budget <180 in quick and full | 600 in deep>
```

The budget is the shell's own deadline, measured from launch; Step 5.5's wait is measured
from the moment the harvest starts, after Steps 2–4. They are not the same clock and do not
need to match. A typical review takes 40–60 s, so a 60 s budget would kill most adversarial
runs at the finish line; 180 s lets them complete, and in `quick` a shell still running at
harvest time is reported as such with its output path — it finishes on its own and is not
killed for being late.

Two background shells, launched together, cost wall-clock once. Running them in
sequence would double the time for no gain — nothing in the second depends on the
first, which is the whole point.

The script always exits 0 and never prompts, in either mode. A missing CLI, an expired
session, a rate limit, a timeout and a parse failure all come back as a status line —
none of them can stall this command.

**Review C needs the openai-codex plugin, Review B does not.** The adversarial stance
lives in that plugin's prompt, and its `/codex:adversarial-review` command is marked
`disable-model-invocation: true` — a deliberate user-only gate that a skill must not
work around by pretending to be the user. What the script drives instead is the plain
Node runtime underneath it, by absolute path. Reusing that runtime keeps the adversarial
prompt tracking upstream rather than drifting in a copy here; the cost is that Review C
reports `adversarial-absent` when the plugin is not installed, which changes nothing
else. `--target commit` has no adversarial equivalent and reports
`unsupported-target`.

> **Do not read either output yet.** Reading them before your own findings are frozen
> anchors Steps 2–5 on what Codex saw, which destroys the independence that makes a
> second review worth running at all. Harvest both in Step 5.5.

## Step 1.6 — Claude's own bug hunt (`full` and `deep`)

Skipped in `quick`, which stays the minimal pre-push check. Launch it in the **same
message** as the two shells above: all three reviewers then work in parallel while you
do Steps 2–4, and all three are harvested together in Step 5.5.

Invoke the built-in review skill over the same scope, at the effort the mode calls for:

| Mode | Invocation |
| --- | --- |
| `full` | `/code-review high` |
| `deep` | `/code-review max` |

The split matches what each mode is for: `high` keeps `full` proportionate to a pre-push
check, and `max` widens coverage — including lower-confidence findings — for the pass that
runs before a merge.

**Map the scope the same way Step 1.5 does, and skip on the same terms.** The built-in
review accepts a PR number, a branch, or a path; it does not accept an arbitrary ref
range, and with no target it reviews *the current diff*:

| Resolved scope | What to pass |
| --- | --- |
| uncommitted work (dirty tree) | no target — the current diff is the scope |
| PR target, after `gh pr checkout` | the PR number |
| branch target that is the current HEAD, or a clean tree ahead of upstream | **the branch name** — never "no target": on a clean tree the built-in's default scope is empty |
| a single file | that path |
| branch target that is **not** checked out | **skip Review D** |
| a ref range not ending at HEAD, or `<base>...FETCH_HEAD` | **skip Review D** |

The third row is the one that bites. On a clean tree, invoked without a target, the
built-in would review an empty diff, return no findings, and Step 6 would print it beside
A, B and C as a peer bug hunt of the same diff — the same false-clean shape the empty-base
guard and the Step 1.5 checkout guard exist to prevent. Passing the branch name gives it
the committed range.

**The built-in is the skill named exactly `code-review`, unprefixed.** This command is
`bymax-quality:code-review`; if no unprefixed `code-review` skill is listed in the session,
skip Review D with `Status: no built-in review` — never invoke a prefixed name, which would
be this command calling itself.

It forks to a background agent and returns only the agent's name; the findings arrive
later as a task notification, so do not wait on it here, and never invent its results.
Nothing in this plugin controls that behaviour. **If the skill instead returns its findings
inline, set them aside unread until Step 5.5 and say so in the report** — reading them
before Review A is frozen breaks independence rule 1.

Unlike Steps 1.5, this one is **not** a second opinion — it is the same model family as
Review A, running a different method: a multi-agent bug hunt with its own finder and
verifier passes. Say that plainly in the report rather than presenting it as a third
independent voice, because two agreeing runs of the same model is weak evidence and a
reader who mistakes it for corroboration will over-trust it.

It costs no session time — it runs as a forked background agent, like the Codex shells —
so `full` carrying it does not make `full` slower to sit through. What it does cost is
tokens, which is the honest reason `quick` leaves it out rather than any claim about
speed.

> **`/code-review ultra` is a different matter.** It is user-triggered and billed, and a
> skill must not launch it. If the diff warrants that depth, say so and let the user
> decide.

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

## Step 5.5 — Harvest the Codex reviews

Only now, with your own findings frozen, read the background shells' output — and, in
`full` and `deep`, Review D's agent report.

### Reviews B and C — the shells

Each shell's first line is `CODEX_STATUS: <status>`. Branch on it deterministically —
never on the prose that follows. **The line after it, when there is one, is reproduced
verbatim under the status in Step 6**, whatever the status: it is the script's one
sentence of detail — the remedy after a failed cancel, the version that was refused, the
budget that was clamped, the reason a scope is unpinned — and it is written for the
reader, not for you to summarise.

| Status | Meaning | What to do |
| --- | --- | --- |
| `ok` | the review follows the status line, over exactly the requested scope | report it in Step 6 |
| `ok-unpinned` | the review follows, but not over exactly the requested scope (see below) | report its findings in Step 6; **never count its silence** |
| `bad-invocation` | the command line you launched was wrong — a flag without its value, an unknown flag or `--mode` | fix the launch and re-run that shell; do not report it as a scope limitation |
| `absent` | Codex CLI not installed | report the status, change nothing else |
| `unauthenticated` | logged out or session expired | idem |
| `unsupported-target` | the scope has no Codex equivalent | idem |
| `timeout` | exceeded the budget | report the status **and the line after it verbatim** — when the cancel failed it names the one command that still reaches a billing run |
| `failed` | non-zero exit, no readable output, or — in adversarial mode — a parse-failure page or a review with no `Target:`/`Verdict:` lines; a standard review is accepted as whatever `codex exec review` returned | report the status and the line after it verbatim |
| `adversarial-absent` | Review C only: the openai-codex plugin (or node) is missing, **or the installed version is not one the script has verified** — the second line says which | report the status and its line |

`ok-unpinned` is followed by a `CODEX_SCOPE:` line naming the cause. For Review C it
usually means the change was too large for the runtime to inline in the prompt (more
than two files or 256 KiB — which is most real reviews), so the reviewer collected its
own scope with git commands, minutes after launch, against a tree that may have moved;
on a branch target it can also mean uncommitted work was outside the reviewed range.
Review B reports it on a branch target when the tree is dirty: `codex exec review --base`
diffs the merge-base against the working tree, so tracked edits are reviewed beyond the
committed range and untracked files are not reviewed at all. (`--uncommitted` reviews
staged, unstaged and untracked changes — exactly Step 1's scope — so Review B on a dirty
tree is always pinned.) An unverified runtime version also makes Review C unpinned: its
inline limits are unknown, so whether the diff was inlined cannot be predicted. **Print the status and reproduce
the scope line verbatim in Review C's section.** Its findings are still about this
change and still get a disposition; what changes is the cross-read: an `ok-unpinned`
Review C that found nothing is not evidence the diff is clean, and must not be written
up as "B and C silent". It examined roughly this change, not demonstrably exactly it.

The two shells are read independently. One of them degrading says nothing about the
other: Review B needs only the `codex` binary, Review C needs the plugin on top of it,
so `adversarial-absent` next to a healthy `ok` is the expected shape on a machine
without the plugin — not a symptom.

If a shell has not finished: in `full` and `deep`, wait until the **later** of the two
budgets has elapsed **plus 20 s** — the script's own `timeout` line lands up to ~19 s after
the budget, because stopping the run (a bounded cancel, then TERM and KILL) happens after
the deadline, not before it — once, for both shells together, never one after the other.
Then treat whatever is still running as `timeout`. In `quick`, wait at most 60 s: it is the
pre-push sanity check and must not stall on a background reviewer. Report an unfinished
shell as `Status: still running — output at <path>` — never as absent, and never as clean
— **and when its task notification arrives later in the session, read the file and append
a "Late arrivals" section to the report** with the same disposition rule as Step 6. A
billed review whose findings nobody reads is worse than no review.

### Review D — the agent

Review D has no `CODEX_STATUS` line: it is a forked agent, not a shell, and the table
above does not apply to it. Its states are:

| State | What to do |
| --- | --- |
| returned a report | report it in Step 6 as Review D |
| skipped (`quick`, `--no-builtin`, or an unmappable scope per Step 1.6) | omit the heading entirely; name the reason in one line only if the user asked for it |
| still running when the rest of the report is ready | print `Status: still running` and say the findings are not in this report |
| returned nothing usable | print `Status: no report` |

**Never predict what a pending agent would have said.** A Review D that has not returned
is reported as pending, not as clean and not as absent — the whole point of the status
line is that a reader can tell "found nothing" from "has not answered".

On `absent` or `unauthenticated`, add one line to the affected review offering
`/bymax-quality:codex-setup`, which installs and authenticates the CLI. On
`adversarial-absent`, read the second line: a missing plugin is fixed by installing the
openai-codex plugin, an unverified version by `BYMAX_CODEX_COMPANION_ALLOW_UNVERIFIED=1`
(the user's call — the script's contract with that runtime is unverified there), and a
project-local install by `BYMAX_CODEX_COMPANION=<path>`. `codex-setup` installs the CLI
and fixes none of those. Offer either once, and only in the report — never
interrupt the review to ask, and never install anything on the user's behalf mid-review.

### The four independence rules

They exist because the dangerous failure here is not Codex being wrong. It is you
quietly making Codex agree with you. They apply to Review B and Review C alike, and to
Review D — where the pull is stronger, not weaker, because that reviewer shares your
model and its findings will feel familiar and therefore right.

1. **Never read it early.** If you did read it before Step 5 finished, say so in the
   report instead of pretending the reviews were independent.
2. **Never delete one of its findings.** You may *annotate* one you believe is wrong
   — "checked `foo.ts:41`, the guard is three lines up" — and that annotation is itself
   auditable. Silently dropping it is not. Your Step 5 verification applies to *your*
   candidates, not to Codex's.
3. **Never rewrite its severity.** Report whichever label the review actually used, and
   keep it visible next to your mapping. The two backends do not share a vocabulary:
   Review B emits `P0`–`P3` (`P0`→CRITICAL, `P1`→HIGH, `P2`→MEDIUM, `P3`→LOW), while
   Review C's runtime emits `critical`/`high`/`medium`/`low` and defaults a missing
   severity to `low`. Never invent a `P`-label for a Review C finding to make it match
   the template — that is a rewrite wearing the costume of a format fix.
4. **Never let it move the verdict.** BLOCK/APPROVE comes from your findings alone.
   Codex-only findings go to the disposition list in Step 6, which is what gives them
   teeth without making the gate depend on a network call.

> **It is a sample, not a measurement.** Three runs over the same commit returned
> overlapping but different findings, and the same issue came back as `P1` in one run and
> `P2` in another. An empty Codex review is not evidence the diff is clean.

> **Agreement between A and D is not corroboration.** They are the same model family
> reading the same diff by different methods, so they fail in correlated ways. Two of
> them missing something is roughly one model missing it. Only B and C are outside
> voices — and Review C is outside on a second axis, since it argues about the approach
> rather than about the code.

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

### Review B — Codex, standard (independent)

Status: ok
- [P1 → HIGH] <file>:<lines> — <title>
  <body, verbatim>
  <optional annotation, clearly marked as yours>

### Review C — Codex, adversarial (independent)

Status: ok
- [high → HIGH] <the approach or assumption being challenged>
  <body, verbatim>

### Review D — Claude, /code-review <high in full | max in deep>

Status: <returned | still running | no report>   (a skipped Review D has no section at all)
Same model family as Review A, different method — not an independent voice.
- <file>:<line> — <finding>

### Cross-read

- **A and an outside review agree (A + B, or A + C):** <issue> — highest confidence: a
  convention reviewer and an independent model converged. Fix first.
- **Both outside reviews found it (B + C):** <issue> — two independent models converged on
  a defect A missed. Fix first.
- **A and D agree, B and C silent:** <issue> — one model's opinion twice; state that.
  (An `ok-unpinned` Review C does not count as silent — it may simply not have looked.)
- **Only A:** <issue> — the convention and mechanical axes no bug hunter covers.
- **Only C:** <issue> — a design objection, not a defect. Answer it on the merits.
- **Only D:** <issue> — the deepest bug hunt in the set found it alone. Same model
  family as A, so it is not corroboration, but a unique finding from the most expensive
  reviewer is the last one to drop for being unconfirmed.
- **Only B, C or D — needs your disposition:** <issue>
```

Each review that did not run collapses to a single line, and nothing else changes:

```
### Review B — Codex, standard (independent)

Status: unauthenticated — no second opinion in this report.
Run /bymax-quality:codex-setup to enable it.

### Review C — Codex, adversarial (independent)

Status: adversarial-absent — the openai-codex plugin is not installed.
```

Omit Review D's heading entirely in `quick`, rather than printing it as skipped — a
reader scanning a `quick` report should not have to work out that an empty section is
expected.

**Never approve code with security vulnerabilities or new suppression comments.**
Any CRITICAL or HIGH in Review A ⇒ verdict is BLOCK.

**Every outside-only finding at the top two severities needs an explicit disposition** —
Codex `P0`/`P1`, Review C `critical`/`high`, and any Review D finding no other review
raised — fixed, or refused with a stated reason — before this review counts as done. This is the same rule the project
already applies to a reviewer's comment on a PR: a finding you choose not to fix needs
a justification on the record, not silence. It is what gives Reviews B and C teeth while
keeping the automated verdict independent of whether Codex was reachable.

A Review C objection is dispositionable in the same way, and it is the one most easily
waved away, because "the approach is wrong" has no line number to check it against.
Answer it with the reasoning or the constraint that makes the current approach right —
or accept it. "Out of scope" disposes of a defect, never of a design objection.

With `--fix`: after the report, apply the mechanical MEDIUM fixes (Tailwind renames and canonical
tokens are deterministic rewrites) and any other finding the user approves, then re-run Step 2 to
confirm the gate is clean. Never commit — the user commits.
