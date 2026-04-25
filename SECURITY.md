# Security Policy

## 🛡️ Reporting a vulnerability

If you discover a security vulnerability in this project — for example, a regex bypass in `secret-scanner.sh`, a command-injection vector in any hook script, or any way to exfiltrate user secrets — please **do not** open a public issue.

Email **security@bymax.one** with:

- A clear description of the vulnerability.
- Steps to reproduce.
- The version (`marketplace.json` `version` field).
- Optional: a suggested fix.

You will receive an acknowledgement within **48 hours**. We will work with you on a fix and a coordinated disclosure timeline (typical: 30–90 days, depending on severity).

---

## 🔒 What's in scope

- All shipped slash commands, skills, agents, hooks, and templates.
- Any way the toolkit could leak secrets, send unauthorized network requests, or write to unintended paths.
- Pattern bypasses in `secret-scanner.sh` (false negatives that let credentials through).

## 📤 What's out of scope

- Vulnerabilities in upstream tools (`claude` CLI itself, ESLint, Prettier, Husky, etc.) — please report those to their maintainers.
- Vulnerabilities in vendor third-party skills under `vendor/` — please report those to their original authors (links in `vendor/*/ATTRIBUTION.md`).
- False positives in `secret-scanner.sh` (benign strings that match a credential pattern). These are usability bugs, not security bugs — open a normal issue.

---

## 🔑 Hardening guidance for users

When using this toolkit:

1. **Never paste credentials in chat** — the `secret-scanner.sh` hook only catches Write/Edit/MultiEdit, not Bash. Use `~/.zshrc` + macOS Keychain for tokens (see `personal/README.md`).
2. **Review the diff** before approving any commit. Claude is asked to never auto-commit, but always verify.
3. **Audit `vendor/` content** before installing on a security-sensitive project — third-party scripts are MIT-licensed but you should still understand what they do.
4. **Keep `secret-scanner.sh` enabled** in `.claude/settings.json` PreToolUse hooks. Disabling it removes the credential gate.

---

## 🔍 What this toolkit does NOT do

- Does **not** send any data to bymax.one or any third-party server.
- Does **not** modify your global git config, credentials helper, or shell profile (except via opt-in `personal/install.sh` lines that are clearly labeled).
- Does **not** install npm packages globally without explicit user consent (the `/bootstrap` command **proposes** dev-deps but you confirm before install).
- Does **not** include any analytics, telemetry, or auto-update mechanism.

---

Thank you for keeping the ecosystem safe. 🙏
