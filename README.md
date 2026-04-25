<p align="center">
  <img src="https://img.shields.io/badge/%40bymaxone-claude--code-A3FF3C?style=for-the-badge&logo=anthropic&logoColor=000000" alt="@bymaxone/claude-code" />
</p>

<h1 align="center">Bymax Claude Code</h1>

<p align="center">
  <strong>A complete, opinionated toolkit for Claude Code</strong><br />
  <sub>Phased Planning · Strict Quality Gates · Project Bootstrap · Mobile Sims · Battle-tested Templates</sub>
</p>

<p align="center">
  <a href="https://github.com/bymaxone/bymax.claude-code/blob/main/LICENSE"><img src="https://img.shields.io/github/license/bymaxone/bymax.claude-code?style=flat-square&colorA=000000&colorB=000000" alt="license" /></a>
  <a href="https://github.com/bymaxone/bymax.claude-code/stargazers"><img src="https://img.shields.io/github/stars/bymaxone/bymax.claude-code?style=flat-square&colorA=000000&colorB=000000" alt="stars" /></a>
  <a href="https://github.com/bymaxone/bymax.claude-code"><img src="https://img.shields.io/badge/Claude_Code-marketplace-A3FF3C?style=flat-square&colorA=000000" alt="claude code marketplace" /></a>
  <a href="https://www.typescriptlang.org/"><img src="https://img.shields.io/badge/TypeScript-strict-3178C6?style=flat-square&logo=typescript&logoColor=white" alt="TypeScript" /></a>
  <a href="https://eslint.org/"><img src="https://img.shields.io/badge/ESLint-flat--config-4B32C3?style=flat-square&logo=eslint&logoColor=white" alt="ESLint" /></a>
  <img src="https://img.shields.io/badge/PRs-welcome-brightgreen?style=flat-square&colorA=000000" alt="PRs welcome" />
</p>

<p align="center">
  <a href="#-overview">Overview</a> ·
  <a href="#-quick-start">Quick Start</a> ·
  <a href="#-plugins">Plugins</a> ·
  <a href="#-the-workflow">The Workflow</a> ·
  <a href="#-architecture">Architecture</a> ·
  <a href="#-contributing">Contributing</a>
</p>

---

## ✨ Overview

**Bymax Claude Code** is a production-ready toolkit that turns Claude Code into a **disciplined senior engineer**. Instead of ad-hoc prompts, you get:

- A **phased planning workflow** (spec → roadmap → phase-tasks → task) with explicit user-approval gates and JIRA-style dashboards.
- **Strict quality gates** — `/code-review` (CRITICAL → LOW), `/tdd` (red-green-refactor), `/verify` (5 checks), and a `secret-scanner` hook that **blocks** writes containing credentials.
- **Six specialist sub-agents** (architect, code-reviewer, security-reviewer, typescript-reviewer, database-reviewer, planner) ready to delegate to.
- **Project bootstrap** with strict TypeScript, ESLint flat-config (security plugin + import-order + suppression bans), Prettier, format-on-save VS Code, Husky + commitlint + lint-staged — for **Next.js, Expo / React Native, Vite + React, and Node backends (Express / Fastify / Hono / NestJS / plain Node)** stacks.
- **Mobile sims** — `/sim-ios` and `/sim-android` boot the iOS Simulator and Android Emulator on Expo / React Native projects in one command (auto-detects whether to reattach Metro or do a full rebuild).
- **Beautiful starter templates** for `CLAUDE.md`, `AGENTS.md`, and `README.md` — distilled from real production projects.

Built and used daily across mobile (Expo / React Native) and web (Next.js / NestJS) products.

### Why this exists

Every Claude Code user reinvents the same scaffolding: standards docs, review skills, planning rituals, ESLint configs, hooks, agents. This repo packages a **battle-tested set** that works across stacks — install once, focus on your product.

```bash
claude plugin marketplace add bymaxone/bymax.claude-code
claude plugin install bymax-all@bymax-claude-code
```

That's it. Restart Claude Code and you have **5 plugins** with **14 slash commands**, **2 skills**, **6 sub-agents**, **2 hooks**, and **20 templates** — the full workflow ready.

