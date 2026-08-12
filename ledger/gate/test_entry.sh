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
# (validated by EntryStore: per-entry shape, the full closed predicate set per
# entry, id-uniqueness, edge-resolution, and supersession termination — the
# relational properties no per-entry contract can see); otherwise a single entry
# (Entry composed with the eleven lifted predicates). The two granularities
# refuse the SAME defects — a predicate that fires only on a lone entry is a
# predicate that never fires, because the corpus is the shape a record takes.
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
expect "corroborated claim discharging a question -> export clean" 0 "" \
  -- run "$fix/green-discharges-corroborated.yaml"
expect "vouched claim discharging a question -> export clean" 0 "" \
  -- run "$fix/green-discharges-vouched.yaml"
expect "closer designation, kind without name -> export clean" 0 "" \
  -- run "$fix/green-closer-unnamed.yaml"
expect "corpus: discharges resolves to a declared question -> export clean" 0 "" \
  -- run "$fix/green-corpus-discharge.yaml"
expect "corpus: surviving question supersedes its duplicate -> export clean" 0 "" \
  -- run "$fix/green-corpus-superseded.yaml"
# The bidirectional half of the supersession-termination reds below: the
# property is that the walk BOTTOMS OUT, never that it is short. A check that
# refuses cycles by refusing depth would pass both reds and fail here.
expect "corpus: two-hop supersession chain bottoms out -> export clean" 0 "" \
  -- run "$fix/green-corpus-supersedes-chain.yaml"

# --- node/directives-resolvable: directives enter the resolvable id space --
#
# ruling-terminal-composition [TC5]/[TC6]: a `directive` closes by authority
# and the extractor routes it to the top-level `directives` list, out of
# `entries` entirely — so a correct `because`/`discharges` ref naming one was
# failing resolution before target-typing was ever consulted, because
# `id_set` only ever counted `entries`. The fix widens the space every edge
# resolves against to entries-or-directives, and widens `discharges`'
# target-typing from question-only to question-or-directive — the same
# relation, not a new one (`discharges` still means "this entry answers that
# open item", and a directive is open until met). DischargeBacked (the
# discharger's own backing) is untouched by either change.
expect "corpus: because names a directive -> export clean" 0 "" \
  -- run "$fix/green-corpus-because-directive.yaml"
expect "corpus: discharges resolves to a declared directive -> export clean" 0 "" \
  -- run "$fix/green-corpus-discharges-directive.yaml"
# The third case, proving the widening is not a blanket weakening: a
# `directives` list is present and non-empty, but the ref names an id that is
# neither a declared entry nor a declared directive. It must still dangle.
expect "corpus: ref naming nothing at all still dangles, directives present" 1 "dangling edge" \
  -- run "$fix/red-corpus-dangling-with-directives.yaml"

# --- node/provenance-gate: TDD reds for the ProvenanceGate relaxation -------
#
# ruling-provenance-gate (ledger commit fcf009e): the 22 no-derivation-edge
# unclosed claims the gate refuses split 2 supersedes-tethered / 20
# externally-cited / 0 actual hallucinations. Design SUPERSEDED once by
# ruling-provenance-representation (ledger commit f257f6f), which WITHDRAWS
# an entry-level `external_refs` mirror this suite originally pinned — see
# 2026-08-12-failure-states [F20]-[F23] for the staleness episode that
# produced. The RULED design: `because` ALONE carries TAGGED refs, a record
# `{kind: corpus|external, name: ...}` (matching the Signer/Closer idiom,
# never a payloaded Nickel variant — those do not serialize). `depends`,
# `discharges`, `supersedes` stay plain corpus ids. `edges_of` is REMOVED,
# replaced by `provenance_of` (every stated antecedent — feeds ProvenanceGate,
# SignerDesignates' derived branch, DirectiveDesignates) and
# `corpus_edges_of` (the walkable subset — feeds chain_floor, unbacked,
# EntryStore).
#
# The cases below assert the CORRECT, POST-FIX behavior — export clean,
# rc=0 — so they are the acceptance gate the fix must reach, not a pin of
# today's defect. Run against the unmodified law they FAIL, each for a
# different, verified reason: the supersedes cases fail ProvenanceGate
# (supersedes is not in provenance_of's precursor, edges_of, yet); the
# tagged-because cases fail SHAPE ("NonEmptyString", since `because` is
# still `Array Ref` — bare strings — and a tagged record element breaks
# that). Each is asserted at BOTH granularities (lone entry and corpus), per
# this file's own pairing discipline — a predicate live on one branch and
# dead on the other is a predicate that never fires.
expect "supersedes-only claim tethers the record -> export clean" 0 "" \
  -- run "$fix/green-supersedes-only-claim.yaml"
