#!/usr/bin/env bash
# Fixtures for reconcile_log.ncl — the reconcile log, reformed to extend the
# entry core: the round-level checkpoint anchoring is pushed down to each
# Judgment (`at` = the state judged; `author` = who judged it), and the
# accept-requires-evaluator gate compares through the core `matches`.
#
# NOT test_reconcile.sh: that suite exercises premise_fresh.sh and
# coherence_impact.sh (RECONCILE-step scripts), not this contract (P9).
#
# The fixtures are pure-data YAML; `reconcile_apply.ncl` applies the law
# EXTERNALLY. Each FAIL case asserts the error names its OWN predicate,
# matched against that case's own output only.
#
# CANARY: red-accept-empty-evaluator is string-backed — a bare tag comparison
# against YAML strings would pass the ungrounded acceptance silently (the D-8
# defect class).
#
# Usage: test_reconcile_log.sh
# Exit:  0 = every case matched, 1 = a case mismatched, 2 = environment error.
set -u
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root="$(cd "$here/../.." && pwd)"
fix="$root/ledger/fixtures/reconcile_log"
apply="$root/ledger/contracts/reconcile_apply.ncl"

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

expect "two rounds, string enums, anchored + authored judgments -> clean" 0 "" \
  -- run "$fix/green-rounds.yaml"

expect "CANARY: string-verdict accept, empty evaluator -> JudgmentGrounded" 1 "JudgmentGrounded" \
  -- run "$fix/red-accept-empty-evaluator.yaml"
expect "judgment without at (required-field red) -> missing field" 1 "at" \
  -- run "$fix/red-judgment-no-at.yaml"
expect "judgment without author -> missing field" 1 "author" \
  -- run "$fix/red-judgment-no-author.yaml"
expect "out-of-set verdict string -> Verdict" 1 "Verdict: expected" \
  -- run "$fix/red-bad-verdict.yaml"
expect "non-hash checkpoint_commit -> CommitRef" 1 "CommitRef: expected" \
  -- run "$fix/red-malformed-checkpoint.yaml"

if [ "$fails" -ne 0 ]; then
  echo "FAIL: $fails reconcile-log case(s) mismatched"; exit 1
fi
echo "PASS: all reconcile-log cases matched their expected exit codes"
exit 0
