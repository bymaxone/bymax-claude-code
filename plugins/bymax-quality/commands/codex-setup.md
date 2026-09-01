---
description: 'Get the Codex CLI ready so /bymax-quality:code-review can run its independent second review. Diagnoses what is missing (binary, session, or nothing), installs Codex through the right channel for the platform (Homebrew cask on macOS, npm elsewhere), walks the user through the interactive login, and verifies the result with a real review run instead of trusting the exit code. Idempotent and safe to re-run; never needed for the rest of the plugin, which works without Codex. Triggers: "instalar codex", "configurar codex", "codex setup", "preparar segunda revisão", "install codex", "codex nao funciona", "/bymax-quality:codex-setup".'
---

# Codex setup

`/bymax-quality:code-review` runs an independent review through the Codex CLI in every
mode, and a second one when it is given `--adversarial`. This command makes the first
available, and explains the second.

Everything here is optional. Without Codex the review command works exactly as it always
did — it reports `Status: absent` in one line and computes the same verdict. Nothing in
this plugin *depends* on Codex; it only gets a second opinion when one is available.

## Step 0 — Diagnose before changing anything

Three checks, all local and instant. Run them first and only fix what is actually broken.

```bash
command -v codex                 # is the binary on PATH?
codex login status               # exit 0 = active session, exit 1 = "Not logged in"
codex --version
```

| Result | State | Go to |
| --- | --- | --- |
| `command -v codex` finds nothing | not installed | Step 1 |
| found, `codex login status` exits 1 | installed, no session | Step 2 |
| found, `codex login status` exits 0 | ready | Step 3 (verify) |

`codex login status` reads the local credential store — no network call, no token spent.
An expired session is therefore free to detect, which is why the review script probes with
it before every run.

For a deeper picture (install method, PATH consistency, git, state DBs), run
`codex doctor`. Use it when something behaves oddly, not as a routine check.

## Step 1 — Install

Pick the channel that matches the machine. Ask the user which they prefer only when both
apply and neither is already in use by their other tools.

**macOS with Homebrew** — preferred there, it self-updates with `brew upgrade`:

```bash
brew install --cask codex
```

**Anywhere with Node.js** — the cross-platform route:

```bash
npm install -g @openai/codex
```

Then confirm the binary resolves, and re-run Step 0:

```bash
command -v codex && codex --version
```

> **Do not mix channels.** Installing through both leaves two binaries and an ambiguous
> PATH. `codex doctor` reports the active install method and every `codex` on PATH — read
> it before adding a second one. To upgrade an existing install, use `codex update`, or
> the channel's own command (`brew upgrade --cask codex`, `npm update -g @openai/codex`).

## Step 2 — Authenticate

```bash
codex login
```

**This step is the user's, not yours.** `codex login` opens a browser for the ChatGPT
sign-in flow and waits for a callback — it cannot be completed from a tool call. Ask the
user to run it themselves; in Claude Code they can type `! codex login` to run it in the
session so the output lands in the conversation.

Two ways to authenticate, and the difference is billing:

| Method | Command | Billing |
| --- | --- | --- |
| ChatGPT account *(usual)* | `codex login` | the user's ChatGPT plan quota |
| API key | `printenv OPENAI_API_KEY \| codex login --with-api-key` | the OpenAI account, per token |

The API-key path is the one to use on a headless machine, where no browser can open. Over
plain SSH without port forwarding, `codex login` cannot complete.

Confirm before moving on — the exact string matters less than the exit code:

```bash
codex login status    # "Logged in using ChatGPT" / "Logged in using an API key", exit 0
```

## Step 3 — Verify with a real run

An exit code is not proof the reviewer works. Run the plugin's own script against a real
commit and read what comes back:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/codex-review.sh" \
  --target commit --ref "$(git rev-parse --short HEAD)" --budget 300
```

Then, if the openai-codex plugin is installed, exercise the adversarial path too — nothing
else will, since Review C is opt-in and this is the one place setup can prove it works. The
run above cannot produce its statuses, so a green standard run says nothing about it. Give
it a scope that exists: on a clean tree the script now refuses `--target uncommitted`, and
on a branch with nothing ahead of its base it refuses `--target base` — a review of nothing
bills a full turn and returns a verdict on nothing. Run this **from a feature branch with
commits on it**, and name the base yourself rather than deriving it: `refs/remotes/origin/HEAD`
is unset on any clone not made by `git clone`, and a wrong guess reports
`unsupported-target — ref does not resolve`, which reads as "this repository is unsupported"
rather than "that base was a guess".

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/codex-review.sh" \
  --mode adversarial --target base --ref "<your default branch, e.g. origin/main>" --budget 300
```

The first line is the contract:

