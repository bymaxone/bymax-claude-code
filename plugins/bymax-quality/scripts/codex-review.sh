#!/usr/bin/env bash
#
# codex-review.sh — optional independent second review via the Codex CLI.
#
# Runs a review against a scope the caller resolved and prints it verbatim. It is
# a SECOND OPINION, never a gate: the Bymax verdict is computed without it.
#
# Two modes, two different questions:
#   standard     `codex exec review` — is this change correct? Needs only the
#                `codex` binary.
#   adversarial  the openai-codex plugin's `adversarial-review` — is this the
#                right approach at all? Challenges design, tradeoffs and
#                assumptions rather than hunting implementation defects.
#
# The adversarial mode drives the openai-codex plugin's own runtime
# (`codex-companion.mjs`) instead of reimplementing it. That plugin marks
# `/codex:adversarial-review` as `disable-model-invocation: true`, so the slash
# command cannot be called from a skill — but the runtime underneath it is a
# plain Node script that locates its own prompts via `import.meta.url`, so it
# runs fine when invoked by absolute path. Reusing it means the adversarial
# prompt keeps tracking upstream instead of drifting in a copy here.
#
# On whether that is a bypass of upstream's boundary — it was raised in review
# and is answered here rather than left to be re-argued each time:
#   - `disable-model-invocation` gates the slash-command WRAPPER: the piece
#     that asks the user "wait or background?" and echoes output verbatim. The
#     runtime carries no such flag, and upstream's own `codex-rescue` subagent
#     invokes that same runtime (`task`) from an agent.
#   - The consent the flag protects is "a model must not start a billed Codex
#     run on its own". Here the billed run is started because the USER invoked
#     `/bymax-quality:code-review` — a user-only command in this toolkit — and
#     opted into this integration by installing the plugin. Review B starts an
#     equally billed `codex exec review` on the same authority.
#   - What the flag cannot express is "this runtime is internal": that is
#     addressed by the version pin below, not by pretending the wrapper was
#     the boundary.
# If upstream ever publishes a supported invocation surface for the
# adversarial review, prefer it and delete this mode's direct call.
#
# The two modes are meant to be launched as two concurrent background shells by
# the caller, so they cost wall-clock only once.
#
# Contract (never violated):
#   - ALWAYS exits 0. A missing CLI, an expired session, a rate limit, a
#     timeout or a parse failure are all reported as status lines, never as
#     failures that could stall /bymax-quality:code-review.
#   - NEVER prompts, NEVER installs anything, NEVER writes to the repo. In
#     standard mode this script pins the sandbox and approval policy per
#     invocation (`-c sandbox_mode=read-only -c approval_policy=never`), so it
#     holds regardless of the user's Codex config. In adversarial mode the
#     guarantee is upstream's, not this script's: the plugin runtime starts its
#     review thread with a hardcoded `sandbox: "read-only"` and an
#     `approvalPolicy` defaulting to `"never"` (lib/codex.mjs), and the app-server
#     protocol takes no `-c` overrides for this script to add. Verified against
#     openai-codex 1.0.6 — a reader auditing this contract must re-check it
#     against the version `find_companion` actually resolves.
#   - First stdout line is always `CODEX_STATUS: <status>`, so the caller can
#     branch deterministically without interpreting prose.
#
# Statuses:
#   ok                 review ran over exactly the requested scope; report follows
#   ok-unpinned        adversarial only: review ran, but the change exceeded the
#                      runtime's inline-diff limit, so the reviewer collected its
#                      own scope. Findings are reportable; silence is not evidence.
#   absent             codex CLI is not installed
#   unauthenticated    no active Codex session (logged out or expired)
#   unsupported-target the caller's scope cannot be expressed as a codex flag
#   timeout            the run exceeded --budget
#   failed             codex exited non-zero, or produced no usable output
#   adversarial-absent --mode adversarial, but the openai-codex plugin (or node)
#                      is not installed. Only this mode is affected.
#
# Usage:
#   codex-review.sh [--mode standard|adversarial] --target uncommitted [--budget <sec>]
#   codex-review.sh [--mode standard|adversarial] --target base --ref <branch> [--budget <sec>]
#   codex-review.sh --target commit --ref <sha> [--budget <sec>]   # standard only
#
# The adversarial runtime is resolved through `claude plugin list --json` — the
# installed, enabled plugin with id `codex@openai-codex`, and nothing else. Set
# BYMAX_CODEX_COMPANION to an explicit codex-companion.mjs path to override that
# (a project-local install, or a pinned version); the override is trusted as the
# user's own decision.
#
# Notes for the caller:
#   - `codex exec review` rejects custom instructions whenever a scope flag is
#     present, so this review is unsteered by design. That independence is the
#     point: it is what makes the second opinion worth having.
#   - The output is NOT deterministic. Two runs over the same commit return
#     overlapping but different findings. Treat it as sampling, not as a gate.

