#!/usr/bin/env bash
# ledger/gate/test_open_surface.sh
#
# Acceptance suite for the rule governing the record's OPEN SURFACE — the
# claims it asserts without backing and the questions it leaves unanswered.
# The shipped conditioning types claims (`grade::`), names their provenance
# (`derives-from::`) and computes openness from the discharge edges, and it
# says NOTHING about what the resulting open surface IS FOR. That silence is
# the gap this suite pins.
#
# THE RULE HAS TWO FACES, AND THEY ARE ONE RULE
# ---------------------------------------------
#   DEBT.     An unbacked claim is not a resting state; it is staging. It moves
#             — refined into an answerable question, answered, or taken off the
#             board — and a record growing in unresolved claims is falling
#             behind rather than getting richer. Nothing is true merely because
#             it is written down.
#   RESOURCE. The open surface is the live frontier of what is known to be
#             unknown, so it is consulted BEFORE something new is derived, not
#             only when a reviewer asks for it. Skipping it re-derives what the
#             record already settled and re-makes recorded mistakes.
#
# They are stated as ONE rule because stating them apart invites a walk to
# honour one face and ignore the other — which is not hypothetical: it is the
# live defect this suite exists for. Section 4a is that requirement, and
# mutants M6, M7 and M15 are the evidence that satisfying one face here does
# not satisfy the other.
#
# WHAT IS SWEPT — the materialized install, never the .ncl sources.
# ------------------------------------------------------------------
# Same technique and same engine as test_conditioning_discipline.sh,
# test_report_fraction.sh and test_scrutiny_allocation.sh: run
# `conditioning/install.sh --harness all` into a throwaway HOME and measure the
# OUTPUT tree. A source grep cannot see what composition does, and section 4b
# makes a claim — "every walk" — that is a statement about the composed
# surfaces and about nothing else.
#
# THE RUNG, AND WHY — core, on a premise verified here rather than inherited
# --------------------------------------------------------------------------
# The rule goes in the ALWAYS-ON LAW (conditioning/core.ncl). The sibling
# suites argue core from the composer's composition, and that argument was
# re-read at `conditioning/compose.ncl` rather than taken on their word. It
# holds, verbatim:
#
#     composer | HasCore = compose [council_render] personas.composer
#
# The composer receives core, the rendered constitution table, and its own
# persona — NOT `dispatched`, NOT `producer`, NOT `council_module`. Every other
# role receives `dispatched`; no other role receives `council_render`. So core
# is the only rung the conductor shares with the walks it dispatches, and
# `HasCore` makes that reach a contract rather than a habit.
#
# The premise TRANSFERS, and with more force than in either sibling. Both faces
# of this rule were failed by the composer specifically: one face honoured and
# the other ignored, and the resource face skipped twice on questions the
# record had already answered. A rule about the record's open surface that did
# not reach the party holding the record would not have caught the failure it
# is written for. Two further reasons, neither structural:
#
#   * It is the DUAL, at the scale of the record, of two rules already in core.
#     "Reporting posture — carry the backing or name its absence" governs one
#     statement at the moment it is made; the debt face governs the same
#     statement for as long as it sits unbacked. Invariant 5's four-quadrant
#     tracker holds known-unknowns with signposts for the length of a walk; the
#     resource face says what that quadrant is FOR. Splitting either half to a
#     lower rung would make a reader join two rungs to recover one rule.
#   * Every walker both asserts and derives. A reviewer asserts findings, a
#     worker asserts that its criteria are met, a survey asserts territory, the
#     composer asserts campaign state — and each of them derives something the
#     record may already answer. The module rungs each reach a proper subset;
#     none reaches all of it.
#
# WHAT THIS SUITE DELIBERATELY DOES NOT PIN
# -----------------------------------------
#   * THE SECTION, and any heading. The report-fraction sibling could pin
#     placement because its rule is the aggregate of a rule already sitting in
#     a named section. This one cannot: the debt face would sit naturally with
#     the reporting posture, the resource face would not — it is about
#     consulting rather than reporting — and the two must stay together (4a).
#     An implementation that gives the rule its own section is as faithful as
#     one that extends an existing section to hold both faces. Pinning a
#     heading here would be this suite guessing at layout and calling the guess
#     a ruling.
#   * THE FRAMING PROSE. "Debt and resource", "the live frontier of what is
#     known to be unknown", "two faces of one surface" — that is the reasoning
#     that CHOSE this rule, not a phrase the shipped text owes a reader. A rule
#     that names the transition, refuses presence-as-evidence, binds
#     consultation ahead of derivation and keeps the two together is faithful
#     whether or not it also says "debt".
#   * THE MECHANISM. How the open surface is computed — the typed-claim
#     grammar, the discharge edges, `entries_query.ncl` — is PROCEDURE and
#     binds only walks that hold a typed corpus. Section 6 only holds core
#     clear of it and does not say where it should live; the goal names the
#     rule, not a mechanism, and pinning a home for text nobody has been asked
#     to write would be this suite inventing scope.
#
# VACUITY — how each case avoids measuring the author instead of the rule
# ----------------------------------------------------------------------
# A bare presence check for "open surface" passes the moment anyone writes the
# phrase, in any voice, binding nobody. Every signature here is built from
# ALTERNATIONS joined by ORDER-FREE PROXIMITY:
#
#   DEBT-TRN  = an open-surface word within a NEIGHBOURHOOD of a transition
#   DEBT-NTR  = an open-surface word within a NEIGHBOURHOOD of a
#               presence-is-not-evidence phrase
#   RESOURCE  = an open-surface word within a NEIGHBOURHOOD of (a consultation
#               verb in the same SENTENCE as a before-derivation term)
#   ONERULE   = a debt-face noun within a NEIGHBOURHOOD of a resource-face noun
#   PERMISSION= an open-surface word in the same SENTENCE as a permission modal
#
# Order-free in the two-branch form `A<window>B|B<window>A` rather than the
# lookahead form, following the scrutiny sibling's measurement: over the 22 KB
# rendered core the lookahead form re-tries the alternation at every window
# offset at every position and does not finish. The two-branch form runs the
# whole suite in seconds.
#
# SIGNATURES EXCLUDED BY MEASUREMENT, NOT BY JUDGEMENT
# ----------------------------------------------------
#   * `known-unknowns` is ABSENT from the open-surface alternation, and it is
#     the term a reader would most expect to find there — core already uses it
#     twice (Invariant 5's tracker, the AGENTS.md boundary). Admitting it makes
#     DEBT-TRN count 1 against the REAL pre-edit core at a 600-char
#     neighbourhood, on `removed code is entropy` in the Cutting Imperative
#     reaching forward to `known-unknowns with signposts` in Invariant 5. A red
#     that is already green before the edit is not a red. It is clean at 400,
#     but with zero headroom, and it changes no verdict on any mutant — so it
#     buys nothing and costs the margin.
#   * The bare word `open` is absent for the reason the report-fraction sibling
#     measured: it matches "opening a longer workstream" in the Discovery
#     sweep. `open questions?` and `open surface` keep the sense.
#   * `close`/`closed` is absent from the TRANSITION alternation. Core's
#     Verification Dual says "closed by the strongest applicable evaluator" and
#     "no evaluator can close it" throughout; a destination signature admitting
#     it would measure the neighbour rather than the rule.
#   * Bare `before` is absent from the before-derivation alternation — core
#     carries twelve of them ("before committing to a direction", "before
#     drawing the boundary"). Every member is multi-word.
#   * The PERMISSION guard does NOT admit `could close` or `could be answered`.
#     The bare-modal form was tried first and mutants M17 and M18 refuted it:
#     both are faithful rules, and both say the thing an open question is —
#     "a question some evaluator could close", "refine it into a question that
#     could be answered". A guard that trips on its own rule's most natural
#     sentence is measuring the author. The modal is pinned to the OBLIGATION's
#     own verbs (refine, strike, remove, consult, read, discharge), which keeps
#     the anti-pattern — "the open surface MAY be consulted" — and drops both
#     false positives.
#
# THE MUTANT TABLE — nineteen shapes at three insertion points
# ------------------------------------------------------------
# Every candidate was measured against mutants of the REAL rendered core, at
# THREE insertion points each the worst case for a different neighbouring
# vocabulary: P1 after the Reporting posture section (`unbacked`, `backing`,
# `evidence`, `derived from`), P2 after the AGENTS.md boundary section
# (`known-unknowns`, `signpost`, `read the nearest ... before`), P3 before the
# Code-edit floor. `P` = the case passes. Every verdict below is IDENTICAL at
# all three insertion points.
#
#   mutant                              2a   2b   3a   4a  | PRM-guard
#   M0  pre-edit (no rule)               f    f    f    f  | pass  <- baseline
#   M1  hollow ("keep it tidy")          f    f    f    f  | pass
#   M2  permission ("may be ...")        P    P    f    f  | TRIPS
#   M3  faithful, dense                  P    P    P    P  | pass
#   M4  faithful, bullet list            P    P    P    P  | pass
#   M5  heading only                     f    f    f    f  | pass
#   M6  DEBT face only                   P    P    f    f  | pass
#   M7  RESOURCE face only               f    f    P    f  | pass
#   M8  no transition named              f    P    P    P  | pass
#   M9  silent on presence-not-evidence  P    f    P    P  | pass
#   M10 resource, RETROSPECTIVE          P    P    f    P  | pass
#   M11 faithful, imperative voice       P    P    P    P  | pass
#   M12 faithful, third voice            P    P    P    P  | pass
#   M13 hollow + bearing prose           P    P    f    f  | pass
#   M14 both faces, far apart            P    P    f    f  | pass
#   M15 two rules, each faithful         P    P    P    f  | pass
#   M16 consult, timing elsewhere        P    P    f    P  | pass
#   M17 faithful, "could close"          P    P    P    P  | pass
#   M18 faithful, "could be answered"    P    P    P    P  | pass
#
# SIX faithful variants in six voices — M3, M4, M11, M12, M17, M18 — pass every
# red. Each red is INDIVIDUALLY NECESSARY, and one mutant isolates each: M8 is
# rejected by 2a alone, M9 by 2b alone, M10 by 3a alone, M15 by 4a alone. No
# red here is carried by another.
#
# The two FACES are independent by measurement, which is what requirement "both
# faces, and satisfying one does not satisfy the other" means operationally:
# M6 states the debt face faithfully and is rejected by 3a and 4a; M7 states
# the resource face faithfully and is rejected by 2a, 2b and 4a.
#
# TWO PROXIMITY GRAINS, and the mutation evidence that forced each
# ----------------------------------------------------------------
# NEIGHBOURHOOD wherever the term merely ACCOMPANIES the surface; SAME SENTENCE
# wherever it must GOVERN. Both halves of the split were chosen by refutation,
# not by taste:
#
#   * Same-sentence for the DEBT cases was refuted by the faithful mutants. At
#     that grain 2a rejects M3, M4, M6, M9, M11, M14 and M15, and 2b rejects
#     M4, M11 and M12 — a faithful rule routinely names the surface in one
#     sentence and its transition in the next.
#   * Same-sentence for the RESOURCE case's OUTER anchor was refuted by M4,
#     whose bulleted rule names the surface in one bullet and the read in the
#     next.
#   * Neighbourhood for the RESOURCE case's INNER pair was refuted by M16: a
#     rule that says to consult the surface when a reviewer asks, followed by
#     unrelated prose carrying "before you begin new work", PASSES at the
#     neighbourhood grain and is correctly rejected at same-sentence. The
#     timing must govern the consultation verb, not merely sit near it.
#
# THE WINDOW IS 400 CHARACTERS, and the mutants bound it from both sides.
# Sweeping 40 → 2400, verdicts are constant across 240–800 and break outside
# it. Below 240 faithful variants start failing (the last to clear is M17's 4a
# at 200; M11's 2a needs 80; M3's 4a needs 100). At 1000 the co-location case
# stops doing its job: M14 and M15 — both faces present but stated apart —
# start PASSING 4a, and M7 passes it at P2 on surrounding prose. At 1200 the
# section-7 delta guards go pre-red on all 22 agent surfaces. 400 is the middle
# of the 240–800 plateau, twice the faithful floor and two and a half times
# under the first false acceptance; within the plateau the evidence does not
# choose, which is stated here rather than left implied.
#
# DECLARED LIMITATION. Mutant M13 — a hollow instruction to keep the surface
# tidy, followed by unrelated prose that happens to carry "an answerable
# question" and "not true merely because it is written down" — passes 2a and
# 2b. A character window cannot tell a transition that GOVERNS a claim from
# transition vocabulary merely near it; only a syntactic reading could, and no
# regex performs one. The exposure is bounded rather than eliminated: M13 is
# still rejected by 3a and 4a, so the suite as a whole refuses it, and the only
# prose that can satisfy 2a/2b hollowly is prose the implementation itself
# adds. Recorded here so a later hand reads it as a ruling, not an oversight.
#
# A SECOND, NARROWER BOUND. The section-7 "one rung, one statement" guards use
# the ONERULE signature, so they catch a second copy of the RULE and not an
# echo of a single face at a lower rung. That is the right grain for the
# question they ask — a duplicate is the whole rule — but it is a bound, and it
# is named rather than left for a reader to discover.
#
# BASELINE POLARITY — the anti-vacuity declaration
# ------------------------------------------------
#   red    — MUST fail before the rule lands. A check that already passes
#            verifies nothing, so its polarity is declared in the source and
#            the summary reports whether the declaration held.
#   guard  — green before AND after. Two kinds here: over-cut guards protecting
#            the rules this one is derived from, which measure text that exists
#            today, and VACUOUS-NOW guards (sections 5, 6, 7) that pass only
#            because the subject text does not exist yet and bite the moment an
#            implementation writes it in the wrong voice, drags the mechanism
#            into the law, or copies the rule to a second rung. Their baselines
#            are declared honestly rather than counted as verification.
#
# The suite is therefore expected to exit 1 until the rule lands, with every
# `red` case failing and every `guard` case passing.
#
# Usage: bash ledger/gate/test_open_surface.sh
# Exit:  0 = every case passes (the rule has landed)
#        1 = at least one case failed
#        2 = environment error (nickel, python3, or install unavailable)

