#!/usr/bin/env bash
#
# Validate marketplace.json + every plugin.json in this repo.
# Used by CI and locally before pushing.
#
# Checks:
#   1. .claude-plugin/marketplace.json is valid JSON and has required fields.
#   2. Every plugin listed in marketplace.json has a corresponding plugin.json.
#   3. Every plugin.json is valid JSON and has required fields.
#   4. Every command/agent/skill path declared in plugin.json actually exists.
#   5. Every command file has a YAML frontmatter `description` field.
#   6. Every agent file has frontmatter with `name`, `description`, and `tools`.
#   7. Every shell hook is executable (chmod +x).
#   8. Every shell script passes shellcheck (if installed).
#
# Exit codes:
#   0 — all valid
#   1 — at least one validation error

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

if [[ -t 1 ]]; then
  GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; BLUE='\033[0;34m'; NC='\033[0m'
else
  GREEN=''; YELLOW=''; RED=''; BLUE=''; NC=''
fi

ok()      { printf "${GREEN}  ✓${NC} %s\n" "$*"; }
warn()    { printf "${YELLOW}  ⚠${NC} %s\n" "$*"; }
fail()    { printf "${RED}  ✗${NC} %s\n" "$*" >&2; ((errors++)); }
section() { printf "${BLUE}==>${NC} %s\n" "$*"; }

errors=0

if ! command -v jq >/dev/null 2>&1; then
  printf "${RED}jq is required but not installed.${NC}\n" >&2
  printf "Install: brew install jq  (macOS)  |  apt-get install jq  (Debian/Ubuntu)\n" >&2
  exit 1
fi

cd "${REPO_ROOT}" || { printf "Cannot cd into repo root: %s\n" "${REPO_ROOT}" >&2; exit 1; }

# ---------------------------------------------------------------------------
# 1. Validate .claude-plugin/marketplace.json
# ---------------------------------------------------------------------------

section "Validating .claude-plugin/marketplace.json"

MP_FILE=".claude-plugin/marketplace.json"
if [[ ! -f "${MP_FILE}" ]]; then
  fail "${MP_FILE} not found"
  exit 1
fi

if ! jq empty "${MP_FILE}" 2>/dev/null; then
  fail "${MP_FILE} is not valid JSON"
  exit 1
fi
ok "${MP_FILE} is valid JSON"

