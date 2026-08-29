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
# The two modes are meant to be launched as two concurrent background shells by
# the caller, so they cost wall-clock only once.
#
# Contract (never violated):
#   - ALWAYS exits 0. A missing CLI, an expired session, a rate limit, a
#     timeout or a parse failure are all reported as status lines, never as
#     failures that could stall /bymax-quality:code-review.
#   - NEVER prompts, NEVER installs anything, NEVER writes to the repo. The
#     sandbox and approval policy are pinned per invocation rather than
#     inherited from the user's Codex config, so this holds regardless of how
#     they have configured Codex for their own use.
#   - First stdout line is always `CODEX_STATUS: <status>`, so the caller can
#     branch deterministically without interpreting prose.
#
# Statuses:
#   ok                 review ran; the report follows the status line
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
# Set BYMAX_CODEX_COMPANION to an explicit codex-companion.mjs path to override
# discovery (a project-local plugin install, or a pinned version).
#
# Notes for the caller:
#   - `codex exec review` rejects custom instructions whenever a scope flag is
#     present, so this review is unsteered by design. That independence is the
#     point: it is what makes the second opinion worth having.
#   - The output is NOT deterministic. Two runs over the same commit return
#     overlapping but different findings. Treat it as sampling, not as a gate.

set -u

BUDGET=300
TARGET=""
REF=""
MODE="standard"
POLL_INTERVAL=2

emit() { printf '%s\n' "$*"; }
status_only() { emit "CODEX_STATUS: $1"; [ "${2:-}" = "" ] || emit "$2"; exit 0; }

while [ "$#" -gt 0 ]; do
  case "$1" in
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

case "${BUDGET}" in
  ''|*[!0-9]*) BUDGET=300 ;;
esac

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

