#!/usr/bin/env python3
"""Decide whether a set of changed paths is authorized by a campaign DAG.

The campaign principle "not in the IBC -> not authorized" made mechanical:
a change is authorized only if every changed path falls under the declared
`file_surface` of some node in the validated DAG. A path with no covering
node is unauthorized, and the gate that calls this script must fail.

The DAG is read as the JSON `nickel export` produces from a `Dag`-validated
artifact (the same export that is the structural gate), so authorization can
only ever run over a graph that already passed its contract.

Locus (gate-locus / D-DUP): this script is a THIN SHIM. The path-containment
PREDICATE — exact match and directory-subtree prefixing — lives in ONE place,
`ledger/contracts/authorized.ncl`, the same definition `dag.ncl` imports for its
conflict gate. The Python here only (a) gathers the effectful inputs (staged
paths from git or stdin, the DAG JSON), (b) hands the (surface, path) pairs to
that Nickel predicate via a single `nickel export`, and (c) routes on the
verdict. Functional core (Nickel), imperative shell (this file).

Shell-glob matching is the ONE honest Python fallback: Nickel's containment
predicate decides exact/prefix containment; a surface carrying a glob
metacharacter (`*?[`) that the containment predicate does NOT cover is then
tested by `fnmatch` here. So a node's `file_surface` entry covers a changed path
when:
  - the entry equals the path, or
  - the entry ends in "/" and is a prefix of the path (a directory surface),
  - the entry is a directory and the path lies beneath it (no trailing "/"),
  - the entry contains a shell glob and fnmatch accepts the path.
The first three are decided by `authorized.ncl`; the last is the fnmatch fallback.

Usage:
  authorized.py --dag <exported.json> --path skills/foo.py [--path ...]
  git diff --cached --name-only | authorized.py --dag <exported.json>
  authorized.py --dag <exported.json> --ibc-surface-check <node-id> \
      --ibc <exported-ibc.json>

Exit codes: 0 = every path authorized, 1 = one or more paths unauthorized,
2 = usage or input error.
"""

import argparse
import fnmatch
import json
import os
import shutil
import subprocess
import sys
import tempfile

# The single Nickel home for the containment predicate. Resolved relative to THIS
# script's real path so the shim finds it wherever it is invoked from (a worktree,
# a consuming repo through a symlink): <plugin>/ledger/gate/authorized.py, so the
# contract is one dir up and over in <plugin>/ledger/contracts/authorized.ncl.
_AUTHORIZED_NCL = os.path.join(
    os.path.dirname(os.path.dirname(os.path.realpath(__file__))),
    "contracts",
    "authorized.ncl",
)

_HAS_GLOB = "*?["


def _has_glob(token: str) -> bool:
    """True if a surface token carries a shell-glob metacharacter."""
    return any(ch in token for ch in _HAS_GLOB)


def _nickel_cmd() -> list:
    """Resolve a portable nickel runner: direct `nickel` XOR `nix run …`.

    Mirrors ledger-validate.sh so the shim is identical in a human shell and a
    headless orchestrator. Exits 2 if neither is reachable — a gate that cannot
    evaluate its own predicate is not a gate that passes.
    """
    if shutil.which("nickel"):
        return ["nickel"]
    if shutil.which("nix"):
        return ["nix", "run", "nixpkgs#nickel", "--"]
    sys.stderr.write(
        "authorized.py: neither 'nickel' nor 'nix' on PATH; "
        "cannot evaluate the containment predicate\n"
    )
    sys.exit(2)


def _nickel_pairs(predicate: str, pairs: list) -> list:
    """Evaluate one containment PREDICATE over many (a, b) pairs in ONE export.

    `predicate` is "covers" or "tokens_overlap" — a function exported by
    authorized.ncl. Returns a list of bools aligned with `pairs`. A single
    `nickel export` decides the whole batch, so the cost is one process per mode,
    not one per pair. Exits 2 on any nickel/parse failure (a predicate that
    cannot be evaluated must not silently pass).
    """
    if not pairs:
        return []
    # The pair list is handed to Nickel as DATA: written to a sidecar .json and
    # `import`ed (Nickel imports JSON natively as a value), so no JSON-vs-Nickel
    # record-syntax mismatch (`:` vs `=`) can arise. The driver imports the
    # shared predicate by absolute path and maps it over the imported pairs.
    tmp_ncl = None
    tmp_json = None
    try:
        with tempfile.NamedTemporaryFile(
            "w", suffix=".json", delete=False, encoding="utf-8"
        ) as jf:
            json.dump([list(p) for p in pairs], jf)
            tmp_json = jf.name
        driver = (
            f'let auth = import "{_AUTHORIZED_NCL}" in\n'
            f'let pairs = import "{tmp_json}" in\n'
            f"std.array.map "
            f"(fun pr => auth.{predicate} (std.array.at 0 pr) (std.array.at 1 pr)) "
            f"pairs\n"
        )
        with tempfile.NamedTemporaryFile(
            "w", suffix=".ncl", delete=False, encoding="utf-8"
        ) as fh:
            fh.write(driver)
            tmp_ncl = fh.name
        proc = subprocess.run(
            _nickel_cmd() + ["export", tmp_ncl],
            capture_output=True,
            text=True,
        )
        if proc.returncode != 0:
            sys.stderr.write(
                "authorized.py: containment predicate failed to evaluate:\n"
                + proc.stderr
            )
            sys.exit(2)
        result = json.loads(proc.stdout)
    except (OSError, json.JSONDecodeError) as exc:
        sys.stderr.write(f"authorized.py: containment evaluation error: {exc}\n")
        sys.exit(2)
    finally:
        for tmp in (tmp_ncl, tmp_json):
            if tmp:
                try:
                    os.unlink(tmp)
                except OSError:
                    pass
    if not isinstance(result, list) or len(result) != len(pairs):
        sys.stderr.write("authorized.py: malformed containment verdict\n")
        sys.exit(2)
    return result


