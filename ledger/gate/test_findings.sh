#!/usr/bin/env bash
# Fixtures for findings.ncl — the findings ledger, reformed to extend the entry
# core (signer + at on every finding; the evaluator moved from a bare name to a
# core Check anchor, so resolution requires a check that WAS RUN).
#
# The fixtures are pure-data YAML; `findings_apply.ncl` applies the law
# EXTERNALLY. Each FAIL case asserts the error names its OWN predicate,
# matched against that case's own output only.
#
# CANARY: red-resolved-unrun is string-backed — the reformed gate compares
# through the core `matches`; a bare tag comparison against YAML strings would
# pass it silently (the D-8 defect class).
#
# Usage: test_findings.sh
# Exit:  0 = every case matched, 1 = a case mismatched, 2 = environment error.
set -u
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root="$(cd "$here/../.." && pwd)"
fix="$root/ledger/fixtures/findings"
apply="$root/ledger/contracts/findings_apply.ncl"

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

expect "open/planned/resolved lifecycle, string enums -> export clean" 0 "" \
  -- run "$fix/green-lifecycle.yaml"

expect "CANARY: string-status resolved, evaluator unrun -> ResolutionRun" 1 "ResolutionRun" \
  -- run "$fix/red-resolved-unrun.yaml"
expect "resolved with no evaluator -> ResolutionRun" 1 "ResolutionRun" \
  -- run "$fix/red-resolved-no-evaluator.yaml"
expect "finding without signer (required-field red) -> missing field" 1 'missing definition for `signer`' \
  -- run "$fix/red-no-signer.yaml"
expect "finding without at -> missing field" 1 'missing definition for `at`' \
  -- run "$fix/red-no-at.yaml"
expect "out-of-set severity string -> Severity" 1 "Severity: expected" \
  -- run "$fix/red-bad-severity.yaml"
expect "out-of-set status string -> Status" 1 "Status: expected" \
  -- run "$fix/red-bad-status.yaml"
expect "duplicate finding id -> Findings duplicate" 1 "duplicate finding id" \
  -- run "$fix/red-dup-id.yaml"
expect "pre-reform bare-name evaluator, still open (B2 headline type-change)" 1 "expected a Record" \
  -- run "$fix/red-evaluator-bare-string.yaml"
expect "malformed at (not a commit hash, D9) -> CommitRef" 1 "CommitRef: expected" \
  -- run "$fix/red-malformed-at.yaml"

if [ "$fails" -ne 0 ]; then
  echo "FAIL: $fails findings case(s) mismatched"; exit 1
fi
echo "PASS: all findings cases matched their expected exit codes"
exit 0