---

## 🚀 Quick Start

### 1. Install the marketplace

```bash
claude plugin marketplace add bymaxone/bymax.claude-code
```

### 2. Install plugins

Pick one approach:

```bash
# Recommended — install everything
claude plugin install bymax-all@bymax-claude-code

# Or pick what you want
claude plugin install bymax-workflow@bymax-claude-code     # planning + execution
claude plugin install bymax-quality@bymax-claude-code      # review + TDD + agents + hooks
claude plugin install bymax-bootstrap@bymax-claude-code    # scaffold new projects
claude plugin install bymax-mobile@bymax-claude-code       # iOS Simulator + Android Emulator
```

### 3. Restart Claude Code

Reopen your terminal session so the new commands and hooks are picked up.

### 4. Verify

In Claude Code, type `/` — you should see all the `bymax-*` commands. Try:

```
/standards          # show the universal coding rules
/spec               # start a new feature spec
/bootstrap          # scaffold a new project
```

---

## 📦 Plugins

The toolkit ships as **five composable plugins**. Use them à la carte or all at once via `bymax-all`.

### 🧭 [`bymax-workflow`](./plugins/bymax-workflow/) — Planning + Execution

End-to-end feature pipeline with explicit approval gates between every layer.

| Command        | Purpose                                                                                               |
| -------------- | ----------------------------------------------------------------------------------------------------- |
| `/spec`        | Layer 1: write a complete technical spec (goal, scope, stories, criteria, risks). Asks if vague.      |
| `/roadmap`     | Layer 2: take an approved spec → phased master plan with status dashboard, dependency DAG, DoD.       |
| `/phase-tasks` | Layer 3: take an approved roadmap → JIRA-style task files with self-contained agent prompts per task. |
| `/task`        | Execute a phase or single task end-to-end with `/verify` → `/security-review` → `/code-review` chain. |
| `/brainstorm`  | Pre-spec: refine vague ideas, explore alternatives, surface tradeoffs.                                |
| `/plan`        | Lightweight plan for single-task work that doesn't need the full spec → roadmap → tasks chain.        |
| `/verify`      | 5-gate verification (static checks, exercise, root-cause, regression scan, acceptance criteria).      |
| `/checkpoint`  | Snapshot SHA + tests + coverage to compare against later (e.g., "did this refactor regress tests?").  |

Plus the `/standards` skill — **universal coding rules** referenced by every other command.

### 🛡️ [`bymax-quality`](./plugins/bymax-quality/) — Review + Testing + Agents

Strict quality gates and specialist reviewers.

| Item                    | Purpose                                                                                                                                    |
| ----------------------- | ------------------------------------------------------------------------------------------------------------------------------------------ |
| `/code-review`          | CRITICAL → HIGH → MEDIUM → LOW review. Blocks suppression comments (`@ts-ignore`, `eslint-disable`, etc.).                                 |
| `/tdd`                  | Strict red-green-refactor cycle. Forces failing test before implementation. 80%+ coverage minimum.                                         |
| `tester` skill          | Multi-stack test writer — auto-detects Jest / Vitest / RN / pure logic. 100% file coverage. Rich `it()` comments.                          |
| `architect` agent       | System design, scalability, technical decisions.                                                                                           |
| `code-reviewer`         | Quality + security + maintainability review (proactive).                                                                                   |
| `security-reviewer`     | OWASP Top 10, secrets, SSRF, injection, unsafe crypto.                                                                                     |
| `typescript-reviewer`   | Type safety, async correctness, idiomatic patterns.                                                                                        |
| `database-reviewer`     | PostgreSQL: query optimization, schema design, security.                                                                                   |
| `planner`               | Complex feature and refactor planning.                                                                                                     |
| `secret-scanner` hook   | **PreToolUse** — blocks Write/Edit/MultiEdit if AWS keys, GitHub PATs, OpenAI/Anthropic/Stripe tokens, JWTs, or private keys are detected. |
| `console-log-scan` hook | **Stop** — warns on stray `console.log/warn/error/debug/info` in modified TS/JS files.                                                     |

