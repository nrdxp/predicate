#!/usr/bin/env bash
# Fixtures for skills/record/process_feedback.ncl — the process-feedback
# record, reformed to extend the entry core: signer + `at` anchor on every
# record. The category model (kind, with AMENDMENT's higher bar) and the
# PROCESS-gate wiring are preserved.
#
# Greens: the seed instance through the apply shim (the same path the PROCESS
# gate uses). Each FAIL case asserts the error names its OWN predicate,
# matched against that case's own output only.
#
# Usage: test_process_feedback.sh
# Exit:  0 = every case matched, 1 = a case mismatched, 2 = environment error.
set -u
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root="$(cd "$here/../.." && pwd)"
fix="$root/ledger/fixtures/process_feedback"
apply="$root/skills/record/process_feedback_apply.ncl"

command -v nickel >/dev/null 2>&1 || { echo "ENV: nickel not found on PATH"; exit 2; }
[ -d "$fix" ] || { echo "ENV: fixtures dir missing: $fix"; exit 2; }
[ -f "$apply" ] || { echo "ENV: apply-file missing: $apply"; exit 2; }

fails=0
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

run() { nickel export "$1" --apply-contract "$apply"; }

expect "seed instance (signed, anchored) -> export clean" 0 "" \
  -- run "$root/ledger/fixtures/process_feedback_seed.yaml"

expect "feedback without signer (required-field red) -> missing field" 1 'missing definition for `signer`' \
  -- run "$fix/red-no-signer.yaml"
expect "feedback without at -> missing field" 1 'missing definition for `at`' \
  -- run "$fix/red-no-at.yaml"
expect "out-of-set kind string -> Kind" 1 "Kind: expected" \
  -- run "$fix/red-bad-kind.yaml"

if [ "$fails" -ne 0 ]; then
  echo "FAIL: $fails process-feedback case(s) mismatched"; exit 1
fi
echo "PASS: all process-feedback cases matched their expected exit codes"
exit 0
