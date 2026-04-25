# 🎁 Bymax All-in-One

> Meta-plugin. Installs `bymax-workflow` + `bymax-quality` + `bymax-bootstrap` + `bymax-mobile` in one command.

## Install

```bash
claude plugin marketplace add bymaxone/bymax.claude-code
claude plugin install bymax-all@bymax-claude-code
```

## What you get

Everything from the four sibling plugins:

- 🧭 [`bymax-workflow`](../bymax-workflow/) — phased planning + execution (`/spec`, `/roadmap`, `/phase-tasks`, `/task`, `/brainstorm`, `/plan`, `/verify`, `/checkpoint`, `/standards` skill).
- 🛡️ [`bymax-quality`](../bymax-quality/) — review, TDD, tester skill, six sub-agents, secret-scanner + console-log-scan hooks.
- 🏗️ [`bymax-bootstrap`](../bymax-bootstrap/) — `/bootstrap` and `/upgrade-standards` with 20 templates.
- 📱 [`bymax-mobile`](../bymax-mobile/) — `/sim-ios` and `/sim-android` for Expo / React Native projects.

## When to use this vs picking individual plugins

- **Just starting** → `bymax-all`. Easier mental model, all tools available.
- **Already have your own equivalents** for some areas → install only what you're missing (`bymax-workflow` if you don't have a planning chain, `bymax-quality` if you don't have review/TDD, `bymax-bootstrap` if you don't have project scaffolding).

## License

MIT — see [root LICENSE](../../LICENSE).