| First line | Meaning |
| --- | --- |
| `CODEX_STATUS: ok` | working — the review follows; setup is done |
| `CODEX_STATUS: ok-unpinned` | working, but not over exactly the requested scope — the `CODEX_SCOPE:` line on the next line says why (either mode; the script header lists every cause). The report treats its findings as real and its silence as nothing |
| `CODEX_STATUS: absent` | the binary is still not on this shell's PATH → back to Step 1 |
| `CODEX_STATUS: unauthenticated` | login did not persist → back to Step 2 |
| `CODEX_STATUS: failed` | the CLI ran and exited non-zero, returned nothing readable, or (adversarial mode) returned a parse-failure page or a review without `Target:`/`Verdict:` — see troubleshooting |
| `CODEX_STATUS: timeout` | exceeded the budget; retry with a larger `--budget` |
| `CODEX_STATUS: unsupported-target` | the requested scope has no Codex equivalent, or nothing to review: a file path, a ref range not ending at HEAD, `--target commit` in adversarial mode, a clean tree for `--target uncommitted`, an empty `<ref>...HEAD` on a clean tree (the verification example below hits this on the default branch itself — run it from a feature branch), or a base with no shared history |
| `CODEX_STATUS: adversarial-absent` | adversarial mode only: the openai-codex plugin or node is missing, **or the installed plugin version is not one the script has verified** — the second line says which; this command fixes neither, see below |
| `CODEX_STATUS: bad-invocation` | the command line was wrong (a flag without its value, an unknown flag or `--mode`) — not a Codex problem |

Expect roughly **40–60 seconds**, largely independent of diff size. A run that returns no
findings is a normal, healthy result — it is not evidence the setup failed.

## No configuration is required

Codex needs no `~/.codex/config.toml` entry for this integration. The review runs on
defaults. In standard mode the script passes only a scope flag, `--ephemeral` (so review
runs do not accumulate in the user's session history), `--output-last-message`, and explicit
`sandbox_mode=read-only` / `approval_policy=never` overrides; in adversarial mode the
plugin runtime pins the equivalents itself over the app-server protocol. If the user already keeps a config
for their own Codex use, leave it alone — do not add settings on their behalf.

## The Codex plugin — needed for one of the two reviews

`/bymax-quality:code-review` runs **two** Codex reviews. This command sets up the binary
and session that both need; only the standard one is complete at that point.

- **Review B, standard** — `codex exec review`. Needs the binary and an active session,
  nothing else. That is what this command delivers.
- **Review C, adversarial** — **opt-in, and off unless `/bymax-quality:code-review` is given
  `--adversarial`.** The adversarial stance lives in the OpenAI **Codex plugin** for Claude
  Code — plugin `codex`, marketplace `openai-codex`, from `openai/codex-plugin-cc`, installed
  with `claude plugin marketplace add openai/codex-plugin-cc` then
  `claude plugin install codex@openai-codex` — and Review C drives that plugin's
  `codex-companion.mjs` runtime directly. The flag is the consent boundary: upstream marks
  its own adversarial command `disable-model-invocation`, so a model must not start that
  billed run on its own, and no command in this toolkit is user-only. Without the plugin
  installed it reports `adversarial-absent` and nothing else changes.

Note what is *not* being called there. The plugin's own `/codex:review` and
`/codex:adversarial-review` are marked `disable-model-invocation`, so a skill cannot
invoke them and must not pretend to be the user in order to. The runtime underneath them
carries no such gate.

So: this command cannot fix `adversarial-absent`, and its second line says what can:

| Second line says | Remedy |
| --- | --- |
| plugin not found among installed, enabled plugins | install it — `claude plugin marketplace add openai/codex-plugin-cc`, then `claude plugin install codex@openai-codex` — or, if it is installed but off, `claude plugin enable codex@openai-codex` |
| node is required by the openai-codex plugin runtime | the runtime is a Node script — install Node.js and put it on the **non-interactive** shell's PATH, which is the one this script runs under |
| the claude CLI is not on PATH / `claude plugin list` failed / neither jq nor python3 | the plugin list could not be read — fix that tool, not the plugin |
| version `X` is not a verified version | the script's contract with that runtime is undocumented and was read in the listed versions only — the message names them, and `COMPANION_VERIFIED_VERSIONS` in `scripts/codex-review.sh` is the source. Installing a listed version is not an option: `claude plugin install` takes no version. So either wait for the plugin to be re-verified, point `BYMAX_CODEX_COMPANION` at a checkout of a verified version (the next row — an override clears the gate), or run the unverified one anyway with `BYMAX_CODEX_COMPANION_ALLOW_UNVERIFIED=1` — the user's explicit decision |
| a project-local or pinned install | point `BYMAX_CODEX_COMPANION` at its `codex-companion.mjs` |

If the user only wants the standard second opinion, they need nothing beyond this command.

## Troubleshooting

| Symptom | Cause | Fix |
| --- | --- | --- |
| `absent` right after a successful install | the shell's PATH predates the install | open a new shell, or check `codex doctor` → *PATH entries* |
| `unauthenticated` right after `codex login` | the browser flow never completed, or a different `CODEX_HOME` is in play | re-run `codex login`; check `codex doctor` → `CODEX_HOME` |
| `failed` on every run | rate limit, expired plan, or network egress blocked | run `codex exec review --uncommitted` directly and read its stderr |
| `failed` only in one repository | not a git repo, or the scope is empty | confirm with `git rev-parse --show-toplevel` and `git status` |
| `timeout` on a large change | budget too small | the review command uses 120 s in `quick`, 180 s in `full`, 600 s in `deep`; the script accepts 30–3600: a 1–4-digit value outside that is clamped to the nearest bound, anything else (five digits, non-numeric) falls back to 300 — either way the timeout line says which |
| two `codex` binaries on PATH | installed via both brew and npm | remove one; `codex doctor` names the active install |

## When you are done

Tell the user plainly which state they ended in — ready, or still missing something and
why. Do not report success on the strength of an install command's exit code alone; report
it on the strength of Step 3 returning `CODEX_STATUS: ok`.
