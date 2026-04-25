# CLAUDE.md — {{PROJECT_NAME}}

Quick rules for Claude Code and any AI coding agent. Read before every task.

Full spec in [AGENTS.md](AGENTS.md). Domain-specific rules in [docs/guidelines/](docs/guidelines/) — load **on demand**, never all at once.

---

## Stack (headline)

> Replace with the project's actual stack. The agent reads this first; keep it accurate.

- **Runtime**: {{e.g., Node 24+ / Expo SDK 55 / Bun 1.x}}
- **Framework**: {{e.g., Next.js 16 / NestJS 11 / React Native 0.85}}
- **Language**: TypeScript {{VERSION}} strict
- **Styling**: {{Tailwind / NativeWind / CSS Modules / Chakra}}
- **State / forms**: {{Zustand / Redux Toolkit}} + React Hook Form 7 + Zod 4
- **Persistence**: {{e.g., Postgres + Prisma / SQLite + Drizzle / DynamoDB}}
- **Tests**: {{Jest 29 + RNTL 13 / Vitest 1 + RTL}}
- **Lint / format**: ESLint 9 flat config + Prettier 3
- **Tooling**: Husky 9, commitlint, lint-staged, {{pnpm 9+ / bun}}

Full inventory: [docs/knowledge-base/{{NN}}-stack.md](docs/knowledge-base/{{NN}}-stack.md).

---

## Non-negotiables

### {{1. Project-specific critical rule}}

> Replace with your project's most important rule. Examples:
> - "Local-first health data — never leaves the device except via user-initiated share"
> - "Multi-tenant scoping — every query filters by `tenantId`"
> - "PCI compliance — payment fields never logged"

See [docs/guidelines/{{relevant-guideline}}.md](docs/guidelines/{{relevant-guideline}}.md).

### TypeScript strict, zero `any`

`strict: true` and `noUncheckedIndexedAccess: true`. Never `// @ts-ignore`, `// @ts-expect-error`, `as any`, or `// eslint-disable`. Fix the root cause. See [docs/guidelines/typescript-guidelines.md](docs/guidelines/typescript-guidelines.md).

### English comments only

Code, JSDoc, and inline comments in English — no exceptions. User-facing strings live in i18n bundles ({{primary locale}} primary). See [docs/guidelines/i18n-guidelines.md](docs/guidelines/i18n-guidelines.md).

### Documentation is mandatory

Every non-trivial file starts with a JSDoc header describing its purpose and layer. Every exported function, hook, component, service, query, and store has a JSDoc block (`@param`, `@returns`, `@throws`). Inline comments explain the **why** when the code is non-obvious. Every test `it` carries a block comment describing the scenario and the rule it protects.

### Feature-based, layered

```
app/            {{Routes / entry points — thin, composition only}}
src/features/*  Feature code: components, hooks, services, queries
src/shared/*    Portable: ui, db, i18n, theme, observability, utils
```

UI → components → hooks → services → queries → storage. Top never imports bottom. Cross-feature imports banned (go through `shared/`).

### Design system