set -uo pipefail

here="$(cd "$(dirname "$(realpath "${BASH_SOURCE[0]}")")" && pwd)"
root="$(cd "$here/../.." && pwd)"
install_sh="$root/conditioning/install.sh"
core_ncl="$root/conditioning/core.ncl"
probe="$here/conditioning_probe.py"

for required in "$install_sh" "$core_ncl" "$probe"; do
  [ -f "$required" ] || { echo "FAIL (env): missing $required" >&2; exit 2; }
done
command -v nickel  >/dev/null 2>&1 || { echo "FAIL (env): nickel not on PATH" >&2; exit 2; }
command -v python3 >/dev/null 2>&1 || { echo "FAIL (env): python3 not on PATH" >&2; exit 2; }

TEMP_HOME="$(mktemp -d)"
CORE_RENDER="$TEMP_HOME/core-render.txt"
cleanup() { rm -rf "$TEMP_HOME"; }
trap cleanup EXIT

# ── case bookkeeping ──────────────────────────────────────────────────────────
PASS_COUNT=0
FAIL_COUNT=0
FAIL_MSGS=()
RED_DECLARED=0
RED_FAILING=0
GUARD_DECLARED=0

# record POLARITY OUTCOME DESC DETAIL
record() {
  local polarity="$1" outcome="$2" desc="$3" detail="${4:-}"
  case "$polarity" in
    red)   RED_DECLARED=$((RED_DECLARED + 1)) ;;
    guard) GUARD_DECLARED=$((GUARD_DECLARED + 1)) ;;
  esac
  if [ "$outcome" = pass ]; then
    echo "  PASS  [$polarity] $desc"
    PASS_COUNT=$((PASS_COUNT + 1))
  else
    echo "  FAIL  [$polarity] $desc${detail:+  ($detail)}"
    FAIL_COUNT=$((FAIL_COUNT + 1))
    FAIL_MSGS+=("[$polarity] $desc${detail:+  ($detail)}")
    [ "$polarity" = red ] && RED_FAILING=$((RED_FAILING + 1))
  fi
}

