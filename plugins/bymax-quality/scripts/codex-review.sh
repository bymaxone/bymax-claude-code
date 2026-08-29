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

# Digits alone are not enough. `/bin/bash` here is 3.2, whose `[` cannot compare
# beyond 64 bits: a caller passing milliseconds makes `[ "${waited}" -ge "${BUDGET}" ]`
# return 2 forever, so the timeout branch never fires and the poll loop spins while
# codex runs unbounded. `--budget 0` has the opposite failure — it kills a run that
# started milliseconds earlier and calls it a timeout.
case "${BUDGET}" in
  ''|*[!0-9]*) BUDGET=300 ;;
esac
# Strip leading zeros so the digit-count test below measures magnitude, not
# padding ("0000600" is 600, not an out-of-range seven-digit value).
BUDGET="${BUDGET#"${BUDGET%%[!0]*}"}"
[ -n "${BUDGET}" ] || BUDGET=0
# Five or more digits is at least 10000: over the cap, and — more importantly —
# past the point where bash 3.2's `[` can compare at all. It fails with status 2,
# which `if` reads as false, so a numeric range check ALONE silently lets the
# value through and the timeout branch then never fires. Bound the length first.
case "${BUDGET}" in
  ?????*) BUDGET=300 ;;
esac
if [ "${BUDGET}" -lt 30 ] || [ "${BUDGET}" -gt 3600 ]; then
  BUDGET=300
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
    # splitting to expand, and that means a `shellcheck disable` comment for a
    # style choice, which is the kind of suppression this toolkit's own review
    # blocks. (validate.sh does pass `-e SC1091,SC2059`; those are two documented
    # project-wide exclusions, not a per-line silence bolted on to keep a
    # particular construct.)
    shopt -s nullglob
    case "${family}" in
      installed) matches=( "${HOME}"/.claude/plugins/cache/*/codex/*/scripts/codex-companion.mjs ) ;;
      checkout)  matches=( "${HOME}"/.claude/plugins/marketplaces/*/plugins/codex/scripts/codex-companion.mjs ) ;;
    esac
    shopt -u nullglob
    [ "${#matches[@]}" -gt 0 ] || continue

    # Several versions can be cached side by side. Sorting the whole path is
    # wrong: the FIRST wildcard is the marketplace name, so `sort -V` compares
    # that segment and a second marketplace shipping a `codex` plugin would win
    # on its name whatever version it carries. Sort on the version segment
    # alone, and carry the path alongside it.
    local entry version
    sorted=""
    for entry in "${matches[@]}"; do
      # .../<marketplace>/codex/<version>/scripts/codex-companion.mjs
      version="${entry%/scripts/codex-companion.mjs}"
      version="${version##*/}"
      sorted="${sorted}${version}	${entry}"$'\n'
    done
    if printf '%s\n' 1 | sort -V >/dev/null 2>&1; then
      sorted="$(printf '%s' "${sorted}" | sort -V)"
    else
      sorted="$(printf '%s' "${sorted}" | sort)"
    fi
    sorted="${sorted##*$'\n'}"
    printf '%s' "${sorted#*	}"
    return 0
  done
  return 1
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
  companion="$(find_companion)" \
    || status_only "adversarial-absent" "openai-codex plugin not found — install it to enable the adversarial review"
fi

