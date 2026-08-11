#!/usr/bin/env bash
# Fixtures for entry.ncl — the ledger ENTRY contract (the typed-claim shape).
# The fixtures are pure-data YAML instances; `entry_apply.ncl` applies the law
# to them EXTERNALLY, so the single command
#   nickel export <fixture>.yaml --apply-contract ledger/contracts/entry_apply.ncl
# IS the gate (degrade-to-primitive: the contract is the law; this script never
# re-implements an invariant). A well-formed entry / corpus exports clean; a
# violating one exits non-zero. Each FAIL case also asserts the error names its
# OWN predicate (right-reason discipline), so a wrong verdict cannot pass by
# coincidence.
#
# entry_apply.ncl is shape-dispatching: a value carrying `entries` is a corpus
# (validated by EntryStore: per-entry shape + id-uniqueness + edge-resolution);
# otherwise it is a single entry (Entry composed with the nine lifted
# predicates).
#
# CANARY: red-corroboration-unrun is the permanent regression tripwire for the
# tag-vs-string defect — a YAML (string-backed) corroborated claim with
# check.ran=false MUST fail CorroborationBacked. YAML carries strings and a
# bare `n.backing != 'corroborated` is unconditionally true against them,
# short-circuiting the predicate to a silent PASS; every enum comparison goes
# through the shared `matches` helper instead. This case going green means the
# dual-comparison idiom regressed.
#
# Usage: test_entry.sh
# Exit:  0 = every case matched, 1 = a case mismatched, 2 = environment error.
set -u
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root="$(cd "$here/../.." && pwd)"
fix="$root/ledger/fixtures/entry"
apply="$root/ledger/contracts/entry_apply.ncl"
law="$root/ledger/contracts/entry.ncl"

command -v nickel >/dev/null 2>&1 || { echo "ENV: nickel not found on PATH"; exit 2; }
[ -d "$fix" ] || { echo "ENV: fixtures dir missing: $fix"; exit 2; }
[ -f "$apply" ] || { echo "ENV: apply-file missing: $apply"; exit 2; }
[ -f "$law" ] || { echo "ENV: law-file missing: $law"; exit 2; }

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

# --- greens: every inhabited cell and the ruled edge cases -------------------
expect "proved claim (corroborated, check ran) -> export clean" 0 "" \
  -- run "$fix/green-proved-claim.yaml"
expect "cited claim (vouched, witness) -> export clean" 0 "" \
  -- run "$fix/green-cited-claim.yaml"
expect "synthesis claim (unclosed, inbound edge) -> export clean" 0 "" \
  -- run "$fix/green-synthesis-claim.yaml"
expect "dispatchable question -> export clean" 0 "" \
  -- run "$fix/green-dispatchable-question.yaml"
expect "routed question -> export clean" 0 "" \
  -- run "$fix/green-routed-question.yaml"
expect "frontier question (edge-free, D-2 claim-scoping) -> export clean" 0 "" \
  -- run "$fix/green-frontier-question.yaml"
expect "residual question -> export clean" 0 "" \
  -- run "$fix/green-residual-question.yaml"
expect "self-vouched claim (admission is the consumer's, D-4) -> export clean" 0 "" \
  -- run "$fix/green-self-vouched-claim.yaml"
expect "derived-signer synthesis (designation IS the edges) -> export clean" 0 "" \
  -- run "$fix/green-derived-synthesis.yaml"
expect "unattributed signer (migration mode, name absent) -> export clean" 0 "" \
  -- run "$fix/green-unattributed-signer.yaml"
expect "corpus aggregate (unique ids, resolving edges) -> export clean" 0 "" \
  -- run "$fix/green-corpus.yaml"

# --- predicate reds: one per predicate, both directions where bidirectional --
expect "CANARY: string-backed corroborated claim, check unrun -> CorroborationBacked" 1 "CorroborationBacked" \
  -- run "$fix/red-corroboration-unrun.yaml"
expect "corroborated claim, no check at all -> CorroborationBacked" 1 "CorroborationBacked" \
  -- run "$fix/red-corroboration-no-check.yaml"