# probe_count SCOPE FLAG VALUE -> "MIN MAX UNITS"
#
# The flag and its value are joined with `=`: every signature in this suite is
# a regex beginning with `(?i)`, and passed as a separate argv word an
# option-shaped value is consumed by the parser as a flag — a case failing on a
# usage error instead of on the condition it asserts.
probe_count() {
  local scope="$1" flag="$2" value="$3"
  python3 "$probe" --tree "$TEMP_HOME" --core "$CORE_RENDER" \
    count --scope "$scope" "$flag=$value"
}

# expect_count POLARITY SCOPE MODE VALUE DESC FLAG NEEDLE
#   MODE eq  — every unit in the scope matches exactly VALUE
#   MODE min — every unit matches at least VALUE
#   MODE max — no unit matches more than VALUE
expect_count() {
  local polarity="$1" scope="$2" mode="$3" want="$4" desc="$5" flag="$6" needle="$7"
  local out rc min max units
  out="$(probe_count "$scope" "$flag" "$needle")"; rc=$?
  if [ "$rc" -ne 0 ]; then
    record "$polarity" fail "$desc" "probe exit $rc"
    return
  fi
  read -r min max units <<<"$out"
  local ok=false
  case "$mode" in
    eq)  [ "$min" -eq "$want" ] && [ "$max" -eq "$want" ] && ok=true ;;
    min) [ "$min" -ge "$want" ] && ok=true ;;
    max) [ "$max" -le "$want" ] && ok=true ;;
  esac
  if $ok; then
    record "$polarity" pass "$desc"
  else
    record "$polarity" fail "$desc" "$scope $mode $want; observed min=$min max=$max over $units unit(s)"
  fi
}