# --- containment cache -----------------------------------------------------
# Each mode primes the cache once (one nickel export per predicate) so the
# predicate functions below are pure cache lookups. This keeps `covers` /
# `tokens_collide` callable inside the existing nested loops without one nickel
# process per pair.
_COVERS_CACHE: dict = {}
_OVERLAP_CACHE: dict = {}


def prime_covers(pairs: list) -> None:
    """Evaluate `covers` for every (surface, path) pair, caching the verdicts."""
    fresh = [p for p in pairs if p not in _COVERS_CACHE]
    for pr, verdict in zip(fresh, _nickel_pairs("covers", fresh)):
        _COVERS_CACHE[pr] = verdict


def prime_overlap(pairs: list) -> None:
    """Evaluate `tokens_overlap` for every (a, b) pair, caching the verdicts."""
    fresh = [p for p in pairs if p not in _OVERLAP_CACHE]
    for pr, verdict in zip(fresh, _nickel_pairs("tokens_overlap", fresh)):
        _OVERLAP_CACHE[pr] = verdict


def covers(surface: str, path: str) -> bool:
    """True if a file_surface entry covers a changed path.

    Containment (exact / directory-prefix) is decided by authorized.ncl; a glob
    surface the containment predicate did not cover is the fnmatch fallback.
    """
    if not surface:
        return False
    key = (surface, path)
    if key not in _COVERS_CACHE:
        prime_covers([key])
    if _COVERS_CACHE[key]:
        return True
    # Glob fallback: the one irreducible authorization-time concern Nickel's
    # containment predicate deliberately leaves to fnmatch.
    if _has_glob(surface) and fnmatch.fnmatch(path, surface):
        return True
    return False


def tokens_collide(a: str, b: str) -> bool:
    """True if two surface TOKENS path-contain one another (either direction).

    Mirrors the Nickel contract's `tokens_overlap`: a directory token contains
    files beneath it, so "docs/" collides with "docs/x.md". Containment is
    decided by authorized.ncl; glob tokens are compared by fnmatch (either
    direction) as the Python fallback. This is the surface-vs-surface collision
    test the surface-exceed protocol's collision-check runs; `covers` is the
    surface-vs-concrete-path test the authorization gate runs.
    """
    if not a or not b:
        return False
    key = (a, b)
    if key not in _OVERLAP_CACHE:
        prime_overlap([key])
    if _OVERLAP_CACHE[key]:
        return True
    # Glob fallback (either direction).
    if _has_glob(a) and fnmatch.fnmatch(b, a):
        return True
    if _has_glob(b) and fnmatch.fnmatch(a, b):
        return True
    return False


def surfaces_collide(surfaces_a: list, surfaces_b: list) -> list:
    """Return the (a, b) token pairs that collide between two surface lists."""
    # Prime the full cross product in one nickel export, then route purely.
    prime_overlap([(sa, sb) for sa in surfaces_a for sb in surfaces_b])
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


def authorizing_node(nodes: list, path: str):
    """Return the id of the first node whose surface covers path, else None."""
    for node in nodes:
        for surface in node.get("file_surface", []):
            if covers(surface, path):
                return node.get("id")
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

    # Prime the containment cache once: every (surface, path) pair across the
    # whole DAG, in a single nickel export, before the routing loop below.
    all_surfaces = [s for node in nodes for s in node.get("file_surface", [])]
    prime_covers([(s, p) for p in paths for s in all_surfaces])

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
    # Prime containment for (declared surface, touched path) pairs in one export.
    declared = node.get("file_surface", [])
    prime_covers([(s, p) for p in touched for s in declared])
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