set -u

# Every number this script reasons about, named once.
DEFAULT_BUDGET=300          # seconds, when --budget is absent or unusable
MIN_BUDGET=30               # below this a run is killed before it can say anything
MAX_BUDGET=3600             # above this bash 3.2's `[` can no longer compare reliably
POLL_INTERVAL=2             # seconds between liveness checks of the review process
KILL_GRACE=2                # seconds between TERM and KILL at budget expiry
CANCEL_DEADLINE=15          # seconds the runtime's `cancel` may take before it is abandoned
REASON_MAX_CHARS=300        # tail of stderr quoted in a `failed` status line
# The plugin runtime inlines the diff in its prompt only under these limits
# (DEFAULT_INLINE_DIFF_MAX_FILES / _BYTES in its lib/git.mjs, openai-codex 1.0.6);
# past them the reviewer collects its own scope.
RUNTIME_INLINE_MAX_FILES=2
RUNTIME_INLINE_MAX_BYTES=262144

BUDGET="${DEFAULT_BUDGET}"
TARGET=""
REF=""
MODE="standard"

emit() { printf '%s\n' "$*"; }
status_only() { emit "CODEX_STATUS: $1"; [ "${2:-}" = "" ] || emit "$2"; exit 0; }

while [ "$#" -gt 0 ]; do
  case "$1" in
    --target=*|--ref=*|--budget=*|--mode=*)
      # `--mode=adversarial` is the form a reader naturally writes. Matching only
      # the space-separated form let it fall through to the catch-all `*) shift`,
      # so the flag was dropped in silence and a standard review was published
      # under the adversarial label.
      flag="${1%%=*}"
      value="${1#*=}"
      case "${flag}" in
        --target) TARGET="${value}" ;;
        --ref)    REF="${value}" ;;
        --budget) BUDGET="${value}" ;;
        --mode)   MODE="${value}" ;;
      esac
      shift
      ;;
    --target|--ref|--budget|--mode)
      # `shift 2` is a no-op when the flag is the last argument, which would spin
      # this loop forever on the same token — refuse instead.
      [ "$#" -ge 2 ] || status_only "unsupported-target" "$1 requires a value"
      case "$1" in
        --target) TARGET="$2" ;;
        --ref)    REF="$2" ;;
        --budget) BUDGET="$2" ;;
        --mode)   MODE="$2" ;;
      esac
      shift 2
      ;;
    *) shift ;;
  esac
done

# One to four digits, then a range check. The digit cap is not cosmetic:
# `/bin/bash` here is 3.2, whose `[` fails with status 2 above 64 bits — a
# status `if` reads as false — so a range check ALONE lets a millisecond value
# through and the timeout branch then never fires. `10#` strips leading zeros.
if [[ "${BUDGET}" =~ ^[0-9]{1,4}$ ]]; then
  BUDGET=$((10#${BUDGET}))
  [ "${BUDGET}" -ge "${MIN_BUDGET}" ] && [ "${BUDGET}" -le "${MAX_BUDGET}" ] || BUDGET="${DEFAULT_BUDGET}"
else
  BUDGET="${DEFAULT_BUDGET}"
fi

case "${MODE}" in
  standard|adversarial) ;;
  *) status_only "unsupported-target" "unknown --mode '${MODE}'" ;;
esac