# ── the signature alternations ────────────────────────────────────────────────
#
# OPN — the open surface itself: what the record asserts without backing and
# what it asks without an answer. `unbacked` is the shipped vocabulary;
# `unanswered`, `unresolved`, `undischarged` and the `without (backing|an
# answer)` forms are what a faithful rewrite reaches for. See SIGNATURES
# EXCLUDED BY MEASUREMENT for why bare `open` and `known-unknowns` are absent.
OPN='(?:open surface|unbacked|unanswered|unresolved|undischarged|open questions?|without (?:backing|an answer|answers)|not (?:yet )?(?:backed|answered)|live frontier)'

# TRN — the TRANSITION an item on the surface must undergo: toward a question
# it can be asked as, toward an answer, or off the board. This is the
# discriminator against "the open surface matters" — a rule that names no
# destination names no obligation, and a walk cannot be wrong about it.
# `\banswer` rather than bare `answer`, because the noun is inside the surface's
# own description ("what it asks without an answer") and the bare form let
# mutants M5 and M8 pass a case they must fail.
TRN='(?:answerable question|into a question|becomes? a question|\banswer(?:ed|ing|s)\b|answer (?:it|them|that|the question)|\bstruck\b|\bstrike\b|off the board|withdraw\w*|retract\w*|\bremoved?\b|\bdropped\b|taken off|\bdischarg\w+)'

