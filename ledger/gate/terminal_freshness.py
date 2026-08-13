#!/usr/bin/env python3
"""Terminal-freshness check (directions:D3-T10): does a terminal target's
satisfying claim carry the coordinate that makes a lapsed corroboration
visible?

D3's whole content is that finishing is known by evidence rather than
assertion. A corroboration is evidence at the moment it is written; without a
coordinate saying whether it stays true, "satisfied" quietly degrades into
"was once satisfied" -- an assertion wearing evidence. This check must itself
be a re-runnable derivation, not an ad-hoc read, for the same reason
self_vouch.py's is (D3-T8): an ad-hoc run corroborates nothing.

WHAT COUNTS AS A VIOLATION
---------------------------
Terminal-target selection and satisfying-claim selection are IDENTICAL to
self_vouch.py's (D3-T8 asks a structurally different question about the same
pair) and are imported from `ledger/derive/terminal_satisfaction.py` rather
than re-derived -- see that module's docstring.

For each terminal target with a satisfying claim, that claim MUST carry
`axes::`. Where its `monotone` coordinate is false, it MUST also carry a
non-empty `freshness::` (the T3 cure `docs/entries.md` §axes already
obliges of any non-monotone claim -- `entry.ncl`'s `NonMonotoneNamesCure`
enforces the pairing wherever axes ARE present, but a claim may omit axes
entirely and still pass that contract, since carrying them is "an authoring
obligation of the authoring surface, never a universal shape law"
(docs/entries.md §axes). This check is the D3-T10 obligation ON TOP of that:
a claim that CLOSES a terminal target has no such latitude to stay
unassessed).

Two distinctions decide whether the answer means anything, both structurally
identical to self_vouch.py's:

  * a target with NO satisfying claim is UNMET, not a violation --
    convergence.py already reports the unmet fraction; conflating unmet with
    improperly-met would double-count the same gap two different ways.
  * a claim that discharges a target but does not SATISFY it (uncorroborated,
    or not `assertion: claim`) is out of scope -- only what closes a target
    is asked about here.

WHAT THIS CHECK ESTABLISHES, AND WHAT IT DOES NOT
----------------------------------------------------
It establishes that a satisfying claim DECLARES its axes, and where
non-monotone, DECLARES a freshness cure -- a structural, re-runnable fact
about the record's grammar. It does NOT establish that the axes are
correctly assessed, or that the named freshness mechanism actually works, or
that it has ever been re-run. `freshness::` is prose naming a mechanism; this
check can confirm the prose exists, never that the prose is true. Reading
this check's exit code as "every satisfaction is fresh" would be exactly the
assertion-wearing-evidence defect D3 exists to catch -- it only ever tells
you that a satisfaction which OWES a coordinate has declared one.

Usage:
  terminal_freshness.py [corpus]   corpus is a directory or file passed
                                    straight to extract_entries.py; default
                                    is the MAIN tree's `.ledger` (a worktree
                                    has none of its own -- same resolution as
                                    ledger/gate/self_vouch.py and
                                    ledger/gate/recorder_close_check.sh: the
                                    common git dir's parent).

Exit codes:
  0  every satisfying claim carries axes, and a freshness cure wherever
     non-monotone.
  1  at least one satisfying claim is missing axes, or is non-monotone and
     missing freshness (named in the report).
  2  usage or environment error (corpus missing, extractor/convergence/
     terminal-satisfaction modules failed to load, extraction itself failed
     outright).
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
TERMINAL_SATISFACTION = ROOT / "ledger" / "derive" / "terminal_satisfaction.py"


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
    ledger/gate/recorder_close_check.sh resolve the recorder."""
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
    out, since both live in the same interpreter and corpus already)."""
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


def missing_coordinate(claim: dict) -> str | None:
    """What, if anything, this satisfying claim is missing -- `None` when it
    carries everything D3-T10 obliges. `axes` absent entirely is the coarser
    defect and reported first; a claim with axes but no freshness where
    non-monotone is the finer one entry.ncl's own contract would already
    catch IF axes were present (module docstring)."""
    axes = claim.get("axes")
    if not axes:
        return "no axes:: at all"
    if axes.get("monotone") is False and not claim.get("freshness"):
        return "non-monotone (axes:: -monotone) but no freshness:: cure"
    return None


def evaluate(export: dict, convergence_mod, terminal_mod) -> dict:
    targets, malformed = terminal_mod.terminal_targets(
        export.get("directives", []), convergence_mod)
    entries = export.get("entries", [])

    rows = []
    violations = []
    for target_id in sorted(targets):
        claims = terminal_mod.discharging_claims(entries, target_id)
        satisfying = [c for c in claims if terminal_mod.is_satisfying(c)]
        row = {"target": target_id, "satisfying": None}
        if satisfying:
            # `discharges` on a directive-shaped target composes with exactly
            # one satisfying claim by construction (ruling-terminal-
            # composition); if authoring ever lands more than one, every
            # satisfying claim is checked rather than only the first.
            for claim in satisfying:
                gap = missing_coordinate(claim)
                row_entry = {
                    "claim": claim["id"],
                    "axes": claim.get("axes"),
                    "freshness": claim.get("freshness"),
                    "gap": gap,
                }
                if row["satisfying"] is None:
                    row["satisfying"] = []
                row["satisfying"].append(row_entry)
                if gap:
                    violations.append({
                        "claim": claim["id"],
                        "target": target_id,
                        "reason": gap,
                    })
        rows.append(row)

    return {
        "targets": rows,
        "violations": violations,
        "malformed_markers": malformed,
    }


def render(result: dict) -> None:
    print(f"terminal targets: {len(result['targets'])}")
    for row in result["targets"]:
        if row["satisfying"] is None:
            print(f"  {row['target']}  UNMET")
            continue
        for entry in row["satisfying"]:
            axes = entry["axes"]
            axes_str = (
                " ".join(f"{'+' if v else '-'}{k}" for k, v in axes.items())
                if axes else "(none)"
            )
            status = "OK" if entry["gap"] is None else "MISSING COORDINATE"
            print(f"  {row['target']}  SATISFIED  <- {entry['claim']}  "
                  f"axes=[{axes_str}]  {status}")
            if entry["gap"]:
                print(f"      ! {entry['gap']}")

    if result["malformed_markers"]:
        print()
        print("malformed terminal-shaped markers (excluded, not targets):")
        for mid in result["malformed_markers"]:
            print(f"  {mid}")

    print()
    print(f"freshness-coordinate violations: {len(result['violations'])}")
    for r in result["violations"]:
        print(f"  ! {r['claim']} -> {r['target']}: {r['reason']}")

    print()
    print("this check establishes only that a satisfying claim DECLARES its "
          "axes/freshness coordinates; it cannot establish that the "
          "coordinates are correctly assessed or that a named freshness "
          "mechanism has ever been re-run.")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("corpus", nargs="?", help="directory or file (default: the main tree's .ledger)")
    opts = parser.parse_args()

    try:
        extract_mod = load_module(EXTRACT_ENTRIES, "terminal_freshness_extract_entries")
        convergence_mod = load_module(CONVERGENCE, "terminal_freshness_convergence")
        terminal_mod = load_module(TERMINAL_SATISFACTION, "terminal_freshness_terminal_satisfaction")
        corpus = Path(opts.corpus) if opts.corpus else resolve_default_corpus()
        if not corpus.exists():
            raise EnvError(f"corpus path does not exist: {corpus}")
        export = extract(extract_mod, corpus)
    except EnvError as err:
        print(f"terminal_freshness: ENV: {err}", file=sys.stderr)
        return 2

    result = evaluate(export, convergence_mod, terminal_mod)
    render(result)

    for finding in export.get("findings", []):
        where = finding["doc"] + (f":{finding['marker']}" if finding.get("marker") else "")
        print(f"terminal_freshness: extraction finding at {where}: {finding['reason']}", file=sys.stderr)

    return 1 if result["violations"] else 0


if __name__ == "__main__":
    sys.exit(main())
