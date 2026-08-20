#!/usr/bin/env python3
"""Directions-register completeness gate (tech-debt/directions-half-conditioned.yaml,
gate half only).

The head ruled AI5 (`.ledger/state/decisions-architect-intake.yaml`) for the
WHOLE-CORPUS form over per-claim attribution: attribution is directions node
[DX1]'s rejected shape (a companion on every entry, a corpus-wide retag, a
third mechanism), and [DX1] stands. This gate implements AI5's own two
conditions, verbatim:

  * a corpus holding graded CLAIMS with an absent or empty directions
    register is an error;
  * a direction carrying zero terminal questions is an error -- the D3 case
    that motivated it: "no drafted terminal questions, so its convergence is
    undefined rather than zero" is correct as a MEASUREMENT (an undrafted
    denominator is not stalled work), but is exactly the state this gate
    exists to refuse -- a register that looks populated and measures
    nothing.

Direction/terminal-target selection is NOT re-derived here: `group_by_direction`
and its `TERMINAL_SHAPE` marker rule already live in
`ledger/derive/convergence.py`, imported in-process (the self_vouch.py /
terminal_freshness.py convention) rather than copied, so this gate can never
drift from what convergence.py measures. Its own reported bugs (marker
grouping splits on the first hyphen only; the register lookup requires a doc
stem literally "directions") are convergence.py's, unrepaired here.

WHAT COUNTS AS "GRADED CLAIMS"
--------------------------------
`assertion == "claim"` entries, precisely -- the vocabulary's own term
(docs/entries.md), not every graded node. A corpus holding only QUESTIONS
and no claim owes no register under AI5's own wording ("a corpus holding
graded claims"); conflating the two would make asking a question, alone,
obligate a direction register nothing else in this pass asks for.

Usage:
  directions_register.py [corpus]   corpus is a directory or file passed
                          straight to extract_entries.py; default is the
                          MAIN tree's `.ledger` (a worktree has none of its
                          own -- same resolution as ledger/gate/self_vouch.py).

Exit codes:
  0  no violation.
  1  at least one violation exists (named in the report).
  2  usage or environment error (corpus missing, convergence/extractor
     modules failed to load, extraction itself failed outright).
"""

from __future__ import annotations

import argparse
import importlib.util
import subprocess
import sys
from pathlib import Path
from types import ModuleType

ROOT = Path(__file__).resolve().parent.parent.parent
EXTRACT_ENTRIES = ROOT / "ledger" / "derive" / "extract_entries.py"
CONVERGENCE = ROOT / "ledger" / "derive" / "convergence.py"


class EnvError(Exception):
    """A usage or environment problem — never a finding about the corpus."""


def load_module(path: Path, name: str) -> ModuleType:
    spec = importlib.util.spec_from_file_location(name, path)
    if spec is None or spec.loader is None:
        raise EnvError(f"cannot load a module from {path}")
    module = importlib.util.module_from_spec(spec)
    sys.modules[name] = module
    try:
        spec.loader.exec_module(module)
    except Exception as err:  # noqa: BLE001 - reported, never swallowed
        raise EnvError(f"{path} failed to import: {err}") from err
    return module


def resolve_default_corpus() -> Path:
    """The MAIN tree's `.ledger` — a linked worktree has none of its own, so
    default to the common git dir's parent, exactly as self_vouch.py and
    terminal_freshness.py resolve it."""
    proc = subprocess.run(
        ["git", "-C", str(ROOT), "rev-parse", "--git-common-dir"],
        capture_output=True, text=True,
    )
    if proc.returncode != 0:
        raise EnvError(
            f"cannot resolve the main tree (not in a git repo?): {proc.stderr.strip()}"
        )
    common_dir = Path(proc.stdout.strip())
    if not common_dir.is_absolute():
        common_dir = (ROOT / common_dir).resolve()
    return common_dir.parent / ".ledger"


def extract(mod, corpus: Path) -> dict:
    """Run extract_entries.py's own extraction pipeline in-process (the
    check_grammar_home.py convention: import the module rather than shell
    out)."""
    try:
        files = mod.collect_files([str(corpus)])
    except FileNotFoundError as err:
        raise EnvError(f"no such corpus path: {err}") from err
    out = mod.Extraction()
    for path in files:
        mod.extract_doc(path, out)
    mod.resolve_qualified(out)
    return {
        "entries": out.entries,
        "directives": out.directives,
        "grades": out.grades,
        "findings": out.findings,
    }


def evaluate(export: dict, convergence_mod) -> dict:
    entries = export.get("entries", [])
    directives = export.get("directives", [])
    directions, question_terminals, directive_terminals, group_findings = (
        convergence_mod.group_by_direction(entries, directives)
    )

    has_claims = any(e.get("assertion") == "claim" for e in entries)

    violations = []
    if has_claims and not directions:
        violations.append({
            "kind": "empty-register",
            "reason": (
                "the corpus carries graded claims but no directive with "
                "document stem 'directions' -- the directions register is "
                "absent or empty"
            ),
        })

    empty_directions = []
    for name in sorted(directions):
        total = len(question_terminals.get(name, [])) + len(
            directive_terminals.get(name, []))
        if total == 0:
            empty_directions.append(name)
            violations.append({
                "kind": "no-terminal-questions",
                "direction": name,
                "reason": f"direction {name} carries zero terminal questions",
            })

    return {
        "directions": sorted(directions),
        "has_claims": has_claims,
        "empty_directions": empty_directions,
        "violations": violations,
        "malformed_markers": group_findings,
    }


def render(result: dict) -> None:
    print(f"directions register: {len(result['directions'])} direction(s), "
          f"graded claims present: {result['has_claims']}")
    if result["directions"]:
        for name in result["directions"]:
            flag = "  <- no terminal questions" if name in result["empty_directions"] else ""
            print(f"  {name}{flag}")

    if result["malformed_markers"]:
        print()
        print("convergence.py findings (not this gate's own, surfaced for visibility):")
        for f in result["malformed_markers"]:
            print(f"  {f['kind']}: {f.get('id', '')} {f['reason']}")

    print()
    print(f"violations: {len(result['violations'])}")
    for v in result["violations"]:
        print(f"  ! {v['kind']}: {v['reason']}")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument(
        "corpus", nargs="?",
        help="directory or file (default: the main tree's .ledger)")
    opts = parser.parse_args()

    try:
        extract_mod = load_module(EXTRACT_ENTRIES, "directions_register_extract_entries")
        convergence_mod = load_module(CONVERGENCE, "directions_register_convergence")
        corpus = Path(opts.corpus) if opts.corpus else resolve_default_corpus()
        if not corpus.exists():
            raise EnvError(f"no such corpus path: {corpus}")
        export = extract(extract_mod, corpus)
    except EnvError as err:
        print(f"directions_register: {err}", file=sys.stderr)
        return 2

    result = evaluate(export, convergence_mod)
    render(result)
    return 1 if result["violations"] else 0


if __name__ == "__main__":
    sys.exit(main())
