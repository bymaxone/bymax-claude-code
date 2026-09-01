# llms-install.md — AI-agent installation runbook

> **Audience:** AI coding agents (Claude Code, Cline, Cursor, Codex, …) installing the **bymax-claude-code** toolkit for a user.
> **Scope:** the PUBLIC toolkit only. This is **not** the author's machine-restore flow — **never run `scripts/install.sh`, never copy `personal/` or `vendor/`** unless the human explicitly states they are the repo author restoring their own machine.
>
> Name mapping (the most common command-construction error):
> - GitHub slug: `bymaxone/bymax-claude-code`
> - Marketplace name (used after `@` in install commands): `bymax-claude-code`

Every step is idempotent — re-running is safe. After each step, run the **Verify** command; do not proceed on failure (see [Failure guidance](#failure-guidance)).

---

## Step 0 — Prerequisites

```bash
claude --version   # Claude Code CLI must exist
node --version     # ≥ 18 required for plugin hooks (≥ 20 recommended)
git --version      # any recent version
```

Missing item → STOP and report to the human:

| Missing | Human action |
|---|---|
| `claude` | `npm install -g @anthropic-ai/claude-code` (or the native installer from docs.claude.com) |
| `node` | `brew install node` (macOS) / nvm — must be on the non-interactive shell PATH |
| `git` | `xcode-select --install` (macOS) or the platform package manager |

## Step 1 — Add the marketplace

```bash
claude plugin marketplace add bymaxone/bymax-claude-code
```

**Verify:** `claude plugin marketplace list` shows `bymax-claude-code`.

## Step 2 — Choose and install plugins (decision point)

Default when the human didn't specify: install the **core pair** plus whatever the project type needs.

| Plugin | Install when | Command |
|---|---|---|
| `bymax-workflow` | always (core) | `claude plugin install bymax-workflow@bymax-claude-code` |
| `bymax-quality` | always (core — ships the hooks + sub-agents) | `claude plugin install bymax-quality@bymax-claude-code` |
| `bymax-bootstrap` | the human will scaffold new projects | `claude plugin install bymax-bootstrap@bymax-claude-code` |
| `bymax-mobile` | Expo / React Native projects only | `claude plugin install bymax-mobile@bymax-claude-code` |
| `bymax-web-verify` | web projects only (needs Step 4's `agent-browser`) | `claude plugin install bymax-web-verify@bymax-claude-code` |
| `bymax-pr` | only if `gh` will be authenticated (Step 4) | `claude plugin install bymax-pr@bymax-claude-code` |

⚠️ **Do NOT install `bymax-all`** — it is a documentation index; it installs no commands.

**Verify:** `claude plugin list` shows each installed plugin.

Scope note: plugins install user-wide by default. Only pin to a single project (via `enabledPlugins` in that project's `.claude/settings.json`) if the human asks for it.

## Step 3 — Restart Claude Code (HUMAN HANDOFF)

Commands and hooks are only picked up on a fresh session. **An agent running inside Claude Code cannot restart its own session** — tell the human:

> "Please restart Claude Code (close and reopen the session), then tell me to continue."

**Verify (after restart):** `claude plugin list` still shows the plugins, and typing `/` inside Claude Code lists `bymax-workflow:*` commands. Use the **namespaced** names (`/bymax-workflow:standards`), not bare `/standards`.

## Step 4 — External CLIs (conditional — only for plugins installed in Step 2)

Each row: check → install → verify. Skip rows whose plugin wasn't installed.

| Tool | Check | Install | Verify |
|---|---|---|---|
| `gh` (for `bymax-pr`) | `command -v gh` | `brew install gh` | `gh auth status` |
| `gh` auth | `gh auth status` | **HUMAN HANDOFF:** `gh auth login` is an interactive OAuth flow — the human must run it | `gh auth status` exits 0 |
| pnpm (pnpm repos) | `command -v pnpm` | `corepack enable pnpm` | `pnpm --version` |
| Xcode (`/sim-ios`) | `xcrun simctl help` | **HUMAN HANDOFF:** Xcode via App Store + `xcode-select --install` | `xcrun simctl list devices` |
| Android SDK (`/sim-android`) | `command -v adb` | **HUMAN HANDOFF:** Android Studio GUI installer + PATH setup | `adb --version` |
| Rust extras (Rust repos) | `command -v cargo` | `cargo install cargo-llvm-cov cargo-mutants cargo-deny cargo-audit cargo-vet` | `cargo llvm-cov --version` |
| `agent-browser` (for `bymax-web-verify`) | `command -v agent-browser` | run `/bymax-web-verify:setup` **inside Claude Code, after Step 3's restart** (downloads Chrome for Testing — tell the human first) | the setup command ends with its own smoke test |
| `codex` CLI (for `bymax-quality`'s independent second review) | `command -v codex` | run `/bymax-quality:codex-setup` **inside Claude Code, after Step 3's restart** — it installs the CLI, then hands off: `codex login` is interactive, so **only the human can finish it** | the setup command ends with a real review run, not an exit code |
| `codex@openai-codex` plugin (only for `/bymax-quality:code-review --adversarial`) | `claude plugin list` shows `codex@openai-codex` with `Status: ✔ enabled` — a disabled plugin still prints its id, and the runtime skips it | `claude plugin marketplace add openai/codex-plugin-cc`, then `claude plugin install codex@openai-codex` | `/bymax-quality:codex-setup` from a **feature branch with commits on it** → `ok` or `ok-unpinned`; several other statuses are expected too, not failures — see below the table |

Both Codex rows are **optional** — `/bymax-quality:code-review` runs without either and prints a
one-line status where the second opinion would go. Type the last row's two commands exactly: the
plugin is `codex`, its marketplace is `openai-codex`, and the repo behind it is
`openai/codex-plugin-cc` — three different names for one install. `claude plugin install` takes no
version, so the plugin arrives at whatever the marketplace publishes; if that version is not one
`bymax-quality` has verified its runtime contract against, the adversarial review answers
`adversarial-absent` and `/bymax-quality:codex-setup` documents the ways out.

**Reading the plugin row's verification.** `ok` and `ok-unpinned` are the passing answers.
The statuses below are expected on a correct install and must not be reported as a failed step:

| Status | Why it is expected |
|---|---|
| `unsupported-target`, second line saying the range is **empty** or there is nothing to review | run from the default branch, where nothing is ahead of the base. Any other second line — a ref that does not resolve, a base sharing no history — is a real misconfiguration, so read it before excusing this status |
| `unauthenticated` | the CLI row's `codex login` has not been completed yet — the script gates on the session before it looks for the plugin |
| `absent` | the CLI row is not done, **or** its install landed outside the non-interactive shell's PATH. Finish that row; an `absent` that survives it is that row failing, and belongs in the report as such |
| `adversarial-absent`, second line naming an **unverified version** | the install cannot pin a version, so a newly published plugin lands here with nothing wrong |

`adversarial-absent` for any other reason is a real failure, as is every other status.

## Step 5 — MCP servers (optional — ask the human, default: context7 only)

Use the `claude mcp add` one-liners (do **not** use the `personal/mcp.template.json` copy method — that is the author-restore path):

```bash
claude mcp add context7 -- npx -y @upstash/context7-mcp
claude mcp add sequential-thinking -- npx -y @modelcontextprotocol/server-sequential-thinking
```

Obsidian knowledge vault — **only if the human has a vault**; the path is theirs to provide (ask, never guess):

```bash
claude mcp add obsidian -- npx -y @bitbonsai/mcpvault@latest /path/the/human/provides
```

**Verify:** `claude mcp list` shows each added server. Restart handoff applies again (Step 3).

## Step 6 — graphify (optional — ask the human; default: skip unless they want token-optimized reuse scans)

Prerequisite: Python ≥ 3.10 plus `uv` (or `pipx`). The PyPI package is **`graphifyy`** (double-y) — other `graphify*` names on PyPI are NOT affiliated.

```bash
uv tool install graphifyy      # or: pipx install graphifyy
graphify install               # registers the /graphify skill with Claude Code
# then, inside Claude Code, in each project to map:   /graphify .
graphify hook install          # post-commit graph refresh
```

**Verify:** `command -v graphify`, and after `/graphify .` the file `graphify-out/graph.json` exists in the project.

## Final verification checklist

```bash
claude plugin marketplace list   # bymax-claude-code present
claude plugin list               # every chosen plugin present
claude mcp list                  # every chosen MCP present (if Step 5 ran)
gh auth status                   # exit 0 (only if bymax-pr installed)
```

Report a pass/fail summary per step to the human. Done.

---

## DO-NOT list

- ❌ **Never run `scripts/install.sh`** — it symlinks the author's personal config and vendor skills into `~/.claude/` (author-restore only).
- ❌ **Never copy or edit `personal/` or `vendor/`** — author backup and third-party content respectively.
- ❌ **Never install `bymax-all`** expecting functionality — it is a docs-only index.
- ❌ **Never run `graphify claude install`** (the "always use the graph" mode) — its always-on `PreToolUse` hooks add per-prompt overhead and conflict with the `bymax-quality` hooks. The toolkit's integration is presence-gated and needs no hooks.
- ❌ **Never add a GitHub MCP server** — GitHub access in this toolkit is `gh` CLI only (short-lived OAuth; org policies often reject long-lived PATs).
- ❌ **Never guess the Obsidian vault path** — ask the human.

## Failure guidance

| Symptom | Likely cause → action |
|---|---|
| `marketplace add` fails | Network/auth → retry once; still failing → report to human with the exact error |
| `plugin install` fails | Marketplace-name typo — it is `@bymax-claude-code` (hyphen), never `@bymax.claude-code` |
| Commands missing after install | Step 3 restart not done → hand off to the human again |
| MCP server missing from `claude mcp list` | Re-run the `claude mcp add` line; if listed but inactive, check `enabledMcpjsonServers` in `~/.claude/settings.local.json` |
| Hooks not firing (`secret-scanner` etc.) | Plugin disabled or restart pending → `claude plugin list`, then restart handoff |
| `adversarial-absent` from `/bymax-quality:code-review --adversarial` | The status has several causes and **the line under it names which one** — a missing plugin, but equally a missing `node`, an unreadable plugin list (no `claude` on PATH, neither `jq` nor `python3`), an install missing its runtime file, or an unverified version. Read that line, then take its row in `/bymax-quality:codex-setup`'s remedy table. Only the missing-plugin case is fixed by Step 4's last row |
| `graphify: command not found` after install | Tool bin dir not on PATH → `uv tool update-shell` (or `pipx ensurepath`), new terminal |