# --- Build the scope flags for the chosen backend --------------------------
# `codex exec review` understands exactly three scopes; the plugin runtime
# understands two and has no per-commit form. Anything else the calling skill
# supports (a single file, a ref range not ending at HEAD) has no equivalent,
# and is reported rather than silently reviewed as the wrong thing.
codex_args=()
if [ "${MODE}" = "standard" ]; then
  case "${TARGET}" in
    uncommitted) codex_args=(--uncommitted) ;;
    base)   [ -n "${REF}" ] || status_only "unsupported-target" "--target base requires --ref"
            codex_args=(--base "${REF}") ;;
    commit) [ -n "${REF}" ] || status_only "unsupported-target" "--target commit requires --ref"
            codex_args=(--commit "${REF}") ;;
    *) status_only "unsupported-target" "no codex scope for target '${TARGET}'" ;;
  esac
else
  case "${TARGET}" in
    uncommitted) codex_args=(--scope working-tree) ;;
    base)   [ -n "${REF}" ] || status_only "unsupported-target" "--target base requires --ref"
            codex_args=(--scope branch --base "${REF}") ;;
    # The plugin runtime reviews a working tree or a branch, never a single
    # commit. Reporting that beats reviewing the wrong diff under a label the
    # reader will trust.
    *) status_only "unsupported-target" "adversarial mode has no scope for target '${TARGET}'" ;;
  esac
fi

# Validate the ref before spending a Codex run on it. Given an unresolvable ref,
# `codex exec review` exits 0 and returns "Commit X does not exist" as its final
# message — which would otherwise be reported as a successful review.
if [ -n "${REF}" ] && ! git rev-parse --verify -q "${REF}" >/dev/null 2>&1; then
  status_only "unsupported-target" "ref '${REF}' does not resolve in this repository"
fi

# --- Will the adversarial reviewer see exactly this scope? ------------------
# Decided HERE, before launch, against the tree the runtime is about to read —
# not after the review, against a tree that may have moved in the meantime.
#
# Three ways the answer is no. Past the runtime's inline limits it stops putting
# the diff in the prompt and tells the agent to collect its own with git
# commands, so the validated scope flags bind nothing. And on a branch target
# it resolves mergeBase..HEAD, which drops uncommitted work the calling command
# deliberately keeps in scope. Measurements mirror the runtime's own commands
# (staged and unstaged diffed separately, `--binary`); untracked contents are
# NOT in the byte count because they are not in the runtime's either. The file
# count is checked first because it alone usually decides, and the byte diff
# is the expensive one.
scope_unpinned=0
scope_reason=""
if [ "${MODE}" = "adversarial" ]; then
  diff_flags=(--binary --no-ext-diff --submodule=diff)
  case "${TARGET}" in
    uncommitted)
      scope_files="$( { git diff --cached --name-only; git diff --name-only;
                        git ls-files --others --exclude-standard; } 2>/dev/null \
                      | sort -u | grep -c .)"
      if [ "${scope_files:-0}" -gt "${RUNTIME_INLINE_MAX_FILES}" ]; then
        scope_unpinned=1
        scope_reason="${scope_files} changed files exceed the runtime's inline limit of ${RUNTIME_INLINE_MAX_FILES}"
      else
        scope_bytes="$(( $(git diff --cached "${diff_flags[@]}" 2>/dev/null | wc -c)
                       + $(git diff "${diff_flags[@]}" 2>/dev/null | wc -c) ))"
        if [ "${scope_bytes}" -gt "${RUNTIME_INLINE_MAX_BYTES}" ]; then
          scope_unpinned=1
          scope_reason="${scope_bytes} diff bytes exceed the runtime's inline limit of ${RUNTIME_INLINE_MAX_BYTES}"
        fi
      fi ;;
    base)
      dirty_files="$( { git diff --name-only HEAD; git ls-files --others --exclude-standard; } 2>/dev/null \
                     | sort -u | grep -c .)"
      if [ "${dirty_files:-0}" -gt 0 ]; then
        scope_unpinned=1
        scope_reason="${dirty_files} uncommitted files are outside the mergeBase..HEAD range the runtime reviews"
      else
        scope_files="$(git diff --name-only "${REF}...HEAD" 2>/dev/null | grep -c .)"
        if [ "${scope_files:-0}" -gt "${RUNTIME_INLINE_MAX_FILES}" ]; then
          scope_unpinned=1
          scope_reason="${scope_files} changed files exceed the runtime's inline limit of ${RUNTIME_INLINE_MAX_FILES}"
        else
          scope_bytes="$(git diff "${diff_flags[@]}" "${REF}...HEAD" 2>/dev/null | wc -c | tr -d ' ')"
          if [ "${scope_bytes:-0}" -gt "${RUNTIME_INLINE_MAX_BYTES}" ]; then
            scope_unpinned=1
            scope_reason="${scope_bytes} diff bytes exceed the runtime's inline limit of ${RUNTIME_INLINE_MAX_BYTES}"
          fi
        fi
      fi ;;
  esac
