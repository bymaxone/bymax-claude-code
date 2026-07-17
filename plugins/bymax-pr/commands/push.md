---
description: 'One-shot "ship my work" command: create or reuse a feature branch (a commit NEVER lands on the default branch), stage the working tree if nothing is staged (respect an existing staged set), commit with a complete Conventional-Commits message (title ≤ 72 chars + body bullets), and push to origin with upstream set. Pass `pr` to also open a GitHub PR with a full description of what changed and why (gh CLI); without it no PR is created. Optional branch name argument. Never force-pushes, never bypasses hooks, no AI-attribution trailers. Triggers: "push", "ship this", "commit and push", "sobe isso", "manda pra branch".'
argument-hint: "[branch-name] [pr]"
---

# /bymax-pr:push — branch → stage → commit → push [→ PR]

Ship the current work end-to-end. The invariant is **a commit must NEVER land on
the default branch** — always isolate it on a branch first, then push.

## Arguments

`$ARGUMENTS` is zero, one, or two tokens, in any order:

- `pr` (case-insensitive) → after pushing, **open a GitHub PR** against the default
  branch with a complete description. Without this token, NO PR is created — the
  command stops at the push and prints the compare URL.
- any other token → the explicit branch name to use instead of a generated one.

```
/bymax-pr:push                    # branch + commit + push, no PR
/bymax-pr:push pr                 # branch + commit + push + open the PR
/bymax-pr:push fix/auth-redirect  # explicit branch, no PR
/bymax-pr:push fix/auth-redirect pr
```

## Step 0 — Inspect (read-only, do this first)

```bash
git rev-parse --is-inside-work-tree                 # must be a git repo
git rev-parse --abbrev-ref HEAD                      # current branch
git remote -v                                        # is there a remote to push to?
git status --porcelain                               # staged / unstaged / untracked
git diff --cached --stat ; git diff --stat           # what changed
```

Determine:

- **Default branch**: `git symbolic-ref --quiet refs/remotes/origin/HEAD | sed 's@^refs/remotes/origin/@@'`
  (fallback: `main`, then `master`).
- **Is anything staged?** `git diff --cached --quiet` → exit 1 means yes.
- **Anything to ship at all?** There must be either something to commit (staged OR
  unstaged OR untracked) **or** commits already ahead of upstream
  (`git log @{upstream}..HEAD --oneline` non-empty). If there is nothing to commit
  **and** nothing ahead → stop (see below).
- **Skip Steps 2–3 only when the working tree is clean AND there are commits ahead** —
  i.e. the sole thing to ship is already-committed work that never left the machine, so
  go straight to push (and PR if requested). Whenever there is *any* uncommitted change
  (staged, unstaged, or untracked), you MUST run Steps 2–3 to stage and commit it, even
  if the branch also has earlier commits ahead of upstream.

Stop early and report (do NOT proceed) if:

- Not a git repo.
- Nothing to commit AND nothing ahead of upstream → "nothing to push".
- No `origin` remote → you can still branch + commit, but tell the user the push
  (and PR) will be skipped, and how to add a remote.
- `pr` was requested → preflight `gh auth status`; if the `gh` CLI is missing or
  unauthenticated, say so with the exact install/`gh auth login` instructions and
  offer to continue without the PR.

## Step 1 — Branch (MANDATORY)

**Never commit on the default branch.** Decide the working branch:

- **On the default branch or detached HEAD** → you MUST create a new branch. Use the
  branch-name argument if given, else generate `<type>/<short-kebab-slug>` from the
  diff — `<type>` is the dominant Conventional-Commit type (feat/fix/chore/docs/
  refactor/test/build/ci), slug is a 2–4 word summary ≤ ~40 chars
  (e.g. `feat/landing-tokens`, `fix/auth-redirect`):
  ```bash
  git switch -c <branch>
  ```
- **Already on a non-default branch** → the work is already isolated; commit there.
  Do NOT create a redundant nested branch unless the argument explicitly names one.
- **ALWAYS `git switch -c <branch>`, never `git checkout -b`** (toolkit convention —
  `switch -c` is unambiguous and carries the working tree onto the new branch).

State the branch you're using and why (created vs. reused) in one line.

## Step 2 — Stage

