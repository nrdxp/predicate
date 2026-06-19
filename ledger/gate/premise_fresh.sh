#!/usr/bin/env bash
# Premise-freshness evaluator (the explicit per-boundary RECONCILE step).
#
# A campaign node's IBC states its world-state assumptions as S1 tripwires:
# falsifiable checks that held when the node was planned. Sibling landings
# mutate the world, so before dispatching a PENDING node its tripwires are
# re-run against current HEAD. A tripwire whose verdict flipped means the
# premise is STALE and the node is INVALIDATED (its IBC realigned before
# dispatch). Running this at every boundary is what kills cross-node drift at
# the boundary instead of letting it accumulate to CLOSE.
#
# Tripwire spec: a file of one tripwire per line,
#     <expected-exit><TAB><shell command>
# Blank lines and #-comments ignored. Each command is run with `bash -c` from
# the repo root (the orchestrator's cwd); its actual exit is compared to the
# expected exit. Match -> FRESH; mismatch -> STALE. The command IS the premise's
# evaluator (Verification Dual: the strongest available check closes it), so a
# premise with no expressible check has no business as a tripwire.
#
# Usage:   premise_fresh.sh <node-id> <tripwire-spec-file>
# Output:  FRESH/STALE per tripwire, then a verdict line.
# Exit:    0 = node FRESH (every tripwire held), 1 = node INVALIDATED (a
#          tripwire is stale), 2 = usage / spec error.
set -u

node="${1:-}"
spec="${2:-}"
if [ -z "$node" ] || [ -z "$spec" ]; then
  echo "usage: premise_fresh.sh <node-id> <tripwire-spec-file>" >&2
  exit 2
fi
if [ ! -f "$spec" ]; then
  echo "premise_fresh: no such spec file: $spec" >&2
  exit 2
fi

stale=0
count=0
while IFS=$'\t' read -r expected cmd || [ -n "$expected" ]; do
  # skip blanks and comments
  case "$expected" in
    ''|'#'*) continue ;;
  esac
  if [ -z "${cmd:-}" ]; then
    echo "premise_fresh: malformed tripwire (no command): $expected" >&2
    exit 2
  fi
  count=$((count + 1))
  bash -c "$cmd" >/dev/null 2>&1
  actual=$?
  if [ "$actual" -eq "$expected" ]; then
    echo "FRESH  ($actual==$expected)  $cmd"
  else
    echo "STALE  (got $actual, want $expected)  $cmd"
    stale=$((stale + 1))
  fi
done < "$spec"

if [ "$count" -eq 0 ]; then
  echo "premise_fresh: spec declared no tripwires" >&2
  exit 2
fi
if [ "$stale" -ne 0 ]; then
  echo "INVALIDATED: node $node has $stale stale premise(s); realign before dispatch"
  exit 1
fi
echo "FRESH: node $node — every premise still holds against HEAD"
exit 0
