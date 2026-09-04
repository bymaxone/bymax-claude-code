#!/bin/bash
# qa-probe — an HTTP probe that captures the full request and response as
# evidence for a bymax-qa finding.
#
# It is a thin curl wrapper: it records what was sent and what came back to a
# file under the run's evidence directory, redacts obvious credentials from the
# saved copy, and prints the status code. The qa-guard hook still governs which
# host it may reach — this script does not bypass the scope, it documents the
# probe.
#
# Usage:
#   qa-probe.sh --out <evidence-dir> --name <finding-id> [curl args...] <url>
#
# Example:
#   qa-probe.sh --out .claude/qa/evidence/2026-09-04-ab12cd/QA-012 --name step2 \
#     -X POST http://localhost:3000/auth/refresh -H 'Content-Type: application/json' \
#     -d '{"refreshToken":"..."}'
#
# Exit code mirrors curl's; 3 on a usage error.

set -u

out=""
name="probe"
args=()

usage() { echo "usage: qa-probe.sh --out <evidence-dir> --name <id> [curl args...] <url>" >&2; exit 3; }

while [ $# -gt 0 ]; do
  case "$1" in
    # Guard the value so a trailing `--out`/`--name` with no argument gives the
    # usage error, not a `set -u` "unbound variable" abort.
    --out)  [ $# -ge 2 ] || usage; out="$2"; shift 2 ;;
    --name) [ $# -ge 2 ] || usage; name="$2"; shift 2 ;;
    *)      args+=("$1"); shift ;;
  esac
done

if [ -z "$out" ] || [ "${#args[@]}" -eq 0 ]; then
  usage
fi

if ! command -v curl >/dev/null 2>&1; then
  echo "qa-probe: curl not found" >&2
  exit 3
fi

