#!/usr/bin/env bash
# Suite for ledger/gate/self_vouch.py -- the derivation behind directions:D3-T8
# ("is any terminal target satisfied on the testimony of its own author?").
#
# D3's whole content is that finishing is known by evidence rather than by
# assertion, so an ad-hoc read of the corpus cannot corroborate its own
# target -- this suite is what makes the check re-runnable and pins the case
# it exists to catch: a corroborated satisfaction whose witness is the same
# party as its own document's declared signer.
#
# Fixtures are synthetic, standalone corpora under ledger/fixtures/self_vouch/
# (never the live .ledger/ -- gitignored, moves under concurrent work, and a
# suite pinned to it would fail for reasons unrelated to this code, the same
# reasoning ledger/gate/test_convergence.sh gives for its own fixtures).
#
#   violation/              a corroborated claim self-witnessed on its target
#                            -- MUST be reported and MUST exit non-zero. This
#                            is the case the check exists to catch; without it
#                            the check has never been seen to fail.
#   vouched_not_violation/  a vouched (not corroborated) claim, self-witnessed
#                            on the same target -- reported for visibility,
#                            never counted: a target's SATISFACTION is what
#                            the question asks about, and this claim did not
#                            satisfy it.
#   unmet/                  a target with no discharging claim at all -- not
#                            a violation, and not conflated with the vouched
#                            case (which DOES have a claim, just not a
#                            satisfying one).
#   clean/                  a corroborated claim satisfying its target,
#                            witnessed by a party OTHER than the document's
#                            own signer -- the ordinary, non-self-vouched case.
#
# Usage: test_self_vouch.sh
# Exit:  0 = every case matched, 1 = a case mismatched, 2 = environment error.
set -u
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root="$(cd "$here/../.." && pwd)"
tool="$root/ledger/gate/self_vouch.py"
fix="$root/ledger/fixtures/self_vouch"

command -v python3 >/dev/null 2>&1 || { echo "ENV: python3 not found on PATH"; exit 2; }
[ -f "$tool" ] || { echo "ENV: self_vouch.py missing: $tool"; exit 2; }
for f in violation vouched_not_violation unmet clean; do
  [ -d "$fix/$f" ] || { echo "ENV: fixture dir missing: $fix/$f"; exit 2; }
done

fails=0
# expect DESC EXPECTED-RC KEYWORD -- COMMAND...
#   KEYWORD="" skips the message check.
expect() {
  local desc="$1" exp="$2" kw="$3"; shift 3
  [ "$1" = "--" ] && shift
  local out rc ok=1
  out="$( "$@" 2>&1 )"; rc=$?
  [ "$rc" -eq "$exp" ] || ok=0
  if [ -n "$kw" ]; then printf '%s' "$out" | grep -q -- "$kw" || ok=0; fi
  if [ "$ok" -eq 1 ]; then
    echo "PASS  ($rc) $desc"
  else
    echo "FAIL  (got rc=$rc want $exp; want-kw='$kw') $desc"
    printf '%s\n' "$out" | tail -10
    fails=$((fails + 1))
  fi
}

echo "-- violation: self-witnessed corroborated satisfaction ------------------"
expect "violation: exits non-zero" 1 "" \
  -- python3 "$tool" "$fix/violation"
expect "violation: names the offending claim and target" 1 \
  "! claim:C1 -> directions:D1-T1  witness=agent/worker == signer of its own document" \
  -- python3 "$tool" "$fix/violation"
expect "violation: the target is still reported SATISFIED" 1 \
  "directions:D1-T1  SATISFIED  <- claim:C1" \
  -- python3 "$tool" "$fix/violation"

echo ""
echo "-- vouched, self-witnessed, NOT a violation ------------------------------"
expect "vouched_not_violation: exits clean" 0 "" \
  -- python3 "$tool" "$fix/vouched_not_violation"
expect "vouched_not_violation: reported present, not a violation" 0 \
  "claim:C1 -> directions:D1-T1  (backing=vouched, witness=agent/worker)" \
  -- python3 "$tool" "$fix/vouched_not_violation"
expect "vouched_not_violation: never counted as a self-vouch violation" 0 \
  "self-vouch violations: 0" \
  -- python3 "$tool" "$fix/vouched_not_violation"
expect "vouched_not_violation: the target is UNMET (a vouch never satisfies)" 0 \
  "directions:D1-T1  UNMET" \
  -- python3 "$tool" "$fix/vouched_not_violation"

echo ""
echo "-- unmet: no discharging claim at all, NOT a violation -------------------"
expect "unmet: exits clean" 0 "" \
  -- python3 "$tool" "$fix/unmet"
expect "unmet: target reported UNMET" 0 "directions:D1-T1  UNMET" \
  -- python3 "$tool" "$fix/unmet"
expect "unmet: nothing self-witnessed reported (distinct from the vouched case)" 0 \
  "self-witnessed claims present, not counted: none" \
  -- python3 "$tool" "$fix/unmet"

echo ""
echo "-- clean: corroborated, witnessed by a different party --------------------"
expect "clean: exits clean" 0 "" \
  -- python3 "$tool" "$fix/clean"
expect "clean: target reported SATISFIED" 0 \
  "directions:D1-T1  SATISFIED  <- claim:C1" \
  -- python3 "$tool" "$fix/clean"
expect "clean: no self-witnessed claims reported at all" 0 \
  "self-witnessed claims present, not counted: none" \
  -- python3 "$tool" "$fix/clean"

echo ""
echo "-- CLI convention -----------------------------------------------------"
expect "nonexistent corpus: usage/environment error, exit 2" 2 "ENV:" \
  -- python3 "$tool" "$fix/does-not-exist-xyz"

echo ""
if [ "$fails" -eq 0 ]; then echo "test_self_vouch: ALL PASS"; exit 0; fi
echo "test_self_vouch: $fails FAILURE(S)"; exit 1
