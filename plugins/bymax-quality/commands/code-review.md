---
description: 'Comprehensive security and quality review of uncommitted changes. Walks every changed file and flags issues across CRITICAL (secrets, SQL injection, XSS, suppression comments like @ts-ignore/eslint-disable), HIGH (long functions, missing JSDoc on exports, cross-feature imports, swallowed errors), MEDIUM (mutation patterns, magic numbers, enum usage, non-English comments), and LOW (nits). Blocks the commit on any CRITICAL or HIGH. Run before /bymax-workflow:verify and before any commit. Triggers: "code review", "review changes", "check this code", "is this safe to commit", "revisar código".'
---

# Code Review

Comprehensive security and quality review of uncommitted changes.

## Steps

1. Get changed files: `git diff --name-only HEAD`
2. For each changed file, check every category below.
3. Generate a report with severity, file:line, description, and suggested fix.
4. **Block commit if any CRITICAL or HIGH issue is found.**

---

## CRITICAL — Block on sight

### Security

- Hardcoded credentials, API keys, tokens, secrets in source or fixtures.
- SQL injection vulnerabilities.
- XSS vulnerabilities (unsafe `dangerouslySetInnerHTML`, unescaped user input in templates, raw HTML rendering).
- Missing input validation on a public boundary (HTTP handler, IPC, file parser).
- Insecure dependencies (known CVEs, abandoned packages).
- Path traversal risks (user-controlled input feeding `fs` or `path.join`).
- Logging or analytics that include PII, credentials, medical data, or other sensitive fields.

### Suppression comments — ZERO tolerance

Any of the following introduced or kept in the diff is a CRITICAL block:

- `// eslint-disable`, `// eslint-disable-line`, `// eslint-disable-next-line`, `/* eslint-disable */` blocks
- `// @ts-ignore`, `// @ts-expect-error`, `// @ts-nocheck`
- `as any`, `as unknown as <T>` (when used to launder a real type error away)
- `// prettier-ignore` (unless preserving a deliberately-formatted table)
- `@SuppressWarnings`, `# noqa`, `# type: ignore`, `# pylint: disable=...` (for cross-language repos)
- CLI bypasses in commit messages or scripts: `--no-verify`, `--no-gpg-sign`, `--force` on a checked branch, `--skip-checks`, `husky` disabled

**The rule:** fix the underlying cause. A failing lint or type error means the code is wrong, the type is wrong, or the rule is wrong — choose one and fix it. Never silence the messenger.

**The only acceptable exception:** a suppression that:
1. References a specific issue or PR (`// eslint-disable-next-line no-unused-vars -- see #1234, follow-up tracked`),
2. AND has a clear, time-bounded reason in the comment.

Even then, flag it as HIGH (not silently allowed) so the reviewer chooses to accept it explicitly.

If the user is genuinely fighting a wrong rule, the right fix is to change the rule config (with justification) — not to scatter `disable` comments through the code.

---

## HIGH — Must fix before merge