# --- Locate the plugin runtime (adversarial mode only) ---------------------
# Resolved by absolute path because `CLAUDE_PLUGIN_ROOT` points at THIS plugin,
# not at openai-codex. The runtime finds its own prompts relative to itself, so
# an absolute path is all it needs.
find_companion() {
  if [ -n "${BYMAX_CODEX_COMPANION:-}" ]; then
    [ -f "${BYMAX_CODEX_COMPANION}" ] || return 1
    printf '%s' "${BYMAX_CODEX_COMPANION}"
    return 0
  fi

  # Globbed rather than listed: `ls | sort` would split on paths containing
  # spaces, and nullglob makes a miss expand to nothing instead of to the
  # literal pattern.
  #
  # The two locations are searched in order, not merged into one sorted list.
  # `cache/` holds the version the user actually has installed and enabled;
  # `marketplaces/` is the marketplace checkout, which can sit at a different
  # revision entirely. Sorting them together compares unrelated path prefixes
  # and lets "marketplaces" win on the letter m — measured, not hypothetical.
  local family matches=() sorted
  for family in installed checkout; do
    # Each glob is expanded where it is written, rather than stored in a
    # variable and re-split — holding a pattern in a string would need word
    # splitting to expand, which means silencing a shellcheck warning, and this
    # toolkit does not silence linters.
    shopt -s nullglob
    case "${family}" in
      installed) matches=( "${HOME}"/.claude/plugins/cache/*/codex/*/scripts/codex-companion.mjs ) ;;
      checkout)  matches=( "${HOME}"/.claude/plugins/marketplaces/*/plugins/codex/scripts/codex-companion.mjs ) ;;
    esac
    shopt -u nullglob
    [ "${#matches[@]}" -gt 0 ] || continue

    # Several versions can be cached side by side. Prefer the highest, using
    # version sort where it exists so 1.0.10 beats 1.0.9 rather than losing to it.
    if printf '%s\n' 1 | sort -V >/dev/null 2>&1; then
      sorted="$(printf '%s\n' "${matches[@]}" | sort -V)"
    else
      sorted="$(printf '%s\n' "${matches[@]}" | sort)"
    fi
    printf '%s' "${sorted##*$'\n'}"
    return 0
  done
  return 1
}

companion=""
if [ "${MODE}" = "adversarial" ]; then
  command -v node >/dev/null 2>&1 \
    || status_only "adversarial-absent" "node is required by the openai-codex plugin runtime"
  companion="$(find_companion)" \
    || status_only "adversarial-absent" "openai-codex plugin not found — install it to enable the adversarial review"
fi

# --- Availability gates (both free: no network, no tokens) -----------------
# Both modes end up shelling out to the same binary and the same session, so
# these gates apply to the plugin runtime exactly as they do to a direct call.
command -v codex >/dev/null 2>&1 || status_only "absent"

# `codex login status` is a local read of the credential store: exit 0 when a
# session is active, exit 1 ("Not logged in") otherwise. Measured at ~13 ms.
# This is what makes an expired session cost nothing to detect.
codex login status >/dev/null 2>&1 || status_only "unauthenticated"

# --- Run under a budget -----------------------------------------------------
# macOS ships neither `timeout` nor `gtimeout`, so the budget is enforced with
# a poll-and-kill loop in pure bash.
workdir="$(mktemp -d 2>/dev/null)" || status_only "failed" "cannot create a temp dir"
trap 'rm -rf "${workdir}"' EXIT
raw="${workdir}/codex.jsonl"
err="${workdir}/codex.err"

# Only `codex exec review` emits the JSONL stream this script knows how to
# parse. The plugin runtime prints the review as plain text, which needs no
# extraction at all.
use_json=0
if [ "${MODE}" = "standard" ] \
  && { command -v jq >/dev/null 2>&1 || command -v python3 >/dev/null 2>&1; }; then
  use_json=1
  codex_args+=(--json)
fi

# Keep stderr: it carries the reason a run failed (rate limit, expired plan,
# blocked egress). Discarding it would leave the caller with a bare exit code,
# which is exactly the "explain why it degraded" job this script exists to do.
#
# `set -m` puts the job in its own process group (pgid == pid). Codex spawns
# child processes of its own, and signalling only the pid at budget expiry
# leaves those children running — the budget would not actually be enforced.
#
# The sandbox and approval policy are pinned rather than inherited. A user whose
# `~/.codex/config.toml` sets `workspace-write` or `danger-full-access` would
# otherwise hand the reviewer write access to their tree, breaking this script's
# "never writes to the repo" contract; an interactive approval policy would stall
# the run until the budget expired. Both are overridden per invocation, so the
# user's own Codex configuration is left untouched.
#
# The plugin runtime is invoked WITHOUT its `--background` flag on purpose. That
# flag is inert there anyway — `adversarial-review` always runs in the
# foreground, and the openai-codex command backgrounds it from the Claude side
# instead. Detaching it here would put the Codex process outside the group this
# script signals at budget expiry, leaving an orphan run billing against the
# user's account after the review has already been reported as `timeout`.
set -m
if [ "${MODE}" = "standard" ]; then
  codex exec review "${codex_args[@]}" --ephemeral \
    -c sandbox_mode="read-only" -c approval_policy="never" \
    >"${raw}" 2>"${err}" &
else
  node "${companion}" adversarial-review "${codex_args[@]}" \
    >"${raw}" 2>"${err}" &
fi
codex_pid=$!
set +m

waited=0
while kill -0 "${codex_pid}" 2>/dev/null; do
  if [ "${waited}" -ge "${BUDGET}" ]; then
    # Signal the whole process group (note the `-` before the pid), so Codex's
    # own children die with it. Grouped and redirected so bash's job-termination
    # notice ("Terminated: 15") stays out of the caller's stderr.
    { kill -TERM -- -"${codex_pid}"
      sleep 2
      kill -KILL -- -"${codex_pid}"
      wait "${codex_pid}"
    } >/dev/null 2>&1
    status_only "timeout" "exceeded ${BUDGET}s"
  fi
  sleep "${POLL_INTERVAL}"
  waited=$((waited + POLL_INTERVAL))
done

wait "${codex_pid}" 2>/dev/null
codex_rc=$?
if [ "${codex_rc}" -ne 0 ]; then
  # Codex writes a long agent trace to stderr; only the tail carries the error.
  reason="$(tail -n 3 "${err}" 2>/dev/null | tr '\n' ' ' | cut -c1-300)"
  status_only "failed" "${MODE} review exited ${codex_rc}${reason:+ — ${reason}}"
fi

# --- Extract the review -----------------------------------------------------
# With --json the review is the `agent_message` item; without it, stdout is
# already the review text and needs no parsing. Both paths are verified.
extract() {
  if [ "${use_json}" -eq 0 ]; then
    cat "${raw}"
  elif command -v jq >/dev/null 2>&1; then
    jq -r 'select(.type == "item.completed")
           | select(.item.type == "agent_message")
           | .item.text' "${raw}" 2>/dev/null
  else
    python3 -c '
import json, sys
out = []
with open(sys.argv[1], encoding="utf-8", errors="replace") as fh:
    for line in fh:
        line = line.strip()
        if not line:
            continue
        try:
            event = json.loads(line)
        except ValueError:
            continue
        item = event.get("item") or {}
        if event.get("type") == "item.completed" and item.get("type") == "agent_message":
            out.append(item.get("text", ""))
print("\n".join(out))
' "${raw}" 2>/dev/null
  fi
}

review="$(extract)"
[ -n "${review}" ] || status_only "failed" "${MODE} review produced no readable output"

# Codex reports absolute paths; make them repo-relative so the findings line up
# with the rest of the report.
repo_root="$(git rev-parse --show-toplevel 2>/dev/null || true)"
if [ -n "${repo_root}" ]; then
  # The left-hand side of `${var//…}` is a glob pattern, so a repo path holding
  # `*`, `?`, `[` or `\` would match the wrong thing — escape them first.
  escaped_root="$(printf '%s' "${repo_root}" | sed 's/[][*?\\]/\\&/g')"
  review="${review//${escaped_root}\//}"
fi

emit "CODEX_STATUS: ok"
emit "${review}"
exit 0
