#!/usr/bin/env bash
# Fixtures for deposit.ncl — the P-GROUND deposit substrate, reformed to extend
# the entry core (evidence species split onto core Check/Witness anchors, a
# signer on every evidence item, the E-4 dirty marker on anchors).
#
# The fixtures are pure-data YAML instances; `deposit_apply.ncl` applies the
# law to them EXTERNALLY, so the single command
#   nickel export <fixture>.yaml --apply-contract ledger/contracts/deposit_apply.ncl
# IS the gate. Each FAIL case also asserts the error names its OWN predicate
# (right-reason discipline), matched against that case's own output only.
#
# Usage: test_deposit.sh
# Exit:  0 = every case matched, 1 = a case mismatched, 2 = environment error.
set -u
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root="$(cd "$here/../.." && pwd)"
fix="$root/ledger/fixtures/deposit"
apply="$root/ledger/contracts/deposit_apply.ncl"

command -v nickel >/dev/null 2>&1 || { echo "ENV: nickel not found on PATH"; exit 2; }
[ -d "$fix" ] || { echo "ENV: fixtures dir missing: $fix"; exit 2; }
[ -f "$apply" ] || { echo "ENV: apply-file missing: $apply"; exit 2; }

fails=0
# expect DESC EXPECTED-RC KEYWORD -- COMMAND...
#   KEYWORD="" skips the message check (the clean PASS cases).
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

# --- greens ------------------------------------------------------------------
expect "both species, signed, dirty anchor, resolving ref -> export clean" 0 "" \
  -- run "$fix/green-species.yaml"

# --- species / signer reds ---------------------------------------------------
expect "review evidence without a named witness -> VouchSpeciesWitnessed" 1 "VouchSpeciesWitnessed" \
  -- run "$fix/red-vouch-no-witness.yaml"
expect "mechanism evidence with unrun check -> CorroborationSpeciesRan" 1 "CorroborationSpeciesRan" \
  -- run "$fix/red-corroboration-unrun.yaml"
expect "mechanism evidence with no check -> CorroborationSpeciesRan" 1 "CorroborationSpeciesRan" \
  -- run "$fix/red-corroboration-no-check.yaml"
expect "evidence without signer -> missing field (required-field red)" 1 "signer" \
  -- run "$fix/red-no-signer.yaml"

# --- shape reds --------------------------------------------------------------
expect "out-of-set method string -> EvidenceMethod" 1 "EvidenceMethod: expected" \
  -- run "$fix/red-bad-method.yaml"
expect "empty evidence array -> NonEmptyEvidence" 1 "at least one evidence item" \
  -- run "$fix/red-empty-evidence.yaml"
expect "deposit missing step (laziness guard) -> per-deposit conformance" 1 "step" \
  -- run "$fix/red-malformed-deposit.yaml"

# --- store reds --------------------------------------------------------------
expect "duplicate deposit id -> DepositStore duplicate" 1 "duplicate deposit id" \
  -- run "$fix/red-dup-id.yaml"
expect "dangling ref.target -> DepositStore dangling" 1 "dangling DepositRef" \
  -- run "$fix/red-dangling-ref.yaml"

if [ "$fails" -ne 0 ]; then
  echo "FAIL: $fails deposit case(s) mismatched"; exit 1
fi
echo "PASS: all deposit cases matched their expected exit codes"
exit 0
