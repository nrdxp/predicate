#!/usr/bin/env bash
# Fixtures for context_map.ncl — the live tracker, reformed per E-3
# (preserve-and-express): requirement/invariant/constraint rows are boundary
# Directives merge-extended with the carrier fields (provenance = the
# authority, signpost = the defeater); unknown rows are full core question
# entries gaining the closer they always lacked. UNKNOWNS REMAIN FIRST-CLASS;
# the non-empty-grounding gate and the tracker_fresh.sh input shape are
# preserved (last_validated keeps its date semantics; `at` adds the commit
# anchor a date cannot carry).
#
# The fixtures are pure-data YAML; `context_map_apply.ncl` applies the law
# EXTERNALLY. Each FAIL case asserts the error names its OWN predicate,
# matched against that case's own output only. The final case runs
# tracker_fresh.sh over the hydrated flat fixture — the external interface g6
# forbids silently breaking.
#
# Usage: test_context_map.sh
# Exit:  0 = every case matched, 1 = a case mismatched, 2 = environment error.
set -u
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root="$(cd "$here/../.." && pwd)"
fix="$root/ledger/fixtures/context_map"
apply="$root/ledger/contracts/context_map_apply.ncl"

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

expect "R/I/C directives + question-entry unknown, string kinds -> clean" 0 "" \
  -- run "$fix/green-map.yaml"

expect "unknown without closer -> QuestionRoutable (core, inherited)" 1 "QuestionRoutable" \
  -- run "$fix/red-unknown-no-closer.yaml"
expect "directive row without provenance -> missing field" 1 "provenance" \
  -- run "$fix/red-ric-no-provenance.yaml"
expect "directive row, unnamed authority -> DirectiveDesignates" 1 "DirectiveDesignates" \
  -- run "$fix/red-ric-unnamed-provenance.yaml"
expect "claim filed as unknown -> UnknownIsQuestion" 1 "UnknownIsQuestion" \
  -- run "$fix/red-unknown-claim.yaml"
expect "unknown without signer -> missing field" 1 "signer" \
  -- run "$fix/red-unknown-no-signer.yaml"
expect "empty grounding (preserved gate) -> NonEmptyString" 1 "NonEmptyString" \
  -- run "$fix/red-empty-grounding.yaml"
expect "out-of-set kind string -> Kind" 1 "Kind: expected" \
  -- run "$fix/red-bad-kind.yaml"
expect "directive row without at (required-field red) -> missing field" 1 "at" \
  -- run "$fix/red-no-at.yaml"
expect "duplicate item id -> ContextMap duplicate" 1 "duplicate context-map item id" \
  -- run "$fix/red-dup-id.yaml"

# The external interface (g6): tracker_fresh.sh still reads a reformed
# instance. Freshness itself is date-relative (rc 0 fresh / rc 1 stale); the
# interface is intact iff the gate parses the items and reports per-item
# verdicts rather than erroring out (rc 2 = environment/shape error).
tf_out="$(bash "$root/ledger/gate/tracker_fresh.sh" "$root/ledger/fixtures/context_map_hydrated.ncl" 2>&1)"; tf_rc=$?
if { [ "$tf_rc" -eq 0 ] || [ "$tf_rc" -eq 1 ]; } && printf '%s' "$tf_out" | grep -qE "FRESH|STALE"; then
  echo "PASS  ($tf_rc) tracker_fresh.sh parses the reformed instance (per-item verdicts)"
else
  echo "FAIL  (rc=$tf_rc) tracker_fresh.sh no longer parses the reformed instance"
  printf '%s\n' "$tf_out" | tail -3
  fails=$((fails + 1))
fi

if [ "$fails" -ne 0 ]; then
  echo "FAIL: $fails context-map case(s) mismatched"; exit 1
fi
echo "PASS: all context-map cases matched their expected exit codes"
exit 0
