#!/usr/bin/env bash
# Fixtures for council.ncl — the council's law as an intrinsic Nickel contract.
# The fixtures are pure-data YAML instances; `council_apply.ncl` applies the law to
# them EXTERNALLY, so the single command
#   nickel export <fixture>.yaml --apply-contract ledger/contracts/council_apply.ncl
# IS the gate (degrade-to-primitive: the contract is the law; this script never
# re-implements an invariant). A lawful constitution / decision exports clean; a
# gapped / unilateral / no-consent / un-ratified / barred instance exits non-zero.
# Each FAIL case also asserts the error names its OWN invariant (not an incidental
# shape error), so a wrong verdict cannot pass by coincidence.
#
# council_apply.ncl is shape-dispatching: a value carrying `seats` is a constitution
# (validated by Constitution); otherwise it is a decisions ledger (validated by
# DecisionLedger threaded with the canonical constitution.yaml).
#
# Usage: test_council.sh
# Exit:  0 = every case matched, 1 = a case mismatched, 2 = environment error.
set -u
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root="$(cd "$here/../.." && pwd)"
fix="$root/ledger/fixtures/council"
# The TEST apply: threads the YAML fixture constitution, keeping these unit tests
# self-contained against the fixture (council_apply.ncl, the production apply, threads
# the live conditioning/constitution.ncl instead).
apply="$root/ledger/contracts/council_fixture_apply.ncl"

command -v nickel >/dev/null 2>&1 || { echo "ENV: nickel not found on PATH"; exit 2; }
[ -d "$fix" ] || { echo "ENV: fixtures dir missing: $fix"; exit 2; }
[ -f "$apply" ] || { echo "ENV: apply-file missing: $apply"; exit 2; }

fails=0
# expect DESC EXPECTED-RC KEYWORD -- COMMAND...
#   KEYWORD="" skips the message check (the clean PASS cases).
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

# 0: the canonical constitution alone -> Constitution path exports clean.
expect "canonical constitution (Constitution path) -> export clean" 0 "" \
  -- run "$fix/constitution.yaml"
# 1: complete constitution + valid ledger (incl. a routine owner-only decision) -> clean.
expect "valid ledger (proportional convening) -> export clean" 0 "" \
  -- run "$fix/good.yaml"
# 2: a decision-type with no delegation rule -> anti-incoherence.
expect "gapped constitution -> anti-incoherence" 1 "anti-incoherence" \
  -- run "$fix/gap.yaml"
# 3: a 'full terminal type with owner-only assent -> anti-unilateral.
expect "unilateral close -> anti-unilateral" 1 "anti-unilateral" \
  -- run "$fix/unilateral.yaml"
# 4: a 'merge whose assent lacks the maintainer -> merge-consent (F5).
expect "merge without maintainer consent -> merge-consent" 1 "merge-consent" \
  -- run "$fix/merge_no_consent.yaml"
# 5: a barred seat present in assent -> no-barred.
expect "barred seat in assent -> no-barred" 1 "no-barred" \
  -- run "$fix/barred.yaml"
# 6: a 'dag-amendment whose assent lacks the head -> head-ratification (F7).
expect "dag-amendment without head ratification -> head-ratification" 1 "head-ratification" \
  -- run "$fix/dag_amend_no_head.yaml"
# 7: a 'close with full MACHINE consensus but no head -> head-ratification. Proves the
# two terminal gates are distinct: 'full machine-consensus is met, yet the head's
# ratification (must_assent) is still required and its absence is named specifically.
expect "close without head ratification -> head-ratification" 1 "head-ratification" \
  -- run "$fix/close_no_head.yaml"
# 8: a 'close carrying the head + two of three JUDGING seats but missing one ->
# anti-unilateral. The composer is excluded from the 'full tally (it conducts, it does
# not vote), so machine-consensus is exactly {architect, maintainer, auditor}; dropping
# one judge fails even with the head present, proving the tally is the full judging set.
expect "close missing one judging seat -> anti-unilateral" 1 "anti-unilateral" \
  -- run "$fix/close_missing_seat.yaml"
# 9-12: the G-1 species-aware grounding. The bare string died; a grounding names a
# run check XOR an admitted witness, and each defect surfaces its own token.
expect "bare-string grounding -> grounding-speciesless" 1 "bare string is gone" \
  -- run "$fix/grounding_bare.yaml"
expect "grounding with no species anchor -> grounding-speciesless" 1 "neither check nor witness" \
  -- run "$fix/grounding_speciesless.yaml"
expect "grounding with both anchors -> grounding-species-ambiguous" 1 "grounding-species-ambiguous" \
  -- run "$fix/grounding_both.yaml"
expect "grounding check never run -> grounding-speciesless" 1 "named-but-unrun" \
  -- run "$fix/grounding_unrun.yaml"
# 13-14: the G-1 provenance fields — proposer (core Signer) and at (core CommitRef)
# are required; Nickel's missing-definition red names the absent field.
expect "decision without proposer -> missing definition" 1 "proposer" \
  -- run "$fix/decision_no_proposer.yaml"
expect "decision without at -> missing definition" 1 'missing definition for .at' \
  -- run "$fix/decision_no_at.yaml"
# 15-16: the G-2 subject machinery — a 'bar always names its subject, and the
# subject's assent on a decision about its own conduct is void.
expect "bar without subject -> bar-without-subject" 1 "bar-without-subject" \
  -- run "$fix/bar_no_subject.yaml"
expect "subject assenting to its own judgement -> self-assent" 1 "self-assent" \
  -- run "$fix/self_assent.yaml"
# 17: the G-8 ORDERING property — subject also barred and in assent trips BOTH
# self-assent and no-barred; the chain must surface self-assent (intrinsic before
# extrinsic). Asserted BOTH ways: the self-assent token present AND the no-barred
# token absent, so a chain-order regression cannot pass on the first grep alone.
expect "subject also barred -> self-assent surfaces first" 1 "self-assent" \
  -- run "$fix/subject_also_barred.yaml"
order_out="$( cd "$root" && run "$fix/subject_also_barred.yaml" 2>&1 )"
if printf '%s' "$order_out" | grep -q -- "no-barred"; then
  echo "FAIL  (ordering) subject_also_barred surfaced no-barred; self-assent must precede it"
  fails=$((fails + 1))
else
  echo "PASS  (ordering) subject_also_barred does not surface no-barred"
fi

if [ "$fails" -ne 0 ]; then
  echo "FAIL: $fails council case(s) mismatched"; exit 1
fi
echo "PASS: all council cases matched their expected exit codes"
exit 0
