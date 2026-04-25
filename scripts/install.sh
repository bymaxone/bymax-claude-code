#!/usr/bin/env bash
#
# bymax.claude-code — restore script.
#
# Restores the author's full Claude Code setup from this repo into ~/.claude/
# (and ~/.mcp.json for user-scope MCP servers).
# Used after wiping a Mac or setting up a new dev machine.
#
# Usage:
#   ./scripts/install.sh                       (default — symlinks plugins + vendor + personal)
#   ./scripts/install.sh --no-vendor           (skip vendor third-party skills)
#   ./scripts/install.sh --no-personal         (skip personal config)
#   ./scripts/install.sh --no-mcp              (skip ~/.mcp.json copy)
#   ./scripts/install.sh --write-mcp-enabled   (also write ~/.claude/settings.local.json with enabledMcpjsonServers)
#   ./scripts/install.sh --plugins-only        (only the marketplace plugins, no vendor / no personal / no mcp)
#   ./scripts/install.sh --dry-run             (print what would happen, write nothing)
#
# What it does:
#   - Symlinks each plugin's commands/, agents/, skills/, hooks/, templates/ into ~/.claude/<kind>/.
#   - Symlinks vendor skills into ~/.claude/skills/<name>/.
#   - Symlinks personal hooks/commands into ~/.claude/hooks|commands/.
#   - Copies (does NOT symlink) personal/mcp.template.json → ~/.mcp.json so you can edit
#     it without affecting the repo. Skipped if ~/.mcp.json already exists.
#   - Idempotent: existing symlinks are refreshed; existing real files are backed up
#     to <name>.bak-<timestamp> before being replaced.
#
# What it does NOT do:
#   - Does NOT install marketplace plugins via `claude plugin install`. The script
#     prints the exact commands at the end — run them manually after restart.
#   - Does NOT touch ~/.claude/settings.json. Copy personal/settings.template.json
#     manually (it has comments explaining each field).
#   - Does NOT install npm packages or the claude binary. Install Claude Code first.
#   - Does NOT add the github MCP (which needs a PAT). The settings.template.json
#     comments document the exact `claude mcp add` command.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
TARGET="${HOME}/.claude"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"

INCLUDE_VENDOR=true
INCLUDE_PERSONAL=true
INCLUDE_MCP=true
WRITE_MCP_ENABLED=false
DRY_RUN=false

# --- arg parse -------------------------------------------------------------

while [[ $# -gt 0 ]]; do
  case "$1" in
    --no-vendor)          INCLUDE_VENDOR=false; shift ;;
    --no-personal)        INCLUDE_PERSONAL=false; shift ;;
    --no-mcp)             INCLUDE_MCP=false; shift ;;
    --write-mcp-enabled)  WRITE_MCP_ENABLED=true; shift ;;
    --plugins-only)       INCLUDE_VENDOR=false; INCLUDE_PERSONAL=false; INCLUDE_MCP=false; shift ;;
    --dry-run)            DRY_RUN=true; shift ;;
    -h|--help)
      sed -n '2,34p' "$0"
      exit 0 ;;
    *)
      printf "Unknown flag: %s\n" "$1" >&2
      exit 1 ;;
  esac
done

# --- color helpers ---------------------------------------------------------

if [[ -t 1 ]]; then
  GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; BLUE='\033[0;34m'; NC='\033[0m'
else
  GREEN=''; YELLOW=''; RED=''; BLUE=''; NC=''
fi

log()    { printf "${BLUE}==>${NC} %s\n" "$*"; }
ok()     { printf "${GREEN}  ✓${NC} %s\n" "$*"; }
warn()   { printf "${YELLOW}  ⚠${NC} %s\n" "$*"; }
fail()   { printf "${RED}  ✗${NC} %s\n" "$*" >&2; exit 1; }
dry()    { printf "${YELLOW}  [dry-run]${NC} would: %s\n" "$*"; }

# --- safety checks ---------------------------------------------------------