# NTR — presence in the record is NOT evidence. The debt face's other half: a
# claim does not become true by sitting written down, and a rule that stages
# claims without saying so leaves the reader free to treat the staging area as
# a conclusion. `is not evidence` is deliberately ABSENT — core's outward-search
# reflex already opens "Internal confidence is not evidence", so the bare phrase
# would measure the neighbour.
NTR='(?:true (?:merely|simply|just) because|(?:merely|simply|just) because it (?:is|was) (?:written|recorded)|presence in the record is not|being recorded is not|recording is not backing|assumed true|taken as true|treated as true|presumed true|written down)'

# CNS — the consultation act. The resource face is not "the surface is
# interesting"; it is that a walk READS it. Every member names a reading of
# something, never a bare verb: `read` alone is prose in a law that says "Read
# the nearest" and "re-read the governing invariant".
CNS='(?:consult\w*|read it\b|reads? (?:the |that )?(?:record|surface|ledger|entries|it)|you read\b|draws? on\b|drawn on\b|drawing on\b|check(?:s|ed|ing)? (?:the |that )?(?:record|surface|ledger)|quer(?:y|ies|ied|ying)|look(?:s|ed|ing)? (?:it )?up)'

# BEF — the timing, and the whole point of the resource face. A rule that fires
# when a reviewer asks arrives after the derivation it should have prevented.
# Bare `before` is absent (twelve in core); every member is multi-word.
BEF='(?:before[^.]{0,40}(?:deriv|conclud|work(?:ing)? out|answer|assert|decid|new)|ahead of[^.]{0,30}(?:deriv|new|conclus)|prior to[^.]{0,30}deriv|(?:rather than|not) only (?:at |when |after |in )?(?:review|audit|asked|a reviewer)|at review only)'

# DBT / RES — the two faces NAMED as faces. This pair is what makes 4a a
# statement about ONE rule rather than a second reading of its contents: a
# faithful rule calls the surface a debt (or an obligation, or staging, or
# something the walk owes) and calls it a resource (or an asset, or a frontier,
# or something the walk draws on), and it does so close enough together that a
# reader meets both in one pass.
DBT='(?:\bdebt\b|\bowe[sd]?\b|obligation|resting state|\bstaging\b|falling behind|liabilit\w+)'
RES='(?:\bresource\b|\basset\b|frontier|draws? on|drawn on|drawing on|\bconsulted\b|to draw on)'

# PRM — a permission modal ATTACHED TO THE OBLIGATION'S OWN VERBS. See
# SIGNATURES EXCLUDED BY MEASUREMENT: the bare-modal form was refuted by two
# faithful mutants that say what an open question IS ("a question some
# evaluator could close").
PRM='(?:(?:may|might|could|can) (?:be )?(?:refin|struck|strike|remov|drop|withdraw|retract|consult|read|discharg)\w*|\boptionally\b|at your discretion|\bif useful\b|\bwhere useful\b|\bwhere helpful\b|\bis optional\b|\bare optional\b)'