# --name becomes part of the evidence filename, so a `/` or `..` in it would
# escape the confined output directory. Keep it a simple token.
case "$name" in
  "" | */* | *..*) echo "qa-probe: --name must be a simple token (no '/' or '..'): $name" >&2; exit 3 ;;
esac

# curl's own output-directing flags would write files anywhere the process can,
# outside the confined evidence dir and unseen by the PreToolUse guard. qa-probe
# captures the evidence itself, so refuse them.
prev_arg=""
for a in "${args[@]}"; do
  # A file-backed request body (`--data @payload.json`, `-d @f`, `--data-binary
  # @f`) sends bytes qa-probe never sees, so the evidence would record the
  # literal `@file`, not the request — an incomplete capture. Reject it; inline
  # the body instead so the evidence is the real request.
  case "$prev_arg" in
    -d | --data | --data-binary | --data-ascii | --data-raw)
      case "$a" in @*) echo "qa-probe: a file-backed request body ('$prev_arg $a') is not captured in evidence — inline the body so the capture is complete" >&2; exit 3 ;; esac ;;
  esac
  case "$a" in
    -d@* | --data=@* | --data-binary=@* | --data-ascii=@*)
      echo "qa-probe: a file-backed request body ('$a') is not captured in evidence — inline the body so the capture is complete" >&2; exit 3 ;;
  esac
  prev_arg="$a"
  case "$a" in
    # Long output/config flags (exact or =value): curl writes files or loads a
    # config the guard cannot see.
    --output | --remote-name | --remote-name-all | --remote-header-name \
      | --dump-header | --trace | --trace-ascii | --trace-config \
      | --cookie-jar | --etag-save | --config | --libcurl | --stderr | --output-dir \
      | --output=* | --dump-header=* | --trace=* | --trace-ascii=* | --cookie-jar=* | --etag-save=* | --config=* | --libcurl=* | --stderr=* | --output-dir=*)
      echo "qa-probe: output/config curl flag '$a' is not allowed — qa-probe captures the evidence itself, and the guard cannot see a file it writes" >&2
      exit 3 ;;
    # Any other long flag is fine here (redaction and the guard handle the rest).
    --*) : ;;
    # Single-dash SHORT flags, including bundled clusters (-sO, -sD, -sc, -sK)
    # and glued values (-ofile): curl's O/o/D/c/J short options direct output
    # and -K loads a config. Match a single-dash cluster that contains any.
    -*[OoDcJK]*)
      echo "qa-probe: output/config curl short flag in '$a' is not allowed — qa-probe captures the evidence itself" >&2
      exit 3 ;;
  esac
done

# Evidence stays inside THIS project's .claude/qa/ workspace. The PreToolUse
# guard cannot police a file write this script makes through Bash, so confine it
# here too, anchored to $PWD/.claude/qa — a bare substring test would accept
# `/tmp/.claude/qa/x`, another project's tree, or `myfile.claude/qa/`.
case "$out" in
  *..*) echo "qa-probe: --out must not contain '..' (got: $out)" >&2; exit 3 ;;
esac
case "$out" in
  /*) abs_out="$out" ;;
  *)  abs_out="$PWD/$out" ;;
esac
qa_root="$PWD/.claude/qa"
case "$abs_out" in
  "$qa_root"/* | "$qa_root") : ;;
  *) echo "qa-probe: --out must be inside ${qa_root} (got: $out)" >&2; exit 3 ;;
esac

# A lexical prefix check is not enough: the audited repo is untrusted, and a
# symlink already under .claude/qa (e.g. evidence -> ../../src) would let the
# write follow it outside the workspace. Resolve the deepest EXISTING ancestor
# physically (symlinks followed) and confirm it is still under the physical QA
# root before creating or writing anything.
[ -d "$qa_root" ] || { echo "qa-probe: no .claude/qa workspace under $PWD" >&2; exit 3; }
qa_phys=$(cd "$qa_root" && pwd -P) || { echo "qa-probe: cannot resolve $qa_root" >&2; exit 3; }
anc="$abs_out"
while [ ! -e "$anc" ]; do anc=$(dirname "$anc"); done
anc_phys=$(cd "$anc" && pwd -P) || { echo "qa-probe: cannot resolve $anc" >&2; exit 3; }
case "$anc_phys/" in
  "$qa_phys"/*) : ;;
  *) echo "qa-probe: --out resolves outside ${qa_phys} (a symlink in .claude/qa?) — refusing" >&2; exit 3 ;;
esac

mkdir -p "$out"
stamp=$(date -u +%Y%m%dT%H%M%SZ)
# A unique per-invocation suffix (pid + a random) so two probes with the same
# --name in the same second do not derive the same filename and overwrite each
# other's evidence.
base="$out/${name}-${stamp}-$$-${RANDOM}"

# Redact common credential shapes from any text we persist. A backstop — the
# auditor still redacts values by hand in the finding. Header-style secrets
# (Authorization, Cookie, Set-Cookie) are redacted to end of line, because the
# value has spaces (`Bearer <token>`, `name=v; Path=/`) and a token-stopping
# match would leave the secret behind the first space. Field-style secrets in a
# JSON/kv body are redacted by value.
redact() {
  sed -E \
    -e 's#(https?://)[^/@[:space:]"'\'']*:[^/@[:space:]"'\'']*@#\1<redacted>@#g' \
    -e 's/(authorization:[[:space:]]*).*/\1<redacted>/I' \
    -e 's/(set-cookie:[[:space:]]*).*/\1<redacted>/I' \
    -e 's/(cookie:[[:space:]]*).*/\1<redacted>/I' \
    -e 's/(^|[[:space:]'\''"])([A-Za-z0-9-]*(auth|key|token|secret|password|apikey|api-key|session|csrf)[A-Za-z0-9-]*:[[:space:]]*)[^[:space:]'\''"]+/\1\2<redacted>/I' \
    -e 's/(Bearer[[:space:]]+)[A-Za-z0-9._~+/=-]+/\1<redacted>/g' \
    -e 's/("?[A-Za-z0-9_-]*(token|password|passwd|secret|api[_-]?key|apikey|session|csrf|xsrf|auth|jwt|credential|cookie)[A-Za-z0-9_-]*"?[[:space:]]*[:=][[:space:]]*")[^"]*/\1<redacted>/Ig' \
    -e 's/("?[A-Za-z0-9_-]*(token|password|passwd|secret|api[_-]?key|apikey|session|csrf|xsrf|auth|jwt|credential|cookie)[A-Za-z0-9_-]*"?[[:space:]]*[:=][[:space:]]*)[^"[:space:],}]+/\1<redacted>/Ig' \
    -e 's/((-u|--user|-b|--cookie|-U|--proxy-user|-E|--cert|--key|--pass)[[:space:]]+)'\''[^'\'']*'\''/\1<redacted>/g' \
    -e 's/((-u|--user|-b|--cookie|-U|--proxy-user|-E|--cert|--key|--pass)[[:space:]]+)"[^"]*"/\1<redacted>/g' \
    -e 's/((-u|--user|-b|--cookie|-U|--proxy-user|-E|--cert|--key|--pass)[[:space:]]+)[^[:space:]]+/\1<redacted>/g' \
    -e 's/((^|[?&"'\''{,;[:space:]])(code|otp|pin|nonce|id_token|access_token|refresh_token|client_secret)"?[[:space:]]*[:=][[:space:]]*"?)[^"&[:space:],}]+/\1<redacted>/Ig'
}

# -i includes response headers; -sS is quiet but shows errors; -w prints the
# status on its own line for the caller. The response is captured into a
# variable first, then redacted into the evidence file — never read and written
# in one pipeline.
# -q (must be first) disables ~/.curlrc, so a default config file cannot add a
# proxy, a redirect, or an output directive the scope guard never saw.
# --noproxy '*' ignores any HTTP_PROXY/HTTPS_PROXY/ALL_PROXY in the environment,
# so a probe reaches the allow-listed host directly, never via an unlisted proxy.
raw=$(curl -q --noproxy '*' -isS -w '\nHTTP_STATUS:%{http_code}\n' "${args[@]}" 2>&1)
rc=$?
# curl's -w line is appended last, so take the LAST HTTP_STATUS match — a
# response body containing a line `HTTP_STATUS:...` cannot spoof the real code.
code=$(printf '%s\n' "$raw" | awk -F: '/^HTTP_STATUS:/{v=$2} END{print v}')

# The args print one per line, so a credential flag and its value (`-u`
# `alice:pass`) land on separate lines that a same-line regex cannot pair. Walk
# the args: redact the value that FOLLOWS a credential flag, and the value GLUED
# to one (`-ualice:pass`, `--user=alice:pass`), before the per-line redact runs.
redact_args() {
  local prev="" a
  for a in "${args[@]}"; do
    case "$prev" in
      -u | --user | -b | --cookie | -U | --proxy-user | -E | --cert | --key | --pass | --tlspassword)
        printf '%s\n' "<redacted>"; prev="$a"; continue ;;
    esac
    case "$a" in
      -u?* | -b?* | -U?* | -E?*)         printf '%s\n' "$a" | sed -E 's/^(-[a-zA-Z]).*/\1<redacted>/' ;;
      --user=* | --cookie=* | --proxy-user=* | --pass=* | --tlspassword=* | --cert=* | --key=*)
        printf '%s\n' "$a" | sed -E 's/^(--[a-z-]+=).*/\1<redacted>/' ;;
      *) printf '%s\n' "$a" | redact ;;
    esac
    prev="$a"
  done
}

{
  echo "# qa-probe ${name} @ ${stamp}"
  echo "## request (curl args, redacted)"
  redact_args
  echo "## response (redacted)"
  printf '%s\n' "$raw" | redact
} > "${base}.txt"

echo "status=${code:-error}  evidence=${base}.txt"

# Mirror curl's exit status (0 on any HTTP response — a 401/500 is data, not a
# probe failure; non-zero only when curl could not complete, e.g. DNS or refused
# connection), so a caller can tell a reached endpoint from an unreachable one.
exit "$rc"