# --- Run under a budget -----------------------------------------------------
# macOS ships neither `timeout` nor `gtimeout`, so the budget is enforced with
# a poll-and-kill loop in pure bash.
workdir="$(mktemp -d 2>/dev/null)" || status_only "failed" "cannot create a temp dir"

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
# A cancel that fails is reported, not swallowed: the caller must know a run may
# still be billing, because nothing else in this script can reach it.
cancel_failed=0
stop_review() {
  [ "${run_active}" -eq 1 ] || return 0
  if [ "${MODE}" = "adversarial" ] && [ -n "${companion}" ]; then
    CODEX_COMPANION_SESSION_ID="${review_session}" \
      node "${companion}" cancel >/dev/null 2>&1 || cancel_failed=1
  fi
  { kill -TERM -- -"${codex_pid}"
    sleep 2
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
    # stop_review signals the whole process group (note the `-` before the pid)
    # so Codex's own children die with it, and additionally cancels the run
    # through the plugin runtime in adversarial mode, where the billed process
    # is deliberately outside this group.
    stop_review
    if [ "${cancel_failed}" -eq 1 ]; then
      status_only "timeout" "exceeded ${BUDGET}s — and the cancel FAILED: the Codex run may still be billing, check /codex:status"
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

# Non-empty stdout is not a review. The plugin runtime exits 0 when the *turn*
# completed even if Codex returned unparseable JSON — it renders a human-readable
# failure page ("Codex did not return valid structured JSON") to stdout instead.
# Without this check that page is published verbatim under `CODEX_STATUS: ok`,
# and the cross-read counts Review C as an outside voice that examined the diff
# and found nothing.
#
# The test is positive rather than a match on upstream's error prose: every real
# adversarial review ends in a `Verdict:` line. If upstream changes the format,
# this fails closed — `failed` — instead of silently going back to publishing
# failure pages as clean reviews.
if [ "${MODE}" = "adversarial" ] \
  && ! printf '%s\n' "${review}" | grep -qE '^[[:space:]]*Verdict:'; then
  reason="$(printf '%s\n' "${review}" | grep -vE '^[[:space:]]*$' | head -n 2 \
    | tr '\n' ' ' | cut -c1-200)"
  status_only "failed" "adversarial review returned no verdict — ${reason}"
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

emit "CODEX_STATUS: ok"

# --- Is the reported scope the scope that was actually reviewed? ------------
# Only the adversarial path can diverge. The plugin runtime inlines the diff in
# the prompt only while the change stays under its thresholds; past them it sets
# `inputMode: "self-collect"` and instructs the agent to run its own read-only
# git commands instead. The scope flags this script validated then bound nothing:
# the model chooses what to look at, minutes later, against a tree that may have
# moved. On a branch target the runtime also resolves `mergeBase..HEAD`, which
# drops uncommitted work that Step 1 of the calling command deliberately includes.
#
# Thresholds mirror DEFAULT_INLINE_DIFF_MAX_FILES / _BYTES in the runtime's
# lib/git.mjs (openai-codex 1.0.6). They are upstream's numbers, not ours — if
# they drift, this note becomes wrong in the conservative direction (claiming a
# self-collected scope that was in fact inlined), never the dangerous one.
#
# The measurements mirror the runtime's own commands rather than approximating
# them. `git diff HEAD` undercounts a file with both staged and unstaged edits
# (it shows one combined hunk where the runtime sends two), and omits binary
# payloads the runtime includes via `--binary` — so a naive measure could stay
# under the byte limit while the runtime had already crossed it and switched to
# self-collection, and this note would then fail to fire exactly when it mattered.
diff_flags=(--binary --no-ext-diff --submodule=diff)
if [ "${MODE}" = "adversarial" ]; then
  case "${TARGET}" in
    uncommitted)
      # Unique files across staged, unstaged and untracked, as the runtime counts.
      scope_files="$( { git diff --cached --name-only; git diff --name-only;
                        git ls-files --others --exclude-standard; } 2>/dev/null \
                      | sort -u | grep -c .)"
      scope_bytes="$(( $(git diff --cached "${diff_flags[@]}" 2>/dev/null | wc -c)
                     + $(git diff "${diff_flags[@]}" 2>/dev/null | wc -c) ))" ;;
    *)
      scope_files="$(git diff --name-only "${REF}...HEAD" 2>/dev/null | grep -c .)"
      scope_bytes="$(git diff "${diff_flags[@]}" "${REF}...HEAD" 2>/dev/null | wc -c)" ;;
  esac
  scope_files="${scope_files//[[:space:]]/}"
  scope_bytes="${scope_bytes//[[:space:]]/}"
  if [ "${scope_files:-0}" -gt 2 ] || [ "${scope_bytes:-0}" -gt 262144 ]; then
    emit "CODEX_SCOPE: self-collected — ${scope_files} files exceeded the runtime's inline-diff limit; the reviewer chose its own scope"
  fi
fi

emit "${review}"
exit 0
