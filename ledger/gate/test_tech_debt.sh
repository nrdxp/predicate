#!/usr/bin/env bash
# Fixtures for skills/record/tech_debt.ncl — the tech-debt record, reformed to
# extend the entry core: signer + `at` anchor on every debt, signpost expressed
# as the core's `discharge`. The category fields (severity, why_deferred,
# location) and the PROCESS-gate wiring are preserved.
#
# Greens: the seed instance through the apply shim (the same path the PROCESS
# gate uses). Each FAIL case asserts the error names its OWN predicate,
# matched against that case's own output only.
#
# Usage: test_tech_debt.sh
# Exit:  0 = every case matched, 1 = a case mismatched, 2 = environment error.
set -u
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root="$(cd "$here/../.." && pwd)"
fix="$root/ledger/fixtures/tech_debt"
apply="$root/skills/record/tech_debt_apply.ncl"

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

expect "seed instance (signed, anchored, discharge) -> export clean" 0 "" \
  -- run "$root/ledger/fixtures/tech_debt_seed.yaml"

expect "debt without signer (required-field red) -> missing field" 1 'missing definition for `signer`' \
  -- run "$fix/red-no-signer.yaml"
expect "debt without at -> missing field" 1 'missing definition for `at`' \
  -- run "$fix/red-no-at.yaml"
expect "out-of-set severity string -> Severity" 1 "Severity: expected" \
  -- run "$fix/red-bad-severity.yaml"

if [ "$fails" -ne 0 ]; then
  echo "FAIL: $fails tech-debt case(s) mismatched"; exit 1
fi
echo "PASS: all tech-debt cases matched their expected exit codes"
exit 0