# Marker an IBC author places on a context_map entry to declare it read-only
# context: the worker will read it but never edit it, so it is exempt from the
# surface-coverage lint below.
_READ_ONLY_MARK = "(read-only)"


def _context_map_path(entry: str):
    """Extract the leading file path from a context_map entry, or None.

    S5 entries lead with a pointer — "path", "path:12-40 — excerpt", or the
    code-span form templates/IBC.md prescribes, "`path:120-180` — why". The
    path is the first whitespace token with any markdown code-span backticks,
    trailing punctuation, and :line suffix stripped. An entry whose first
    token does not look like a path (no "/" and no ".") is non-path context
    (a quoted spec clause, a command narrative) and is skipped rather than
    guessed at.
    """
    token = entry.split()[0] if entry.split() else ""
    token = token.strip("`").rstrip(":,;")
    token = token.split(":")[0].strip("`")
    if "/" in token or "." in token:
        return token
    return None


def run_ibc_surface_check(args: argparse.Namespace) -> int:
    """Pre-dispatch lint: context_map ⊆ file_surface, or tagged read-only.

    The most common IBC-authoring defect in the field: the context_map names a
    file the worker will plausibly need to EDIT, but the node's declared
    file_surface omits it — so the worker's own commit gate correctly blocks
    an otherwise-correct change, costing a HALT, an investigation, a widen,
    and a re-dispatch. Everything needed to prevent that round-trip is known
    at authoring time, so this check runs BEFORE dispatch: every path-bearing
    context_map entry must either fall under the node's declared file_surface
    or carry the explicit "(read-only)" marker. Exit 0 = lint clean, 1 = at
    least one unmarked, uncovered path, 2 = input error.
    """
    dag = load_dag(args.dag)
    node = node_by_id(dag.get("nodes", []), args.ibc_surface_check)
    if node is None:
        sys.stderr.write(
            f"ibc-surface-check: no node {args.ibc_surface_check!r} in DAG\n"
        )
        return 2
    try:
        with open(args.ibc, encoding="utf-8") as fh:
            ibc = json.load(fh)
    except (OSError, json.JSONDecodeError) as exc:
        sys.stderr.write(f"cannot read IBC {args.ibc!r}: {exc}\n")
        return 2
    declared = node.get("file_surface", [])
    entries = ibc.get("context_map", [])
    checkable = []
    for entry in entries:
        if _READ_ONLY_MARK in entry:
            print(f"RO    {entry}")
            continue
        path = _context_map_path(entry)
        if path is None:
            print(f"SKIP  {entry}  <- no leading path token")
            continue
        checkable.append((entry, path))
    # One nickel export primes every (surface, path) pair before the loop.
    prime_covers([(s, p) for _, p in checkable for s in declared])
    uncovered = []
    for entry, path in checkable:
        if any(covers(s, path) for s in declared):
            print(f"OK    {path}  <- declared surface of {args.ibc_surface_check}")
        else:
            uncovered.append((entry, path))
    for entry, path in uncovered:
        print(f"UNCOVERED {path}  <- context_map entry outside file_surface: {entry}")
    if uncovered:
        print(
            f"FAIL: {len(uncovered)} context_map path(s) outside node "
            f"{args.ibc_surface_check}'s file_surface — add each to "
            f"file_surface (if the worker may edit it) or mark the entry "
            f"{_READ_ONLY_MARK} (if it is context only). Do not rely on the "
            "worker's HALT to catch this after dispatch."
        )
        return 1
    print(
        f"PASS: every path-bearing context_map entry of node "
        f"{args.ibc_surface_check} is covered or read-only"
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
    mode.add_argument(
        "--ibc-surface-check", metavar="NODE_ID",
        help="pre-dispatch lint: every path-bearing context_map entry in "
        "--ibc is covered by the node's file_surface or marked (read-only)",
    )
    parser.add_argument(
        "--against-surfaces", action="append", metavar="S1,S2,...",
        help="comma-separated concurrent surfaces (collision-check mode)",
    )
    parser.add_argument(
        "--ibc", metavar="IBC_JSON",
        help="exported worker-IBC JSON (ibc-surface-check mode)",
    )
    args = parser.parse_args()

    if args.collision_check:
        return run_collision_check(args)
    if args.reconcile_node:
        if not args.dag:
            sys.stderr.write("reconcile-node mode requires --dag\n")
            return 2
        return run_reconcile_node(args)
    if args.ibc_surface_check:
        if not args.dag or not args.ibc:
            sys.stderr.write("ibc-surface-check mode requires --dag and --ibc\n")
            return 2
        return run_ibc_surface_check(args)
    # Default mode: authorize the change set against the whole DAG.
    if not args.dag:
        sys.stderr.write("authorize mode requires --dag\n")
        return 2
    return run_authorize(args)


if __name__ == "__main__":
    sys.exit(main())