expect "corpus: supersedes-only claim tethers the record -> export clean" 0 "" \
  -- run "$fix/green-corpus-supersedes-claim-tether.yaml"
expect "because-tagged EXTERNAL ref tethers the record -> export clean" 0 "" \
  -- run "$fix/green-external-provenance-claim.yaml"
expect "corpus: because-tagged EXTERNAL ref tethers the record -> export clean" 0 "" \
  -- run "$fix/green-corpus-external-provenance-claim.yaml"
# Symmetric case: a because-tagged CORPUS ref, with no depends and no
# supersedes. Existing corpus-tagged coverage (green-synthesis-claim.yaml and
# siblings, migrated below) tests this only incidentally, on the way to
# testing something else; this is the dedicated, minimal pin.
expect "because-tagged CORPUS ref tethers the record -> export clean" 0 "" \
  -- run "$fix/green-because-corpus-ref-claim.yaml"
expect "corpus: because-tagged CORPUS ref tethers the record -> export clean" 0 "" \
  -- run "$fix/green-corpus-because-corpus-ref-claim.yaml"

# Boundary guards, all PERMANENT — before and after the fix. Single-violation
# by construction.
#
# A present-but-EMPTY `because` array names no tether. Guards array LENGTH
# over field PRESENCE (`std.record.has_field` would let an empty array
# through). Its reason (ProvenanceGate) is stable across the fix — an empty
# array is shape-valid under BOTH the old and new `because` type.
expect "empty because array is not a tether -> ProvenanceGate" 1 "ProvenanceGate" \
  -- run "$fix/red-because-empty-not-tether.yaml"
expect "empty supersedes array is not a tether -> ProvenanceGate" 1 "ProvenanceGate" \
  -- run "$fix/red-supersedes-empty-not-tether.yaml"
# A `because` entry's `kind` is a CLOSED two-variant enum — `corpus` or
# `external`, nothing else. Refusing the six antecedent kinds the earlier
# discriminator enumerated is load-bearing (ruling-provenance-representation
# [SR5]): an open variant set is worse than the sidecar it replaces.
expect "because entry with out-of-set kind -> RefKind enum" 1 "RefKind" \
  -- run "$fix/red-because-invalid-kind.yaml"
# Criterion 7: tagged refs live on `because` ALONE. `depends` stays plain
# corpus ids — the record's own deletion semantics (depends means THIS ENTRY
# BREAKS if the target is deleted, and an antecedent outside the corpus has
# no deletion event to break on), so a tagged `depends` element is a shape
# violation, permanently. This is the boundary a later author will drift on
# if nothing pins it.
expect "tagged depends element is refused -> NonEmptyString" 1 "NonEmptyString" \
  -- run "$fix/red-depends-wrongly-tagged.yaml"

# --- node/tags: the coining bar -----------------------------------------
#
# ledger/log/2026-08-12-tagging-hypothesis.md [G8]: "the risk is not in the
# hypothesis but in shipping tags without their registry." A tag is admitted
# by closed-set membership against tag_registry.ncl, enforced at the SHAPE
# tier (TagName, beside SignerKind/Backing) — a registered tag exports clean,
# an unregistered one is REFUSED, never merely reported.
expect "claim tagged with a registered direction tag -> export clean" 0 "" \
  -- run "$fix/green-tagged-claim.yaml"
expect "claim tagged with an unregistered tag -> TagName" 1 "TagName" \
  -- run "$fix/red-unregistered-tag.yaml"