fi

# --- Locate the plugin runtime (adversarial mode only) ---------------------
# Resolved through `claude plugin list`, never by searching the filesystem. The
# runtime is executed with `node` under the user's own permissions — the
# read-only sandbox applies to the Codex thread it starts, not to the Node
# process itself — so whatever this function returns runs with full access to
# the repository and the user's credentials. That makes the selection a trust
# decision, and the only trustworthy answer is "the plugin the user installed
# and enabled", by its exact id. An earlier version globbed
# `*/codex/*/scripts/codex-companion.mjs` and fell back to marketplace
# checkouts: any marketplace shipping a plugin named `codex`, installed or not,
# would have been executed merely by running a code review.
#
# `CLAUDE_PLUGIN_ROOT` cannot help here — it points at THIS plugin.
COMPANION_PLUGIN_ID="codex@openai-codex"

# The runtime contract this script depends on — read-only sandbox pinned per
# thread, `approvalPolicy: never`, the detached broker and its `cancel`,
# CODEX_COMPANION_SESSION_ID scoping, the `--scope`/`--base` flags, and a
# `Verdict:` line in the output — is UNDOCUMENTED. It was verified by reading
# openai-codex 1.0.6. A routine plugin update can change any of it, and the
# failure modes are the bad kind: a run that keeps billing past its budget, or
# a Node process with the user's permissions whose read-only guarantee no
# longer holds. So only versions that were actually read are accepted — an
# exact allowlist, not a range. An earlier draft admitted `1.0.*` while its own
# comment said 1.0.6 was the only version inspected, which is a range hoped
# compatible, not a contract verified. Add a version here only after re-reading
# lib/codex.mjs, lib/broker-lifecycle.mjs, lib/job-control.mjs and
# lib/render.mjs in that version; BYMAX_CODEX_COMPANION_ALLOW_UNVERIFIED=1 runs
# any other version anyway, as the user's own explicit decision.
COMPANION_VERIFIED_VERSIONS="1.0.6"
companion_version=""
companion_record=""

find_companion() {
  # An explicit override is the user's own decision, made in their environment,
  # and is honoured as such. It is the one path that bypasses the identity check.
  if [ -n "${BYMAX_CODEX_COMPANION:-}" ]; then
    [ -f "${BYMAX_CODEX_COMPANION}" ] || return 1
    # No version to report for an override: it is trusted as-is.
    printf '%s\t%s' "override" "${BYMAX_CODEX_COMPANION}"
    return 0
  fi

  command -v claude >/dev/null 2>&1 || return 1
  local listing install_path
  listing="$(claude plugin list --json 2>/dev/null)" || return 1
  [ -n "${listing}" ] || return 1

  # Exact id AND enabled. A disabled plugin is one the user turned off; running
  # its code anyway would override that choice. Version and path come out as
  # one tab-separated line so the two cannot disagree.
  local record
  if command -v jq >/dev/null 2>&1; then
    record="$(printf '%s' "${listing}" | jq -r --arg id "${COMPANION_PLUGIN_ID}" '
      map(select(.id == $id and .enabled == true)) | .[0]
      | select(. != null) | "\(.version // "")\t\(.installPath // "")"' 2>/dev/null)"
  elif command -v python3 >/dev/null 2>&1; then
    record="$(printf '%s' "${listing}" | python3 -c '
import json, sys
wanted = sys.argv[1]
try:
    plugins = json.load(sys.stdin)
except ValueError:
    sys.exit(0)
for plugin in plugins if isinstance(plugins, list) else []:
    if plugin.get("id") == wanted and plugin.get("enabled") is True:
        print(str(plugin.get("version", "")) + "\t" + str(plugin.get("installPath", "")))
        break
' "${COMPANION_PLUGIN_ID}" 2>/dev/null)"
  else
    return 1
  fi

  [ -n "${record}" ] || return 1
  install_path="${record#*	}"
  [ -n "${install_path}" ] || return 1
  [ -f "${install_path}/scripts/codex-companion.mjs" ] || return 1
  # Printed as "<version><TAB><path>": this runs in a command substitution, so
  # a variable set here would not survive — the caller splits the one line.
  printf '%s\t%s' "${record%%	*}" "${install_path}/scripts/codex-companion.mjs"
}

