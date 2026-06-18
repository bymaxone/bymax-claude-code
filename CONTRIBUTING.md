# Contributing to Bymax Claude Code

Thanks for considering a contribution! This toolkit is built and used in production every day, so changes go through a deliberate review.

---

## 🐛 Reporting bugs

Open an issue with:

- **Version** — output of `claude --version` and the marketplace version (see `.claude-plugin/marketplace.json`).
- **Reproduction** — exact slash command + minimal repo state that triggers the bug.
- **Expected vs actual** — one sentence each.
- **Logs** — relevant snippet (redact any token/credential).

For **security vulnerabilities** (e.g., a regex bypass in `secret-scanner.sh`), do **not** open a public issue. Email `security@bymax.one`.

---

## 💡 Proposing a new command, skill, or agent

Open an issue first with the `proposal` label. Cover:

1. **Goal** — what user need it solves.
2. **Trigger** — when should it be invoked (auto via description, or explicit `/name`).
3. **Sketch** — rough description of what the command/skill body would do.
4. **Why it belongs here** — vs being its own plugin.

We'll discuss before any code is written. This avoids duplicate work and keeps the toolkit focused.

---

## 🛠️ Local development

```bash
# Clone
git clone https://github.com/bymaxone/bymax-claude-code.git
cd bymax-claude-code

# Validate the marketplace + every plugin
./scripts/validate.sh
# (this delegates to `claude plugin validate` so it stays in sync with upstream)

# Test locally — install the marketplace from the local path
claude plugin marketplace add ./
claude plugin install bymax-workflow@bymax-claude-code
claude plugin install bymax-quality@bymax-claude-code
claude plugin install bymax-bootstrap@bymax-claude-code
claude plugin install bymax-mobile@bymax-claude-code

# Restart Claude Code, then verify your changes
```

---

## ✅ Pull-request checklist

Before opening a PR, verify:

- [ ] Each new `commands/*.md` has a YAML frontmatter `description` field with **clear English** triggers (PT/EN both welcome). If the description contains inline `Word: ` patterns, wrap it in single quotes.
- [ ] Each new `agents/*.md` has `name`, `description`, `tools`, `model` (≥ `sonnet` — no `haiku`).
- [ ] Each new `skills/*/SKILL.md` follows the official Claude Code skill format.
- [ ] Each new `hooks/*.sh` is `chmod +x` and has an `exit 0` happy path. Plugin-level hooks are wired via `<plugin>/hooks/hooks.json`.
- [ ] Every test `it()` in any included test has a block comment (scenario + rule it protects).
- [ ] No new `// @ts-ignore`, `// eslint-disable*`, `as any`, or other suppression comments.
- [ ] `marketplace.json` and every touched `plugin.json` (under `<plugin>/.claude-plugin/plugin.json`) validate via `./scripts/validate.sh`.
- [ ] If you bumped a plugin version, you also bumped the marketplace version (semver appropriately — see [Versioning](#versioning)).
- [ ] You updated [`CHANGELOG.md`](./CHANGELOG.md) with a one-liner under the appropriate section.
- [ ] Commit messages follow [Conventional Commits](https://www.conventionalcommits.org/) (e.g., `feat(workflow): add /release command`).

---

## 🏷️ Versioning

We follow [Semantic Versioning](https://semver.org/):

- **MAJOR** — breaking changes to existing slash command behavior, removed commands, changed plugin layouts.
- **MINOR** — new commands, new skills, new agents, new templates (additive).
- **PATCH** — bug fixes, docs, internal refactors that don't change behavior.

Marketplace and individual plugins version independently. Bump **both** when a plugin changes.

---

## 🎯 What we want

- New slash commands or skills that **generalize** patterns from real projects.
- Better stack templates (Vue, Svelte, SolidStart, Astro, Remix, etc.).
- Hardening for `secret-scanner.sh` (more patterns, lower false positives).
- Improvements to the `tester` skill for new test runners.
- Better agent prompts.
- Polished READMEs and docs.

---

## 🚫 What we don't want

- Project-specific commands (e.g., `/sim` for one app) — keep those in your own `.claude/`.
- Vendor lock-in to a paid service.
- Anything that ships secrets, API keys, or PII.
- Anything that bypasses quality gates (`--no-verify`, `// @ts-ignore`, etc.).
- Skills that duplicate `bymax-quality` or `bymax-workflow` without a clear differentiator.

---

## 📜 Code of conduct

Be kind, be precise, assume good intent. See [CODE_OF_CONDUCT.md](./CODE_OF_CONDUCT.md).

---

Questions? Open a [Discussion](https://github.com/bymaxone/bymax-claude-code/discussions).