# The two proximity grains (see TWO PROXIMITY GRAINS in the header).
#
#   SAME SENTENCE — `[^.]*` cannot cross a period, so both terms lie in one
#   period-free run. Used where the term must GOVERN the other: the timing
#   governs the consultation verb, and a permission modal changes the rule's
#   force only in its own sentence.
SS='[^.]*'
#   NEIGHBOURHOOD — a bounded span that MAY cross sentence and list boundaries.
#   Used where the term merely ACCOMPANIES: a faithful rule names the surface in
#   one sentence and its transition, its consultation, or its other face in the
#   next.
NB='.{0,400}'

RX_DEBT_TRN="(?i)(?:${OPN}${NB}${TRN}|${TRN}${NB}${OPN})"
RX_DEBT_NTR="(?i)(?:${OPN}${NB}${NTR}|${NTR}${NB}${OPN})"
RES_PAIR="(?:${CNS}${SS}${BEF}|${BEF}${SS}${CNS})"
RX_RESOURCE="(?i)(?:${OPN}${NB}${RES_PAIR}|${RES_PAIR}${NB}${OPN})"
RX_ONERULE="(?i)(?:${DBT}${NB}${RES}|${RES}${NB}${DBT})"
RX_PERMISSION="(?i)(?:${OPN}${SS}${PRM}|${PRM}${SS}${OPN})"

# ══════════════════════════════════════════════════════════════════════════════
echo ""
echo "════════════════════════════════════════════════════════════════════════"
echo "SECTION 1 — Materialize the install and anchor the core region"
echo "════════════════════════════════════════════════════════════════════════"

# The universe this suite claims coverage over is the install's OUTPUT, so it is
# established by running the install and enumerating what it wrote — never by a
# directory listing carried in from somewhere else.
HOME="$TEMP_HOME" \
PREDICATE_CLAUDE_DIR="$TEMP_HOME/.claude" \
PREDICATE_GEMINI_DIR="$TEMP_HOME/.gemini" \
  bash "$install_sh" --harness all >"$TEMP_HOME/install.log" 2>&1
install_rc=$?
if [ "$install_rc" -ne 0 ]; then
  echo "FAIL (env): install.sh exited $install_rc" >&2
  sed 's/^/    /' "$TEMP_HOME/install.log" >&2
  exit 2
fi
echo "  install.sh exit: $install_rc"

nickel export --format text "$core_ncl" >"$CORE_RENDER" 2>"$TEMP_HOME/nickel.err"
nickel_rc=$?
if [ "$nickel_rc" -ne 0 ]; then
  echo "FAIL (env): nickel export of core.ncl exited $nickel_rc" >&2
  sed 's/^/    /' "$TEMP_HOME/nickel.err" >&2
  exit 2
fi

echo "  materialized surfaces:"
find "$TEMP_HOME/.claude" "$TEMP_HOME/.gemini" -type f -name '*.md' | sort | sed "s|^$TEMP_HOME/|    |"

# The identity anchor. Section 4b's "every surface" claim and section 7's
# delta-scoped guards both treat "the core region" as a property of the SHIPPED
# artifact; this is what earns that. Guard, because a regression here
# invalidates the measurements rather than reporting a rule that did not land.
verify_out="$(python3 "$probe" --tree "$TEMP_HOME" --core "$CORE_RENDER" verify-core)"
verify_rc=$?
echo "  $verify_out"
if [ "$verify_rc" -eq 0 ]; then
  record guard pass "rendered core is a verbatim single occurrence in every surface"
else
  record guard fail "rendered core is a verbatim single occurrence in every surface" \
    "$(printf '%s' "$verify_out" | tr '\n' ';')"
fi

# ══════════════════════════════════════════════════════════════════════════════
echo ""
echo "════════════════════════════════════════════════════════════════════════"
echo "SECTION 2 — Face one: the open surface is DEBT"
echo "════════════════════════════════════════════════════════════════════════"
echo ""

# 2a. THE TRANSITION. An unbacked claim is staging, and staging means it moves:
# refined into a question that can be asked, answered, or taken off the board.
# "Review the record" satisfies nothing here — it names no destination, so no
# walk can be shown to have failed it. Mutant M8 is the rule that describes the
# debt without naming where its items go, and this is the single case that
# rejects it.
expect_count red core min 1 \
  "debt: the transition is named (question, answer, or off the board)" \
  --regex "$RX_DEBT_TRN"

