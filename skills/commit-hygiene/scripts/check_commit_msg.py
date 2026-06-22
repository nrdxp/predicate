#!/usr/bin/env python3
"""Deterministic commit message validator for the commit-hygiene skill.

Checks the hard constraints from skills/commit-hygiene/SKILL.md:
  E1  header line <= 50 characters
  E2  header matches Conventional Commits: type(scope)!: description
  E3  header has no trailing period
  E4  a single blank line separates header from body
  E5  body/footer lines <= 72 characters (lines containing a URL are
      exempt, since unbreakable tokens cannot be wrapped)

Soft conventions are reported as warnings (exit code stays 0):
  W1  description starts with an uppercase letter (proper nouns are
      legitimate, so this cannot be a hard failure)
  W2  description begins with a likely non-imperative verb form
      ("added", "adds", "adding", ...)

Usage:
  check_commit_msg.py --message "feat: add thing\n\nbody..."
  check_commit_msg.py --file /path/to/COMMIT_EDITMSG
  check_commit_msg.py --ref HEAD          # validate an existing commit
  git log --format=%B -1 | check_commit_msg.py    # stdin

Exit codes: 0 = pass (warnings allowed), 1 = one or more errors,
2 = usage or git failure.
"""

import argparse
import re
import subprocess
import sys

TYPES = (
    "feat|fix|docs|style|refactor|perf|test|build|ci|chore|revert"
)
HEADER_RE = re.compile(
    rf"^(?:{TYPES})(?:\([a-z0-9._/-]+\))?!?: \S.*$"
)
NON_IMPERATIVE_RE = re.compile(
    r"^(added|adds|adding|fixed|fixes|fixing|updated|updates|updating|"
    r"removed|removes|removing|changed|changes|changing|refactored|"
    r"implemented|implements|implementing)\b",
    re.IGNORECASE,
)
URL_RE = re.compile(r"[a-z][a-z0-9+.-]*://\S+")
# Git's auto-generated merge subjects: "Merge branch ...", "Merge pull
# request ...", "Merge remote-tracking branch ...", "Merge tag ...".
MERGE_RE = re.compile(r"^Merge ")


def read_message(args: argparse.Namespace) -> str:
    if args.message is not None:
        return args.message
    if args.file is not None:
        with open(args.file, encoding="utf-8") as fh:
            return fh.read()
    if args.ref is not None:
        proc = subprocess.run(
            ["git", "log", "--format=%B", "-1", args.ref],
            capture_output=True, text=True,
        )
        if proc.returncode != 0:
            sys.stderr.write(proc.stderr)
            sys.exit(2)
        return proc.stdout
    return sys.stdin.read()


def validate(message: str) -> tuple[list[str], list[str]]:
    errors: list[str] = []
    warnings: list[str] = []

    # Strip comment lines (as git commit would) and trailing whitespace.
    lines = [
        ln.rstrip() for ln in message.splitlines()
        if not ln.startswith("#")
    ]
    while lines and not lines[-1]:
        lines.pop()
    if not lines or not lines[0]:
        return ["E2: message is empty"], warnings

    header = lines[0]
    # Merge commits carry git's auto-generated "Merge ..." subject, which is
    # not Conventional Commits and need not be. Exempt them, as commitlint and
    # similar tools do, so a legitimate merge does not fail the gate (and push
    # people toward --no-verify).
    if MERGE_RE.match(header):
        return errors, warnings
    if len(header) > 50:
        errors.append(
            f"E1: header is {len(header)} chars (limit 50): {header!r}"
        )
    if not HEADER_RE.match(header):
        errors.append(
            "E2: header does not match "
            "'type(scope)!: description' with a valid type "
            f"({TYPES.replace('|', ', ')}): {header!r}"
        )
    if header.endswith("."):
        errors.append("E3: header ends with a period")

    match = re.match(rf"^(?:{TYPES})(?:\([^)]*\))?!?: (.+)$", header)
    if match:
        desc = match.group(1)
        if desc[0].isupper() and not desc.split()[0].isupper():
            warnings.append(
                "W1: description starts uppercase (fine for proper "
                f"nouns, otherwise lowercase it): {desc!r}"
            )
        if NON_IMPERATIVE_RE.match(desc):
            warnings.append(
                f"W2: description may not be imperative mood: {desc!r}"
            )

    if len(lines) > 1:
        body_start = 2
        if lines[1]:
            errors.append(
                "E4: missing blank line between header and body"
            )
            body_start = 1
        for idx, line in enumerate(
            lines[body_start:], start=body_start + 1
        ):
            if len(line) > 72 and not URL_RE.search(line):
                errors.append(
                    f"E5: line {idx} is {len(line)} chars (limit 72): "
                    f"{line[:60]!r}..."
                )

    return errors, warnings


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Validate a commit message against commit-hygiene "
        "hard constraints."
    )
    source = parser.add_mutually_exclusive_group()
    source.add_argument("--message", help="message text to validate")
    source.add_argument("--file", help="path to a message file")
    source.add_argument(
        "--ref", help="git ref whose commit message to validate"
    )
    args = parser.parse_args()

    errors, warnings = validate(read_message(args))
    for warning in warnings:
        print(f"WARN  {warning}")
    for error in errors:
        print(f"ERROR {error}")
    if errors:
        print(f"FAIL: {len(errors)} hard-constraint violation(s)")
        return 1
    print("PASS: commit message satisfies hard constraints")
    return 0


if __name__ == "__main__":
    sys.exit(main())
