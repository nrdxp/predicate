#!/usr/bin/env bash
# ledger/gate/test_clause_backing.sh
#
# Acceptance suite for `ledger/gate/clause_backing.py` — the derivation that
# proves or refutes each clause's `backing` declaration in
# `conditioning/core_clauses.ncl` instead of letting "corroborated" be a
# hand-graded reading. Three things must hold:
#
#   1. The two fixtures the derivation is required to catch loudly — a
#      declared gate that does not exist, and a declared check that exists
#      but does not actually reference the clause — are both caught
#      (`--selftest`).
#   2. The real corpus run is clean (no declared-but-unverified entry) and
#      reproduces the four clauses currently proven at CLAUSE grain:
#      `grounded-critique`, `roles-dispatch-under-persona`,
#      `reporting-posture`, `open-surface`.
#   3. `scrutiny-stakes` / `scrutiny-uncloseability` — corroborated at
#      SECTION grain by the hand-graded passes but refused here because their
#      declared checks survive with either bullet's own text removed — stay
#      out of the corroborated set. A regression that re-adds them without
#      first fixing the decorative-link problem must fail this case.
#
# Usage: bash ledger/gate/test_clause_backing.sh
# Exit:  0 = every case passes
#        1 = at least one case failed

set -uo pipefail

here="$(cd "$(dirname "$(realpath "${BASH_SOURCE[0]}")")" && pwd)"
root="$(cd "$here/../.." && pwd)"
tool="$here/clause_backing.py"

[ -f "$tool" ] || { echo "FAIL (env): missing $tool" >&2; exit 1; }
command -v nickel  >/dev/null 2>&1 || { echo "FAIL (env): nickel not on PATH" >&2; exit 1; }
command -v python3 >/dev/null 2>&1 || { echo "FAIL (env): python3 not on PATH" >&2; exit 1; }

FAIL=0

echo "── 1. selftest: the two required fixtures ───────────────────────────────"
selftest_out="$(cd "$root" && python3 "$tool" --selftest 2>&1)"
selftest_rc=$?
echo "$selftest_out" | sed 's/^/  /'
if [ "$selftest_rc" -eq 0 ]; then
  echo "  PASS  selftest exits 0"
else
  echo "  FAIL  selftest exited $selftest_rc"
  FAIL=1
fi

echo ""
echo "── 2. real corpus: clean run, four clauses proven at clause grain ───────"
full_out="$(cd "$root" && python3 "$tool" 2>&1)"
full_rc=$?
echo "$full_out" | sed 's/^/  /'
if [ "$full_rc" -eq 0 ]; then
  echo "  PASS  full run exits 0 (no declared-but-unverified entry)"
else
  echo "  FAIL  full run exited $full_rc"
  FAIL=1
fi

for cid in grounded-critique roles-dispatch-under-persona reporting-posture open-surface; do
  if echo "$full_out" | grep -q "^  + $cid  <-"; then
    echo "  PASS  corroborated: $cid"
  else
    echo "  FAIL  expected corroborated, not reported: $cid"
    FAIL=1
  fi
done

echo ""
echo "── 3. scrutiny-stakes / scrutiny-uncloseability stay UNCLOSED ───────────"
for cid in scrutiny-stakes scrutiny-uncloseability; do
  if echo "$full_out" | grep -q "^  + $cid  <-"; then
    echo "  FAIL  $cid reported corroborated (its declared check does not bind at clause grain)"
    FAIL=1
  else
    echo "  PASS  $cid not corroborated"
  fi
done

echo ""
if [ "$FAIL" -ne 0 ]; then
  echo "RESULT: FAIL"
  exit 1
fi
echo "RESULT: ALL PASS"
exit 0
