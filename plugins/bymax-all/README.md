# 🎁 Bymax All — Reference Index

> **Docs-only marketplace entry.** Claude Code's plugin manifest does not auto-install dependencies, so this plugin does nothing on its own. Install the six sibling plugins individually for the complete toolkit.

## Install

```bash
claude plugin marketplace add bymaxone/bymax.claude-code
claude plugin install bymax-workflow@bymax-claude-code
claude plugin install bymax-quality@bymax-claude-code
claude plugin install bymax-bootstrap@bymax-claude-code
claude plugin install bymax-mobile@bymax-claude-code
claude plugin install bymax-web-verify@bymax-claude-code
claude plugin install bymax-pr@bymax-claude-code
```

## What you get

The complete bymax toolkit (after installing the six siblings above):

- 🧭 [`bymax-workflow`](../bymax-workflow/) — phased planning + execution (`/bymax-workflow:spec`, `/bymax-workflow:roadmap`, `/bymax-workflow:phase-tasks`, `/bymax-workflow:task`, `/bymax-workflow:brainstorm`, `/bymax-workflow:plan`, `/bymax-workflow:verify`, `/bymax-workflow:checkpoint`, `/bymax-workflow:standards` skill).
- 🛡️ [`bymax-quality`](../bymax-quality/) — review, TDD, tester skill, six sub-agents, secret-scanner + console-log-scan hooks.
- 🏗️ [`bymax-bootstrap`](../bymax-bootstrap/) — `/bymax-bootstrap:bootstrap` and `/bymax-bootstrap:upgrade-standards` with 20 templates.
- 📱 [`bymax-mobile`](../bymax-mobile/) — `/bymax-mobile:sim-ios` and `/bymax-mobile:sim-android` for Expo / React Native projects.
- 🌐 [`bymax-web-verify`](../bymax-web-verify/) — `/bymax-web-verify:setup` and `/bymax-web-verify:verify` for real-browser verification (depends on the `agent-browser` CLI).
- 🤖 [`bymax-pr`](../bymax-pr/) — `/bymax-pr:babysit-pr` autonomously drives an open PR to merge-readiness (depends on the `gh` CLI).

## When to use this vs picking individual plugins

- **Just starting** → install all six. Easier mental model, all tools available.
- **Already have your own equivalents** for some areas → install only what you're missing (`bymax-workflow` if you don't have a planning chain, `bymax-quality` if you don't have review/TDD, `bymax-bootstrap` if you don't have project scaffolding, `bymax-web-verify` for browser checks, `bymax-pr` for PR automation).

## License

MIT — see [root LICENSE](../../LICENSE).