> Replace with your project's design conventions. Examples:
> - Dark-first, lime primary palette, Instrument Serif + DM Sans, large radii
> - Branded blue (#0066FF), system fonts, 8px-grid spacing
>
> Never introduce hex values outside `tailwind.config.js`.

See [docs/guidelines/design-system-guidelines.md](docs/guidelines/design-system-guidelines.md).

### `shared/ui/` is portable

Zero domain imports. Designed to extract as `@{{org}}/ui` later. Primitives accept `className` for overrides; feature code never styles primitives by forking them.

### Suppression comments — banned

No `// eslint-disable*`, `// @ts-ignore`, `// @ts-expect-error`, `as any`, `as unknown as <T>` (when used to launder a real type error). Fix the root cause. See [docs/guidelines/lint-format-guidelines.md](docs/guidelines/lint-format-guidelines.md).

### Banned dependencies

> Replace with your project's banned-dep list.

- `crypto` → use `node:crypto` (prefixed)
- `bcrypt` → use `argon2`
- `crypto-js` → use `node:crypto` / WebCrypto
- `md5` → use SHA-256 via `node:crypto`
- `uuid` / `nanoid` → use `crypto.randomUUID()`
- `moment` → use `date-fns`
- `lodash` (default entry) → native ES methods
- {{Other project-specific bans}}

---

## Before ANY task — in this order

1. Skim this file.
2. Open [AGENTS.md](AGENTS.md) → "Critical Rules" + "Common Pitfalls".
3. Read **only the guidelines** needed for the task (see table below).
4. Read the relevant `docs/knowledge-base/` chapter if the task touches domain logic.
5. Before coding, list:
   - Files to be created/modified
   - Guidelines consulted
   - Risks and edge cases

Never open every guideline — load on demand.

---

## On-demand guidelines map

> Replace the rows below with this project's actual guideline files.

| Task                                       | Guideline                                                                      |
| ------------------------------------------ | ------------------------------------------------------------------------------ |
| Routing, navigation, deep linking          | [{{routing}}-guidelines.md](docs/guidelines/{{routing}}-guidelines.md)         |
| Components, hooks, lists                   | [react-guidelines.md](docs/guidelines/react-guidelines.md)                     |
| Types, interfaces, generics                | [typescript-guidelines.md](docs/guidelines/typescript-guidelines.md)           |
| Styling, dark mode, tokens                 | [{{styling}}-guidelines.md](docs/guidelines/{{styling}}-guidelines.md)         |
| Animation, gestures                        | [animation-guidelines.md](docs/guidelines/animation-guidelines.md)             |
| Charts / visualizations                    | [charts-guidelines.md](docs/guidelines/charts-guidelines.md)                   |
| Any screen / component creation            | [design-system-guidelines.md](docs/guidelines/design-system-guidelines.md)     |
| Database schema, queries, migrations       | [{{orm}}-guidelines.md](docs/guidelines/{{orm}}-guidelines.md)                 |
| Settings, flags, local storage             | [storage-guidelines.md](docs/guidelines/storage-guidelines.md)                 |
| Global state                               | [state-guidelines.md](docs/guidelines/state-guidelines.md)                     |
| Forms, validation                          | [forms-guidelines.md](docs/guidelines/forms-guidelines.md)                     |
| Any user-facing string                     | [i18n-guidelines.md](docs/guidelines/i18n-guidelines.md)                       |
| Reminders, notifications                   | [notifications-guidelines.md](docs/guidelines/notifications-guidelines.md)    |
| Analytics event, error capture             | [observability-guidelines.md](docs/guidelines/observability-guidelines.md)     |
| Subscriptions, paywalls                    | [billing-guidelines.md](docs/guidelines/billing-guidelines.md)                 |
| Export (PDF / CSV / share)                 | [export-guidelines.md](docs/guidelines/export-guidelines.md)                   |
| Data, secrets, PII, opt-outs               | [security-privacy-guidelines.md](docs/guidelines/security-privacy-guidelines.md) |
| Tests, mocks, coverage                     | [testing-guidelines.md](docs/guidelines/testing-guidelines.md)                 |
| Lint errors, Prettier, commit hooks        | [lint-format-guidelines.md](docs/guidelines/lint-format-guidelines.md)         |
| Codebase style + code documentation policy | [coding-style.md](docs/guidelines/coding-style.md)                             |
| Git workflow, branches, PRs                | [git-workflow.md](docs/guidelines/git-workflow.md)                             |
| Handing off work to another agent          | [agent-handoff.md](docs/guidelines/agent-handoff.md)                           |

---

## Verification before finishing

```bash
{{PKG_MGR}} type-check     # TS must compile — 0 errors
{{PKG_MGR}} lint           # ESLint must pass — 0 errors or suppressions
{{PKG_MGR}} format:check   # Prettier must be clean
{{PKG_MGR}} test --passWithNoTests
```

Manual sweep on changed files:

- [ ] No `console.log` (use `captureError` for errors, `appLog` — if added — for dev logs).
- [ ] No `any`, no `// @ts-ignore`, no `// eslint-disable`.
- [ ] Comments in English only.
- [ ] File-header JSDoc on every non-trivial new file.
- [ ] JSDoc on every new exported function, hook, component, service.
- [ ] Every new test `it` has a block comment describing the scenario and the rule it protects.
- [ ] User-facing strings via `t()`.
- [ ] No hex literals in components — theme tokens only.
- [ ] No cross-feature imports.
- [ ] {{Project-specific check — e.g., "No PII in analytics or logs"}}
- [ ] New external deps documented in `docs/knowledge-base/{{NN}}-stack.md`.

---

## Git

> Replace with your project's git policy. Examples:
> - "Never commit or push without explicit user approval."
> - "Open a PR for review; never push directly to main."
> - "Conventional Commits enforced via commitlint."

Conventional Commits grammar (`feat(scope): …`, `fix(scope): …`). See [docs/guidelines/git-workflow.md](docs/guidelines/git-workflow.md).

---

## When to load global skills

- New feature or non-trivial change → start with `/brainstorm` (if vague) or `/plan` (if clear).
- Big multi-phase feature → `/spec` → `/roadmap` → `/phase-tasks` → `/task`.
- Implementation → `/tdd` for new code, `tester` for adding tests to existing code.
- Before declaring done → `/verify`.
- Before commit / PR → `/code-review` and `/security-review`.
- Reference for any universal rule → `/standards`.

---

## If a rule conflicts with task

Security and privacy win. Design system wins over any one-off. A rule you think is wrong → raise it in the PR or open an ADR in [docs/decisions/](docs/decisions/). Don't silently work around it.

---

**When in doubt, read the specific guideline before you write code.**
