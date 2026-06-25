#!/usr/bin/env python3
"""Tracker-freshness gate — the Python effectful tier (K10 middle layer).

Decides whether a context-map instance is FRESH (all item `last_validated`
dates >= the reference date) or STALE (one or more items are behind).

This is the P-TRACK gate (primitives-spec.md §P-TRACK I-T3): the tracker
MUST be re-surfaced and updated at each step; staleness is caught via
`last_validated` compared against the HEAD git commit date.

Architecture (K10 three-tier):
  Nickel/functional  tracker_freshness.ncl  — pure staleness predicate
  Python (this file) tracker_fresh.py       — effectful: export the
                                              context-map, get HEAD date,
                                              call the Nickel predicate
  Bash               tracker_fresh.sh       — thin entrypoint; routes here

DOWNSTREAM PORTABILITY (the -I constraint from the IBC):
  This script locates tracker_freshness.ncl by resolving its own real path
  (symlink-safe via os.path.realpath) and stepping two directories up to
  the plugin root — exactly the same pattern as authorized.py. It NEVER
  uses a project-relative path; the -I flag and contract imports are always
  absolute, so the gate runs correctly wherever predicate is installed.

Usage:
  tracker_fresh.py --artifact <context_map_instance.ncl>
                   [--reference-date YYYY-MM-DD]
                   [--git-root <repo-root>]

  --artifact         path to a .ncl file that exports a ContextMap instance
  --reference-date   override the reference date (default: HEAD commit date)
  --git-root         git repository root for HEAD date lookup (default: cwd)

Exit codes:
  0 = FRESH (every item's last_validated >= reference date)
  1 = STALE (one or more items are behind; reorientation may be due)
  2 = usage or environment error (nickel/nix not found, artifact not found, …)
"""

import argparse
import json
import os
import shutil
import subprocess
import sys
import tempfile

# ── Plugin-root resolution (symlink-safe) ──────────────────────────────────
# This script lives at <plugin>/ledger/gate/tracker_fresh.py.
# Two parent directories up → <plugin>/.
_SELF_DIR = os.path.dirname(os.path.realpath(__file__))
_PLUGIN_ROOT = os.path.dirname(os.path.dirname(_SELF_DIR))
_CONTRACTS_DIR = os.path.join(_PLUGIN_ROOT, "ledger", "contracts")
_FRESHNESS_NCL = os.path.join(_CONTRACTS_DIR, "tracker_freshness.ncl")
_CONTEXT_MAP_NCL = os.path.join(_CONTRACTS_DIR, "context_map.ncl")


def _nickel_cmd() -> list:
    """Resolve a portable nickel runner: direct `nickel` XOR `nix run …`.

    Mirrors ledger-validate.sh / authorized.py so the gate is identical in a
    human shell and a headless orchestrator. Exits 2 if neither is reachable.
    """
    if shutil.which("nickel"):
        return ["nickel"]
    if shutil.which("nix"):
        return ["nix", "run", "nixpkgs#nickel", "--"]
    sys.stderr.write(
        "tracker_fresh: neither 'nickel' nor 'nix' on PATH; "
        "cannot evaluate the freshness predicate\n"
    )
    sys.exit(2)


def export_artifact(artifact: str, nickel: list) -> dict:
    """Export a ContextMap .ncl instance to JSON; exit 2 on failure.

    Uses -I pointing at the PLUGIN's contracts/ directory so `import
    "context_map.ncl"` resolves via the installed predicate, not a
    project-relative path.  Downstream consumers need not vendor the
    contracts locally.
    """
    proc = subprocess.run(
        nickel + ["export", "-I", _CONTRACTS_DIR, artifact],
        capture_output=True,
        text=True,
    )
    if proc.returncode != 0:
        sys.stderr.write(
            f"tracker_fresh: nickel export failed for {artifact!r}:\n"
            + proc.stderr
        )
        sys.exit(2)
    try:
        return json.loads(proc.stdout)
    except json.JSONDecodeError as exc:
        sys.stderr.write(
            f"tracker_fresh: cannot parse nickel export output: {exc}\n"
        )
        sys.exit(2)


