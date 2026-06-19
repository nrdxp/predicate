#!/usr/bin/env bash
# Fixtures for the derive-and-verify surface protocol in authorized.py.
#
# Two protocols beyond plain authorization, each closed by an exit code so an
# orchestrator routes on the code with no judgment:
#
#   collision-check  the surface-exceed router. A worker HALTs on an undeclared
#                    file; the orchestrator collides the requested path against
#                    the CONCURRENT nodes' surfaces. exit 0 -> authorize-and-
#                    widen (disjoint); exit 3 -> serialize (the file belongs to
#                    a sibling). The exit code IS the decision.
#
#   reconcile-node   the honesty check. Derive a node's ACTUAL touched set (its
#                    diff) and reconcile it against its DECLARED file_surface.
#                    exit 0 -> surface honest; exit 1 -> touched-but-undeclared
#                    paths, so the conflict guarantee was computed over too
#                    narrow a surface and must be reconciled before acceptance.
#
# Each case names its expected exit code; a mismatch fails the script (the
# baseline-failure discipline: the assertion is non-trivial because the wrong
# routing would change the code). Usage: test_surface_protocol.sh
# Exit: 0 = every case matched, 1 = a case mismatched, 2 = environment error.
set -u
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
auth="$here/authorized.py"

fails=0
expect() { # description expected-rc -- command...
  local desc="$1" exp="$2"; shift 2
  "$@" >/dev/null 2>&1; local rc=$?
  if [ "$rc" -eq "$exp" ]; then
    echo "PASS  ($rc) $desc"
  else
    echo "FAIL  (got $rc, want $exp) $desc"; fails=$((fails + 1))
  fi
}

# collision-check: disjoint requested path -> widen (0).
expect "collision-check disjoint -> widen" 0 \
  python3 "$auth" --collision-check --path "newdir/file.py" \
    --against-surfaces "src/,docs/"

# collision-check: requested file lies beneath a concurrent dir -> serialize (3).
expect "collision-check dir-contains-file -> serialize" 3 \
  python3 "$auth" --collision-check --path "docs/x.md" \
    --against-surfaces "src/,docs/"

# collision-check: exact-token collision -> serialize (3).
expect "collision-check exact collision -> serialize" 3 \
  python3 "$auth" --collision-check --path "README.md" \
    --against-surfaces "README.md"

# collision-check: glob token matches requested -> serialize (3).
expect "collision-check glob match -> serialize" 3 \
  python3 "$auth" --collision-check --path "templates/IBC.md" \
    --against-surfaces "templates/*.md"

# A DAG with one node whose declared surface is narrow; used by reconcile cases.
tmp_dag="$(mktemp)"
cat > "$tmp_dag" <<'JSON'
{ "nodes": [
  { "id": "N", "depends_on": [], "file_surface": ["src/", "docs/x.md"],
    "discipline": "core", "mitigates": [] }
] }
JSON

# reconcile-node: every touched path under the declared surface -> honest (0).
expect "reconcile-node honest surface" 0 \
  python3 "$auth" --dag "$tmp_dag" --reconcile-node N \
    --path "src/a.py" --path "docs/x.md"

# reconcile-node: a touched path outside the declared surface -> undeclared (1).
expect "reconcile-node undeclared touch" 1 \
  python3 "$auth" --dag "$tmp_dag" --reconcile-node N \
    --path "src/a.py" --path "docs/y.md"

# reconcile-node: unknown node id is an environment error (2).
expect "reconcile-node unknown id" 2 \
  python3 "$auth" --dag "$tmp_dag" --reconcile-node NOPE --path "src/a.py"

rm -f "$tmp_dag"

if [ "$fails" -ne 0 ]; then
  echo "FAIL: $fails surface-protocol case(s) mismatched"; exit 1
fi
echo "PASS: all surface-protocol cases matched their expected exit codes"
exit 0
