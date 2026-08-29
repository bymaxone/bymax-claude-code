---
description: 'Get the Codex CLI ready so /bymax-quality:code-review can run its independent second review. Diagnoses what is missing (binary, session, or nothing), installs Codex through the right channel for the platform (Homebrew cask on macOS, npm elsewhere), walks the user through the interactive login, and verifies the result with a real review run instead of trusting the exit code. Idempotent and safe to re-run; never needed for the rest of the plugin, which works without Codex. Triggers: "instalar codex", "configurar codex", "codex setup", "preparar segunda revisão", "install codex", "codex nao funciona", "/bymax-quality:codex-setup".'
---

# Codex setup

`/bymax-quality:code-review` runs a **second, independent review** through the Codex CLI in
its `full` and `deep` modes. This command makes that reviewer available.

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

The first line is the contract:

| First line | Meaning |
| --- | --- |
| `CODEX_STATUS: ok` | working — the review follows; setup is done |
| `CODEX_STATUS: absent` | the binary is still not on this shell's PATH → back to Step 1 |
| `CODEX_STATUS: unauthenticated` | login did not persist → back to Step 2 |
| `CODEX_STATUS: failed` | the CLI ran and exited non-zero — see troubleshooting |
| `CODEX_STATUS: timeout` | exceeded the budget; retry with a larger `--budget` |

Expect roughly **40–60 seconds**, largely independent of diff size. A run that returns no
findings is a normal, healthy result — it is not evidence the setup failed.

## No configuration is required

Codex needs no `~/.codex/config.toml` entry for this integration. The review runs on
defaults, and the script passes only a scope flag, `--ephemeral` (so review runs do not
accumulate in the user's session history) and `--json`. If the user already keeps a config
for their own Codex use, leave it alone — do not add settings on their behalf.

The OpenAI **Codex plugin** for Claude Code is also not required, and installing it does
not help here: its `/codex:review` and `/codex:adversarial-review` are marked
`disable-model-invocation`, so a skill cannot call them. This integration deliberately
depends on the `codex` binary alone.

## Troubleshooting

| Symptom | Cause | Fix |
| --- | --- | --- |
| `absent` right after a successful install | the shell's PATH predates the install | open a new shell, or check `codex doctor` → *PATH entries* |
| `unauthenticated` right after `codex login` | the browser flow never completed, or a different `CODEX_HOME` is in play | re-run `codex login`; check `codex doctor` → `CODEX_HOME` |
| `failed` on every run | rate limit, expired plan, or network egress blocked | run `codex exec review --uncommitted` directly and read its stderr |
| `failed` only in one repository | not a git repo, or the scope is empty | confirm with `git rev-parse --show-toplevel` and `git status` |
| `timeout` on a large change | budget too small | the review command uses 180 s in `full`, 600 s in `deep` |
| two `codex` binaries on PATH | installed via both brew and npm | remove one; `codex doctor` names the active install |

## When you are done

Tell the user plainly which state they ended in — ready, or still missing something and
why. Do not report success on the strength of an install command's exit code alone; report
it on the strength of Step 3 returning `CODEX_STATUS: ok`.