if [[ "${REPO_ROOT}" == "${TARGET}" ]]; then
  fail "REPO_ROOT equals TARGET (${REPO_ROOT}). Move this repo somewhere else (e.g. ~/dotfiles-claude) and re-run."
fi

if [[ "${DRY_RUN}" == false ]]; then
  mkdir -p "${TARGET}"/{commands,agents,skills,hooks,templates}
fi

log "Source : ${REPO_ROOT}"
log "Target : ${TARGET}"
log "Vendor : $([[ "${INCLUDE_VENDOR}"   == true ]] && echo include || echo skip)"
log "Personal: $([[ "${INCLUDE_PERSONAL}" == true ]] && echo include || echo skip)"
log "MCP    : $([[ "${INCLUDE_MCP}"      == true ]] && echo include || echo skip)"
[[ "${DRY_RUN}" == true ]] && warn "DRY RUN — no files will be written"
echo

# --- symlink helper --------------------------------------------------------

# Symlink src → dst, backing up existing real files.
link_one() {
  local src="$1"
  local dst="$2"

  if [[ "${DRY_RUN}" == true ]]; then
    dry "ln -s ${src} ${dst}"
    return 0
  fi

  if [[ -L "${dst}" ]]; then
    rm "${dst}"
    ln -s "${src}" "${dst}"
    ok "refreshed: ${dst}"
  elif [[ -e "${dst}" ]]; then
    local backup="${dst}.bak-${TIMESTAMP}"
    mv "${dst}" "${backup}"
    ln -s "${src}" "${dst}"
    ok "backed up + linked: ${dst} (old → ${backup})"
  else
    ln -s "${src}" "${dst}"
    ok "linked: ${dst}"
  fi
}