# --- Availability gates (both free: no network, no tokens) -----------------
# Both modes need the same binary and the same credential store, so these gates
# apply to the plugin runtime as they do to a direct call. They do NOT reach the
# same execution path: standard runs `codex exec`, adversarial drives the
# app-server protocol through the runtime's broker.
#
# They run BEFORE the adversarial-only plugin check on purpose. The plugin is
# the shallower prerequisite: checking it first would report `adversarial-absent`
# on a machine that has neither, sending the user to install a plugin when what
# they actually lack is the CLI or a session — the remediation Step 5.5 prints
# for that status explicitly says `codex-setup` will not help.
command -v codex >/dev/null 2>&1 || status_only "absent"

# `codex login status` is a local read of the credential store: exit 0 when a
# session is active, exit 1 ("Not logged in") otherwise. Measured at ~13 ms.
# This is what makes an expired session cost nothing to detect.
codex login status >/dev/null 2>&1 || status_only "unauthenticated"

companion=""
if [ "${MODE}" = "adversarial" ]; then
  command -v node >/dev/null 2>&1 \
    || status_only "adversarial-absent" "node is required by the openai-codex plugin runtime"
  companion_record="$(find_companion)" \
    || status_only "adversarial-absent" "openai-codex plugin not found — install it to enable the adversarial review"
  companion_version="${companion_record%%	*}"
  companion="${companion_record#*	}"
  version_verified=0
  [ "${companion_version}" = "override" ] && version_verified=1
  for verified in ${COMPANION_VERIFIED_VERSIONS}; do
    [ "${companion_version}" = "${verified}" ] && version_verified=1
  done
  if [ "${version_verified}" -eq 0 ] && [ "${BYMAX_CODEX_COMPANION_ALLOW_UNVERIFIED:-0}" != "1" ]; then
    status_only "adversarial-absent" \
      "openai-codex ${companion_version:-?} is not a verified version (verified: ${COMPANION_VERIFIED_VERSIONS}) — the runtime contract this script relies on is undocumented and was read in those versions only; set BYMAX_CODEX_COMPANION_ALLOW_UNVERIFIED=1 to run it anyway"
  fi
fi

# --- Run under a budget -----------------------------------------------------
# macOS ships neither `timeout` nor `gtimeout`, so the budget is enforced with
# a poll-and-kill loop in pure bash.
workdir="$(mktemp -d 2>/dev/null)" || status_only "failed" "cannot create a temp dir"
raw="${workdir}/codex.out"
err="${workdir}/codex.err"

# Set once the review process is launched, cleared once it has been reaped. The
# cleanup below uses it to tell "nothing started yet / already finished" from
# "a billed run is still in flight and this script is going away".
run_active=0

# The plugin runtime scopes job lookup by CODEX_COMPANION_SESSION_ID. An ID-less
# `cancel` resolves the jobs of the current session and refuses when there is
# more than one ("Multiple Codex jobs are active") — so if the user has their own
# `/codex:*` job running when this review times out, a cancel issued under the
# shared session would fail and the billed turn would survive. Giving this run a
# session ID nobody else uses makes the ID-less cancel unambiguous: exactly one
# job carries it. The same variable is exported to the launch and to the cancel,
# and to nothing else.
review_session="bymax-review-$$-$(date +%s)"