for field in name version plugins; do
  if [[ "$(jq -r ".${field} // empty" "${MP_FILE}")" == "" ]]; then
    fail "${MP_FILE} missing required field: ${field}"
  else
    ok "${MP_FILE} has .${field}"
  fi
done

# ---------------------------------------------------------------------------
# 2. Validate every plugin
# ---------------------------------------------------------------------------

# Returns 0 if file has a YAML frontmatter block (--- ... ---) at the top
# AND the named field is present and non-empty.
has_frontmatter_field() {
  local file="$1"
  local field="$2"

  # Frontmatter must be lines 1..N where lines 1 and N are exactly "---".
  if [[ "$(head -n 1 "${file}")" != "---" ]]; then
    return 1
  fi

  awk -v field="${field}" '
    NR == 1 && $0 == "---" { in_fm=1; next }
    in_fm && $0 == "---" { in_fm=0; exit }
    in_fm {
      # Match "field: value" with non-empty value.
      pat="^[[:space:]]*" field "[[:space:]]*:[[:space:]]*[^[:space:]].*$"
      if ($0 ~ pat) found=1
    }
    END { exit (found ? 0 : 1) }
  ' "${file}"
}

plugin_paths=$(jq -r '.plugins[].path' "${MP_FILE}")

while IFS= read -r plugin_path; do
  [[ -z "${plugin_path}" ]] && continue

  section "Validating plugin: ${plugin_path}"

  if [[ ! -d "${plugin_path}" ]]; then
    fail "Plugin directory does not exist: ${plugin_path}"
    continue
  fi

  PLUGIN_JSON="${plugin_path}/plugin.json"
  if [[ ! -f "${PLUGIN_JSON}" ]]; then
    fail "${PLUGIN_JSON} not found"
    continue
  fi

  if ! jq empty "${PLUGIN_JSON}" 2>/dev/null; then
    fail "${PLUGIN_JSON} is not valid JSON"
    continue
  fi
  ok "${PLUGIN_JSON} is valid JSON"

  for field in name version description; do
    if [[ "$(jq -r ".${field} // empty" "${PLUGIN_JSON}")" == "" ]]; then
      fail "${PLUGIN_JSON} missing required field: ${field}"
    fi
  done

  # 2.a. Verify all referenced commands/agents files exist + carry correct frontmatter.
  while IFS= read -r ref; do
    [[ -z "${ref}" ]] && continue
    target="${plugin_path}/${ref#./}"
    if [[ ! -f "${target}" ]]; then
      fail "${PLUGIN_JSON} references missing command file: ${ref} (resolved: ${target})"
      continue
    fi
    if ! has_frontmatter_field "${target}" "description"; then
      fail "Command ${target} is missing YAML frontmatter 'description' field"
    fi
  done < <(jq -r '.commands[]? // empty' "${PLUGIN_JSON}")

  while IFS= read -r ref; do
    [[ -z "${ref}" ]] && continue
    target="${plugin_path}/${ref#./}"
    if [[ ! -f "${target}" ]]; then
      fail "${PLUGIN_JSON} references missing agent file: ${ref} (resolved: ${target})"
      continue
    fi
    for fm_field in name description tools; do
      if ! has_frontmatter_field "${target}" "${fm_field}"; then
        fail "Agent ${target} is missing YAML frontmatter '${fm_field}' field"
      fi
    done
  done < <(jq -r '.agents[]? // empty' "${PLUGIN_JSON}")

  # 2.b. Verify skills resolve to either ${path}/SKILL.md or ${path}.md.
  while IFS= read -r ref; do
    [[ -z "${ref}" ]] && continue
    target="${plugin_path}/${ref#./}"
    skill_md="${target}/SKILL.md"
    if [[ ! -f "${skill_md}" ]] && [[ ! -f "${target}.md" ]]; then
      fail "${PLUGIN_JSON} references missing skill: ${ref} (expected ${skill_md} or ${target}.md)"
    fi
  done < <(jq -r '.skills[]? // empty' "${PLUGIN_JSON}")

  ok "Plugin ${plugin_path} structure is consistent"

done <<< "${plugin_paths}"

# ---------------------------------------------------------------------------
# 3. Verify every shell script is executable
# ---------------------------------------------------------------------------

section "Verifying shell scripts are executable"

shell_scripts=()
for f in plugins/*/hooks/*.sh personal/*.sh scripts/*.sh; do
  [[ -f "${f}" ]] || continue
  shell_scripts+=("${f}")
  if [[ ! -x "${f}" ]]; then
    fail "${f} is not executable. Run: chmod +x ${f}"
  fi
done

if [[ "${#shell_scripts[@]}" -gt 0 ]]; then
  ok "Checked ${#shell_scripts[@]} shell scripts for +x"
else
  warn "No shell scripts found"
fi

# ---------------------------------------------------------------------------
# 4. Lint shell scripts with shellcheck (optional)
# ---------------------------------------------------------------------------

section "Linting shell scripts with shellcheck"

if command -v shellcheck >/dev/null 2>&1; then
  if [[ "${#shell_scripts[@]}" -gt 0 ]]; then
    # SC1091 — disabled because shellcheck cannot follow dynamic source paths in this repo.
    # SC2059 — disabled because we deliberately put color escapes in printf format strings.
    if shellcheck -e SC1091,SC2059 "${shell_scripts[@]}" 2>&1; then
      ok "All shell scripts pass shellcheck"
    else
      fail "shellcheck reported issues"
    fi
  fi
else
  warn "shellcheck not installed — skipping (install with: brew install shellcheck)"
fi

# ---------------------------------------------------------------------------
# 5. Verify required project-level files exist
# ---------------------------------------------------------------------------

section "Verifying required project files"

REQUIRED_FILES=(
  "README.md"
  "LICENSE"
  "CONTRIBUTING.md"
  "CHANGELOG.md"
  "SECURITY.md"
  "CODE_OF_CONDUCT.md"
  ".gitignore"
  "templates/CLAUDE.md"
  "templates/AGENTS.md"
  "templates/README.md"
  "personal/settings.template.json"
  "personal/mcp.template.json"
)

for f in "${REQUIRED_FILES[@]}"; do
  if [[ -f "${f}" ]]; then
    ok "${f} exists"
  else
    fail "${f} is missing"
  fi
done

# ---------------------------------------------------------------------------
# 6. Summary
# ---------------------------------------------------------------------------

echo
if [[ "${errors}" -eq 0 ]]; then
  printf "${GREEN}✓ All validations passed.${NC}\n"
  exit 0
else
  printf "${RED}✗ ${errors} validation error(s) found.${NC}\n" >&2
  exit 1
fi
