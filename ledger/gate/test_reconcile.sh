#!/usr/bin/env bash
# Fixtures for the two explicit RECONCILE steps: premise-freshness and
# bidirectional coherence-impact. Each case asserts an exit code, so the
# evaluators are verified non-trivial (a wrong verdict changes the code).
#
#   premise-freshness  re-run a node's S1 tripwires against HEAD; a flipped
#                      verdict is STALE -> node INVALIDATED (exit 1).
#   coherence-impact   re-run the machine-checks over the affected surface; a
#                      surviving file referencing a removed workflow is breakage
#                      caught at the boundary (exit 1), not at CLOSE.
#
# Usage: test_reconcile.sh
# Exit:  0 = every case matched, 1 = a case mismatched, 2 = environment error.
set -u
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root="$(cd "$here/../.." && pwd)"
fix="$root/ledger/fixtures/reconcile"

fails=0
expect() { # description expected-rc -- command...
  local desc="$1" exp="$2"; shift 2
  ( cd "$root" && "$@" ) >/dev/null 2>&1; local rc=$?
  if [ "$rc" -eq "$exp" ]; then
    echo "PASS  ($rc) $desc"
  else
    echo "FAIL  (got $rc, want $exp) $desc"; fails=$((fails + 1))
  fi
}

# premise-freshness: a premise that still holds -> FRESH (0).
expect "premise-freshness FRESH premise" 0 \
  "$here/premise_fresh.sh" FIXTURE "$fix/premise_fresh.tsv"

# premise-freshness: a premise refuted by a sibling landing -> INVALIDATED (1).
expect "premise-freshness STALE premise -> INVALIDATED" 1 \
  "$here/premise_fresh.sh" FIXTURE "$fix/premise_stale.tsv"

# coherence-impact: a landing leaving a live /ghost orphan -> INCOHERENT (1).
expect "coherence-impact breaking landing caught at boundary" 1 \
  "$here/coherence_impact.sh" "$fix/coherence_broken" --removed ghost

# coherence-impact: a clean tree -> COHERENT (0).
expect "coherence-impact clean tree" 0 \
  "$here/coherence_impact.sh" "$fix/coherence_clean" --removed ghost

if [ "$fails" -ne 0 ]; then
  echo "FAIL: $fails reconcile case(s) mismatched"; exit 1
fi
echo "PASS: all reconcile cases matched their expected exit codes"
exit 0