`/code-review` also flags **30+ Tailwind v4 canonical-class patterns** in projects on Tailwind 4 (skipped on v3 / NativeWind 4): CSS variable shorthand (`[var(--x)]` → `(--x)`), ARIA boolean variants (`aria-[invalid=true]:` → `aria-invalid:`), on-scale `rem` values (`[8rem]` → `32`), gradient renames (`bg-gradient-to-r` → `bg-linear-to-r`), scale shifts (`shadow` → `shadow-sm`, `rounded` → `rounded-sm`, etc.), individual renames (`outline-none` → `outline-hidden`, `flex-shrink-*` → `shrink-*`, etc.), opacity-modifier deprecation (`bg-opacity-50` → `bg-blue-500/50`), arbitrary z-index integers (`z-[200]` → `z-200`), on-scale filter px (`backdrop-blur-[12px]` → `backdrop-blur-md`), and negative zero (`-bottom-0` → `bottom-0`). Full reference in `/standards § 12`.

### 🏗️ [`bymax-bootstrap`](./plugins/bymax-bootstrap/) — Project Scaffold

Set up a new project with **all the standards wired** in one shot. Detects the stack, picks the right ESLint preset, writes `.vscode/`, `tsconfig.json`, `.prettierrc.json`, `.editorconfig`, `.gitignore`, `commitlint.config.cjs`, `lint-staged.config.cjs`, `.husky/{pre-commit,commit-msg}`, and a `CLAUDE.md` filled with detected stack.

| Command              | Purpose                                                                    |
| -------------------- | -------------------------------------------------------------------------- |
| `/bootstrap`         | New project — full scaffold (asks/detects stack first).                    |
| `/upgrade-standards` | Existing project — non-destructive incremental upgrade with confirmations. |

#### Stacks supported by the ESLint flat-configs

| Stack                                                             | Config                              |
| ----------------------------------------------------------------- | ----------------------------------- |
| **Next.js** (15+/16) + TypeScript (App Router or Pages)           | `eslint.config.next.cjs`            |
| **Expo / React Native** + TypeScript                              | `eslint.config.expo-rn.cjs`         |
| **Vite + React** + TypeScript (SPA or library)                    | `eslint.config.vite-react.cjs`      |
| **Node backend** — Express / Fastify / Hono / NestJS / plain Node | `eslint.config.node.cjs`            |
| **Tailwind CSS** (overlay, auto-detects v3/v4)                    | `eslint.config.tailwind.cjs`        |
| Anything else (Vue, Svelte, Astro, Remix…)                        | universal layer only (still strict) |

All four stack-specific configs inherit the **universal layer**: `eslint-plugin-security`, import-order, suppression bans (`@ts-ignore`, `eslint-disable`, `as any`), risky-import bans (`crypto` → `node:crypto`, `bcrypt` → `argon2`, etc.), Prettier integration. The **Tailwind overlay** spreads on top of any of them and adds class-sorting + canonical-class warnings (v4 only — falls back to long-form lints on v3 / NativeWind 4).

20 templates included total: 5 ESLint flat-configs + 1 Tailwind overlay (auto-detects v3/v4), `tsconfig`, `prettier`, `editorconfig`, `gitignore`, `vscode-settings`, `vscode-extensions`, `commitlint`, `lint-staged`, Husky hooks, plus the `claude-md` project template and the workflow doc templates (`spec`, `roadmap`, `phase-tasks`). The repo also bundles three reference starters (`CLAUDE.md` / `AGENTS.md` / `README.md`) at [`/templates/`](./templates/) for forks and standalone use.

### 📱 [`bymax-mobile`](./plugins/bymax-mobile/) — iOS Simulator + Android Emulator

Two slash commands that take an Expo / React Native project from cold to running on a simulator in one shot.