# (mutation) prove the registry check is load-bearing: a mutant that widens
# TagName to accept any string must make the unregistered-tag fixture go
# GREEN when it must not — the failure mode the coining bar exists to refuse.
# The mutant lives in its own tmp dir (law + registry + apply-file copied
# together, so the relative imports between them still resolve) rather than
# patching the tracked file in place.
tags_mut="$(mktemp -d)"
cp "$law" "$tags_mut/entry.ncl"
cp "$root/ledger/contracts/tag_registry.ncl" "$tags_mut/tag_registry.ncl"
cp "$apply" "$tags_mut/entry_apply.ncl"
sed -i 's/std.record.has_field v tag_registry/true/' "$tags_mut/entry.ncl"
grep -q 'if std.is_string v && true' "$tags_mut/entry.ncl" \
  || { echo "ENV: TagName mutation did not apply — the literal moved"; exit 2; }
mutant_out="$(cd "$root" && nickel export "$fix/red-unregistered-tag.yaml" \
  --apply-contract "$tags_mut/entry_apply.ncl" 2>&1)"
mutant_rc=$?
if [ "$mutant_rc" -eq 0 ]; then
  echo "PASS  (mutation) widened TagName lets the unregistered-tag fixture through — the pinned red is load-bearing"
else
  echo "FAIL  (mutation) unregistered-tag fixture still fails under a widened TagName (rc=$mutant_rc) — the pin proves nothing"
  printf '%s\n' "$mutant_out" | tail -3
  fails=$((fails + 1))
fi
rm -rf "$tags_mut"

# --- predicate reds: one per predicate, both directions where bidirectional --
expect "CANARY: string-backed corroborated claim, check unrun -> CorroborationBacked" 1 "CorroborationBacked" \
  -- run "$fix/red-corroboration-unrun.yaml"
expect "corroborated claim, no check at all -> CorroborationBacked" 1 "CorroborationBacked" \
  -- run "$fix/red-corroboration-no-check.yaml"
expect "vouched claim, no witness -> VouchBacked" 1 "VouchBacked" \
  -- run "$fix/red-vouch-no-witness.yaml"
# SURVIVING-MODE PIN (ruling-provenance-gate [P9]): this is the actual
# hallucination the gate exists to catch — a synthesis with no `because`, no
# `depends`, and no `supersedes` — and the relaxation above must not touch
# it. It fails ProvenanceGate today and must go on failing it once
# `provenance_of` is checking supersedes and tagged because-refs too; nothing
# about this fixture changes when the fix lands, and this holds under BOTH
# the withdrawn mirror design and the ruled tagged-ref one — an empty
# `because` array is empty either way.
expect "unclosed claim, no edges -> ProvenanceGate" 1 "ProvenanceGate" \
  -- run "$fix/red-unclosed-claim-no-edges.yaml"
expect "question missing discharge -> QuestionRoutable" 1 "QuestionRoutable" \
  -- run "$fix/red-question-no-discharge.yaml"
expect "question missing closer -> QuestionRoutable" 1 "QuestionRoutable" \
  -- run "$fix/red-question-no-closer.yaml"
expect "residual claim -> ResidualIsQuestion" 1 "ResidualIsQuestion" \
  -- run "$fix/red-residual-claim.yaml"
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
# Criterion 9, repair 1/3 (ibc-provenance-gate): SignerDesignates' derived
# branch must accept a legitimate external-derived designation it refuses
# today. Green-to-be: export clean, rc=0. Fails SHAPE today ("NonEmptyString")
# for the same reason the because-tagged cases above do.
expect "derived signer, external-only provenance -> export clean" 0 "" \
  -- run "$fix/green-derived-signer-external-provenance.yaml"
expect "unattributed signer, named -> SignerDesignates" 1 "SignerDesignates" \
  -- run "$fix/red-unattributed-named.yaml"
# Both fixtures below are string-form YAML (backing and signer.kind carry
# plain strings, never nickel tags), so a green here would mean
# UnattributedUnclosed's `matches` comparison regressed to a bare `==` — the
# same dual-comparison tripwire the CANARY above guards for CorroborationBacked.
expect "unattributed signer, vouched -> UnattributedUnclosed" 1 "UnattributedUnclosed" \
  -- run "$fix/red-unattributed-vouched.yaml"
