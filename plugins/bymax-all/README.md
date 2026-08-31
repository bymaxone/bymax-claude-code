# 🎁 Bymax All — Reference Index

> **Docs-only marketplace entry.** Claude Code's plugin manifest does not auto-install dependencies, so this plugin does nothing on its own. Install the seven sibling plugins individually for the complete toolkit.

## Install

```bash
claude plugin marketplace add bymaxone/bymax-claude-code
claude plugin install bymax-workflow@bymax-claude-code
claude plugin install bymax-quality@bymax-claude-code
claude plugin install bymax-bootstrap@bymax-claude-code
claude plugin install bymax-mobile@bymax-claude-code
claude plugin install bymax-web-verify@bymax-claude-code
claude plugin install bymax-pr@bymax-claude-code
claude plugin install bymax-pm@bymax-claude-code
```

## What you get

The complete bymax toolkit (after installing the seven siblings above):

- 🧭 [`bymax-workflow`](../bymax-workflow/) — phased planning + execution (`/bymax-workflow:spec`, `/bymax-workflow:roadmap`, `/bymax-workflow:phase-tasks`, `/bymax-workflow:task`, `/bymax-workflow:brainstorm`, `/bymax-workflow:plan`, `/bymax-workflow:verify`, `/bymax-workflow:checkpoint`, `/bymax-workflow:standards` skill).
- 🛡️ [`bymax-quality`](../bymax-quality/) — review, TDD, tester skill (TypeScript + Rust), seven sub-agents (incl. a Rust reviewer), secret-scanner + console-log-scan hooks.
- 🏗️ [`bymax-bootstrap`](../bymax-bootstrap/) — `/bymax-bootstrap:bootstrap` and `/bymax-bootstrap:upgrade-standards` with 20 templates.
- 📱 [`bymax-mobile`](../bymax-mobile/) — `/bymax-mobile:sim-ios` and `/bymax-mobile:sim-android` for Expo / React Native projects.
- 🌐 [`bymax-web-verify`](../bymax-web-verify/) — `/bymax-web-verify:setup` and `/bymax-web-verify:verify` for real-browser verification (depends on the `agent-browser` CLI).
- 🤖 [`bymax-pr`](../bymax-pr/) — `/bymax-pr:babysit-pr` autonomously drives an open PR to merge-readiness (depends on the `gh` CLI).
- 📋 [`bymax-pm`](../bymax-pm/) — `/bymax-pm:pm`, the Engineering Project Manager that coordinates independent Claude Code peer sessions with task contracts, quality gates, and a persistent board.

## When to use this vs picking individual plugins

- **Just starting** → install all seven. Easier mental model, all tools available.
- **Already have your own equivalents** for some areas → install only what you're missing (`bymax-workflow` if you don't have a planning chain, `bymax-quality` if you don't have review/TDD, `bymax-bootstrap` if you don't have project scaffolding, `bymax-web-verify` for browser checks, `bymax-pr` for PR automation).

## License

MIT — see [root LICENSE](../../LICENSE).
