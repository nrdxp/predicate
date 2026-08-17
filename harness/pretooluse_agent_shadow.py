#!/usr/bin/env python3
"""pretooluse_agent_shadow.py — Claude Code PreToolUse hook, SHADOW MODE ONLY.

Matches the Agent/Task tool (harness/hooks.json's matcher covers both names —
this harness's own tool list calls it "Agent", the underlying Claude Code
event historically calls it "Task", and this hook does not assume which one
a given build reports). Checks a dispatch's `tool_input.prompt` against the
composer persona's own dispatch rules (conditioning/personas/composer.ncl's
rendered form; see the composer's "Every dispatch opens with the workspace
header and the sanction" and "PROVENANCE TRAVELS with the header" clauses,
and its seat-continuity rule "a re-seating is declared as such in its
dispatch") — and logs what it WOULD have flagged. It never blocks anything.

--- WHY SHADOW, AND WHY THIS IS SAFE (node/cond-hooks) -----------------------

PreToolUse fails OPEN by design (verified against the live docs at
code.claude.com/docs/en/hooks, quoted rather than assumed):
  - A timed-out command hook "doesn't block the tool call. The call
    continues through the normal permission flow."
  - Any exit code other than 0 or 2 is, for most hook events, "a
    non-blocking error... the action proceeds."
  - Exit 0 with stdout that fails JSON-schema validation "is a non-blocking
    error: the action proceeds."
  - A missing or non-executable hook script "lands in the same non-blocking
    bucket... For most hook events, the action proceeds."
  - The ONLY way a PreToolUse hook blocks anything is exit code 2, or valid
    JSON carrying `hookSpecificOutput.permissionDecision: "deny"`.

This script never does either. It is wrapped so that EVERY path — including
an uncaught exception — reaches a plain `exit 0` with no `permissionDecision`
field printed at all (not even "allow": omitting the field, like every
failure mode above, is silent-allow through the normal permission flow, and
gives this script no code path that could ever assemble a "deny").

--- RECOVERY IF THIS EVER SEEMS TO WEDGE DISPATCH ----------------------------

It cannot gate (see above), so it cannot be the cause of a wedged dispatch —
but if something else does and you need hooks off while you debug:
  - Session-wide, immediate: relaunch with `claude --settings
    '{"disableAllHooks": true}'` (takes precedence over project/local
    settings for that one run).
  - Persistent: set `"disableAllHooks": true` in a settings file.
  - There is no per-hook disable — it is all hooks or none.
  - Hook edits in settings files hot-reload via the file watcher; a change
    to a PLUGIN's own hooks/hooks.json (this file's registration in
    harness/hooks.json) may need a session restart to be picked up —
    unconfirmed which applies to self-hosted plugin hooks specifically, so
    if a live-session edit does not seem to take effect, restart before
    concluding the hook itself is broken.

--- WHAT IT CHECKS, AND WHY THESE ARE HEURISTICS, NOT A PARSER ---------------

Regex/keyword heuristics over free-text dispatch prose — not a grammar, and
not validated against a labeled corpus for precision/recall. That imprecision
is exactly why this ships observe-only: the log this hook accumulates is the
first real evidence of how often each check would have been right, which is
the input a future decision to promote any of this to an enforcing deny
would need and does not yet have.

  - workspace_path   an absolute filesystem path appears in the prompt
  - branch           the word "branch" appears near a name/token
  - base_commit      a git-hash-shaped token, or "tip"/"HEAD"/"base commit"
  - sanction         "sanction", "authoriz(e/ed/ation)", or "auto mode"
  - cited_sources    "source" or "cited" appears, or a bracketed [id] ref
  - seat_role        subagent_type names a known council-seat persona
  - seating_declared (only checked when seat_role is true) "first seating",
                     "resum(e/ing)", or "re-seat(ing)" appears

Exit: ALWAYS 0. Output: ALWAYS `{}` (no hookSpecificOutput, ever).
"""

from __future__ import annotations

import json
import os
import re
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Optional

LOG_RELPATH = "state/agent-dispatch-shadow.jsonl"