expect "unattributed signer, corroborated -> UnattributedUnclosed" 1 "UnattributedUnclosed" \
  -- run "$fix/red-unattributed-corroborated.yaml"
# Misclosure is unrepresentable by SHAPE: a discharges edge is valid only from
# a corroborated or vouched CLAIM. All three reds below must name
# DischargeBacked, and each is here for a DIFFERENT clause of it — the
# predicate enumerates two violation modes, and a suite that exercises one of
# them twice leaves the other clause deletable without a red going green.
# Verified by mutation, which is the only instrument that can see an
# unexercised clause (keyword analysis structurally cannot):
#   - drop the ASSERTION clause: only red-question-backed-discharges goes
#     green. The two reds below survive it — both carry `backing: unclosed`,
#     so the backing clause fails in both regardless.
#   - drop the BACKING clause: only red-discharges-from-synthesis goes green.
#   - red-question-discharges violates BOTH clauses, so it kills neither
#     mutant on its own; it is kept as the both-modes case, not as a clause
#     witness.
expect "synthesis claim carrying discharges -> DischargeBacked" 1 "DischargeBacked" \
  -- run "$fix/red-discharges-from-synthesis.yaml"
expect "question carrying discharges -> DischargeBacked" 1 "DischargeBacked" \
  -- run "$fix/red-question-discharges.yaml"
expect "backed question carrying discharges -> DischargeBacked" 1 "DischargeBacked" \
  -- run "$fix/red-question-backed-discharges.yaml"

# --- shape reds --------------------------------------------------------------
expect "empty statement -> NonEmptyString" 1 "NonEmptyString" \
  -- run "$fix/red-empty-statement.yaml"
expect "malformed commit ref -> CommitRef" 1 "CommitRef" \
  -- run "$fix/red-malformed-commit.yaml"
expect "out-of-set backing string -> Backing enum" 1 "Backing: expected" \
  -- run "$fix/red-invalid-backing.yaml"
# `derived` is a valid SignerKind, so this red also refutes an implementation
# that reuses the signer's enum for the closer designation.
expect "closer with out-of-set kind -> CloserKind" 1 "CloserKind" \
  -- run "$fix/red-closer-bad-kind.yaml"

# --- corpus reds (EntryStore) ------------------------------------------------
expect "corpus with duplicate ids -> EntryStore duplicate" 1 "duplicate entry id" \
  -- run "$fix/red-corpus-dup-id.yaml"
expect "corpus with dangling edge -> EntryStore dangling" 1 "dangling edge" \
  -- run "$fix/red-corpus-dangling-edge.yaml"
# Target-typing lives with resolution at the corpus level: discharges targets
# a question; supersedes targets a declared entry. Distinct tokens per red so
# a wrong verdict cannot pass by coincidence.
expect "corpus: discharges onto a claim -> EntryStore target type" 1 "discharges target" \
  -- run "$fix/red-corpus-discharges-claim.yaml"
expect "corpus: unresolved discharges ref -> EntryStore" 1 "dangling discharges" \
  -- run "$fix/red-corpus-dangling-discharges.yaml"
expect "corpus: unresolved supersedes ref -> EntryStore" 1 "dangling supersedes" \
  -- run "$fix/red-corpus-dangling-supersedes.yaml"
# Resolution was the ONLY condition the corpus placed on a supersession edge,
# and resolution does not bound the walk: a resolved cycle retires everything
# it touches and delivers no survivor. Openness is derived from the closure
# edges, so both reds below silently empty `awaiting_human` — the questions
# leave the work lists while remaining, by the record's own account,
# unanswered. Two shapes because one does not cover the other: a check that
# refuses only a self-reference passes the mutual pair unchanged.
expect "corpus: question supersedes itself -> SupersessionTerminates" 1 "SupersessionTerminates" \
  -- run "$fix/red-corpus-supersedes-self.yaml"
expect "corpus: two duplicates supersede each other -> SupersessionTerminates" 1 "SupersessionTerminates" \
  -- run "$fix/red-corpus-supersedes-cycle.yaml"
# Guards EntryStore's eager per-entry conformance fold (the deep_seq
# machinery): deleting that fold lets a shape-malformed entry export clean
# from a corpus. This is the only case that fails under that mutation.
expect "corpus with shape-malformed entry (empty statement) -> per-entry conformance" 1 "NonEmptyString" \
  -- run "$fix/red-corpus-malformed-entry.yaml"
