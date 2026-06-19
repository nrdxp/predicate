#!/usr/bin/env python3
"""Decide whether a set of changed paths is authorized by a campaign DAG.

The campaign principle "not in the IBC -> not authorized" made mechanical:
a change is authorized only if every changed path falls under the declared
`file_surface` of some node in the validated DAG. A path with no covering
node is unauthorized, and the gate that calls this script must fail.

The DAG is read as the JSON `nickel export` produces from a `Dag`-validated
artifact (the same export that is the structural gate), so authorization can
only ever run over a graph that already passed its contract.

A node's `file_surface` entry covers a changed path when:
  - the entry equals the path, or
  - the entry ends in "/" and is a prefix of the path (a directory surface),
  - the entry is a directory and the path lies beneath it (no trailing "/"),
  - the entry contains a shell glob and fnmatch accepts the path.

Usage:
  authorized.py --dag <exported.json> --path skills/foo.py [--path ...]
  git diff --cached --name-only | authorized.py --dag <exported.json>

Exit codes: 0 = every path authorized, 1 = one or more paths unauthorized,
2 = usage or input error.
"""

import argparse
import fnmatch
import json
import sys


def covers(surface: str, path: str) -> bool:
    """True if a file_surface entry covers a changed path."""
    if not surface:
        return False
    if surface == path:
        return True
    # Directory surface: trailing slash, or an entry that names a dir prefix.
    prefix = surface if surface.endswith("/") else surface + "/"
    if path.startswith(prefix):
        return True
    # Glob surface (e.g. "templates/*.md").
    if any(ch in surface for ch in "*?[") and fnmatch.fnmatch(path, surface):
        return True
    return False


def authorizing_node(nodes: list, path: str):
    """Return the id of the first node whose surface covers path, else None."""
    for node in nodes:
        for surface in node.get("file_surface", []):
            if covers(surface, path):
                return node.get("id")
    return None


def read_paths(args: argparse.Namespace) -> list:
    if args.path:
        return list(args.path)
    return [ln.strip() for ln in sys.stdin if ln.strip()]


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Check changed paths against a DAG's authorizing surfaces."
    )
    parser.add_argument(
        "--dag", required=True, help="path to exported DAG JSON"
    )
    parser.add_argument(
        "--path", action="append", help="a changed path (repeatable)"
    )
    args = parser.parse_args()

    try:
        with open(args.dag, encoding="utf-8") as fh:
            dag = json.load(fh)
    except (OSError, json.JSONDecodeError) as exc:
        sys.stderr.write(f"cannot read DAG {args.dag!r}: {exc}\n")
        return 2

    nodes = dag.get("nodes", [])
    paths = read_paths(args)
    if not paths:
        # No staged change is vacuously authorized; the caller decides whether
        # an empty change set is meaningful.
        print("PASS: no paths to authorize")
        return 0

    unauthorized = []
    for path in paths:
        node = authorizing_node(nodes, path)
        if node is None:
            unauthorized.append(path)
        else:
            print(f"OK   {path}  <- node {node}")

    for path in unauthorized:
        print(f"DENY {path}  <- no authorizing DAG node")
    if unauthorized:
        print(
            f"FAIL: {len(unauthorized)} unauthorized path(s) "
            "(not in the IBC -> not authorized)"
        )
        return 1
    print("PASS: every changed path is authorized by a DAG node")
    return 0


if __name__ == "__main__":
    sys.exit(main())
