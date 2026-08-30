#!/usr/bin/env python3
"""Validate the YAML frontmatter of every command, skill and agent in this repo.

`claude plugin validate` checks the JSON manifests. It does not parse the Markdown
that defines a command, a skill or an agent, so a frontmatter block that is not
valid YAML ships green: the plugin validates, and the metadata the loader reads is
whatever survived the malformed block.

The failure that motivated this gate is mundane and easy to reintroduce — an
unquoted `description:` stops being a string the moment a colon-space lands inside
it (`Modes: quick | full`), and an unquoted `argument-hint: [a|b]` is a list, not
the hint text.

PyYAML is required rather than optional. An earlier version shipped a hand-written
fallback for machines without it; that parser was measured to disagree with PyYAML
in both directions — accepting `description: 12345`, `description: null` and
`argument-hint: yes`, while rejecting folded scalars, literal scalars and trailing
comments that YAML accepts. A gate whose verdict depends on which machine ran it is
worse than one that says plainly what it needs. This file does not reimplement YAML.

Exit codes:
  0 — every file valid
  1 — at least one file invalid, or PyYAML is not installed
"""

from __future__ import annotations

import pathlib
import re
import sys

REPO_ROOT = pathlib.Path(__file__).resolve().parents[2]

# What each kind of file must declare for the loader to have usable metadata.
# Commands take their name from the filename; skills and agents name themselves.
REQUIRED_FIELDS = {
    "command": ("description",),
    "skill": ("name", "description"),
    "agent": ("name", "description", "tools", "model"),
}

# CONTRIBUTING.md requires every agent to run on at least `sonnet`. An allowlist,
# not a `haiku` denylist: `inherit` takes whatever the parent session runs on and
# a typo like `sonet` names nothing. Matched against the WHOLE value rather than
# as a substring — `sonnet-6-preview` and `my-opus-fork` contain a tier name and
# are not one. A new canonical id is added here when it exists, which is the
# point of an allowlist.
AGENT_ALLOWED_MODELS = ("sonnet", "opus")
# Anchored at BOTH ends: `^claude-(sonnet|opus)[-.]` alone accepted
# `claude-sonnet-typo` and `claude-opus-anything`, which is every string that
# merely starts like an id. A real one ends in a version, optionally dated:
# claude-sonnet-5, claude-opus-4-1, claude-haiku-4-5-20251001.
AGENT_ALLOWED_MODEL_PATTERN = re.compile(r"^claude-(sonnet|opus)-\d+(?:[-.]\d+)*$")

# Optional everywhere, but must be a string when present: a bare `[a|b]` parses as
# a sequence, which is the bug that prompted this gate.
OPTIONAL_STRING_FIELDS = ("argument-hint", "model")



def frontmatter_files() -> list[tuple[pathlib.Path, str]]:
    """Every Markdown file whose frontmatter Claude Code reads, tagged by kind."""
    found: list[tuple[pathlib.Path, str]] = []
    # `**` on purpose: a namespaced command or agent in a subdirectory loads the
    # same way, and a one-level glob skipped it while still printing a green
    # "Checked N files" because the flat siblings kept the count non-zero.
    for path in REPO_ROOT.glob("plugins/*/commands/**/*.md"):
        found.append((path, "command"))
    for path in REPO_ROOT.glob("plugins/*/skills/**/SKILL.md"):
        found.append((path, "skill"))
    for path in REPO_ROOT.glob("plugins/*/agents/**/*.md"):
        found.append((path, "agent"))
    return sorted(found)


def split_frontmatter(text: str) -> str | None:
    """Return the frontmatter block, or None when the file has no closed one.

    Line endings are normalised first: on a `core.autocrlf=true` checkout every
    line carries a trailing CR, and matching on a bare `---` would report every
    file in the repo as missing its frontmatter.
    """
    lines = text.replace("\r\n", "\n").replace("\r", "\n").split("\n")
    # Trailing whitespace on a fence is invisible in an editor and irrelevant
    # to YAML; treating it as "not a fence" would fail a valid file.
    if not lines or lines[0].rstrip() != "---":
        return None
    for index, line in enumerate(lines[1:], 1):
        if line.rstrip() == "---":
            return "\n".join(lines[1:index])
    return None