# THE FLIP. This case was pinned green while the corpus path applied NONE of
# the eleven predicates, on the reading that per-entry violation COLLECTION
# over a corpus was a future batch validator's job. The pin named its own flip
# condition — rc=1, VouchBacked — and that condition has arrived: the corpus is
# the ONLY shape a real record takes, so a predicate that never runs there is a
# predicate that never runs. Collection remains the batch validator's job;
# REFUSAL is the contract's, at either granularity.
expect "corpus with predicate-violating entry (vouched, no witness) -> VouchBacked" 1 "VouchBacked" \
  -- run "$fix/red-corpus-pred-violation.yaml"

# THE MISCLOSURE, on the live path: an unratified proposal (a claim whose own
# backing is `unclosed`) discharging the question that asks for its
# ratification. DischargeBacked names this case in its own comment and was
# nevertheless never reached by it, because the predicate ran only on lone
# entries. The corpus form exported clean, and openness being DERIVED from the
# closure edges, the query then dropped the question from `awaiting_human` —
# the record reporting no outstanding human work on the strength of a proposal
# nobody ratified. This is the case whose absence let the defect through.
expect "corpus: unratified proposal discharges its own question -> DischargeBacked" 1 "DischargeBacked" \
  -- run "$fix/red-corpus-unratified-discharge.yaml"

# --- live-path predicate reds: the closed set, one per predicate -------------
#
# The two cases above cover VouchBacked and DischargeBacked; these nine cover
# the rest, closing the set at all eleven. The coverage is the point rather
# than the individual cases: a per-entry red proves a predicate is WRITTEN, and
# only a corpus red proves it RUNS on the shape a record takes. The pairing is
# the standing acceptance rule for any boundary that adds a predicate here —
# never single-entry reds alone.
#
# Every fixture in this block places its clean entry FIRST and its violation
# SECOND, so a fold that inspects only the head of the corpus fails all nine.
# Each is single-violation by construction: the token names the one predicate
# the entry breaks, and no other entry in the corpus breaks any.
expect "corpus: corroborated claim, check unrun -> CorroborationBacked" 1 "CorroborationBacked" \
  -- run "$fix/red-corpus-corroboration-unrun.yaml"
# SURVIVING-MODE PIN, corpus granularity (see the lone-entry pin above):
# unaffected by the relaxation, and must stay this way.
expect "corpus: unclosed claim, no edges -> ProvenanceGate" 1 "ProvenanceGate" \
  -- run "$fix/red-corpus-unclosed-no-edges.yaml"
expect "corpus: question missing closer -> QuestionRoutable" 1 "QuestionRoutable" \
  -- run "$fix/red-corpus-question-unroutable.yaml"
expect "corpus: residual claim -> ResidualIsQuestion" 1 "ResidualIsQuestion" \
  -- run "$fix/red-corpus-residual-claim.yaml"
expect "corpus: question with axes -> ClaimHasAxes" 1 "ClaimHasAxes" \
  -- run "$fix/red-corpus-question-with-axes.yaml"
expect "corpus: determined claim, no certifiable -> CertifiabilityFibered" 1 "CertifiabilityFibered" \
  -- run "$fix/red-corpus-certifiability.yaml"
expect "corpus: non-monotone claim, no freshness -> NonMonotoneNamesCure" 1 "NonMonotoneNamesCure" \
  -- run "$fix/red-corpus-nonmonotone.yaml"
expect "corpus: non-derived signer, unnamed -> SignerDesignates" 1 "SignerDesignates" \
  -- run "$fix/red-corpus-signer-unnamed.yaml"