expect "vouched claim, no witness -> VouchBacked" 1 "VouchBacked" \
  -- run "$fix/red-vouch-no-witness.yaml"
expect "unclosed claim, no edges -> ProvenanceGate" 1 "ProvenanceGate" \
  -- run "$fix/red-unclosed-claim-no-edges.yaml"
expect "question missing discharge -> QuestionRoutable" 1 "QuestionRoutable" \
  -- run "$fix/red-question-no-discharge.yaml"
expect "question missing closer -> QuestionRoutable" 1 "QuestionRoutable" \
  -- run "$fix/red-question-no-closer.yaml"
expect "residual claim -> ResidualIsQuestion" 1 "ResidualIsQuestion" \
  -- run "$fix/red-residual-claim.yaml"
expect "claim without axes -> ClaimHasAxes" 1 "ClaimHasAxes" \
  -- run "$fix/red-claim-no-axes.yaml"
expect "question with axes -> ClaimHasAxes" 1 "ClaimHasAxes" \
  -- run "$fix/red-question-with-axes.yaml"
expect "determined claim missing certifiable -> CertifiabilityFibered" 1 "CertifiabilityFibered" \
  -- run "$fix/red-determined-no-certifiable.yaml"
expect "undetermined claim carrying certifiable -> CertifiabilityFibered" 1 "CertifiabilityFibered" \
  -- run "$fix/red-undetermined-certifiable.yaml"
expect "non-monotone claim, no freshness -> NonMonotoneNamesCure" 1 "NonMonotoneNamesCure" \
  -- run "$fix/red-nonmonotone-no-freshness.yaml"
expect "non-derived signer, unnamed -> SignerDesignates" 1 "SignerDesignates" \
  -- run "$fix/red-underived-unnamed.yaml"
expect "derived signer, no edges -> SignerDesignates" 1 "SignerDesignates" \
  -- run "$fix/red-derived-no-edges.yaml"
expect "unattributed signer, named -> SignerDesignates" 1 "SignerDesignates" \
  -- run "$fix/red-unattributed-named.yaml"

# --- shape reds --------------------------------------------------------------
expect "empty statement -> NonEmptyString" 1 "NonEmptyString" \
  -- run "$fix/red-empty-statement.yaml"
expect "malformed commit ref -> CommitRef" 1 "CommitRef" \
  -- run "$fix/red-malformed-commit.yaml"
expect "out-of-set backing string -> Backing enum" 1 "Backing: expected" \
  -- run "$fix/red-invalid-backing.yaml"

# --- corpus reds (EntryStore) ------------------------------------------------
expect "corpus with duplicate ids -> EntryStore duplicate" 1 "duplicate entry id" \
  -- run "$fix/red-corpus-dup-id.yaml"
expect "corpus with dangling edge -> EntryStore dangling" 1 "dangling edge" \
  -- run "$fix/red-corpus-dangling-edge.yaml"
# Guards EntryStore's eager per-entry conformance fold (the deep_seq
# machinery): deleting that fold lets a shape-malformed entry export clean
# from a corpus. This is the only case that fails under that mutation.
expect "corpus with shape-malformed entry (empty statement) -> per-entry conformance" 1 "NonEmptyString" \
  -- run "$fix/red-corpus-malformed-entry.yaml"
# DELIBERATE ASYMMETRY, pinned: the corpus path applies NONE of the nine
# predicates — per-entry violation COLLECTION over a corpus is the future
# batch validator's job (the design reason the predicates are bare booleans),
# so a predicate-violating entry that is red alone exports GREEN inside a
# corpus. This expectation FLIPS to rc=1 (VouchBacked) when the batch
# validator lands; until then the corpus gate is the weaker one, on purpose.
expect "corpus with predicate-violating entry (vouched, no witness) -> green TODAY" 0 "" \
  -- run "$fix/green-corpus-pred-violation.yaml"

