#!/usr/bin/env bash
# Scale-invariant gate-set evaluator (C7).
#
# Proves, mechanically and deterministically, that the gate set a /core task
# runs is a SUPERSET of the gate set a DAG node runs: every gate a node passes,
# a /core task also passes. The discipline is then scale-invariant — a direct
# task meets at least the gates a campaign node does, so nothing is enforced on
# the campaign path that is skippable on the direct path.
#
# The two sets are data, in gate-sets/{node,core}.txt — each line a gate
# identifier naming the evaluator that closes one boundary step (sourced from
# rules.md §3, the universal Commit Gate, and §4, the /core Verification
# Protocol additions). The proof is set inclusion via `comm -23`:
#
#   comm -23 <sorted node-gates> <sorted core-gates>
#
# emits the gates in node NOT in core. Empty output  =>  node ⊆ core  =>  the
# /core set is a superset. A non-empty line is a node gate the /core set fails
# to cover: a superset violation, and the gate exits non-zero naming it.
#
# Usage:
#   gate-set.sh node            print the node gate set (sorted, comments stripped)
#   gate-set.sh core            print the /core gate set (sorted, comments stripped)
#   gate-set.sh check           prove core ⊇ node; exit 0 iff `comm -23` is empty
#   gate-set.sh diff            print the gates /core ADDS over a node (comm -13)
#
# Exit codes: 0 = superset holds, 1 = a node gate is uncovered (violation),
# 2 = usage or environment error.
set -euo pipefail

# Resolve THIS script's own real directory (symlink-safe via realpath) so the
# gate-set DATA it reads — gate-sets/{node,core}.txt — is located relative to
# where the PLUGIN lives, not relative to whatever repo is being gated. The proof
# is correct wherever it is invoked from, including through a symlink downstream.
here="$(cd "$(dirname "$(realpath "${BASH_SOURCE[0]}")")" && pwd)"
sets="$here/gate-sets"

# Read a gate-set file to a sorted, de-duplicated, comment-free stream. Sorting
# here makes author order in the data files irrelevant to the comparison and
# satisfies `comm`'s precondition that both inputs are sorted.
normalize() {
  local file="$1"
  if [[ ! -f "$file" ]]; then
    echo "gate-set: no such gate-set file: $file" >&2
    exit 2
  fi
  grep -v '^[[:space:]]*#' "$file" \
    | grep -v '^[[:space:]]*$' \
    | sed 's/[[:space:]]*$//' \
    | LC_ALL=C sort -u
}

cmd_node() { normalize "$sets/node.txt"; }
cmd_core() { normalize "$sets/core.txt"; }

# check: comm -23 over the two normalized sets. The two process substitutions
# feed comm sorted streams; -23 suppresses lines unique to core (column 2) and
# lines common to both (column 3), leaving only lines unique to node (column 1)
# — exactly the node gates the /core set fails to cover.
cmd_check() {
  local uncovered
  uncovered="$(LC_ALL=C comm -23 <(cmd_node) <(cmd_core))"
  if [[ -n "$uncovered" ]]; then
    echo "FAIL: /core gate set is NOT a superset of the node gate set." >&2
    echo "Node gates not covered by /core:" >&2
    echo "$uncovered" | sed 's/^/  - /' >&2
    return 1
  fi
  echo "PASS: /core gate set ⊇ node gate set (every node gate is a /core gate)."
  return 0
}

# diff: the gates /core adds over a node (comm -13: suppress node-unique and
# common, leaving core-unique). Informational; not a pass/fail gate.
cmd_diff() {
  echo "Gates /core adds over a node:"
  LC_ALL=C comm -13 <(cmd_node) <(cmd_core) | sed 's/^/  + /'
}

main() {
  local sub="${1:-}"
  case "$sub" in
    node)  cmd_node ;;
    core)  cmd_core ;;
    check) cmd_check ;;
    diff)  cmd_diff ;;
    *)
      echo "usage: gate-set.sh {node|core|check|diff}" >&2
      exit 2
      ;;
  esac
}

main "$@"