def check_fields(data: dict, kind: str, relative: pathlib.Path) -> list[str]:
    """Problems with the required and optional fields of one parsed frontmatter."""
    problems = []
    for field in REQUIRED_FIELDS[kind]:
        value = data.get(field)
        if value is None or value == "" or value == []:
            problems.append(f"{relative}: {kind} is missing required '{field}'")
        elif field == "tools":
            # A list of tool names, or a comma-separated string — both load.
            if not isinstance(value, (list, str)):
                problems.append(f"{relative}: 'tools' must be a list or string, got {type(value).__name__}")
        elif not isinstance(value, str):
            problems.append(
                f"{relative}: '{field}' must be a string, got {type(value).__name__}"
                " — wrap it in quotes"
            )

    # Skip anything the required loop already judged for this kind, or a
    # non-string `model` on an agent is reported twice for one defect.
    for field in OPTIONAL_STRING_FIELDS:
        if field in REQUIRED_FIELDS[kind]:
            continue
        if field in data and not isinstance(data[field], str):
            problems.append(
                f"{relative}: '{field}' must be a string, got {type(data[field]).__name__}"
                " — wrap it in quotes"
            )
    return problems


def check_identity(data: dict, kind: str, path: pathlib.Path, relative: pathlib.Path) -> list[str]:
    """Problems with how an agent or skill identifies itself: model tier, directory name."""
    problems = []
    # `model` is required above; it must also name a tier CONTRIBUTING.md allows.
    if kind == "agent" and isinstance(data.get("model"), str):
        model = data["model"].strip().lower()
        if model not in AGENT_ALLOWED_MODELS and not AGENT_ALLOWED_MODEL_PATTERN.match(model):
            problems.append(
                f"{relative}: agent model '{data['model']}' is not sonnet or opus, the minimum"
                " CONTRIBUTING.md requires"
            )

    # A skill is addressed by its `name`, and Claude Code resolves it from the
    # directory. A mismatch loads nothing while every other check passes.
    if kind == "skill" and isinstance(data.get("name"), str):
        if data["name"] != path.parent.name:
            problems.append(
                f"{relative}: name '{data['name']}' does not match its directory"
                f" '{path.parent.name}'"
            )
    return problems


def check(path: pathlib.Path, kind: str, yaml) -> list[str]:
    """Return a list of human-readable problems with one file's frontmatter."""
    relative = path.relative_to(REPO_ROOT)
    # `utf-8-sig` drops a BOM, which Notepad adds and which would otherwise make
    # the first line `\ufeff---` and the whole file "missing frontmatter". A file
    # that is not UTF-8 at all is one finding, not a traceback: the exception would
    # otherwise escape the comprehension in main() and leave every later file
    # unchecked under a red run that names no file.
    try:
        text = path.read_text(encoding="utf-8-sig")
    except UnicodeDecodeError as exc:
        return [f"{relative}: is not UTF-8 — {exc}"]
    block = split_frontmatter(text)

    if block is None:
        return [f"{relative}: missing or unclosed YAML frontmatter"]

    try:
        data = yaml.safe_load(block)
    except yaml.YAMLError as exc:
        # A colon-space inside an unquoted scalar is by far the most common cause,
        # so name the fix rather than only echoing the parser's complaint.
        return [
            f"{relative}: frontmatter is not valid YAML — {exc}",
            "    hint: quote any value containing ': ' — 'like this, with '' for an apostrophe'",
        ]

    if not isinstance(data, dict):
        return [f"{relative}: frontmatter must be a mapping, got {type(data).__name__}"]

    return check_fields(data, kind, relative) + check_identity(data, kind, path, relative)


def main() -> int:
    """Validate every command, skill and agent file; print one summary or the problems."""
    try:
        import yaml
    except ImportError:
        print("  ✗ PyYAML is required for the frontmatter check", file=sys.stderr)
        print("    install it with: python3 -m pip install pyyaml", file=sys.stderr)
        return 1

    files = frontmatter_files()
    if not files:
        # No files is a broken invocation, not a clean repo: this script is only
        # ever run from a checkout that has commands in it.
        print("No command, skill or agent files found — is this the right repository?")
        return 1

    problems = [problem for path, kind in files for problem in check(path, kind, yaml)]
    if problems:
        for problem in problems:
            print(f"  ✗ {problem}")
        return 1

    print(f"Checked {len(files)} command/skill/agent files for valid frontmatter")
    return 0


if __name__ == "__main__":
    sys.exit(main())
