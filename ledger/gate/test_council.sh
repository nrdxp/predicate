#!/usr/bin/env bash
# Fixtures for council.ncl — the council's law as an intrinsic Nickel contract.
# `nickel export <fixture>` IS the gate: a lawful constitution+ledger exports clean;
# a gapped / unilateral / no-consent / un-ratified / barred decision makes the export
# exit non-zero. Each FAIL case also asserts the error names its OWN invariant (not an
# incidental shape error), so a wrong verdict cannot pass by coincidence.
#
# Usage: test_council.sh
# Exit:  0 = every case matched, 1 = a case mismatched, 2 = environment error.
set -u
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root="$(cd "$here/../.." && pwd)"
fix="$root/ledger/fixtures/council"

command -v nickel >/dev/null 2>&1 || { echo "ENV: nickel not found on PATH"; exit 2; }
[ -d "$fix" ] || { echo "ENV: fixtures dir missing: $fix"; exit 2; }

fails=0
# expect DESC EXPECTED-RC KEYWORD -- COMMAND...
#   KEYWORD="" skips the message check (the clean PASS case).
expect() {
  local desc="$1" exp="$2" kw="$3"; shift 3
  [ "$1" = "--" ] && shift
  local out rc ok=1
  out="$( cd "$root" && "$@" 2>&1 )"; rc=$?
  [ "$rc" -eq "$exp" ] || ok=0
  if [ -n "$kw" ]; then printf '%s' "$out" | grep -q -- "$kw" || ok=0; fi
  if [ "$ok" -eq 1 ]; then
    echo "PASS  ($rc) $desc"
  else
    echo "FAIL  (got rc=$rc want $exp; want-kw='$kw') $desc"
    printf '%s\n' "$out" | tail -3
    fails=$((fails + 1))
  fi
}

# 1: complete constitution + valid ledger (incl. a routine owner-only decision) -> clean.
expect "complete law + valid ledger (proportional convening) -> export clean" 0 "" \
  -- nickel export "$fix/good.ncl"
# 2: a decision-type with no delegation rule -> anti-incoherence.
expect "gapped constitution -> anti-incoherence" 1 "anti-incoherence" \
  -- nickel export "$fix/gap.ncl"
# 3: a 'full terminal type with owner-only assent -> anti-unilateral.
expect "unilateral close -> anti-unilateral" 1 "anti-unilateral" \
  -- nickel export "$fix/unilateral.ncl"
# 4: a 'merge whose assent lacks the maintainer -> merge-consent (F5).
expect "merge without maintainer consent -> merge-consent" 1 "merge-consent" \
  -- nickel export "$fix/merge_no_consent.ncl"
# 5: a barred seat present in assent -> no-barred.
expect "barred seat in assent -> no-barred" 1 "no-barred" \
  -- nickel export "$fix/barred.ncl"
# 6: a 'dag-amendment whose assent lacks the head -> head-ratification (F7).
expect "dag-amendment without head ratification -> head-ratification" 1 "head-ratification" \
  -- nickel export "$fix/dag_amend_no_head.ncl"
# 7: a 'close with full MACHINE consensus but no head -> head-ratification. Proves the
# two terminal gates are distinct: 'full machine-consensus is met, yet the head's
# ratification (must_assent) is still required and its absence is named specifically.
expect "close without head ratification -> head-ratification" 1 "head-ratification" \
  -- nickel export "$fix/close_no_head.ncl"

if [ "$fails" -ne 0 ]; then
  echo "FAIL: $fails council case(s) mismatched"; exit 1
fi
echo "PASS: all council cases matched their expected exit codes"
exit 0