# Subagent_type values (or substrings) this repo's own council-seat personas
# use — harness/../.claude/agents/predicate-*-seat.md and the delegation
# table in the always-on law (architect, composer, maintainer/lead-
# maintainer, auditor/process-auditor, plus the guest hacker seat). Matched
# case-insensitively as a substring, not an exact set, since a seat can be
# dispatched under a descriptive name as well as its bare persona id.
SEAT_ROLE_MARKERS = (
    "architect-seat", "lead-maintainer-seat", "process-auditor-seat",
    "hacker-seat", "security-seat",
)

ABS_PATH_RE = re.compile(r"(?<![\w.])/[A-Za-z0-9_.][A-Za-z0-9_./-]{2,}")
GIT_HASH_RE = re.compile(r"\b[0-9a-f]{7,40}\b")
BRANCH_KW_RE = re.compile(r"\bbranch\b", re.IGNORECASE)
BASE_COMMIT_KW_RE = re.compile(r"\b(tip|base\s+commit|HEAD)\b", re.IGNORECASE)
SANCTION_KW_RE = re.compile(r"\bsanction|authoriz\w*|auto\s+mode\b", re.IGNORECASE)
CITED_SOURCE_RE = re.compile(r"\bcited\b|\bsources?\b|\[[A-Za-z0-9][\w-]*\]", re.IGNORECASE)
SEATING_DECLARED_RE = re.compile(
    r"\bfirst\s+seating\b|\bresum(e|ing|ed)\b|\bre-?seat(ing|ed)?\b", re.IGNORECASE
)

PROMPT_HEAD_CHARS = 150  # identify the dispatch without accumulating its bulk


def _run(cmd, cwd: Path, timeout: int = 5) -> Optional[str]:
    """Best-effort subprocess capture — never raises. Same collapse-to-None
    contract as harness/session_start.py's own `_run`, reused here rather
    than imported so this hook stays a single dependency-free file (a hook
    script failing to import its sibling is exactly the kind of failure this
    file's own never-block contract must survive without help)."""
    try:
        r = subprocess.run(
            cmd, cwd=str(cwd), capture_output=True, text=True, timeout=timeout,
        )
    except (OSError, subprocess.TimeoutExpired):
        return None
    if r.returncode != 0:
        return None
    return r.stdout.strip() or None


def resolve_project_root(input_data: dict) -> Path:
    """Same resolution order as harness/session_start.py's
    resolve_project_root: stdin cwd, then $CLAUDE_PROJECT_DIR, then process
    cwd, widened to the git toplevel when possible."""
    candidate = input_data.get("cwd") or os.environ.get("CLAUDE_PROJECT_DIR") or os.getcwd()
    path = Path(candidate)
    toplevel = _run(["git", "rev-parse", "--show-toplevel"], path if path.is_dir() else Path.cwd())
    if toplevel:
        return Path(toplevel)
    return path


def resolve_ledger_root(project_root: Path) -> Path:
    """Same worktree-correct resolution as harness/session_start.py's
    resolve_ledger_root: .ledger lives beside the MAIN checkout, not
    necessarily beside a linked worktree's own toplevel."""
    direct = project_root / ".ledger"
    if direct.is_dir():
        return direct
    common_dir = _run(["git", "rev-parse", "--git-common-dir"], project_root)
    if not common_dir:
        return direct
    common_path = Path(common_dir)
    if not common_path.is_absolute():
        common_path = project_root / common_path
    return common_path.resolve().parent / ".ledger"


def is_seat_dispatch(subagent_type: str) -> bool:
    low = (subagent_type or "").lower()
    return any(marker in low for marker in SEAT_ROLE_MARKERS)


