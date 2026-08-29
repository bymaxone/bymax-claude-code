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

The check never skips itself. Without PyYAML it drops to a reduced mode that still
catches the failure classes this exists for — an unclosed block, an unquoted scalar
carrying a colon-space, a bracketed value that YAML would read as a list — and says so
in its summary. A gate that reports success without having run is worse than no gate,
so "PyYAML is missing" must not be spelled "all valid".
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


class ReducedYAMLError(Exception):
    """A frontmatter problem the dependency-free parser can prove without PyYAML."""


def reduced_scalar(value: str, key: str, lineno: int):
    """Read one scalar, refusing every shape this parser cannot prove is valid."""
    quote = value[:1]
    if quote in ("'", '"'):
        if len(value) < 2 or value[-1] != quote:
            raise ReducedYAMLError(
                f"line {lineno}: '{key}' opens with {quote} but the line does not close it"
            )
        inner = value[1:-1]
        if quote == "'" and inner.replace("''", "").count("'"):
            raise ReducedYAMLError(
                f"line {lineno}: '{key}' holds an unescaped apostrophe — double it as ''"
            )
        return inner.replace("''", "'") if quote == "'" else inner
    if ": " in value:
        raise ReducedYAMLError(
            f"line {lineno}: unquoted '{key}' contains ': ', which YAML reads as a nested mapping"
        )
    # A bracketed value is a flow sequence. Returned as a list on purpose, so the
    # string-field check reports it the same way PyYAML would.
    return [value[1:-1]] if value.startswith("[") else value


def reduced_parse(block: str) -> dict:
    """Parse a frontmatter block well enough to police it, without PyYAML.

    This is not a YAML implementation and must never grow into one. It reads the
    subset every command and skill in this repo actually uses — one scalar per
    line, plus the indented `- item` block sequence that `allowed-tools` uses —
    and raises on anything else it cannot prove correct.

    Refusing the unknown is the whole point. An earlier version skipped indented
    lines silently, which meant malformed nested YAML passed the reduced check
    and failed only where a real parser ran: a gate whose verdict depended on
    which machine ran it.
    """
    data: dict = {}
    sequence_key = None
    for lineno, line in enumerate(block.split("\n"), 2):
        if not line.strip() or line.lstrip().startswith("#"):
            continue

        if line[:1].isspace():
            item = line.strip()
            if sequence_key is None or not item.startswith("- "):
                raise ReducedYAMLError(
                    f"line {lineno}: indented line that is not a '- item' under a key —"
                    " install PyYAML for full validation of this file"
                )
            data[sequence_key].append(reduced_scalar(item[2:].strip(), sequence_key, lineno))
            continue

        sequence_key = None
        key, separator, value = line.partition(":")
        if not separator:
            raise ReducedYAMLError(f"line {lineno}: '{line.strip()}' is not 'key: value'")
        key, value = key.strip(), value.strip()
        if not value:
            # `key:` alone opens a block sequence; an empty list is also the right
            # answer when nothing follows, and a required field will be rejected.
            data[key] = []
            sequence_key = key
            continue
        data[key] = reduced_scalar(value, key, lineno)
    return data


SELF_TEST_CASES = (
    ("description: plain value", False),
    ("description: 'quoted value'", False),
    ("description: 'it''s escaped'", False),
    ("description: value\nallowed-tools:\n  - Bash\n  - Read", False),
    ("description: Prove it. Modes: quick | full", True),
    ("description: 'unterminated", True),
    ("description: 'it's unescaped'", True),
    ("description: ok\n  stray: indented", True),
    ("description ok", True),
)


def self_test() -> int:
    """Prove the reduced parser accepts this repo's shapes and rejects the rest."""
    failures = []
    for block, should_reject in SELF_TEST_CASES:
        try:
            reduced_parse(block)
            rejected = False
        except ReducedYAMLError:
            rejected = True
        if rejected != should_reject:
            verb = "accepted" if not rejected else "rejected"
            failures.append(f"  ✗ reduced parser {verb} {block!r}")
    if failures:
        print("\n".join(failures))
        return 1
    print(f"Reduced frontmatter parser passes {len(SELF_TEST_CASES)} self-test cases")
    return 0


def frontmatter_files() -> list[pathlib.Path]:
    """Every Markdown file whose frontmatter Claude Code parses at load time."""
    files = list(REPO_ROOT.glob("plugins/*/commands/*.md"))
    files += REPO_ROOT.glob("plugins/*/skills/*/SKILL.md")
    return sorted(files)


def check(path: pathlib.Path, parse, parse_error) -> list[str]:
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
        data = parse("\n".join(lines[1:closing]))
    except parse_error as exc:
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
    """Validate every command and skill file, printing one summary or the problems."""
    if "--self-test" in sys.argv[1:]:
        return self_test()

    try:
        import yaml
    except ImportError:
        parse, parse_error, mode = reduced_parse, ReducedYAMLError, "reduced"
    else:
        parse, parse_error, mode = yaml.safe_load, yaml.YAMLError, "full"

    files = frontmatter_files()
    if not files:
        # No files is a broken invocation, not a clean repo: this script is only
        # ever run from a checkout that has commands in it.
        print("No command or skill files found — is this the right repository?")
        return 1

    problems = [problem for path in files for problem in check(path, parse, parse_error)]
    if problems:
        for problem in problems:
            print(f"  ✗ {problem}")
        return 1

    if mode == "reduced":
        print(
            f"Checked {len(files)} command/skill files — reduced check only "
            "(PyYAML not installed; install it for full YAML validation)"
        )
        return 0

    print(f"Checked {len(files)} command/skill files for valid frontmatter")
    return 0


if __name__ == "__main__":
    sys.exit(main())
