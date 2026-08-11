#!/usr/bin/env bash
# Fixture-polarity sweep — the regression-proof coverage gate for all campaign
# contracts and their negative/positive controls.
#
# Every ledger/fixtures/*.ncl declares its expected behaviour via the polarity
# convention already implemented in ledger-validate.sh:
#
#   '# EXPECT: fail'  (leading whitespace allowed) — negative control.
#       The fixture MUST make `nickel export` exit non-zero.  ledger-validate.sh
#       returns 0 when the negative control fires as declared.
#
#   Anything else — positive control (including '# EXPECT: pass' annotations).
#       The fixture MUST export cleanly (rc 0).
#
# This sweep runs ledger-validate.sh structure against EVERY fixture and asserts
# rc 0 — "behaves per its declared polarity".  A failing assertion means either:
#   (a) a positive fixture broke (contract regression), or
#   (b) a negative fixture stopped failing (gate regression — equally serious).
#
# Coverage — READ THIS BEFORE ASSUMING A CONTRACT IS EXERCISED HERE: the glob
# below is `ledger/fixtures/*.ncl` and `ledger/fixtures/dag_*.yaml` — FLAT,
# non-recursive. It reaches:
#   - the flat tag-form .ncl fixtures at the top of ledger/fixtures/ (e.g.
#     deposit_dangling_ref.ncl, findings_empty_evaluator.ncl,
#     reconcile_empty_evaluator.ncl, context_map_empty_grounding.ncl,
#     worker_no_acceptance.ncl, tech_debt_dup_id.ncl,
#     process_feedback_dup_id.ncl, refine_procedure_*.ncl, dag_*.ncl, …) —
#     these are the SOLE coverage of the TAG branch of every `e.matches`
#     value-restricted enum; the dedicated per-contract suites below only
#     exercise the string branch.
#   - dag_*.yaml — YAML DAG instances (dag_valid.yaml, dag_cycle.yaml),
#     validated via ledger-validate.sh, which applies dag_apply.ncl.
#
# It does NOT reach the per-contract instance fixtures that live in
# subdirectories (ledger/fixtures/{deposit,findings,reconcile_log,worker_ibc,
# context_map,tech_debt,process_feedback,refine_output}/*.yaml) — the glob
# does not descend, and even a recursive glob could not fix this: for any
# *.yaml, `ledger-validate.sh structure` hardcodes --apply-contract
# dag_apply.ncl (it assumes every YAML fixture is a DAG instance). Pointing it
# at, say, ledger/fixtures/deposit/green-species.yaml does not "correctly
# fail" — it fails on `missing field \`nodes\`` against the WRONG contract
# entirely. Those fixtures are validated by their own dedicated suite
# (ledger/gate/test_<contract>.sh), which applies the right shim per fixture.
# A prior version of this comment claimed blanket coverage of "every contract
# introduced by the process campaign" here; that was false for every
# contract whose instances are subdirectory YAML (deposit, findings,
# reconcile_log, worker_ibc, context_map, tech_debt, process_feedback,
# refine_output all added 59 such fixtures with zero addition to this sweep).
#
# The sweep is additive within its actual reach — it adds ZERO new fixtures of
# its own; instead it asserts the flat-.ncl/dag_*.yaml universe already
# defined, making future regressions detectable. Adding a fixture directly
# under ledger/fixtures/ (*.ncl or dag_*.yaml — NOT a subdirectory) extends
# this sweep automatically; MIN_FIXTURES below is a floor, not a ceiling, so
# growth needs no edit here.
#
# Usage: test_fixture_sweep.sh
# Exit:  0 = every fixture behaved per its declared polarity
#        1 = one or more polarities mismatched
#        2 = environment error (nickel / validate script not found, or the
#            glob's matched count fell below the committed floor)
set -u

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root="$(cd "$here/../.." && pwd)"
validate="$here/ledger-validate.sh"

if [[ ! -x "$validate" ]]; then
  echo "FAIL (env): ledger-validate.sh not found at $validate" >&2
  exit 2
fi

# Committed floor: the glob's matched count as of this pass. A count below
# this means the glob itself regressed (renamed/reindented block, moved
# fixture, typo'd pattern) — silent, total coverage loss for the tag-branch
# enum surface this sweep is the SOLE guard for. Raise this number when
# deliberately adding a flat fixture; never lower it to make a regression pass.
readonly MIN_FIXTURES=43

fails=0
total=0

for fixture in "$root"/ledger/fixtures/*.ncl "$root"/ledger/fixtures/dag_*.yaml; do
  [[ -f "$fixture" ]] || continue
  name="$(basename "$fixture")"
  total=$((total + 1))

  result=$(bash "$validate" structure "$fixture" 2>&1)
  rc=$?

  if [[ "$rc" -eq 0 ]]; then
    echo "PASS  $name"
  else
    echo "FAIL  $name (ledger-validate rc=$rc)"
    if [[ -n "$result" ]]; then
      # Indent the diagnostic so it is clearly subordinate to the FAIL line.
      printf '%s\n' "$result" | sed 's/^/      /'
    fi
    fails=$((fails + 1))
  fi
done

echo ""
echo "Fixture polarity sweep: $((total - fails))/$total passed"
if [[ "$total" -lt "$MIN_FIXTURES" ]]; then
  echo "FAIL: sweep matched only $total fixture(s), below the committed floor of $MIN_FIXTURES (glob regressed — silent coverage loss)"
  exit 2
fi
if [[ "$fails" -ne 0 ]]; then
  echo "FAIL: $fails fixture(s) did not behave per declared polarity"
  exit 1
fi
echo "PASS: all fixtures behaved per declared polarity"
exit 0