# Symlink every direct child of ${src_dir} into ${dst_dir} (file or directory).
link_each_child() {
  local src_dir="$1"
  local dst_dir="$2"

  if [[ ! -d "${src_dir}" ]]; then
    return 0
  fi

  [[ "${DRY_RUN}" == false ]] && mkdir -p "${dst_dir}"
  for child in "${src_dir}"/*; do
    [[ -e "${child}" ]] || continue
    local name; name="$(basename "${child}")"
    link_one "${child}" "${dst_dir}/${name}"
  done
}

# Copy (NOT symlink) src → dst, refusing to overwrite an existing file.
copy_once() {
  local src="$1"
  local dst="$2"

  if [[ "${DRY_RUN}" == true ]]; then
    dry "cp ${src} ${dst}"
    return 0
  fi

  if [[ -e "${dst}" ]]; then
    warn "${dst} already exists — leaving as-is. Diff with: diff ${src} ${dst}"
    return 0
  fi

  cp "${src}" "${dst}"
  ok "copied: ${dst}"
}

# --- 1. plugins ------------------------------------------------------------

log "Installing plugins"
for plugin_dir in "${REPO_ROOT}"/plugins/*/; do
  [[ -d "${plugin_dir}" ]] || continue
  plugin_name="$(basename "${plugin_dir}")"
  echo "  ${BLUE}plugin:${NC} ${plugin_name}"

  link_each_child "${plugin_dir}commands"  "${TARGET}/commands"
  link_each_child "${plugin_dir}agents"    "${TARGET}/agents"
  link_each_child "${plugin_dir}skills"    "${TARGET}/skills"
  link_each_child "${plugin_dir}hooks"     "${TARGET}/hooks"
  link_each_child "${plugin_dir}templates" "${TARGET}/templates"
done
echo

# --- 2. vendor -------------------------------------------------------------

if [[ "${INCLUDE_VENDOR}" == true ]]; then
  log "Installing vendor (third-party MIT-licensed skills)"

  if [[ -d "${REPO_ROOT}/vendor/ecc-skills" ]]; then
    for f in "${REPO_ROOT}"/vendor/ecc-skills/*.md; do
      [[ -e "${f}" ]] || continue
      base="$(basename "${f}")"
      [[ "${base}" == "ATTRIBUTION.md" ]] && continue
      [[ "${base}" == "LICENSE" ]] && continue
      link_one "${f}" "${TARGET}/skills/${base}"
    done
  fi

  if [[ -d "${REPO_ROOT}/vendor/ui-ux-pro-max" ]]; then
    link_one "${REPO_ROOT}/vendor/ui-ux-pro-max" "${TARGET}/skills/ui-ux-pro-max"
  fi
  echo
else
  warn "Skipping vendor (--no-vendor)"
  echo
fi

# --- 3. personal -----------------------------------------------------------

if [[ "${INCLUDE_PERSONAL}" == true ]]; then
  log "Installing personal config"

  [[ -f "${REPO_ROOT}/personal/prettier-format.sh"  ]] && link_one "${REPO_ROOT}/personal/prettier-format.sh"  "${TARGET}/hooks/prettier-format.sh"

  warn "settings.template.json is NOT auto-applied. Copy + edit manually:"
  printf "       cp %s/personal/settings.template.json %s/settings.json\n" "${REPO_ROOT}" "${TARGET}"
  printf "       vi %s/settings.json   # replace {{PLACEHOLDERS}}\n" "${TARGET}"
  echo
else
  warn "Skipping personal (--no-personal)"
  echo
fi

# --- 4. mcp config ---------------------------------------------------------

if [[ "${INCLUDE_MCP}" == true ]]; then
  log "Installing MCP config (~/.mcp.json)"

  if [[ -f "${REPO_ROOT}/personal/mcp.template.json" ]]; then
    copy_once "${REPO_ROOT}/personal/mcp.template.json" "${HOME}/.mcp.json"
  fi

  if [[ "${WRITE_MCP_ENABLED}" == true ]]; then
    settings_local="${TARGET}/settings.local.json"
    enabled_payload='{"enabledMcpjsonServers":["context7","sequential-thinking"]}'

    if [[ "${DRY_RUN}" == true ]]; then
      dry "write ${enabled_payload} to ${settings_local}"
    elif [[ -e "${settings_local}" ]]; then
      warn "${settings_local} already exists — leaving as-is. Diff or merge manually."
      printf "       %s\n" "${enabled_payload}"
    else
      printf '%s\n' "${enabled_payload}" > "${settings_local}"
      ok "wrote: ${settings_local}"
    fi
  else
    warn "Activate the MCPs by writing ~/.claude/settings.local.json (or re-run with --write-mcp-enabled):"
    printf "       echo '{\"enabledMcpjsonServers\":[\"context7\",\"sequential-thinking\"]}' > %s/settings.local.json\n" "${TARGET}"
  fi

  warn "Add the github MCP (needs your PAT — never committed):"
  printf "       claude mcp add github -e GITHUB_PERSONAL_ACCESS_TOKEN=<YOUR_PAT> -- npx -y @modelcontextprotocol/server-github\n"
  echo
else
  warn "Skipping MCP config (--no-mcp)"
  echo
fi

# --- 5. summary ------------------------------------------------------------

log "Done."
echo
echo "Next steps (in order):"
echo "  1. Configure ~/.claude/settings.json from personal/settings.template.json."
echo "  2. (optional) Activate MCPs: write ~/.claude/settings.local.json (see warning above)."
echo "  3. Restart Claude Code so it picks up the new commands, skills, agents, hooks."
echo "  4. Install marketplace plugins:"
echo "       claude plugin marketplace add bymaxone/bymax.claude-code"
echo "       claude plugin install bymax-all@bymax-claude-code"
echo "       claude plugin marketplace add anthropics/claude-plugins-official"
echo "       claude plugin install frontend-design@claude-plugins-official"
echo "       claude plugin marketplace add getsentry/sentry-mcp"
echo "       claude plugin install sentry-mcp@sentry-mcp"
echo "  5. (optional, github MCP) claude mcp add github -e GITHUB_PERSONAL_ACCESS_TOKEN=<PAT> -- npx -y @modelcontextprotocol/server-github"
echo "  6. Verify: launch claude, type '/' — you should see all bymax-* commands."