# Stop the Codex work this script started, by the most specific means available.
#
# In adversarial mode the plugin runtime does NOT keep Codex inside this
# script's process group: it spawns an app-server broker with `detached: true`
# and `unref()`, so the group signal below cannot reach it. Measured — a review
# abandoned at the budget left `app-server-broker.mjs` and `codex app-server`
# alive and billing for 41 minutes. `cancel` is the runtime's own public remedy:
# it interrupts the Codex turn (which is what bills) and terminates that job's
# process tree, without killing the broker daemon, which is shared per workspace
# and may be serving another session's review.
#
# Three things about that cancel, each learned from a review of the previous
# version:
#   - It is bounded. It talks to the broker over a socket, and a hung broker is
#     exactly the case a timeout is handling; unbounded, it would block here
#     forever and `timeout` would never be emitted.
#   - Its exit status is not its verdict. The runtime exits 0 once it has
#     RESOLVED the job, even when the interrupt RPC failed and the turn is still
#     running. The `--json` payload's `turnInterrupted` is the fact that matters.
#   - A cancel that fails is reported, not swallowed, with the one command that
#     can still reach the run: `/codex:status` cannot show it (it filters by the
#     Claude session id, and this run carries its own), so the remedy is the
#     ID-less cancel under this run's session id.
cancel_failed=0
stop_review() {
  [ "${run_active}" -eq 1 ] || return 0
  if [ "${MODE}" = "adversarial" ] && [ -n "${companion}" ]; then
    local cancel_out="${workdir}/cancel.json" cancel_pid cancel_waited=0
    CODEX_COMPANION_SESSION_ID="${review_session}" \
      node "${companion}" cancel --json >"${cancel_out}" 2>/dev/null &
    cancel_pid=$!
    while kill -0 "${cancel_pid}" 2>/dev/null; do
      if [ "${cancel_waited}" -ge "${CANCEL_DEADLINE}" ]; then
        kill -KILL "${cancel_pid}" 2>/dev/null
        break
      fi
      sleep 1
      cancel_waited=$((cancel_waited + 1))
    done
    wait "${cancel_pid}" 2>/dev/null
    if ! grep -q '"turnInterrupted": *true' "${cancel_out}" 2>/dev/null; then
      # Not a failure if the review simply finished while the cancel was being
      # issued: the front-end process is gone, so there is no turn to reach.
      kill -0 "${codex_pid}" 2>/dev/null && cancel_failed=1
    fi
  fi
  { kill -TERM -- -"${codex_pid}"
    sleep "${KILL_GRACE}"
    kill -KILL -- -"${codex_pid}"
    wait "${codex_pid}"
  } >/dev/null 2>&1
  run_active=0
}

# The trap fires on every exit, including the `status_only` early returns and a
# TERM from whoever backgrounded this script. Without it, killing this script
# leaves the review running: the caller sees the shell end and has no way left
# to reach what it started.
trap 'stop_review; rm -rf "${workdir}"' EXIT
trap 'exit 143' TERM
trap 'exit 130' INT

# Keep stderr: it carries the reason a run failed (rate limit, expired plan,
# blocked egress). Discarding it would leave the caller with a bare exit code,
# which is exactly the "explain why it degraded" job this script exists to do.
#
# `set -m` puts the job in its own process group (pgid == pid). Codex spawns
# child processes of its own, and signalling only the pid at budget expiry
# leaves those children running — the budget would not actually be enforced.
#
# Standard mode: the sandbox and approval policy are pinned rather than
# inherited, so a `~/.codex/config.toml` set to `workspace-write` or
# `danger-full-access` does not hand the reviewer write access; the review text
# is written by `--output-last-message`, the CLI's own way to hand back the
# final message, so no JSONL stream needs parsing.
#
# Adversarial mode: the runtime is invoked WITHOUT its `--background` flag. That
# flag is inert there anyway — `adversarial-review` always runs in the
# foreground and the openai-codex command backgrounds it from the Claude side.
set -m
if [ "${MODE}" = "standard" ]; then
  codex exec review "${codex_args[@]}" --ephemeral \
    -c sandbox_mode="read-only" -c approval_policy="never" \
    --output-last-message "${raw}" \
    >/dev/null 2>"${err}" &
