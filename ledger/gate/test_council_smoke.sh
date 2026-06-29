#!/usr/bin/env bash
# Council end-to-end COMPOSITION smoke test.
#
# test_council.sh proves council.ncl's invariants in isolation: it runs the
# apply-contract over each fixture and reads the law's verdict. This smoke proves
# something test_council.sh does NOT — that the law (council_apply.ncl), the
# merge-consent GATE (council_consent.sh), and the decision-ledger YAML instance
# pattern actually COMPOSE: the consent gate and the law must agree over the SAME
# instances, and each must catch the failure class it owns.
#
# The composition thesis, over the landed ledger/fixtures/council/*.yaml:
#   * good.yaml is the joint PASS witness — the maintainer-consented merge (D3) and
#     the head-ratified close (D6) make the SAME instance pass BOTH the consent gate
#     (rc 0) AND the law (export rc 0). The two gates agree on a lawful ledger.
#   * merge_no_consent.yaml is caught by the CONSENT gate (rc 1, names merge-consent):
#     a merge without the maintainer's recorded assent.
#   * close_no_head.yaml is caught by the LAW DIRECTLY (export rc != 0, names
#     head-ratification). It is checked via the apply-contract, NOT council_consent.sh:
#     the consent gate returns rc 2 (environment error) for any export failure that
#     does not name merge-consent, so it is NOT a verdict for the head-ratification
#     class. Routing this case to the law is the composition boundary the smoke draws.
#
# Degrade-to-primitive: every verdict here is read from `council_consent.sh` or from
# `nickel export ... --apply-contract council_apply.ncl`. The smoke re-implements no
# assent/consensus invariant in bash; a second source of the law would be a defeater
# against council.ncl being THE law.
#
# Usage: test_council_smoke.sh
# Exit:  0 = every composed assertion held, 1 = an assertion mismatched,
#        2 = environment error.
set -u

# Resolve the repo root from this script's own location so the gate is runnable from
# any cwd (mirrors test_council.sh / council_consent.sh).
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root="$(cd "$here/../.." && pwd)"
fix="$root/ledger/fixtures/council"
# law() uses the TEST apply (threads the YAML fixture constitution) so the law's
# assertions stay self-contained; consent() below calls the PRODUCTION gate
# (council_consent.sh -> council_apply.ncl -> the live conditioning constitution).
apply="$root/ledger/contracts/council_fixture_apply.ncl"
consent_gate="$root/ledger/gate/council_consent.sh"

command -v nickel >/dev/null 2>&1 || { echo "ENV: nickel not found on PATH"; exit 2; }
[ -d "$fix" ]            || { echo "ENV: fixtures dir missing: $fix"; exit 2; }
[ -f "$apply" ]         || { echo "ENV: apply-file missing: $apply"; exit 2; }
[ -f "$consent_gate" ]  || { echo "ENV: consent gate missing: $consent_gate"; exit 2; }

fails=0
# expect DESC EXPECTED-RC KEYWORD -- COMMAND...
#   Captures the command's exit code IMMEDIATELY after it runs — no command may
#   intervene between the run and the `rc=$?` read, or the code is clobbered.
#   KEYWORD="" skips the message check (the clean PASS cases).
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
    printf '%s\n' "$out" | tail -3
    fails=$((fails + 1))
  fi
}

# The two landed primitives the smoke composes — never a hand-rolled check.
law()     { nickel export "$1" --apply-contract "$apply"; }
consent() { bash "$consent_gate" "$1"; }

# --- The composition assertions ------------------------------------------------

# A1 + A3 — the JOINT PASS witness: the SAME instance (good.yaml) passes BOTH gates.
# A1: the consent gate accepts the maintainer-consented merge (D3).
expect "compose: consent gate PASSES the consented ledger (good.yaml)" 0 "" \
  -- consent "$fix/good.yaml"
# A3: the law validates that same ledger — both gates agree it is lawful.
expect "compose: law VALIDATES the same ledger (good.yaml)" 0 "" \
  -- law "$fix/good.yaml"

# A2 — the CONSENT gate's failure class: a merge lacking the maintainer's assent is
# caught by council_consent.sh (rc 1), and the message names the merge-consent guard.
expect "compose: consent gate FAILS the unconsented merge (merge_no_consent.yaml)" 1 "merge-consent" \
  -- consent "$fix/merge_no_consent.yaml"

# A4 — the LAW's failure class, routed AWAY from the consent gate: a close with full
# machine consensus but no head ratification is caught by the apply-contract DIRECTLY
# (export rc != 0, names head-ratification). The consent gate would mislabel this as
# rc 2 (env error), so the smoke checks it via the law — the composition boundary.
expect "compose: law FAILS the un-ratified close via apply-contract (close_no_head.yaml)" 1 "head-ratification" \
  -- law "$fix/close_no_head.yaml"

if [ "$fails" -ne 0 ]; then
  echo "FAIL: $fails council composition assertion(s) mismatched"; exit 1
fi
echo "PASS: council law + consent gate + YAML instances compose over the same fixtures"
exit 0