# --- cure_for: pinned against the ibc-pass1.md §2b table, NOT its own branches
# The six expected strings are HARDCODED here (sourced from the paper's cell
# table via the boundary); deriving them from cure_for itself would be the
# self-referential check this section exists to forbid.
cure() {
  printf 'let e = import "%s" in e.cure_for { determined = %s, %s monotone = %s }' \
    "$law" "$1" "$2" "$3" | nickel export --format raw
}
# check_cure DESC determined certifiable-field monotone EXPECTED
check_cure() {
  local desc="$1" det="$2" cert="$3" mono="$4" want="$5"
  local got rc
  got="$(cure "$det" "$cert" "$mono")"; rc=$?
  if [ "$rc" -eq 0 ] && [ "$got" = "$want" ]; then
    echo "PASS  (0) cure_for: $desc"
  else
    echo "FAIL  (rc=$rc) cure_for: $desc"
    echo "  want: $want"
    echo "  got:  $got"
    fails=$((fails + 1))
  fi
}
check_cure "det+cert+mono -> verify" \
  true "certifiable = true," true \
  'none — verify'
check_cure "det+cert+non-mono -> T3" \
  true "certifiable = true," false \
  'T3: a liveness holder (witness quorum or gossip), or restriction to "as of t", or an accepted expiry'
check_cure "det+non-cert+mono -> T2" \
  true "certifiable = false," true \
  'T2: a voucher — an admitted judgement; or restriction to a decidable subclass'
check_cure "det+non-cert+non-mono -> T2+T3" \
  true "certifiable = false," false \
  'T2+T3: a voucher, plus a freshness mechanism'
check_cure "undet+mono -> T1 (certifiable undefined)" \
  false "" true \
  'T1: witness of history — an admitted signer or attestor'
check_cure "undet+non-mono -> T1+T3 (certifiable undefined)" \
  false "" false \
  'T1+T3: an admitted signer, plus a freshness mechanism'

# --- law-shape checks (c8, c9, c12) ------------------------------------------
# c12: the predicate set is CLOSED — exactly the nine, the removed admission
# predicate absent (non-comment scope, per c6's structural-not-lexical rule).
names="$(grep -v '^ *#' "$law" \
  | grep -oE '(CorroborationBacked|VouchBacked|ProvenanceGate|QuestionRoutable|ResidualIsQuestion|ClaimHasAxes|CertifiabilityFibered|NonMonotoneNamesCure|SignerDesignates|NoSelfVouch)' \
  | sort -u)"
want_names="$(printf '%s\n' CertifiabilityFibered ClaimHasAxes CorroborationBacked \
  NonMonotoneNamesCure ProvenanceGate QuestionRoutable ResidualIsQuestion \
  SignerDesignates VouchBacked | sort)"
if [ "$names" = "$want_names" ]; then
  echo "PASS  (0) c12: predicate set closed at exactly the nine"
else
  echo "FAIL  c12: exported predicate set diverges from the closed nine"
  diff <(printf '%s\n' "$want_names") <(printf '%s\n' "$names")
  fails=$((fails + 1))
fi
# c8: cure_for carries no validation branch (comments may record the removal).
illformed="$(grep -v '^ *#' "$law" | grep -c 'ill-formed')"
if [ "$illformed" = "0" ]; then
  echo "PASS  (0) c8: no non-comment 'ill-formed' branch in the law"
else
  echo "FAIL  c8: found $illformed non-comment 'ill-formed' occurrence(s)"
  fails=$((fails + 1))
fi
# c9: the Axes record carries no fallback values.
axes_defaults="$(sed -n '/^  Axes = {/,/^  },/p' "$law" | grep -c 'default')"
if [ "$axes_defaults" = "0" ]; then
  echo "PASS  (0) c9: Axes record carries no fallback values"
else
  echo "FAIL  c9: found $axes_defaults 'default' occurrence(s) in the Axes record"
  fails=$((fails + 1))
fi

if [ "$fails" -ne 0 ]; then
  echo "FAIL: $fails entry case(s) mismatched"; exit 1
fi
echo "PASS: all entry cases matched their expected exit codes"
exit 0