# 2b. PRESENCE IS NOT EVIDENCE. The other half, and the one an implementation
# is most likely to leave out, because it reads as obvious right up until a
# later walk cites a staged claim as settled. A record that stages claims
# without saying they are staged has invented a resting state for them. Mutant
# M9 is faithful in every other respect and silent here; this is the single
# case that rejects it.
expect_count red core min 1 \
  "debt: nothing is true merely because it is written down" \
  --regex "$RX_DEBT_NTR"

# ══════════════════════════════════════════════════════════════════════════════
echo ""
echo "════════════════════════════════════════════════════════════════════════"
echo "SECTION 3 — Face two: the open surface is a RESOURCE"
echo "════════════════════════════════════════════════════════════════════════"
echo ""

# 3a. CONSULTED BEFORE NEW DERIVATION. The timing is this face's whole content.
# A rule that has the surface read when a reviewer asks arrives after the
# derivation it existed to prevent — by then the walk has already re-derived
# what the record settled and re-made the mistake it holds. Mutant M10 is
# exactly that rule, faithful in every other respect and retrospective only,
# and this is the single case that rejects it.
#
# The inner pair is SAME-SENTENCE and the outer anchor is a NEIGHBOURHOOD, and
# both grains were chosen by refutation: M16 (consult here, "before you begin
# new work" in unrelated prose two sentences on) passes at the wider inner
# grain, and M4 (bulleted, surface named in one bullet and the read in the
# next) fails at the tighter outer one.
expect_count red core min 1 \
  "resource: it is consulted BEFORE new derivation, not only at review" \
  --regex "$RX_RESOURCE"

# ══════════════════════════════════════════════════════════════════════════════
echo ""
echo "════════════════════════════════════════════════════════════════════════"
echo "SECTION 4 — ONE rule, and it reaches every walk"
echo "════════════════════════════════════════════════════════════════════════"
echo ""

# 4a. THE TWO FACES ARE STATED TOGETHER. Sections 2 and 3 prove both faces are
# present; neither proves they are one rule, and a reader who meets the debt
# under one heading and the resource under another has been handed two rules to
# honour separately — which is how one gets honoured and the other ignored.
# Mutant M15 states BOTH faces faithfully as two separate rules a page apart:
# it passes 2a, 2b and 3a, and this is the single case that rejects it.
#
# This case names the faces rather than re-reading their contents, so it is a
# statement about the rule's shape and not a third copy of sections 2 and 3.
expect_count red core min 1 \
  "one rule: the debt and resource faces are stated together" \
  --regex "$RX_ONERULE"

# 4b. EVERY WALK, and the conductor above all — the composer is the party that
# honoured one face and ignored the other, and it receives no module rung at
# all. Stated as a separate case rather than inferred from 4a: 4a proves the
# text is in core, and this proves core's reach is intact for it across all 24
# materialized prompts — the two are one condition only for as long as
# `HasCore` holds on every field, which is what section 1 verifies and not
# something this case should assume on its own.
expect_count red surfaces min 1 \
  "reach: it reaches EVERY materialized surface (composer included)" \
  --regex "$RX_ONERULE"

# ══════════════════════════════════════════════════════════════════════════════
echo ""
echo "════════════════════════════════════════════════════════════════════════"
echo "SECTION 5 — It is an OBLIGATION, not a permission"
echo "════════════════════════════════════════════════════════════════════════"
echo ""
# VACUOUS AT THIS BASELINE and declared guard for that reason: core carries one
# open-surface word today (`unbacked`, in the reporting posture) and no modal
# governs it, so this passes without verifying much. It bites the moment an
# implementation writes "the open surface may be consulted" or "unbacked claims
# may be struck" — the most likely way to satisfy sections 2 and 3 while
# shipping the gap, and mutant M2, the one mutant this guard trips on.
expect_count guard core eq 0 \
  "obligation: no permission modal governs the open-surface duties" \
  --regex "$RX_PERMISSION"

# ══════════════════════════════════════════════════════════════════════════════
echo ""
echo "════════════════════════════════════════════════════════════════════════"
echo "SECTION 6 — The MECHANISM stays out of the law"
echo "════════════════════════════════════════════════════════════════════════"
# The rule is posture and binds every walk; HOW the open surface is computed —
# the typed-claim grammar, the discharge edges, the query that reads them — is
# PROCEDURE and binds only walks that hold a typed corpus. The risk is specific
# and higher here than in either sibling: the open surface is precisely what
# `entries_query.ncl` computes, so an implementation writing the resource face
# has every reason to reach for the query while doing it, and would put
# procedure in the law whatever else it got right.
#
# Every case here is VACUOUS AT THIS BASELINE — none of these tokens is in core
# today — and all are declared guard for that reason. Where the mechanism
# SHOULD live is deliberately unpinned; see WHAT THIS SUITE DELIBERATELY DOES
# NOT PIN.
echo ""
for token in \
  'entries_query.ncl' \
  'extract_entries.py' \
  'grade::' \
  'derives-from::' \
  'discharge::' \
  'closer::' \
  'awaiting_human' \
  'runnable_now' \
  'unpaid_cures' \
