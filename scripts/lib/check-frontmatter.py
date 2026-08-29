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
import sys

REPO_ROOT = pathlib.Path(__file__).resolve().parents[2]

# What each kind of file must declare for the loader to have usable metadata.
# Commands take their name from the filename; skills and agents name themselves.
REQUIRED_FIELDS = {
    "command": ("description",),
    "skill": ("name", "description"),
    "agent": ("name", "description"),
}

# Optional everywhere, but must be a string when present: a bare `[a|b]` parses as
# a sequence, which is the bug that prompted this gate.
OPTIONAL_STRING_FIELDS = ("argument-hint", "model")


def frontmatter_files() -> list[tuple[pathlib.Path, str]]:
    """Every Markdown file whose frontmatter Claude Code reads, tagged by kind."""
    found: list[tuple[pathlib.Path, str]] = []
    for path in REPO_ROOT.glob("plugins/*/commands/*.md"):
        found.append((path, "command"))
    for path in REPO_ROOT.glob("plugins/*/skills/*/SKILL.md"):
        found.append((path, "skill"))
    for path in REPO_ROOT.glob("plugins/*/agents/*.md"):
        found.append((path, "agent"))
    return sorted(found)


def split_frontmatter(text: str) -> str | None:
    """Return the frontmatter block, or None when the file has no closed one.

    Line endings are normalised first: on a `core.autocrlf=true` checkout every
    line carries a trailing CR, and matching on a bare `---` would report every
    file in the repo as missing its frontmatter.
    """
    lines = text.replace("\r\n", "\n").replace("\r", "\n").split("\n")
    if not lines or lines[0] != "---":
        return None
    for index, line in enumerate(lines[1:], 1):
        if line == "---":
            return "\n".join(lines[1:index])
    return None


def check(path: pathlib.Path, kind: str, yaml) -> list[str]:
    """Return a list of human-readable problems with one file's frontmatter."""
    relative = path.relative_to(REPO_ROOT)
    block = split_frontmatter(path.read_text(encoding="utf-8"))

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

    problems = []
    for field in REQUIRED_FIELDS[kind]:
        value = data.get(field)
        if value is None or value == "":
            problems.append(f"{relative}: {kind} is missing required '{field}'")
        elif not isinstance(value, str):
            problems.append(
                f"{relative}: '{field}' must be a string, got {type(value).__name__}"
                " — wrap it in quotes"
            )

    for field in OPTIONAL_STRING_FIELDS:
        if field in data and not isinstance(data[field], str):
            problems.append(
                f"{relative}: '{field}' must be a string, got {type(data[field]).__name__}"
                " — wrap it in quotes"
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
