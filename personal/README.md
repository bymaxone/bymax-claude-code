# 👤 Personal

The author's personal Claude Code config bits — kept in the repo as **backup**, not as marketplace content.

These files are **NOT** redistributed via `/plugin install`. They're here so a fresh Mac can be restored to the author's exact setup via [`scripts/install.sh`](../scripts/install.sh).

---

## What's here

### `settings.template.json`

A sanitized version of `~/.claude/settings.json`. Tokens, OAuth credentials, and machine-specific paths are replaced with `{{PLACEHOLDERS}}`. Inline `_comment_*` keys document the full restore steps (settings, MCP config, marketplace plugins, `gh` CLI auth). Copy to `~/.claude/settings.json` and edit by hand.

### `mcp.template.json`

A sanitized version of `~/.mcp.json`. Lists the user-scope MCP servers Claude Code launches via `npx`:

- **`context7`** — `@upstash/context7-mcp` — fetches up-to-date library docs.
- **`sequential-thinking`** — `@modelcontextprotocol/server-sequential-thinking` — structured reasoning.

The install script copies this to `~/.mcp.json` (only if it doesn't already exist — no clobbering). To **activate** the servers, you must also write `~/.claude/settings.local.json`:

```bash
echo '{"enabledMcpjsonServers":["context7","sequential-thinking"]}' > ~/.claude/settings.local.json
```

> **GitHub access is via the `gh` CLI, not an MCP server.** Every GitHub operation in the toolkit (PRs, issues, CI logs, releases, `bymax-pr:babysit-pr`) runs through `gh`, which uses a short-lived OAuth token managed by `gh auth login` — it works across orgs whose token policies reject long-lived fine-grained PATs (which is exactly why the github MCP was dropped). Restore with:
> `brew install gh && gh auth login`

> The `obsidian` knowledge-vault MCP is also registered via the `claude` CLI (machine-specific vault path, so it stays out of the template). It powers the `/bymax-workflow:standards` §0 reuse ladder — per-stack `Patterns.md` / `Gotchas.md` lookups. Restore with:
> `claude mcp add obsidian -- npx -y @bitbonsai/mcpvault@latest /path/to/your/vault`

### `prettier-format.sh`

A `PostToolUse Write|Edit` hook that auto-runs Prettier on the file just edited. Personal preference — most projects already have format-on-save in VS Code, so this is belt-and-suspenders.

> The previous `/sim` command lived here as a personal helper. It has graduated into the public `bymax-mobile` plugin as `/sim-ios` and `/sim-android` (auto-detects iPhone 17 default + run mode). See [`plugins/bymax-mobile/`](../plugins/bymax-mobile/).

---

## How they get installed

When you run [`scripts/install.sh`](../scripts/install.sh) (personal content is included by default), these files are placed into your home:

| Source                              | Destination                            | Mode      |
| ----------------------------------- | -------------------------------------- | --------- |
| `personal/prettier-format.sh`       | `~/.claude/hooks/prettier-format.sh`   | symlink   |
| `personal/mcp.template.json`        | `~/.mcp.json`                          | **copy** (no clobber) |
| `personal/settings.template.json`   | `~/.claude/settings.json`              | **manual** (you copy + edit) |

Why **copy** for `~/.mcp.json` instead of symlink? Because `~/.mcp.json` may grow over time with project-specific MCP servers. A copy lets you edit it on the new Mac without polluting the repo. Re-running `install.sh` will not overwrite an existing `~/.mcp.json`.

To skip personal content entirely: `--no-personal`.
To skip just the MCP copy: `--no-mcp`.

---

## Why these aren't in the marketplace

- **`prettier-format.sh`** — duplicate of VS Code format-on-save for most users. Keeping it as personal opt-in.
- **`settings.template.json` / `mcp.template.json`** — every user's settings + MCP set differ. Templates only.
