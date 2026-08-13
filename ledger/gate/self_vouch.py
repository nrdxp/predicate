#!/usr/bin/env python3
"""Self-vouch check (directions:D3-T8): is any terminal target satisfied on
the testimony of its own author?

D3's whole content is that finishing is known by evidence rather than
assertion, so this check must itself be a re-runnable derivation, not an
ad-hoc read — an ad-hoc run corroborates nothing.

WHAT COUNTS AS A VIOLATION
---------------------------
A terminal target is a `directive` node under document stem `directions`
whose marker has the `<DIRECTION>-<TAG>` shape (the exact selection
`ledger/derive/convergence.py` already makes for the same corpus — its
`TERMINAL_SHAPE` regex is imported rather than re-derived, so the two tools
never drift apart on what "terminal" means).

A target is SATISFIED by a claim: `assertion: claim`, `backing:
corroborated`, naming the target in its own `discharges` edge
(ruling-terminal-composition [TC1] — see convergence.py). This check reads
every claim naming a target in `discharges`, regardless of backing, because
self-witness is a property of the CLAIM, not only of a satisfying one — but
only a SATISFYING claim's self-witness is a violation:

  * a corroborated, self-witnessed claim IS the failure this check exists to
    catch (the witness of record and the document's declared author are the
    same party, so nothing outside that party's own word backs the claim).
  * a vouched or unclosed claim naming the same target, even if
    self-witnessed, is not what closed it — a target's SATISFACTION is what
    the question asks about, so these are reported for visibility and never
    counted.
  * a target with no satisfying claim at all is UNMET, not a violation —
    convergence.py already reports the unmet fraction; conflating unmet with
    improperly-met would double-count the same gap two different ways.

Terminal-target selection (what is a terminal target, what satisfies one) is
shared with `ledger/gate/terminal_freshness.py` (D3-T10) via
`ledger/derive/terminal_satisfaction.py` rather than re-derived here -- see
that module's docstring.

WHERE THE SIGNER AND THE WITNESS COME FROM
--------------------------------------------
Both are read from the documents by `extract_entries.py`, never hardcoded
here: `entry["signer"]` is the declared `signer::` of the document the claim
itself lives in (attached per-document during extraction), and
`entry["witness"]["name"]` is the raw `source::` value on the claim's own
node. A witness is compared to the signer by parsing its leading `kind[/name]`
token with the extractor's own `parse_signer` (any trailing prose after a
comma — "agent/x, reading <doc>" — is descriptive, not part of the
designation) and falling back to a literal string comparison only when that
parse fails, so an oddly-shaped witness is still checked rather than
silently waved through.

Usage:
  self_vouch.py [corpus]   corpus is a directory or file passed straight to
                            extract_entries.py; default is the MAIN tree's
                            `.ledger` (a worktree has none of its own — same
                            resolution as ledger/gate/recorder_close_check.sh:
                            the common git dir's parent).

Exit codes:
  0  no self-witnessed satisfying claim exists.
  1  at least one self-witnessed satisfying claim exists (named in the report).
  2  usage or environment error (corpus missing, extractor/convergence
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
    default to the common git dir's parent, exactly as
    ledger/gate/recorder_close_check.sh resolves the recorder."""
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


def _reconstruct_signer(signer: dict) -> str:
    return signer["kind"] if "name" not in signer else f"{signer['kind']}/{signer['name']}"


def self_witnessed(entry: dict, extract_mod) -> bool:
    """The claim's witness (its `source::`) and the document it lives in's
    declared `signer::` name the same party. `entry["signer"]` already IS
    that document's own header signer — extract_entries.py attaches it to
    every entry in the document during extraction — so no second lookup
    against the document is needed here."""
    witness = entry.get("witness")
    signer = entry.get("signer")
    if not witness or not signer:
        return False
    head = witness["name"].split(",", 1)[0].strip()
    parsed = extract_mod.parse_signer(head)
    if parsed is not None:
        return parsed == signer
    # An unparseable witness is still checked, literally, rather than waved
    # through silently — the failure mode this check exists to prevent is a
    # self-vouch nobody noticed, not one that merely didn't parse cleanly.
    return head == _reconstruct_signer(signer)


def evaluate(export: dict, extract_mod, convergence_mod, terminal_mod) -> dict:
    targets, malformed = terminal_mod.terminal_targets(
        export.get("directives", []), convergence_mod)
    entries = export.get("entries", [])

    rows = []
    violations = []
    non_violating = []
    for target_id in sorted(targets):
        claims = terminal_mod.discharging_claims(entries, target_id)
        satisfying = [c for c in claims if terminal_mod.is_satisfying(c)]
        for claim in claims:
            if not self_witnessed(claim, extract_mod):
                continue
            record = {
                "claim": claim["id"],
                "target": target_id,
                "backing": claim.get("backing"),
                "witness": claim["witness"]["name"],
            }
            (violations if terminal_mod.is_satisfying(claim) else non_violating).append(record)
        rows.append({
            "target": target_id,
            "satisfying": [c["id"] for c in satisfying],
        })

    return {
        "targets": rows,
        "violations": violations,
        "non_violating_self_witnessed": non_violating,
        "malformed_markers": malformed,
    }


def render(result: dict) -> None:
    print(f"terminal targets: {len(result['targets'])}")
    for row in result["targets"]:
        if row["satisfying"]:
            claims = ", ".join(row["satisfying"])
            print(f"  {row['target']}  SATISFIED  <- {claims}")
        else:
            print(f"  {row['target']}  UNMET")

    print()
    if result["non_violating_self_witnessed"]:
        print("self-witnessed claims present, not counted (target not satisfied by them):")
        for r in result["non_violating_self_witnessed"]:
            print(f"  {r['claim']} -> {r['target']}  (backing={r['backing']}, witness={r['witness']})")
    else:
        print("self-witnessed claims present, not counted: none")

    if result["malformed_markers"]:
        print()
        print("malformed terminal-shaped markers (excluded, not targets):")
        for mid in result["malformed_markers"]:
            print(f"  {mid}")

    print()
    print(f"self-vouch violations: {len(result['violations'])}")
    for r in result["violations"]:
        print(f"  ! {r['claim']} -> {r['target']}  witness={r['witness']} == signer of its own document")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("corpus", nargs="?", help="directory or file (default: the main tree's .ledger)")
    opts = parser.parse_args()

    try:
        extract_mod = load_module(EXTRACT_ENTRIES, "self_vouch_extract_entries")
        convergence_mod = load_module(CONVERGENCE, "self_vouch_convergence")
        terminal_mod = load_module(TERMINAL_SATISFACTION, "self_vouch_terminal_satisfaction")
        corpus = Path(opts.corpus) if opts.corpus else resolve_default_corpus()
        if not corpus.exists():
            raise EnvError(f"corpus path does not exist: {corpus}")
        export = extract(extract_mod, corpus)
    except EnvError as err:
        print(f"self_vouch: ENV: {err}", file=sys.stderr)
        return 2

    result = evaluate(export, extract_mod, convergence_mod, terminal_mod)
    render(result)

    for finding in export.get("findings", []):
        where = finding["doc"] + (f":{finding['marker']}" if finding.get("marker") else "")
        print(f"self_vouch: extraction finding at {where}: {finding['reason']}", file=sys.stderr)

    return 1 if result["violations"] else 0


if __name__ == "__main__":
    sys.exit(main())
