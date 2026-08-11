#!/usr/bin/env bash
# Fixtures for skills/refine/refine_output.ncl — the refine REPORT, reformed
# to extend the entry core: maintainer judgments and the auditor postmortem
# are VOUCHES (core Witness: name + at), and the refined targets are
# edge-typed `depends` references. The fixed-point-hash monotonicity design
# and the unanimity gate are preserved.
#
# The fixtures are pure-data YAML; `refine_output_apply.ncl` applies
# RefineReport + RefineOutput EXTERNALLY. Each FAIL case asserts the error
# names its OWN predicate, matched against that case's own output only.
#
# CANARY: red-pending-verdict is string-backed — the unanimity gate compares
# through the core `matches`; a bare tag comparison against YAML strings would
# approve-by-vacuity (the D-8 defect class).
#
# Usage: test_refine_output.sh
# Exit:  0 = every case matched, 1 = a case mismatched, 2 = environment error.
set -u
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root="$(cd "$here/../.." && pwd)"
fix="$root/ledger/fixtures/refine_output"
apply="$root/skills/refine/refine_output_apply.ncl"

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

expect "converged report, vouched judgments, signed postmortem -> clean" 0 "" \
  -- run "$fix/green-report.yaml"

expect "judgment witness without at -> missing field" 1 "at" \
  -- run "$fix/red-judgment-no-at.yaml"
expect "postmortem without auditor witness (required-field red)" 1 "witness" \
  -- run "$fix/red-postmortem-unsigned.yaml"
expect "CANARY: string pending verdict -> unanimity gate" 1 "EXIT_GATE_INVARIANCE" \
  -- run "$fix/red-pending-verdict.yaml"
expect "no refined targets -> depends gate" 1 "depends must be non-empty" \
  -- run "$fix/red-no-depends.yaml"
expect "final_loop 0 -> loop gate" 1 "loop never ran" \
  -- run "$fix/red-zero-loop.yaml"
expect "zero clean sweeps -> convergence gate" 1 "no convergence verified" \
  -- run "$fix/red-zero-sweeps.yaml"
expect "empty maintainer panel -> non-empty-judgments gate" 1 "must be non-empty" \
  -- run "$fix/red-no-judgments.yaml"
expect "out-of-set verdict string -> MaintainerVerdict" 1 "MaintainerVerdict: expected" \
  -- run "$fix/red-bad-verdict.yaml"

if [ "$fails" -ne 0 ]; then
  echo "FAIL: $fails refine-output case(s) mismatched"; exit 1
fi
echo "PASS: all refine-output cases matched their expected exit codes"
exit 0
