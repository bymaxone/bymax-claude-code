# 🌐 Bymax Web Verify

> Real-browser verification for web apps, powered by the [`agent-browser`](https://github.com/vercel-labs/agent-browser) CLI (Vercel Labs). One-command setup, a `SessionStart` reminder when the CLI is missing, and a verify command that drives a live browser — navigate, interact, screenshot, read console/errors.

This plugin **depends on** `agent-browser` but never bundles it — the same "require, don't embed" approach as [`bymax-mobile`](../bymax-mobile) (which depends on Xcode / the Android SDK). `agent-browser` is `~93%` lighter on context than the Playwright MCP because it returns compact snapshot **refs** (`@e1`, `@e2`) instead of a full accessibility tree.

## Install

```bash
claude plugin marketplace add bymaxone/bymax.claude-code
claude plugin install bymax-web-verify@bymax-claude-code
```

Then, once (or after a fresh macOS install), let Claude install the CLI + browser:

```
/bymax-web-verify:setup
```

That's the whole "format-my-Mac" recovery path: install the plugin, run `/bymax-web-verify:setup`, done.

## What you get

| Command                      | What it does                                                                                                                |
| ---------------------------- | --------------------------------------------------------------------------------------------------------------------------- |
| `/bymax-web-verify:setup`    | One-shot, idempotent install of the `agent-browser` CLI **and** its Chrome for Testing engine, finished by a live smoke test. |
| `/bymax-web-verify:verify`   | Drives a real browser to confirm a change works: opens a URL (default: your local dev server), exercises the path, and reports PASS/FAIL with screenshot + console/page errors. |

Plus a **`SessionStart` hook** that stays silent when the CLI is present, and — only when it's missing — nudges Claude to offer `/bymax-web-verify:setup`. It never installs anything unprompted and never blocks the session.

## Why a separate plugin (not a bundled copy)

- **Licensing & updates.** `agent-browser` is Apache-2.0 and ships its own version-matched skills (`core`, `dogfood`, `electron`, …). Pinning a copy would drift; depending on the global CLI keeps the skills in sync.
- **Optional weight.** Pure React Native projects (see `bymax-mobile`) don't need a browser. Web targets (the Next.js / Vite + React templates) do.

## Prerequisites

- **Node.js + npm** — `agent-browser` is a global npm package. `/bymax-web-verify:setup` checks for these first and points you at `nvm` if missing.
- **macOS / Linux** with enough disk for Chrome for Testing (downloaded by `agent-browser install`).
- A **running dev server** (or an explicit URL) when you run `/bymax-web-verify:verify`. It auto-probes ports `3000, 5173, 8080, 4321, 3001`.

## Manual install (if you skip the command)

```bash
npm install -g agent-browser
agent-browser install            # downloads Chrome for Testing
agent-browser --version          # verify
```

## Relationship to the rest of the toolkit

| Step                          | Plugin              |
| ----------------------------- | ------------------- |
| Plan the work                 | `bymax-workflow`    |
| Write code (TDD) + review     | `bymax-quality`     |
| Verify logic / tests pass     | `/bymax-workflow:verify` |
| **Verify it works in a browser** | **`bymax-web-verify`** |
| Run native mobile             | `bymax-mobile`      |

## License

MIT — see [root LICENSE](../../LICENSE). The `agent-browser` CLI itself is Apache-2.0 and is installed separately.