| Command        | Platform | What it does                                                                                               |
| -------------- | -------- | ---------------------------------------------------------------------------------------------------------- |
| `/sim-ios`     | iOS      | Boots **iPhone 17** (or `$BYMAX_SIM_IOS`), runs `expo start` if app already built, else `expo run:ios`.    |
| `/sim-android` | Android  | Boots the first AVD listed (or `$BYMAX_SIM_ANDROID`), runs `expo start` if built, else `expo run:android`. |

Both commands auto-detect the package manager (`pnpm` / `yarn` / `npm`), use a build-artifact heuristic to choose between Metro reattach and full rebuild, and pre-flight tooling so they bail early with a clear, actionable error if Xcode CLI tools or the Android SDK are missing.

### 🎁 [`bymax-all`](./plugins/bymax-all/) — Everything

Meta-plugin that pulls in all four above. Recommended starting point.

---

## 🔥 The Workflow

This is the heart of the toolkit. **Big features** flow through three planning layers + one executor:

```
/spec         →  docs/specs/<feature>.md         (the WHAT and WHY)
   ⏸ approval
/roadmap      →  docs/plans/<feature>-plan.md    (phased master plan + dashboard + DAG)
   ⏸ approval
/phase-tasks  →  docs/tasks/phase-NN-*.md        (per-phase task files with agent prompts)
   ⏸ approval per phase
/task         →  /verify → /security-review → /code-review → completion protocol
   ⏸ user reviews diff
commit (Conventional Commits — never auto-committed)
```

Each layer **stops and waits** for explicit user approval. You review, modify, or approve. Nothing auto-chains.

### Status legend (used in every roadmap and task file)

| Emoji | Meaning     |
| ----- | ----------- |
| 📋    | ToDo        |
| 🔄    | In Progress |
| 👀    | Review      |
| ✅    | Done        |
| ⛔    | Blocked     |
| 🟡    | Partial     |

### Small tasks / bug fixes

Skip the heavy chain — use `/plan` (single PR), then `/tdd` (new code) or the `tester` skill (existing code), then `/verify` and `/code-review`.

---

## 🏛️ Architecture

```
bymax.claude-code/
├── .claude-plugin/
│   └── marketplace.json                ← marketplace metadata
│
├── plugins/                            ← installable via /plugin install
│   ├── bymax-workflow/                 ← planning + execution
│   ├── bymax-quality/                  ← review + TDD + agents + hooks
│   ├── bymax-bootstrap/                ← project scaffolding
│   ├── bymax-mobile/                   ← iOS Simulator + Android Emulator
│   └── bymax-all/                      ← meta (depends on the four above)
│
├── templates/                          ← project bootstrapping templates
│   ├── CLAUDE.md                       ← starter CLAUDE.md (load-on-demand pattern)
│   ├── AGENTS.md                       ← starter AGENTS.md (full spec for agents)
│   └── README.md                       ← beautiful README starter (badges + sections + emojis)
│
├── vendor/                             ← third-party MIT-licensed extras (backup, not in marketplace)
│   ├── ecc-skills/                     ← Everything Claude Code domain skills
│   └── ui-ux-pro-max/                  ← UI/UX design intelligence skill
│
├── personal/                           ← author's personal config (backup, not in marketplace)
│   ├── settings.template.json          ← sanitized ~/.claude/settings.json
│   ├── mcp.template.json               ← sanitized ~/.mcp.json (context7 + sequential-thinking)
│   └── prettier-format.sh              ← personal autoformat hook
│
├── scripts/
│   ├── install.sh                      ← restore everything to ~/.claude/ (for new Mac)
│   └── validate.sh                     ← validate marketplace.json + plugin.json
│
└── docs/
    └── PROPOSAL.md                     ← original design proposal
```

### Two ways to use this repo

**A. Public marketplace** (recommended for everyone)

```bash
claude plugin marketplace add bymaxone/bymax.claude-code
claude plugin install bymax-all@bymax-claude-code
```

Only the `plugins/` content is exposed via `/plugin install`. The vendor/ and personal/ folders are visible in the repo for backup but not installable.

**B. Personal restore** (full Mac wipe — author workflow)

After installing Claude Code itself (`brew install claude` or upstream installer):