expect "corpus: unattributed signer, vouched -> UnattributedUnclosed" 1 "UnattributedUnclosed" \
  -- run "$fix/red-corpus-unattributed-vouched.yaml"

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
# c12: the predicate set is CLOSED — exactly the eleven (DischargeBacked
# joined the ten per the recovered-edges amendment; UnattributedUnclosed
# joined the nine per the unattributed-closure ruling), the removed admission
# predicate absent (non-comment scope, per c6's structural-not-lexical rule).
names="$(grep -v '^ *#' "$law" \
  | grep -oE '(CorroborationBacked|VouchBacked|ProvenanceGate|QuestionRoutable|ResidualIsQuestion|ClaimHasAxes|CertifiabilityFibered|NonMonotoneNamesCure|SignerDesignates|UnattributedUnclosed|DischargeBacked|NoSelfVouch)' \
  | sort -u)"
want_names="$(printf '%s\n' CertifiabilityFibered ClaimHasAxes CorroborationBacked \
  DischargeBacked NonMonotoneNamesCure ProvenanceGate QuestionRoutable \
  ResidualIsQuestion SignerDesignates UnattributedUnclosed VouchBacked | sort)"
if [ "$names" = "$want_names" ]; then
  echo "PASS  (0) c12: predicate set closed at exactly the eleven"
else
  echo "FAIL  c12: exported predicate set diverges from the closed eleven"
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

# c13 (ibc-provenance-gate acceptance #5, AS CORRECTED): `edges_of` no
# longer exists, and `provenance_of` / `corpus_edges_of` each exist exactly
# once. This criterion was PREVIOUSLY THE EXACT OPPOSITE — "edges_of is
# declared once, body textually unchanged" — written under the withdrawn
# mirror ruling (ruling-provenance-gate) and inverted once the
# representation ruling (ruling-provenance-representation [SR8]) explicitly
# REMOVED edges_of rather than aliasing it: "Keeping edges_of as an alias is
# refused: the conflation IS the defect, and a surviving name that answers
# both questions lets the next consumer pick the wrong one exactly as three
# did." Landed here is the corrected, currently-RED form of this check — see
# 2026-08-12-failure-states [F20]-[F23] for the episode where the stale form
# would have blocked the correct fix. A structural check on the LAW's own
# source, the same tier as c8/c9/c12/c14 — never a check on rendered tool
# output. TODAY: edges_of exists (count=1, want 0) and neither helper does
# (count=0 each, want 1) — genuinely red, not a stays-green regression guard
# like c8/c9/c12/c14.
edges_of_defs="$(grep -c '^  edges_of ' "$law")"
provenance_of_defs="$(grep -c '^  provenance_of ' "$law")"
corpus_edges_of_defs="$(grep -c '^  corpus_edges_of ' "$law")"
if [ "$edges_of_defs" = "0" ] && [ "$provenance_of_defs" = "1" ] \
   && [ "$corpus_edges_of_defs" = "1" ]; then
  echo "PASS  (0) c13: edges_of removed, provenance_of/corpus_edges_of exist once each"
else
  echo "FAIL  c13: edges_of=$edges_of_defs (want 0), provenance_of=$provenance_of_defs (want 1), corpus_edges_of=$corpus_edges_of_defs (want 1)"
  fails=$((fails + 1))
fi

# c14 (ibc-provenance-gate acceptance #6): `discharges` appears in NO clause
# of ProvenanceGate's own body — DischargeBacked already forbids an unclosed
# claim from carrying a discharges edge, so a ProvenanceGate clause consulting
# it could never fire (ruling-provenance-gate [P8]: "a clause that cannot
# fail is the class this seat ruled against"). Scoped to ProvenanceGate's own
# definition, not the whole file — DischargeBacked legitimately names
# `discharges` elsewhere, and a file-wide grep would misfire on it.
provenance_gate_body="$(sed -n '/^  ProvenanceGate = fun n =>/,/^  QuestionRoutable/p' "$law" | sed '$d')"
provenance_gate_discharges="$(printf '%s\n' "$provenance_gate_body" | grep -c 'discharges')"
if [ "$provenance_gate_discharges" = "0" ]; then
  echo "PASS  (0) c14: discharges appears in no ProvenanceGate clause"
else
  echo "FAIL  c14: found $provenance_gate_discharges 'discharges' occurrence(s) in ProvenanceGate"
  fails=$((fails + 1))
fi

if [ "$fails" -ne 0 ]; then
  echo "FAIL: $fails entry case(s) mismatched"; exit 1
fi
echo "PASS: all entry cases matched their expected exit codes"
exit 0