def evaluate(prompt: str, subagent_type: str) -> dict:
    """Runs every heuristic check against the dispatch prompt and returns the
    would-have-decided verdict as a plain dict — never raises (a regex over
    a string cannot, but a caller relying on that without stating it is how
    a future edit here quietly breaks the never-block contract, hence
    stating it)."""
    seat = is_seat_dispatch(subagent_type)

    if not prompt:
        # No prompt text means no dispatch prose was ever inspected — every
        # prompt-dependent check is not-applicable (None), never False.
        # False would assert an absence this check never looked for (the
        # same rule seating_declared already follows below), and a
        # would_deny built on regexes run against an empty string is not
        # evidence about the dispatch, it is an artifact of the empty
        # string. seat_role stays a real verdict: it reads subagent_type,
        # not the prompt, so it is available regardless.
        checks = {
            "workspace_path": None,
            "branch": None,
            "base_commit": None,
            "sanction": None,
            "cited_sources": None,
            "seat_role": seat,
            "seating_declared": None,
        }
        return {"checks": checks, "failed": [], "would_deny": None}

    checks = {
        "workspace_path": bool(ABS_PATH_RE.search(prompt)),
        "branch": bool(BRANCH_KW_RE.search(prompt)),
        "base_commit": bool(GIT_HASH_RE.search(prompt) or BASE_COMMIT_KW_RE.search(prompt)),
        "sanction": bool(SANCTION_KW_RE.search(prompt)),
        "cited_sources": bool(CITED_SOURCE_RE.search(prompt)),
    }
    checks["seat_role"] = seat
    # seating_declared is only a meaningful check for a seat dispatch; for a
    # non-seat worker it is reported None (not applicable), never False —
    # False would misreport an absence this check never looked for.
    checks["seating_declared"] = (
        bool(SEATING_DECLARED_RE.search(prompt)) if seat else None
    )

    failed = [
        name for name, ok in checks.items()
        if name not in ("seat_role",) and ok is False
    ]
    would_deny = len(failed) > 0
    return {"checks": checks, "failed": failed, "would_deny": would_deny}


def append_log(ledger_root: Path, record: dict) -> None:
    """Appends one JSONL line — never raises past the caller's own
    try/except, but also never leaves a partial line: build the full string
    first, then a single write call."""
    log_path = ledger_root / LOG_RELPATH
    log_path.parent.mkdir(parents=True, exist_ok=True)
    line = json.dumps(record, sort_keys=True) + "\n"
    with log_path.open("a", encoding="utf-8") as f:
        f.write(line)


def main() -> int:
    # This hook must NEVER exit non-zero, NEVER print a permissionDecision,
    # and NEVER raise past this point — see the module docstring's
    # never-block contract. `{}` and exit 0 on every path, no exceptions.
    try:
        raw = sys.stdin.read() if not sys.stdin.isatty() else ""
        try:
            input_data = json.loads(raw) if raw.strip() else {}
        except json.JSONDecodeError:
            input_data = {}

        tool_name = input_data.get("tool_name", "")
        tool_input = input_data.get("tool_input") or {}
        prompt = tool_input.get("prompt") or ""
        subagent_type = tool_input.get("subagent_type") or ""
        description = tool_input.get("description") or ""

        project_root = resolve_project_root(input_data)
        ledger_root = resolve_ledger_root(project_root)

        result = evaluate(prompt, subagent_type)

        record = {
            "ts": datetime.now(timezone.utc).isoformat(timespec="seconds"),
            "tool_name": tool_name,
            "subagent_type": subagent_type,
            "description": description[:PROMPT_HEAD_CHARS],
            "prompt_head": prompt[:PROMPT_HEAD_CHARS],
            "checks": result["checks"],
            "failed": result["failed"],
            "would_deny_if_enforced": result["would_deny"],
            "session_id": input_data.get("session_id", ""),
        }
        try:
            append_log(ledger_root, record)
        except OSError as exc:
            # A log write failing is itself a diagnostic, but never a reason
            # to deviate from the never-block contract — stderr only.
            sys.stderr.write(f"pretooluse_agent_shadow: log write failed: {exc}\n")

        sys.stderr.write(
            "pretooluse_agent_shadow: SHADOW (no decision emitted) "
            f"subagent_type={subagent_type!r} "
            f"would_deny_if_enforced={result['would_deny']} "
            f"failed={result['failed']}\n"
        )
        print(json.dumps({}))
        return 0
    except Exception as exc:  # last-resort: this hook must never block a dispatch
        sys.stderr.write(f"pretooluse_agent_shadow: internal error (no decision emitted): {exc}\n")
        print(json.dumps({}))
        return 0


if __name__ == "__main__":
    sys.exit(main())
