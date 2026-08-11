#!/usr/bin/env bash
# Fixtures for worker_ibc.ncl — the boundary contract, reformed to extend the
# entry core: premises as CLOSED claim entries, unknowns as ROUTABLE question
# entries, and normative content (goal/non-goals/constraints/criteria) as
# provenance-carrying Directives (ruling E-1) that close by authority and
# reject evidence fields as category errors.
#
# The fixtures are pure-data YAML; `worker_ibc_apply.ncl` applies the law
# EXTERNALLY (Worker shape + WorkerIBC sufficiency gate). Each FAIL case
# asserts the error names its OWN predicate, matched against that case's own
# output only.
#
# Usage: test_worker_ibc.sh
# Exit:  0 = every case matched, 1 = a case mismatched, 2 = environment error.
set -u
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root="$(cd "$here/../.." && pwd)"
fix="$root/ledger/fixtures/worker_ibc"
apply="$root/ledger/contracts/worker_ibc_apply.ncl"

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

expect "full reformed IBC (string enums throughout) -> export clean" 0 "" \
  -- run "$fix/green-full.yaml"

expect "no acceptance criteria -> sufficiency gate" 1 "no acceptance criteria" \
  -- run "$fix/red-no-acceptance.yaml"
expect "premise with neither check nor witness -> PremiseClosed" 1 "PremiseClosed" \
  -- run "$fix/red-premise-unclosed.yaml"
expect "question filed as premise -> PremiseIsClaim" 1 "PremiseIsClaim" \
  -- run "$fix/red-premise-question.yaml"
expect "claim filed as unknown -> UnknownIsQuestion" 1 "UnknownIsQuestion" \
  -- run "$fix/red-unknown-claim.yaml"
expect "unknown without closer -> QuestionRoutable (core, inherited)" 1 "QuestionRoutable" \
  -- run "$fix/red-unknown-no-closer.yaml"
expect "directive WITH backing (category error) -> closed-record extra field" 1 'extra field `backing`' \
  -- run "$fix/red-directive-backing.yaml"
expect "non-derived provenance unnamed -> DirectiveDesignates" 1 "DirectiveDesignates" \
  -- run "$fix/red-directive-unnamed.yaml"
expect "constraint without evaluator (required-field red) -> missing field" 1 "evaluator" \
  -- run "$fix/red-constraint-no-evaluator.yaml"
expect "empty goal statement -> NonEmptyString (subsumed gate branch)" 1 "NonEmptyString" \
  -- run "$fix/red-goal-empty.yaml"

if [ "$fails" -ne 0 ]; then
  echo "FAIL: $fails worker-IBC case(s) mismatched"; exit 1
fi
echo "PASS: all worker-IBC cases matched their expected exit codes"
exit 0