```bash
# 1. Clone the repo
git clone https://github.com/bymaxone/bymax.claude-code ~/dotfiles-claude
cd ~/dotfiles-claude

# 2. Preview what install.sh will do (no writes)
./scripts/install.sh --dry-run

# 3. Run for real — symlinks plugins/vendor/personal into ~/.claude/, copies
#    ~/.mcp.json, AND writes ~/.claude/settings.local.json to enable the MCPs.
./scripts/install.sh --write-mcp-enabled

# 4. Configure your settings (template has comments inline)
cp personal/settings.template.json ~/.claude/settings.json
$EDITOR ~/.claude/settings.json

# 5. Install marketplace plugins
claude plugin marketplace add bymaxone/bymax.claude-code
claude plugin install bymax-all@bymax-claude-code
claude plugin marketplace add anthropics/claude-plugins-official
claude plugin install frontend-design@claude-plugins-official
claude plugin marketplace add getsentry/sentry-mcp
claude plugin install sentry-mcp@sentry-mcp

# 6. (Optional) Add the github MCP — needs a PAT
claude mcp add github -e GITHUB_PERSONAL_ACCESS_TOKEN=<your_pat> -- npx -y @modelcontextprotocol/server-github

# 7. Restart Claude Code; type "/" — you should see all bymax-* commands.
```

#### What `install.sh` restores

| Layer        | What                                                                             | Mode     |
| ------------ | -------------------------------------------------------------------------------- | -------- |
| **plugins**  | every `commands/`, `agents/`, `skills/`, `hooks/`, `templates/` from each plugin | symlinks |
| **vendor**   | `ecc-skills/*.md` + the full `ui-ux-pro-max/` directory                          | symlinks |
| **personal** | `prettier-format.sh` (hook)                                                      | symlinks |
| **MCP**      | `mcp.template.json` → `~/.mcp.json` (only if not already present)                | **copy** |

Settings (`~/.claude/settings.json`) and the marketplace plugin install commands are **manual** — the script prints them at the end so you can copy/paste.

Flags: `--dry-run`, `--no-vendor`, `--no-personal`, `--no-mcp`, `--write-mcp-enabled`, `--plugins-only`.

---

## 📐 Standards

Every command and template enforces the same universal rules:

- **TypeScript strict** + `noUncheckedIndexedAccess`, zero `any`, zero `// @ts-ignore`, zero `// eslint-disable`.
- **JSDoc** on every non-trivial file header and every export.
- **Every test `it()`** carries a block comment (scenario + rule it protects).
- **English-only** comments.
- **Layered architecture**: `app/` → `features/*` → `shared/*`. No cross-feature imports.
- **Conventional Commits** enforced via Husky + commitlint.
- **Banned suppression comments** caught by `/code-review` and `/verify`.
- **Banned risky imports**: `crypto` (use `node:crypto`), `bcrypt` (use `argon2`), `crypto-js`, `md5`, `uuid`, `nanoid` (use `crypto.randomUUID`).

Full reference: [`/standards`](./plugins/bymax-workflow/skills/standards/SKILL.md) skill (loaded on demand).

---

## 🧱 Tech Stack

The included ESLint configs and templates target modern stacks:

<p>
  <img src="https://img.shields.io/badge/Node.js-24%2B-339933?style=flat-square&logo=node.js&logoColor=white" alt="Node.js" />
  <img src="https://img.shields.io/badge/TypeScript-strict-3178C6?style=flat-square&logo=typescript&logoColor=white" alt="TypeScript" />
  <img src="https://img.shields.io/badge/React-19-61DAFB?style=flat-square&logo=react&logoColor=black" alt="React" />
</p>

<p>
  <img src="https://img.shields.io/badge/Next.js-16-000000?style=flat-square&logo=next.js&logoColor=white" alt="Next.js" />
  <img src="https://img.shields.io/badge/Expo-55-000020?style=flat-square&logo=expo&logoColor=white" alt="Expo" />
  <img src="https://img.shields.io/badge/React_Native-0.85-61DAFB?style=flat-square&logo=react&logoColor=black" alt="React Native" />
  <img src="https://img.shields.io/badge/Vite-7-646CFF?style=flat-square&logo=vite&logoColor=white" alt="Vite" />