; do
  expect_count guard core eq 0 \
    "mechanism: '$token' absent from core (procedure stays out of the law)" \
    --needle "$token"
done

# ══════════════════════════════════════════════════════════════════════════════
echo ""
echo "════════════════════════════════════════════════════════════════════════"
echo "SECTION 7 — One rung, one statement (no second copy at a lower rung)"
echo "════════════════════════════════════════════════════════════════════════"
# Core reaches all 24 surfaces, so a module or persona that also states the rule
# makes the walker read it twice in one prompt — the defect class the
# conditioning-discipline pass exists to remove, and a duplication its unbounded
# k-gram sweep would report as UNDECLARED.
#
# The signature is ONERULE rather than either face's, and the choice is
# measured: at this baseline ONERULE returns 0 on all 22 agent deltas and both
# composer deltas at every window from 400 to 800, so neither guard is red
# before the edit. (At 1200 it returns 1 on every agent delta — one of the
# several measurements putting the window well below that.) The narrower bound
# this buys is declared in the header.
#
# VACUOUS AT THIS BASELINE, hence guard. Strike these two if the architect rules
# a rung needs its own elaboration — the composer at campaign CLOSE, where the
# open surface becomes the campaign's residue, is the plausible candidate.
echo ""
expect_count guard agents-delta eq 0 \
  "one statement: no second copy in any dispatched-role delta" \
  --regex "$RX_ONERULE"
expect_count guard composer-delta eq 0 \
  "one statement: no second copy in the composer delta" \
  --regex "$RX_ONERULE"

# ══════════════════════════════════════════════════════════════════════════════
echo ""
echo "════════════════════════════════════════════════════════════════════════"
echo "SECTION 8 — Over-cut guards: the rules this one is derived from survive"
echo "════════════════════════════════════════════════════════════════════════"
# Genuinely green at BOTH baselines — unlike sections 5, 6 and 7, these four
# measure text that exists today. This rule is the record-scale dual of the
# per-statement reporting posture and of the tracker's known-unknown quadrant;
# an implementation could rewrite either on its way past, and folding one of
# them INTO the new rule would look like tightening while removing the rung the
# new rule is derived from.
echo ""
expect_count guard core min 1 \
  "survives: the per-statement reporting posture this aggregates" \
  --needle '## Reporting posture'
expect_count guard core min 1 \
  "survives: the backing clause that defines an unbacked claim" \
  --needle '**backing**'
expect_count guard core min 1 \
  "survives: the tracker's known-unknown quadrant" \
  --needle 'known-unknowns with signposts'
expect_count guard core min 1 \
  "survives: the durable home of the live unknowns" \
  --needle 'live known-unknowns (each with a signpost)'

# ══════════════════════════════════════════════════════════════════════════════
echo ""
echo "════════════════════════════════════════════════════════════════════════"
echo "SUMMARY"
echo "════════════════════════════════════════════════════════════════════════"
echo "  PASS: $PASS_COUNT"
echo "  FAIL: $FAIL_COUNT"
echo "  cases declared red (must fail pre-rule):   $RED_DECLARED  — currently failing: $RED_FAILING"
echo "  cases declared guard (green pre and post): $GUARD_DECLARED"

if [ "$RED_DECLARED" -gt 0 ] && [ "$RED_FAILING" -eq "$RED_DECLARED" ]; then
  echo "  BASELINE: every red case is failing — the suite is a valid red baseline."
elif [ "$RED_FAILING" -eq 0 ]; then
  echo "  BASELINE: no red case is failing — the rule has landed."
else
  echo "  BASELINE: partially red — $RED_FAILING of $RED_DECLARED red cases failing."
fi

if [ "${#FAIL_MSGS[@]}" -gt 0 ]; then
  echo ""
  echo "  Failed cases:"
  for msg in "${FAIL_MSGS[@]}"; do
    echo "    x $msg"
  done
fi

echo ""
if [ "$FAIL_COUNT" -gt 0 ]; then
  echo "RESULT: FAIL — $FAIL_COUNT case(s) failed."
  exit 1
fi
echo "RESULT: ALL PASS"
exit 0