- **Nothing staged** (`git diff --cached --quiet` exits 0) → stage everything: `git add -A`.
- **Something already staged** → respect it: commit ONLY the staged set (no extra
  `git add`). Tell the user which files are going in.

Show `git diff --cached --name-status` so the commit's contents are explicit.

## Step 3 — Commit (Conventional Commits, complete message)

Author the message from the staged diff — read the diff and describe what actually
changed; never a generic "update files".

- **Title**: `<type>(<scope>): <imperative subject>` — **HARD LIMIT 72 chars**
  (aim ≤ 50), lowercase subject, no trailing period. GitHub and `git log --oneline`
  truncate longer titles to `…`. Don't cram enumerations into the title — summarize
  there, enumerate in the body.
- **Body — always present for non-trivial changes**: 2–6 bullet lines covering
  *what* changed per area and *why* (motivation, root cause for fixes, behavior
  before → after). The body is the complete record; the title is the index entry.
- **Timeless**: no `Phase N` / task-ID / sprint references (see
  `/bymax-workflow:standards` — plan-stage names are meaningless after the plan).
- **No attribution footer** — no `Co-Authored-By` trailer, no "generated with" line.
  The message is exactly title + body, nothing else.

Validate the title length BEFORE committing, then commit from a temp file
(robust against quoting):

```bash
msg=$(mktemp); # write the full message to "$msg"
title=$(head -n1 "$msg"); n=${#title}
[ "$n" -le 72 ] && echo "OK ($n chars)" || echo "TOO LONG ($n) — shorten, move detail to body"
git commit -F "$msg"
```

If it reports TOO LONG, rewrite and re-check until it passes. Project hooks
(husky/commitlint/lint-staged) run normally; if one fails, **fix the root cause**
and re-commit. **NEVER** `--no-verify`, `--no-gpg-sign`, or any bypass. If your
harness prompts for approval on `git commit`/`git push`, that is expected — let it.

## Step 4 — Push

```bash
git push -u origin <branch>
```

**Never force-push** (`--force` / `--force-with-lease`) from this command, and never
push to the default branch. After success, note the short SHA (`git rev-parse --short HEAD`).

## Step 5 — PR (only when `pr` was passed)

If a PR already exists for this branch (`gh pr view --json url` succeeds), report its
URL and update nothing — the push already refreshed it.

Otherwise author the PR from **everything the PR will contain** — the full range
`git log <default>..HEAD` and `git diff <default>...HEAD --stat`, not just the last
commit — and create it:

```bash
gh pr create --base <default-branch> --title "<title>" --body-file "$body"
```

- **Title**: Conventional-Commits style, ≤ 72 chars. For a single-commit PR, reuse
  the commit title; for multi-commit, summarize the branch's purpose.
- **Body — complete, in this shape**:

  ```markdown
  ## Summary
  <2–4 sentences: what this PR does and why it exists — the problem/motivation first.>

  ## Changes
  - <area/file group> — <what changed and why>
  - <area/file group> — <what changed and why>

  ## How to verify
  - <commands to run, pages to open, or behaviors to check>

  ## Notes
  <breaking changes, follow-ups, review focus — omit the section if empty>
  ```

- Same rules as the commit: timeless (no phase/task refs), **no attribution footer**
  of any kind.

## Step 6 — Report

One concise summary: branch (created/reused), files committed, commit title + SHA,
push result, and the PR URL (or the compare URL when no PR was requested). If a step
was skipped (no remote, existing PR), say so and how to finish manually.

Suggest the natural next step when relevant: `/bymax-pr:babysit-pr <PR#>` to shepherd
the new PR to green, or `/bymax-quality:code-review` first if the work never went
through a review gate.

## Hard rules (always)

- **Never commit on the default branch** — branch first, every time.
- **`git switch -c`**, never `git checkout -b`.
- **Conventional Commits** with a real body; timeless; title ≤ 72 chars validated
  before committing.
- **PROHIBITED: any AI-attribution trailer** (`Co-Authored-By`, "generated with", …)
  in commits AND PR bodies.
- **Never** `--force`, `--no-verify`, or any hook/approval bypass. One git mutation
  per step; verify each before moving on. If a step fails, stop and report — never
  improvise a bypass.
- **No `pr` token → no PR.** The flag is explicit opt-in; never open one unasked.
- GitHub operations via the **`gh` CLI** only.
