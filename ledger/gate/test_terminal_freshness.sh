#!/usr/bin/env bash
# Suite for ledger/gate/terminal_freshness.py -- the derivation behind
# directions:D3-T10 ("do terminal claims carry the coordinate that makes a
# lapsed corroboration visible?").
#
# D3's whole content is that finishing is known by evidence rather than by
# assertion, so an ad-hoc read of the corpus cannot corroborate its own
# target -- this suite is what makes the check re-runnable and pins the two
# cases it exists to catch: a satisfying claim with no axes:: at all, and a
# non-monotone satisfying claim with no freshness:: cure.
#
# Fixtures are synthetic, standalone corpora under
# ledger/fixtures/terminal_freshness/ (never the live .ledger/ -- gitignored,
# moves under concurrent work, and a suite pinned to it would fail for
# reasons unrelated to this code, the same reasoning
# ledger/gate/test_self_vouch.sh gives for its own fixtures).
#
#   missing_axes/               a corroborated satisfying claim with no
#                                axes:: at all -- MUST be reported and MUST
#                                exit non-zero.
#   non_monotone_no_freshness/  a corroborated satisfying claim, axes ::
#                                -monotone, no freshness:: cure -- MUST be
#                                reported and MUST exit non-zero.
#   monotone_no_freshness/      a corroborated satisfying claim, axes ::
#                                +monotone, no freshness:: -- monotone owes no
#                                cure, so this is NOT a violation.
#   unmet/                      a target with no discharging claim at all --
#                                not a violation, and not conflated with a
#                                claim missing its coordinate (which DOES
#                                satisfy the target, just incompletely).
#   clean/                      a non-monotone, corroborated satisfying claim
#                                that names its freshness cure -- the
#                                ordinary, fully-declared case.
#
# Usage: test_terminal_freshness.sh
# Exit:  0 = every case matched, 1 = a case mismatched, 2 = environment error.
set -u
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root="$(cd "$here/../.." && pwd)"
tool="$root/ledger/gate/terminal_freshness.py"
fix="$root/ledger/fixtures/terminal_freshness"

command -v python3 >/dev/null 2>&1 || { echo "ENV: python3 not found on PATH"; exit 2; }
[ -f "$tool" ] || { echo "ENV: terminal_freshness.py missing: $tool"; exit 2; }
for f in missing_axes non_monotone_no_freshness monotone_no_freshness unmet clean; do
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

echo "-- missing_axes: satisfying claim with no axes:: at all -------------------"
expect "missing_axes: exits non-zero" 1 "" \
  -- python3 "$tool" "$fix/missing_axes"
expect "missing_axes: names the offending claim and target" 1 \
  "! claim:C1 -> directions:D1-T1: no axes:: at all" \
  -- python3 "$tool" "$fix/missing_axes"
expect "missing_axes: the target is still reported SATISFIED" 1 \
  "directions:D1-T1  SATISFIED  <- claim:C1" \
  -- python3 "$tool" "$fix/missing_axes"

echo ""
echo "-- non_monotone_no_freshness: -monotone with no cure -----------------------"
expect "non_monotone_no_freshness: exits non-zero" 1 "" \
  -- python3 "$tool" "$fix/non_monotone_no_freshness"
expect "non_monotone_no_freshness: names the offending claim and target" 1 \
  "! claim:C1 -> directions:D1-T1: non-monotone (axes:: -monotone) but no freshness:: cure" \
  -- python3 "$tool" "$fix/non_monotone_no_freshness"

echo ""
echo "-- monotone_no_freshness: +monotone owes no cure, NOT a violation ----------"
expect "monotone_no_freshness: exits clean" 0 "" \
  -- python3 "$tool" "$fix/monotone_no_freshness"
expect "monotone_no_freshness: target reported SATISFIED, no gap" 0 \
  "directions:D1-T1  SATISFIED  <- claim:C1  axes=\[+determined +certifiable +monotone\]  OK" \
  -- python3 "$tool" "$fix/monotone_no_freshness"
expect "monotone_no_freshness: zero violations" 0 \
  "freshness-coordinate violations: 0" \
  -- python3 "$tool" "$fix/monotone_no_freshness"

echo ""
echo "-- unmet: no discharging claim at all, NOT a violation ---------------------"
expect "unmet: exits clean" 0 "" \
  -- python3 "$tool" "$fix/unmet"
expect "unmet: target reported UNMET" 0 "directions:D1-T1  UNMET" \
  -- python3 "$tool" "$fix/unmet"
expect "unmet: zero violations (distinct from a missing-coordinate satisfaction)" 0 \
  "freshness-coordinate violations: 0" \
  -- python3 "$tool" "$fix/unmet"

echo ""
echo "-- clean: non-monotone, freshness cure named --------------------------------"
expect "clean: exits clean" 0 "" \
  -- python3 "$tool" "$fix/clean"
expect "clean: target reported SATISFIED, no gap" 0 \
  "directions:D1-T1  SATISFIED  <- claim:C1  axes=\[+determined +certifiable -monotone\]  OK" \
  -- python3 "$tool" "$fix/clean"
expect "clean: zero violations" 0 \
  "freshness-coordinate violations: 0" \
  -- python3 "$tool" "$fix/clean"

echo ""
echo "-- honesty of scope: the check names its own limits ------------------------"
expect "report states it cannot verify the coordinates are correct" 0 \
  "cannot establish that the coordinates are correctly assessed" \
  -- python3 "$tool" "$fix/clean"

echo ""
echo "-- CLI convention -----------------------------------------------------"
expect "nonexistent corpus: usage/environment error, exit 2" 2 "ENV:" \
  -- python3 "$tool" "$fix/does-not-exist-xyz"

echo ""
if [ "$fails" -eq 0 ]; then echo "test_terminal_freshness: ALL PASS"; exit 0; fi
echo "test_terminal_freshness: $fails FAILURE(S)"; exit 1
