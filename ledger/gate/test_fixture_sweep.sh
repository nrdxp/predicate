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
# Coverage: every contract introduced by the process campaign is exercised here
# because every campaign-added fixture lives under ledger/fixtures/:
#   deposit, arsenal_registry, boundary_procedure, context_map, campaign_ibc,
#   dag (existing + new disciplines + prefix-overlap), discovery, findings,
#   procedure (spine, loop, shrink, XOR, invoke-registry), refine_procedure,
#   reconcile_log, refine_output, state_machine, tracker_freshness, worker_ibc.
#
# The sweep is additive — it adds ZERO new fixtures of its own; instead it
# asserts the universe already defined, making future regressions detectable.
# Adding a new fixture to ledger/fixtures/ automatically extends this sweep.
#
# Usage: test_fixture_sweep.sh
# Exit:  0 = every fixture behaved per its declared polarity
#        1 = one or more polarities mismatched
#        2 = environment error (nickel / validate script not found)
set -u

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root="$(cd "$here/../.." && pwd)"
validate="$here/ledger-validate.sh"

if [[ ! -x "$validate" ]]; then
  echo "FAIL (env): ledger-validate.sh not found at $validate" >&2
  exit 2
fi

fails=0
total=0

for fixture in "$root"/ledger/fixtures/*.ncl; do
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
if [[ "$fails" -ne 0 ]]; then
  echo "FAIL: $fails fixture(s) did not behave per declared polarity"
  exit 1
fi
echo "PASS: all fixtures behaved per declared polarity"
exit 0