def head_commit_date(git_root: str) -> str:
    """Return the HEAD commit date as YYYY-MM-DD.

    Runs `git log -1 --format=%cs` in git_root.  Exits 2 on failure.
    """
    proc = subprocess.run(
        ["git", "-C", git_root, "log", "-1", "--format=%cs"],
        capture_output=True,
        text=True,
    )
    if proc.returncode != 0 or not proc.stdout.strip():
        sys.stderr.write(
            f"tracker_fresh: cannot get HEAD commit date from {git_root!r}:\n"
            + proc.stderr
        )
        sys.exit(2)
    return proc.stdout.strip()


def call_freshness_predicate(items: list, reference_date: str, nickel: list) -> list:
    """Call tracker_freshness.ncl's stale_items predicate; return stale items.

    Writes a temporary driver .ncl that imports the freshness contract by
    ABSOLUTE path (the plugin root — no project-relative assumption) and
    the items as a JSON sidecar.  Returns the list of stale item records.
    """
    # Nickel imports JSON natively; write items to a sidecar to avoid
    # quoting issues between Python and Nickel string literals.
    stale = []
    tmp_ncl = None
    tmp_json = None
    try:
        with tempfile.NamedTemporaryFile(
            "w", suffix=".json", delete=False, encoding="utf-8"
        ) as jf:
            json.dump(items, jf)
            tmp_json = jf.name

        driver = (
            f'let tf = import "{_FRESHNESS_NCL}" in\n'
            f'let items = import "{tmp_json}" in\n'
            f'tf.stale_items items "{reference_date}"\n'
        )
        with tempfile.NamedTemporaryFile(
            "w", suffix=".ncl", delete=False, encoding="utf-8"
        ) as fh:
            fh.write(driver)
            tmp_ncl = fh.name

        proc = subprocess.run(
            nickel + ["export", tmp_ncl],
            capture_output=True,
            text=True,
        )
        if proc.returncode != 0:
            sys.stderr.write(
                "tracker_fresh: freshness predicate failed:\n" + proc.stderr
            )
            sys.exit(2)
        stale = json.loads(proc.stdout)
    except (OSError, json.JSONDecodeError) as exc:
        sys.stderr.write(f"tracker_fresh: predicate evaluation error: {exc}\n")
        sys.exit(2)
    finally:
        for tmp in (tmp_ncl, tmp_json):
            if tmp:
                try:
                    os.unlink(tmp)
                except OSError:
                    pass
    return stale


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Tracker-freshness gate: check whether a context-map's "
        "last_validated fields are current against the HEAD commit date."
    )
    parser.add_argument(
        "--artifact",
        required=True,
        help="path to a .ncl file that exports a ContextMap instance",
    )
    parser.add_argument(
        "--reference-date",
        default=None,
        help="reference date YYYY-MM-DD (default: HEAD commit date of --git-root)",
    )
    parser.add_argument(
        "--git-root",
        default=".",
        help="git repo root for HEAD date lookup (default: current directory)",
    )
    args = parser.parse_args()

    if not os.path.isfile(args.artifact):
        sys.stderr.write(
            f"tracker_fresh: no such artifact: {args.artifact!r}\n"
        )
        return 2

    nickel = _nickel_cmd()

    # Resolve reference date: prefer the explicit override, else query git HEAD.
    reference_date = args.reference_date or head_commit_date(args.git_root)

    # Export the context-map instance to JSON.
    context_map = export_artifact(args.artifact, nickel)
    items = context_map.get("items", [])

    if not items:
        print(f"tracker_fresh: no items in context map — trivially FRESH")
        return 0

    # Delegate staleness detection to the Nickel predicate.
    stale = call_freshness_predicate(items, reference_date, nickel)

    # Report.
    fresh_ids = {it["id"] for it in items} - {it["id"] for it in stale}
    for it in items:
        if it["id"] in fresh_ids:
            print(f"FRESH  {it['id']}  last_validated={it['last_validated']!r}  (>= {reference_date})")
        else:
            src = it.get("hydration_source")
            src_note = f"  hydration_source={src!r}" if src else ""
            print(
                f"STALE  {it['id']}  last_validated={it['last_validated']!r}"
                f"  (< {reference_date}){src_note}"
            )

    if stale:
        print(
            f"\nSTALE: {len(stale)} item(s) behind reference date {reference_date}; "
            "reorientation may be due (run /orient to refresh AGENTS.md)"
        )
        return 1

    print(f"\nFRESH: every item is current as of {reference_date}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
