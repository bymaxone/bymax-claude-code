#!/usr/bin/env python3
"""Validate the YAML frontmatter of every command and skill in this repo.

`claude plugin validate` covers the JSON manifests. It does not read the Markdown
that actually defines a command, so a malformed frontmatter block ships green: the
plugin validates, and the command silently fails to parse at load time. The failure
this guards against is mundane and easy to reintroduce — an unquoted `description:`
scalar stops parsing the moment a colon-space lands inside it, as in
`description: Prove it works. Modes: quick | full`.

Prints a one-line summary on success; the caller decorates it. Exit codes:
  0 — every file valid
  1 — at least one file has invalid frontmatter
  2 — check skipped (PyYAML unavailable); the message is still on stdout
"""

from __future__ import annotations

import pathlib
import sys

REPO_ROOT = pathlib.Path(__file__).resolve().parents[2]

# Fields every command and skill must carry, and the type each must parse as.
REQUIRED_STRING_FIELDS = ("description",)
# Fields that are optional, but must be a string when present. `argument-hint`
# is here because a bare `[a|b]` parses as a YAML list, not the hint text.
OPTIONAL_STRING_FIELDS = ("argument-hint", "name", "model")


def frontmatter_files() -> list[pathlib.Path]:
    """Every Markdown file whose frontmatter Claude Code parses at load time."""
    files = list(REPO_ROOT.glob("plugins/*/commands/*.md"))
    files += REPO_ROOT.glob("plugins/*/skills/*/SKILL.md")
    return sorted(files)


def check(path: pathlib.Path, yaml) -> list[str]:
    """Return a list of human-readable problems with one file's frontmatter."""
    rel = path.relative_to(REPO_ROOT)
    text = path.read_text(encoding="utf-8")

    if not text.startswith("---\n"):
        return [f"{rel}: missing YAML frontmatter (file must start with '---')"]

    lines = text.split("\n")
    closing = next((i for i, line in enumerate(lines[1:], 1) if line == "---"), None)
    if closing is None:
        return [f"{rel}: frontmatter is never closed (no terminating '---')"]

    try:
        data = yaml.safe_load("\n".join(lines[1:closing]))
    except yaml.YAMLError as exc:
        # A colon-space inside an unquoted scalar is by far the most common cause,
        # so name the fix rather than only echoing the parser's complaint.
        return [
            f"{rel}: frontmatter is not valid YAML — {exc}",
            "    hint: quote any value containing ': ' — 'like this, with '' for an apostrophe'",
        ]

    if not isinstance(data, dict):
        return [f"{rel}: frontmatter must be a mapping, got {type(data).__name__}"]

    problems = []
    for field in REQUIRED_STRING_FIELDS:
        value = data.get(field)
        if not value:
            problems.append(f"{rel}: missing required '{field}'")
        elif not isinstance(value, str):
            problems.append(f"{rel}: '{field}' must be a string, got {type(value).__name__}")

    for field in OPTIONAL_STRING_FIELDS:
        if field in data and not isinstance(data[field], str):
            problems.append(
                f"{rel}: '{field}' must be a string, got {type(data[field]).__name__}"
                " — wrap it in quotes"
            )

    return problems


def main() -> int:
    try:
        import yaml
    except ImportError:
        print("PyYAML not installed — skipping (install with: pip install pyyaml)")
        return 2

    files = frontmatter_files()
    if not files:
        print("No command or skill files found")
        return 2

    problems = [problem for path in files for problem in check(path, yaml)]
    if problems:
        for problem in problems:
            print(f"  ✗ {problem}")
        return 1

    print(f"Checked {len(files)} command/skill files for valid frontmatter")
    return 0


if __name__ == "__main__":
    sys.exit(main())