else
  CODEX_COMPANION_SESSION_ID="${review_session}" \
    node "${companion}" adversarial-review "${codex_args[@]}" \
    >"${raw}" 2>"${err}" &
fi
codex_pid=$!
set +m
run_active=1

waited=0
while kill -0 "${codex_pid}" 2>/dev/null; do
  if [ "${waited}" -ge "${BUDGET}" ]; then
    # Re-check liveness before declaring a timeout: a review that finished in
    # the last poll interval is a finished review, not a timed-out one, and
    # its output must not be thrown away.
    kill -0 "${codex_pid}" 2>/dev/null || break
    stop_review
    if [ "${cancel_failed}" -eq 1 ]; then
      status_only "timeout" "exceeded ${BUDGET}s — and the cancel FAILED, so the Codex run may still be billing. Stop it with: CODEX_COMPANION_SESSION_ID=${review_session} node \"${companion}\" cancel"
    fi
    status_only "timeout" "exceeded ${BUDGET}s"
  fi
  sleep "${POLL_INTERVAL}"
  waited=$((waited + POLL_INTERVAL))
done

wait "${codex_pid}" 2>/dev/null
codex_rc=$?
run_active=0
if [ "${codex_rc}" -ne 0 ]; then
  # Codex writes a long agent trace to stderr; only the tail carries the error.
  reason="$(tail -n 3 "${err}" 2>/dev/null | tr '\n' ' ' | cut -c1-"${REASON_MAX_CHARS}")"
  status_only "failed" "${MODE} review exited ${codex_rc}${reason:+ — ${reason}}"
fi

# --- Accept the review ------------------------------------------------------
review="$(cat "${raw}" 2>/dev/null)"
[ -n "${review}" ] || status_only "failed" "${MODE} review produced no readable output"

# Non-empty stdout is not a review. The plugin runtime exits 0 when the *turn*
# completed even if Codex returned unparseable JSON — it renders a failure page
# to stdout instead, and that page quotes the raw model output in a text fence,
# which for a review typically contains a `Verdict:` line of its own. So the
# page is rejected by its own markers first, and only then is the structure a
# real review has required: the renderer's `Target:` line, then `Verdict:`.
# Positive tests fail closed if upstream changes its format.
if [ "${MODE}" = "adversarial" ]; then
  if printf '%s\n' "${review}" | grep -qE 'did not return valid structured JSON|unexpected review shape'; then
    reason="$(printf '%s\n' "${review}" | grep -E 'Parse error|unexpected review shape' | head -n 1 | cut -c1-"${REASON_MAX_CHARS}")"
    status_only "failed" "adversarial review returned unparseable output — ${reason:-see the runtime failure page}"
  fi
  if ! printf '%s\n' "${review}" | grep -qE '^[[:space:]]*Target:' \
    || ! printf '%s\n' "${review}" | grep -qE '^[[:space:]]*Verdict:'; then
    reason="$(printf '%s\n' "${review}" | grep -vE '^[[:space:]]*$' | head -n 2 | tr '\n' ' ' | cut -c1-"${REASON_MAX_CHARS}")"
    status_only "failed" "adversarial review has no Target/Verdict lines — ${reason}"
  fi
fi

# Codex reports absolute paths; make them repo-relative so the findings line up
# with the rest of the report.
repo_root="$(git rev-parse --show-toplevel 2>/dev/null || true)"
if [ -n "${repo_root}" ]; then
  # The left-hand side of `${var//…}` is a glob pattern, so a repo path holding
  # `*`, `?`, `[` or `\` would match the wrong thing — escape them first.
  escaped_root="$(printf '%s' "${repo_root}" | sed 's/[][*?\\]/\\&/g')"
  review="${review//${escaped_root}\//}"
fi

# A distinct status, not a note under `ok`: the caller branches on the status
# line and never on prose, so the one fact that changes how the review may be
# used has to live in the status. The review is still published — its findings
# are about this change — but its silence is not evidence.
if [ "${scope_unpinned}" -eq 1 ]; then
  emit "CODEX_STATUS: ok-unpinned"
  emit "CODEX_SCOPE: self-collected — ${scope_reason}; the reviewer chose its own scope"
else
  emit "CODEX_STATUS: ok"
fi
emit "${review}"
exit 0