### Code quality
- Functions > 50 lines.
- Files > 800 lines.
- Nesting depth > 4 levels.
- `console.log`, `console.warn`, `console.error` in production code (use the project's logger).
- TODO / FIXME / XXX / HACK without an issue link.
- An existing `eslint-disable` / `@ts-ignore` / `as any` retained without an issue-link justification (see Suppression Comments above).

### Documentation (mandatory per `/bymax-workflow:standards`)
- **Non-trivial source file missing the file-header JSDoc** (Purpose + Layer + optional Constraints). Trivial barrel `index.ts` files are exempt — a one-line `// Public API of …` comment is enough.
- **Exported function / hook / component / service / store missing JSDoc** with imperative summary, `@param`, `@returns`, and `@throws` where applicable.
- **Test `it` / `test` block without a comment** explaining the scenario and the rule it protects.

### Architecture (mandatory per `/bymax-workflow:standards`)
- **Cross-feature import** — `features/X/` importing from `features/Y/`. Must orchestrate one level up via `app/` or `shared/`.
- **Domain import inside `shared/ui/`** — UI primitives must be portable; zero domain imports.
- **Internal export leaked through a feature barrel** — `index.ts` should expose only the public API.

### Error handling (mandatory per `/bymax-workflow:standards`)
- **Error swallowed silently** — empty `catch`, `catch` that only logs without re-throwing or surfacing, or rejected promises ignored.
- **Missing input validation at a system boundary** (network response, file parse, IPC, user input). Must run through Zod or equivalent.

### TypeScript discipline (mandatory per `/bymax-workflow:standards`)
- **`any` introduced** — use `unknown` + guard, a generic, or the upstream type.
- **Non-null assertion (`!`) without an explanatory comment** describing the invariant that proves it safe.

---

## MEDIUM — Should fix

- Mutation patterns where immutable would do.
- Emoji in code or comments.
- Missing tests for new code.
- Accessibility issues (a11y) — missing labels, keyboard traps, color contrast.
- Magic numbers without a named constant.
- **`enum` declared instead of a string-literal union type** (per `/bymax-workflow:standards` §1).
- **Comment not in English** — code, JSDoc, and inline notes must all be English. User-facing strings live in i18n bundles.
- **`interface` used for a union/utility type, or `type` used for an entity-like shape** — see `/bymax-workflow:standards` §1 for the convention.
- **Boolean variable not prefixed with `is` / `has` / `should` / `can`** (per `/bymax-workflow:standards` §2).
- **Relative `../../../` import where a path alias exists** (`@/`, `@app/`, `@tests/`).
- **Tailwind v4 — CSS variable in long form** `[var(--x)]`. Suggest the canonical shorthand `(--x)` (e.g., `border-[var(--glass-border)]` → `border-(--glass-border)`). See `/bymax-workflow:standards` § 12. **Skip this check on Tailwind v3 / NativeWind 4 projects** (the long form is the only valid form there).
- **Tailwind v4 — ARIA boolean variant in long form** `aria-[<name>=true]:` where `<name>` is one of `invalid / disabled / pressed / expanded / hidden / selected / checked / busy / modal / required / readonly`. Suggest the canonical short variant (e.g., `aria-[invalid=true]:border-destructive` → `aria-invalid:border-destructive`). See `/bymax-workflow:standards` § 12.
- **Tailwind v4 — arbitrary `rem` value that matches the default spacing/type scale** (e.g., `min-w-[8rem]`, `p-[1rem]`, `gap-[2rem]`, `text-[1rem]`, `h-[12rem]`). Suggest the canonical token (`min-w-32`, `p-4`, `gap-8`, `text-base`, `h-48`). Quick math: `token = rem × 4` for spacing/sizing. See `/bymax-workflow:standards` § 12 "Canonical numeric tokens". Only flag when the value cleanly maps to the default scale; **off-scale values stay arbitrary** (e.g., `w-[7.3rem]` is valid).
- **Tailwind v4 — arbitrary `px` on the filter scale** (`backdrop-blur-[Npx]` or `blur-[Npx]`). Suggest the named token: `[4px]` = `xs`, `[8px]` = `sm`, `[12px]` = `md`, `[16px]` = `lg`, `[24px]` = `xl`, `[40px]` = `2xl`, `[64px]` = `3xl`. E.g., `backdrop-blur-[12px]` → `backdrop-blur-md`, `backdrop-blur-[16px]` → `backdrop-blur-lg`. See `/bymax-workflow:standards` § 12.
- **Tailwind v4 — arbitrary z-index integer** `z-[N]`. v4 supports bare integers for z-index without brackets: `z-[200]` → `z-200`, `z-[9999]` → `z-9999`. See `/bymax-workflow:standards` § 12.
- **Negative zero** — `-{utility}-0` equals `{utility}-0`. Flag and replace with the positive form: `-bottom-0` → `bottom-0`, `-top-0` → `top-0`, `-left-0` → `left-0`, `-right-0` → `right-0`, `-m-0` → `m-0`.
- **Tailwind v4 — renamed utility from v3** still in use:
  - **Scale shifts**: `shadow` → `shadow-sm`, `shadow-sm` → `shadow-xs`; `drop-shadow` → `drop-shadow-sm`, `drop-shadow-sm` → `drop-shadow-xs`; `blur` → `blur-sm`, `blur-sm` → `blur-xs`; `backdrop-blur` → `backdrop-blur-sm`, `backdrop-blur-sm` → `backdrop-blur-xs`; `rounded` → `rounded-sm`, `rounded-sm` → `rounded-xs`.
  - **Gradients**: `bg-gradient-to-{r,l,t,b,tr,tl,br,bl}` → `bg-linear-to-{...}` (v4 added radial / conic, so "linear" disambiguates).
  - **Ring default**: `ring` (was 3px) → `ring-3`; `ring-1` is now the default `ring`.
  - **Renames**: `outline-none` → `outline-hidden`; `decoration-clone` → `box-decoration-clone`; `decoration-slice` → `box-decoration-slice`; `overflow-ellipsis` → `text-ellipsis`; `flex-shrink-*` → `shrink-*`; `flex-grow-*` → `grow-*`.
  - **Opacity modifiers**: `bg-opacity-50`, `text-opacity-*`, `border-opacity-*`, `divide-opacity-*`, `placeholder-opacity-*`, `ring-opacity-*` → use `<color>/<n>` (e.g., `bg-blue-500/50`).
  - See `/bymax-workflow:standards` § 12 "Renamed utilities (v3 → v4)" for the full table.
- **Hardcoded hex value in JSX `className`** outside `tailwind.config.js`. Always use a token (`bg-primary`, `text-ink-base`).
- **Dynamic Tailwind class string** the JIT can't see (e.g., `` `text-${size}` ``). Use full literals + `cn()` / `clsx()`.

---

## LOW — Nit

- Inconsistent naming with surrounding code.
- Unnecessary re-exports.
- Verbose comments that restate the code.

---

## Report format

```
## Code Review Report

### CRITICAL (n)
- <file>:<line> — <issue> — <suggested fix>

### HIGH (n)
- <file>:<line> — <issue> — <suggested fix>

### MEDIUM (n)
- ...

### LOW (n)
- ...

Verdict: BLOCK / APPROVE WITH CHANGES / APPROVE
```

**Never approve code with security vulnerabilities or new suppression comments.**