</p>

<p>
  <img src="https://img.shields.io/badge/Express-5-000000?style=flat-square&logo=express&logoColor=white" alt="Express" />
  <img src="https://img.shields.io/badge/Fastify-5-000000?style=flat-square&logo=fastify&logoColor=white" alt="Fastify" />
  <img src="https://img.shields.io/badge/Hono-4-E36002?style=flat-square&logo=hono&logoColor=white" alt="Hono" />
  <img src="https://img.shields.io/badge/NestJS-11-E0234E?style=flat-square&logo=nestjs&logoColor=white" alt="NestJS" />
</p>

<p>
  <img src="https://img.shields.io/badge/Tailwind_CSS-4-06B6D4?style=flat-square&logo=tailwindcss&logoColor=white" alt="Tailwind CSS" />
  <img src="https://img.shields.io/badge/NativeWind-4-06B6D4?style=flat-square&logo=tailwindcss&logoColor=white" alt="NativeWind" />
</p>

<p>
  <img src="https://img.shields.io/badge/ESLint-9-4B32C3?style=flat-square&logo=eslint&logoColor=white" alt="ESLint" />
  <img src="https://img.shields.io/badge/Prettier-3-F7B93E?style=flat-square&logo=prettier&logoColor=black" alt="Prettier" />
  <img src="https://img.shields.io/badge/Jest-30-C21325?style=flat-square&logo=jest&logoColor=white" alt="Jest" />
  <img src="https://img.shields.io/badge/Vitest-3-6E9F18?style=flat-square&logo=vitest&logoColor=white" alt="Vitest" />
</p>

<p>
  <img src="https://img.shields.io/badge/Husky-9-FFB94A?style=flat-square&logo=husky&logoColor=black" alt="Husky" />
  <img src="https://img.shields.io/badge/commitlint-19-FE5196?style=flat-square&logo=commitlint&logoColor=white" alt="commitlint" />
  <img src="https://img.shields.io/badge/lint--staged-15-FFB94A?style=flat-square&logoColor=white" alt="lint-staged" />
</p>

---

## 🤝 Contributing

Contributions, bug reports, and ideas are very welcome! Please read [CONTRIBUTING.md](./CONTRIBUTING.md) before opening a PR.

```bash
# Clone the repo
git clone https://github.com/bymaxone/bymax.claude-code.git
cd bymax.claude-code

# Validate marketplace + plugin manifests
./scripts/validate.sh

# Test locally
claude plugin marketplace add ./
claude plugin install bymax-all@bymax-claude-code
```

---

## 🔒 Security

If you discover a security vulnerability (e.g., a regex bypass in `secret-scanner.sh`), please **do not** open a public issue. Email **security@bymax.one** instead. See [SECURITY.md](./SECURITY.md).

---

## 🙏 Credits

This repo bundles two MIT-licensed third-party skills as backup (not redistributed via the marketplace — see `vendor/README.md` for original sources):

- **[Everything Claude Code](https://github.com/affaan-m/everything-claude-code)** by Affaan Mustafa — domain skills (api-design, backend-patterns, postgres-patterns, etc.)
- **[ui-ux-pro-max](https://github.com/nextlevelbuilder/ui-ux-pro-max-skill)** by nextlevelbuilder — UI/UX design intelligence

Inspired by:

- [Anthropic Claude Code](https://github.com/anthropics/claude-code) and the [official plugin marketplace](https://github.com/anthropics/claude-plugins-official).
- [Superpowers](https://github.com/obra/superpowers) — for the spec → plan → execute discipline mindset.
- [awesome-claude-code](https://github.com/hesreallyhim/awesome-claude-code) — community index.

---

## 📄 License

[MIT](./LICENSE) © [Maximiliano Salvatti](https://github.com/bymaxone)

---

<p align="center">
  <sub>Built with ❤️ by <a href="https://github.com/bymaxone">Bymax One</a> · Used in production every day at <a href="https://bymax.one">bymax.one</a></sub>
</p>
