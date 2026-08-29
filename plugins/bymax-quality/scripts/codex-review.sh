#!/usr/bin/env bash
#
# codex-review.sh — optional independent second review via the Codex CLI.
#
# Runs `codex exec review` against a scope the caller resolved, and prints the
# review verbatim. It is a SECOND OPINION, never a gate: the Bymax verdict is
# computed without it.
#
# Contract (never violated):
#   - ALWAYS exits 0. A missing CLI, an expired session, a rate limit, a
#     timeout or a parse failure are all reported as status lines, never as
#     failures that could stall /bymax-quality:code-review.
#   - NEVER prompts, NEVER installs anything, NEVER writes to the repo.
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
#
# Usage:
#   codex-review.sh --target uncommitted [--budget <sec>]
#   codex-review.sh --target base   --ref <branch> [--budget <sec>]
#   codex-review.sh --target commit --ref <sha>    [--budget <sec>]
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
POLL_INTERVAL=2

emit() { printf '%s\n' "$*"; }
status_only() { emit "CODEX_STATUS: $1"; [ "${2:-}" = "" ] || emit "$2"; exit 0; }

while [ "$#" -gt 0 ]; do
  case "$1" in
    --target|--ref|--budget)
      # `shift 2` is a no-op when the flag is the last argument, which would spin
      # this loop forever on the same token — refuse instead.
      [ "$#" -ge 2 ] || status_only "unsupported-target" "$1 requires a value"
      case "$1" in
        --target) TARGET="$2" ;;
        --ref)    REF="$2" ;;
        --budget) BUDGET="$2" ;;
      esac
      shift 2
      ;;
    *) shift ;;
  esac
done

case "${BUDGET}" in
  ''|*[!0-9]*) BUDGET=300 ;;
esac

# --- Build the codex scope flags -------------------------------------------
# `codex exec review` understands exactly three scopes. Anything else the
# calling skill supports (a single file, a ref range not ending at HEAD) has no
# equivalent, and is reported rather than silently reviewed as the wrong thing.
codex_args=()
case "${TARGET}" in
  uncommitted) codex_args=(--uncommitted) ;;
  base)   [ -n "${REF}" ] || status_only "unsupported-target" "--target base requires --ref"
          codex_args=(--base "${REF}") ;;
  commit) [ -n "${REF}" ] || status_only "unsupported-target" "--target commit requires --ref"
          codex_args=(--commit "${REF}") ;;
  *) status_only "unsupported-target" "no codex scope for target '${TARGET}'" ;;
esac

# Validate the ref before spending a Codex run on it. Given an unresolvable ref,
# `codex exec review` exits 0 and returns "Commit X does not exist" as its final
# message — which would otherwise be reported as a successful review.
if [ -n "${REF}" ] && ! git rev-parse --verify -q "${REF}" >/dev/null 2>&1; then
  status_only "unsupported-target" "ref '${REF}' does not resolve in this repository"
fi

# --- Availability gates (both free: no network, no tokens) -----------------
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

use_json=0
if command -v jq >/dev/null 2>&1 || command -v python3 >/dev/null 2>&1; then
  use_json=1
  codex_args+=(--json)
fi

# Keep stderr: it carries the reason a run failed (rate limit, expired plan,
# blocked egress). Discarding it would leave the caller with a bare exit code,
# which is exactly the "explain why it degraded" job this script exists to do.
codex exec review "${codex_args[@]}" --ephemeral >"${raw}" 2>"${err}" &
codex_pid=$!

waited=0
while kill -0 "${codex_pid}" 2>/dev/null; do
  if [ "${waited}" -ge "${BUDGET}" ]; then
    # Grouped and redirected so bash's own job-termination notice
    # ("Terminated: 15") stays out of the caller's stderr.
    { kill -TERM "${codex_pid}"
      sleep 2
      kill -KILL "${codex_pid}"
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
  status_only "failed" "codex exited ${codex_rc}${reason:+ — ${reason}}"
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
[ -n "${review}" ] || status_only "failed" "codex produced no readable review"

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
