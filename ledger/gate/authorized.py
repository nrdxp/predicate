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


def tokens_collide(a: str, b: str) -> bool:
    """True if two surface TOKENS path-contain one another (either direction).

    Mirrors the Nickel contract's `tokens_overlap`: a directory token contains
    files beneath it, so "docs/" collides with "docs/x.md". Glob tokens are
    compared by fnmatch in either direction. This is the surface-vs-surface
    collision test the surface-exceed protocol's collision-check runs; `covers`
    is the surface-vs-concrete-path test the authorization gate runs.
    """
    if not a or not b:
        return False
    if a == b:
        return True

    def dir_contains(parent: str, child: str) -> bool:
        prefix = parent if parent.endswith("/") else parent + "/"
        return child.startswith(prefix)

    if dir_contains(a, b) or dir_contains(b, a):
        return True
    a_glob = any(ch in a for ch in "*?[")
    b_glob = any(ch in b for ch in "*?[")
    if a_glob and fnmatch.fnmatch(b, a):
        return True
    if b_glob and fnmatch.fnmatch(a, b):
        return True
    return False


def surfaces_collide(surfaces_a: list, surfaces_b: list) -> list:
    """Return the (a, b) token pairs that collide between two surface lists."""
    return [
        (sa, sb)
        for sa in surfaces_a
        for sb in surfaces_b
        if tokens_collide(sa, sb)
    ]


def node_by_id(nodes: list, node_id: str):
    """Return the node record with the given id, or None."""
    for node in nodes:
        if node.get("id") == node_id:
            return node
    return None


def undeclared_paths(node: dict, paths: list) -> list:
    """Paths a node actually touched that its declared file_surface omits.

    The reconcile honesty check: derive the worker's ACTUAL touched set (its
    diff) and reconcile it against the DECLARED file_surface. A path no declared
    surface entry `covers` is an undeclared touch — the conflict guarantee was
    computed against a surface narrower than reality, so the orchestrator must
    widen-and-recheck (collision-free) or treat it as a surface-exceed.
    """
    declared = node.get("file_surface", [])
    return [p for p in paths if not any(covers(s, p) for s in declared)]


def read_paths(args: argparse.Namespace) -> list:
    if args.path:
        return list(args.path)
    return [ln.strip() for ln in sys.stdin if ln.strip()]


def load_dag(dag_path: str):
    """Load the exported DAG JSON, or exit 2 on a read/parse error."""
    try:
        with open(dag_path, encoding="utf-8") as fh:
            return json.load(fh)
    except (OSError, json.JSONDecodeError) as exc:
        sys.stderr.write(f"cannot read DAG {dag_path!r}: {exc}\n")
        sys.exit(2)


def run_authorize(args: argparse.Namespace) -> int:
    """Default gate: every changed path is covered by some DAG node surface."""
    dag = load_dag(args.dag)
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


def run_collision_check(args: argparse.Namespace) -> int:
    """Surface-exceed protocol: does a requested path collide with the surfaces
    of the CONCURRENT nodes?

    The orchestrator runs this when a worker HALTs on a surface-exceed: derive
    the requested file, collision-check it against every concurrent node's
    declared surface. Disjoint (exit 0) -> authorize-and-widen the node's
    surface. Collision (exit 3) -> the requested file belongs to a concurrent
    node, so serialize instead of widening. The exit code IS the routing
    decision; no human judgment closes it.
    """
    requested = read_paths(args)
    if not requested:
        sys.stderr.write("collision-check: no --path requested\n")
        return 2
    against = []
    for group in args.against_surfaces or []:
        against.extend(s for s in group.split(",") if s)
    collisions = surfaces_collide(requested, against)
    if collisions:
        for req, surf in collisions:
            print(f"COLLIDE {req}  <- concurrent surface {surf}")
        print(
            f"SERIALIZE: {len(collisions)} collision(s) with concurrent "
            "surfaces (the requested file belongs to a sibling; serialize)"
        )
        return 3
    print(
        "WIDEN: requested paths are disjoint from all concurrent surfaces "
        "(authorize-and-widen the node's declared surface)"
    )
    return 0


def run_reconcile_node(args: argparse.Namespace) -> int:
    """Reconcile honesty: the node's ACTUAL touched set vs its DECLARED surface.

    Derive the worker's actual touched paths (its diff, on --path or stdin) and
    reconcile them against the node's declared file_surface. Touched-but-
    undeclared paths mean the conflict guarantee was computed over a surface
    narrower than reality; the orchestrator must reconcile (widen-and-recheck or
    treat as a surface-exceed) before accepting. Exit 0 = surface honest, exit
    1 = undeclared touches found.
    """
    dag = load_dag(args.dag)
    nodes = dag.get("nodes", [])
    node = node_by_id(nodes, args.reconcile_node)
    if node is None:
        sys.stderr.write(
            f"reconcile-node: no node {args.reconcile_node!r} in DAG\n"
        )
        return 2
    touched = read_paths(args)
    if not touched:
        print(f"PASS: node {args.reconcile_node} touched nothing")
        return 0
    undeclared = undeclared_paths(node, touched)
    for path in touched:
        if path not in undeclared:
            print(f"OK    {path}  <- declared surface of {args.reconcile_node}")
    for path in undeclared:
        print(f"UNDECLARED {path}  <- touched but outside declared surface")
    if undeclared:
        print(
            f"FAIL: {len(undeclared)} undeclared touch(es) for node "
            f"{args.reconcile_node} (reconcile the surface before accepting)"
        )
        return 1
    print(
        f"PASS: every touched path of node {args.reconcile_node} "
        "falls under its declared surface"
    )
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Authorize changed paths against a campaign DAG, and run "
        "the surface-exceed collision-check and reconcile honesty check."
    )
    parser.add_argument(
        "--dag", help="path to exported DAG JSON (authorize / reconcile modes)"
    )
    parser.add_argument(
        "--path", action="append", help="a changed path (repeatable)"
    )
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument(
        "--collision-check", action="store_true",
        help="surface-exceed routing: collide --path against concurrent "
        "--against-surfaces; exit 0 widen, exit 3 serialize",
    )
    mode.add_argument(
        "--reconcile-node", metavar="NODE_ID",
        help="reconcile honesty: check a node's touched paths against its "
        "declared file_surface",
    )
    parser.add_argument(
        "--against-surfaces", action="append", metavar="S1,S2,...",
        help="comma-separated concurrent surfaces (collision-check mode)",
    )
    args = parser.parse_args()

    if args.collision_check:
        return run_collision_check(args)
    if args.reconcile_node:
        if not args.dag:
            sys.stderr.write("reconcile-node mode requires --dag\n")
            return 2
        return run_reconcile_node(args)
    # Default mode: authorize the change set against the whole DAG.
    if not args.dag:
        sys.stderr.write("authorize mode requires --dag\n")
        return 2
    return run_authorize(args)


if __name__ == "__main__":
    sys.exit(main())
