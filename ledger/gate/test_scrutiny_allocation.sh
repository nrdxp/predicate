#!/usr/bin/env bash
# ledger/gate/test_scrutiny_allocation.sh
#
# Acceptance suite for the missing half of the classification reform: the
# campaign shipped a classification whose cells are load-bearing and
# machine-checked, and NOTHING ALLOCATES SCRUTINY BY THEM. Every claim draws
# the same attention regardless of what it costs to be wrong about it and how
# hard it is to close.
#
# THE CASE THIS EXISTS TO CATCH — a live defect, not a hypothetical
# -----------------------------------------------------------------
# The composer authored the campaign's own terminal claim — the statement of
# when the work is done — set it narrower than the goal it served, met its own
# bar, and began treating the campaign as converging. Every gate passed. No law
# was broken. The claim was maximal-stakes, uncloseable by its author, and drew
# no more scrutiny than any other line. The four discriminators in sections 3-6
# are that failure decomposed: the two factors that would have ranked it, the
# timing that would have caught it at authoring rather than at review, the
# procedure the top rank owes, and the self-closure that made it uncloseable on
# its own backing.
#
# WHAT THE RULE MUST SAY IS NOT THIS SUITE'S INVENTION. The design is recorded
# — escalation and scrutiny as two projections of ONE ladder (the Verification
# Dual's evaluator hierarchy the law already carries), allocation by
# stakes x uncloseability, conditioning maximal on that scale, and the top
# tier's procedure being the comprehension probe. This suite pins that a rule
# with those properties EXISTS IN THE SHIPPED CONDITIONING. It does not pin its
# wording, and it does not pin its section.
#
# WHAT IS SWEPT — the materialized install, never the .ncl sources.
# ------------------------------------------------------------------
# Same technique and same engine as test_conditioning_discipline.sh and
# test_report_fraction.sh: run `conditioning/install.sh --harness all` into a
# throwaway HOME and measure the OUTPUT tree. A source grep cannot see what
# composition does, and section 2b makes a claim — "every walk" — that is a
# statement about the composed surfaces and about nothing else.
#
# THE RUNG, AND WHY — core, and the reasoning is the failure case's own
# ---------------------------------------------------------------------
# The obligation goes in the ALWAYS-ON LAW (conditioning/core.ncl). Three
# reasons, the first structural and decisive:
#
#   1. THE ACTOR IN THE LIVE DEFECT IS THE COMPOSER, and `compose.ncl` gives
#      the composer NEITHER `dispatched` NOR `producer` NOR `council` —
#      `composer | HasCore = compose [council_render] personas.composer`, where
#      the sole extra segment is the rendered constitution table. Core is the
#      only rung the conductor shares with the workers and reviewers it
#      dispatches, and `HasCore` makes that reach a contract rather than a
#      habit. A rule about allocating scrutiny that does not reach the composer
#      would not have caught the very failure it is written for. This is the
#      sibling suite's argument for the fraction obligation, and it transfers
#      here with more force, because there the composer was one walker among
#      many and here it is the defendant.
#   2. It is the RETROSPECTIVE PROJECTION of a rule already in core. Prime
#      Invariant 1 routes each condition to the strongest evaluator that closes
#      it; allocation says how much of the walk's attention each condition
#      earns on the way. One ladder, two read-outs. Splitting the read-outs
#      across rungs would make a reader join two rungs to recover one rule.
#   3. Every walker allocates. A reviewer distributes attention across
#      findings, a worker across its acceptance criteria, a survey across its
#      territory, the composer across a campaign. The module rungs each reach
#      a proper subset; none of them reaches all of it.
#
# WHAT THIS SUITE DELIBERATELY DOES NOT PIN
# -----------------------------------------
#   * THE SECTION. The sibling suite could pin placement because its rule is
#     the aggregate of a rule already sitting in a named section. This one has
#     no such home: it is derived from Prime Invariant 1 but is not an
#     elaboration of any single existing section, and an implementation that
#     gives it a section of its own is as faithful as one that folds it into
#     the Dual. Pinning a heading here would be this suite guessing at layout
#     and calling the guess a ruling.
#   * THE LADDER PROSE. The record's "two projections of one ladder" is the
#     reasoning that CHOSE this rule; it is not a phrase the shipped text owes
#     a reader. A rule naming both factors, binding at authoring, naming the
#     top rank's procedure and calling out self-closure is faithful whether or
#     not it also says "the same ladder as escalation".
#   * WHERE CONDITIONING SITS ON THE SCALE. That conditioning is maximal on
#     both factors follows from the rule rather than being part of it, and
#     `conditioning` is a word core does not currently use at all.
#
# VACUITY — how each case avoids measuring the author instead of the rule
# ----------------------------------------------------------------------
# A bare presence check for "scrutiny" passes the moment anyone writes the word
# in any voice, binding nobody. Every signature here is built from two
# ALTERNATIONS joined by an ORDER-FREE PROXIMITY test:
#
#   ALLOC     = a scrutiny word within one sentence of an allocation verb
#   STAKES    = ALLOC within a NEIGHBOURHOOD of the stakes factor
#   UNCLOSE   = ALLOC within a NEIGHBOURHOOD of the uncloseability factor
#   PROSPECT  = ALLOC within a NEIGHBOURHOOD of a term binding it BEFORE the work
#   TIERPROC  = a top-of-ladder position in the same SENTENCE as a named procedure
#   SELF      = a same-author-same-satisfier phrase in the same SENTENCE as its
#               consequence
#
# Order-free in the two-branch form `A<window>B|B<window>A` rather than the
# lookahead form, for two reasons. It is order-free either way — both orders
# are enumerated, and intra-span backtracking recovers the overlapping cases,
# which was checked against every faithful mutant below. And the lookahead form
# `(?=<window>A)<window>B` was measurably unusable here: over the 22 KB
# rendered core it re-tries a twenty-branch alternation at every one of ~241
# window offsets at every position, and did not finish in 120 seconds. The
# two-branch form runs the whole suite in seconds.
#
# TWO PROXIMITY GRAINS, and the mutation evidence that forced the split
# ---------------------------------------------------------------------
# Both grains were measured against twelve mutants of the REAL rendered core —
# the rule inserted in each of the shapes an implementation might plausibly
# take — at THREE insertion points, each the worst case for a different
# neighbouring vocabulary: P1 inside Prime Invariant 1 (`strongest`,
# `evaluator`), P2 as its own section after Focus before ceremony
# (`attention`, `before`), P3 before the Code-edit floor. `P` = the case
# passes. Every verdict below is IDENTICAL at all three insertion points.
#
#   mutant                            2a  3a  3b  4   5   6   | PRM-guard
#   M0  pre-edit (no rule)             f   f   f   f   f   f   | pass  <- baseline
#   M1  hollow ("spend more where      P   f   f   f   f   f   | pass
#       it matters")
#   M2  permission ("may be            P   P   P   f   f   f   | TRIPS
#       allocated by ...")
#   M3  faithful, dense                P   P   P   P   P   P   | pass
#   M4  faithful, bullet list +        P   P   P   P   P   P   | pass
#       four sentences
#   M5  heading only                   P   f   f   f   f   f   | pass
#   M6  faithful but RETROSPECTIVE     P   P   P   f   P   P   | pass
#       ("when you audit a landed
#       claim")
#   M7  top tier as INTENSITY          P   P   P   P   f   P   | pass
#       ("gets the most scrutiny")
#   M8  faithful, SILENT on            P   P   P   P   P   f   | pass
#       self-closure
#   M9  faithful, third voice          P   P   P   P   P   P   | pass
#   M10 hollow + factor-bearing        P   P   P   f   f   f   | pass
#       neighbouring prose
#   M11 faithful, imperative voice     P   P   P   P   P   P   | pass
#
# Four faithful variants — M3, M4, M9, M11, in four different voices — pass
# every red. Each of the four discriminators is INDIVIDUALLY NECESSARY: M6
# is rejected by section 4 alone, M7 by section 5 alone, M8 by section 6
# alone, and M1/M5 by sections 3a/3b alone. No red here is carried by another.
#
# THE WINDOW IS 400 CHARACTERS, and the mutants chose it rather than taste.
# The same-sentence grain for EVERYTHING was refuted by M4: a rule that names
# the two factors in a bulleted list and binds the timing four sentences later
# — an entirely faithful shape — failed section 4 at every width up to 240. A
# wide neighbourhood for EVERYTHING was refuted from the other side at 800,
# where at insertion point P3 the hollow mutants M1, M2, M5, M6 and M10 all
# PASSED section 4 on a `before ... commit` that belongs to the SURROUNDING
# prose, not to the rule. 400 and 600 produce identical verdicts on all twelve
# mutants at all three points; 400 is the tighter of the two equally-supported
# choices. Sections 3a and 3b are insensitive to the window across the whole
# swept range (240-800 identical), so the choice rests on section 4 alone —
# which is stated here rather than left implied, since a reader would otherwise
# assume all three cases contributed evidence.
#
# DECLARED LIMITATION. Mutant M10 — a hollow intensity instruction followed by
# unrelated prose that happens to carry "stakes" and "uncloseable" — passes 2a,
# 3a and 3b. A character window cannot tell a factor that GOVERNS the
# allocation from a factor word merely near it; only a syntactic reading could,
# and no regex performs one. The exposure is bounded rather than eliminated:
# M10 is still rejected by three of the six reds (sections 4, 5 and 6), so the
# suite as a whole refuses it, and the only prose that can satisfy 3a/3b
# hollowly is prose the implementation itself adds. Recorded here so a later
# hand reads it as a ruling rather than an oversight.
#
# BASELINE POLARITY — the anti-vacuity declaration
# ------------------------------------------------
#   red    — MUST fail before the rule lands. A check that already passes
#            verifies nothing, so its polarity is declared in the source and
#            the summary reports whether the declaration held.
#   guard  — green before AND after. Two kinds here: over-cut guards protecting
#            the rules this one is derived from, and VACUOUS-NOW guards
#            (sections 7, 8, 9) that pass today only because the subject text
#            does not exist yet, and bite the moment an implementation writes
#            it in the wrong voice, drags the record grammar into the law, or
#            copies the rule to a second rung. Their baselines are declared
#            honestly rather than counted as verification.
#
# The suite is therefore expected to exit 1 until the rule lands, with every
# `red` case failing and every `guard` case passing.
#
# Usage: bash ledger/gate/test_scrutiny_allocation.sh
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
# SCR — the scrutiny half. `scrutiny` is the record's word; attention, care and
# rigour are what a faithful rewrite reaches for, and the `how closely ...
# checked` form covers the phrasings that state the quantity without naming it
# as a noun. `attention` and `care` are each generic enough to be prose on
# their own, which is exactly why no case uses SCR unpaired.
SCR='(?:scrutin\w+|\battention\b|\bcare\b|rigou?r\w*|(?:verification|review|checking) effort|depth of (?:review|checking|verification|the check)|how (?:hard|closely|carefully)[^.]{0,40}(?:check|read|verif|review))'

# ALV — an allocation verb: the rule says scrutiny VARIES with something, it
# does not merely say scrutiny is good. `not every` and `the same` are here
# because the rule's most natural opening is the negative one — "not every
# claim earns the same scrutiny" — and a signature that only recognised the
# positive voice would measure phrasing.
ALV='(?:allocat\w+|apportion\w+|concentrat\w+|in proportion to|proportional\w*|proportionate\w*|\bscales?\b|\bscaled\b|\bscaling\b|graded (?:to|by)|ranks? each|rank\w* by|according to|determined by|\bearns?\b|\bearned\b|prioriti[sz]\w+|budget\w*|\bmore\b|\bless\b|uniform\w*|evenly|the same regardless|not every|the same\b)'

# ALLOC — the two halves inside one sentence, either order.
ALLOC="(?:${SCR}[^.]{0,80}${ALV}|${ALV}[^.]{0,80}${SCR})"

# STK — the stakes factor: what it costs to be wrong about the claim.
STK='(?:\bstakes?\b|cost(?:s)? of (?:being wrong|a miss|getting it wrong)|what it costs to be wrong|consequences? of (?:being wrong|error|a miss)|how much (?:rides|depends|turns) on|severity|blast radius|how costly)'

# UNC — the uncloseability factor: how far the claim sits beyond an evaluator
# that could settle it. Both spellings of the derived noun are admitted; the
# record uses one and an author is as likely to reach for the other.
UNC='(?:unclos\w+|hard(?:er|est)? to close|how hard[^.]{0,30}to close|difficult(?:y)? (?:to|of) clos\w+|cannot be closed|can never be closed|no evaluator (?:can )?clos\w+|nothing (?:downstream|later) can (?:catch|close)|resist\w* closure|closab\w+|closeab\w+|beyond (?:any )?clos\w+)'

# PRO — the prospective-binding half: the rule fires at authoring, not only at
# review. Bare `before` is deliberately ABSENT — core carries twelve of them
# ("before committing to a direction", "before drawing the boundary") and on
# its own it measures prose, not the rule. Every member here is multi-word.
PRO='(?:at the outset|up ?front|prospectiv\w+|in advance|ahead of[^.]{0,20}work|before[^.]{0,40}(?:work|begin|start|proceed|act\b|commit|dispatch|author|rely|relied)|when (?:you|a walk) (?:set|sets|state|states|author|authors|write|writes|make|makes)|as you (?:set|state|author|write|make)|at the point[^.]{0,30}(?:made|set|authored|stated)|not (?:only|merely|just) (?:at|after|in) (?:review|audit|the review|hindsight)|rather than (?:at|after) (?:review|audit))'

# TIER — the top of the ladder named as a POSITION. Bare `strongest` is absent:
# core already says "the strongest applicable evaluator" and "Hierarchy,
# strongest first" in Prime Invariant 1, which is one of the places the rule
# might plausibly be written, so the bare word would measure the neighbour.
TIER='(?:top(?:most)? (?:tier|rung|rank|of the ladder|of the scale)|highest (?:tier|rung|rank)|strongest (?:tier|rung|rank)|\btopmost\b|maximal|the maximum of|most consequential|the ceiling)'

# PRC — a named PROCEDURE. This is the discriminator against an intensity:
# "more scrutiny" is unfalsifiable, and the record's answer is a specific act —
# a fresh reader's produced understanding, plus the adversarial battery.
PRC='(?:probes?\b|probing|comprehension|fresh (?:reader|eyes|pair)|context-free read\w*|reads? back|states? back|reports? the understanding|adversarial batter\w+|\bbatter(?:y|ies)\b|produced understanding|independent read\w+)'

# SLF — the author of the claim is also the party who will satisfy it. This is
# the structural feature that made the terminal claim uncloseable by its own
# backing. `self-audit` is deliberately ABSENT: core's One-shot skepticism rule
# already contains "an adversarial self-audit of the work".
SLF='(?:closes? (?:its|their|your) own|(?:its|their|your) own (?:author|closer|judge)|authored by the (?:same|very) party|by the same party|the (?:same )?party (?:who|that) (?:will |must |would |is to )?(?:also )?(?:satisfy|satisfies|close|closes|meet|meets)|author (?:is|will be) also|author will also be|writer is also|sets? (?:its|their|your) own (?:bar|target|criteri\w+)|marking (?:your|its|their) own|judge in (?:your|its|their) own|graded by (?:its|their|your) own)'

# RSE — the consequence a self-authored claim carries. Naming the structure
# without naming what follows from it is an observation, not a rule.
RSE='(?:scrutin\w+|\btiers?\b|\brungs?\b|\branks?\b|escalat\w+|cannot close|does not close|never closes|unclos\w+|another party|a second party|outside[^.]{0,20}(?:review|party|author)|independent\w*|maximal|closeab\w+|closab\w+|own backing)'

# PRM — a permission modal ATTACHED TO THE ALLOCATION ACT. The bare-modal form
# tried first was refuted by the faithful mutants: M3 and M8 both say the claim
# "sits beyond any evaluator that COULD settle it", and a guard that trips on
# its own rule's most natural sentence is measuring phrasing. Pinning the modal
# to the act keeps the anti-pattern — "scrutiny MAY be allocated by ..." — and
# drops the false positive.
PRM='(?:(?:may|might|could|can) (?:be )?(?:allocat|apportion|concentrat|scrutini|prioriti|graded|scaled|earned|spent|given|applied|raised|increased)\w*|\boptionally\b|at your discretion|\bif useful\b|\bwhere useful\b|\bwhere helpful\b|\bis optional\b|\bare optional\b)'

# The two proximity grains (see TWO PROXIMITY GRAINS in the header).
#
#   SAME SENTENCE — `[^.]*` cannot cross a period, so both terms lie in one
#   period-free run. Used where the term must GOVERN the other: a permission
#   modal changes the rule's force only in its own sentence, a procedure
#   answers a tier only when it is stated as that tier's procedure, and a
#   consequence attaches to self-closure only when stated with it.
SS='[^.]*'
#   NEIGHBOURHOOD — a bounded character span that MAY cross sentence and list
#   boundaries. Used where the term merely ACCOMPANIES the allocation rule: a
#   faithful rule is free to name its factors in a bulleted list and bind its
#   timing several sentences later.
NB='.{0,400}'

RX_ALLOC="(?i)${ALLOC}"
RX_STAKES="(?i)(?:${ALLOC}${NB}${STK}|${STK}${NB}${ALLOC})"
RX_UNCLOSE="(?i)(?:${ALLOC}${NB}${UNC}|${UNC}${NB}${ALLOC})"
RX_PROSPECT="(?i)(?:${ALLOC}${NB}${PRO}|${PRO}${NB}${ALLOC})"
RX_TIERPROC="(?i)(?:${TIER}${SS}${PRC}|${PRC}${SS}${TIER})"
RX_SELF="(?i)(?:${SLF}${SS}${RSE}|${RSE}${SS}${SLF})"
RX_PERMISSION="(?i)(?:${SCR}${SS}${PRM}|${PRM}${SS}${SCR})"

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

# The identity anchor. Section 2b's "every surface" claim and section 9's
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
echo "SECTION 2 — Scrutiny is ALLOCATED, at the always-on rung"
echo "════════════════════════════════════════════════════════════════════════"
echo ""

# 2a. The rung ruling itself: the always-on law says scrutiny varies with
# something rather than being spread flat. This case is the ANCHOR, not a
# discriminator — mutant M5 (a heading and nothing else) satisfies it, and that
# is intended: sections 3-6 are what a heading cannot buy.
expect_count red core min 1 \
  "allocation: core says scrutiny varies rather than being uniform" \
  --regex "$RX_ALLOC"

# 2b. A rule that does not reach the composer would not have caught the failure
# it is written for. Stated as a separate case rather than inferred from 2a: 2a
# proves the text is in core, and this proves core's reach is intact for it
# across all 24 materialized prompts — the two are one condition only for as
# long as `HasCore` holds on every field, which is what section 1 verifies and
# not something this case should assume on its own.
expect_count red surfaces min 1 \
  "allocation: it reaches EVERY materialized surface (composer included)" \
  --regex "$RX_ALLOC"

# ══════════════════════════════════════════════════════════════════════════════
echo ""
echo "════════════════════════════════════════════════════════════════════════"
echo "SECTION 3 — Allocation is by the TWO FACTORS, named"
echo "════════════════════════════════════════════════════════════════════════"
echo ""
# "Scrutinise carefully" is not a rule — it names no quantity to allocate by,
# so no walk can be wrong about it. The record's answer is two factors, and
# each gets its own case so a half-implemented rule reports WHICH half is
# missing rather than a single undifferentiated failure. Both use the
# NEIGHBOURHOOD grain: a faithful rule is free to name its factors in a
# bulleted list under the sentence that introduces them, which mutant M4 does.

# 3a. Stakes — what it costs to be wrong about the claim. Without it, a rule
# allocates by difficulty alone and spends its deepest checking on whatever is
# hardest to verify rather than on whatever matters most to get right.
expect_count red core min 1 \
  "factors: the stakes — what it costs to be wrong" \
  --regex "$RX_STAKES"

# 3b. Uncloseability — how far the claim sits beyond an evaluator that could
# settle it. Without it, a rule allocates by consequence alone and gives its
# attention to high-stakes claims a test already closes, while the claims no
# gate can catch pass with the same glance as the rest. This is the factor the
# live defect turned on: the terminal claim was uncloseable by its author, and
# nothing downstream could have caught it.
expect_count red core min 1 \
  "factors: uncloseability — how hard the claim is to close" \
  --regex "$RX_UNCLOSE"

# ══════════════════════════════════════════════════════════════════════════════
echo ""
echo "════════════════════════════════════════════════════════════════════════"
echo "SECTION 4 — It binds BEFORE the load-bearing work, not only after"
echo "════════════════════════════════════════════════════════════════════════"
echo ""
# The failure was a TARGET SET AT THE OUTSET. A rule that fires only when a
# reviewer picks a claim up would not have caught it: by then the claim is the
# frame the review inherits rather than the thing the review questions. Mutant
# M6 is exactly that rule — faithful in every other respect, retrospective
# only — and this is the single case that rejects it.
expect_count red core min 1 \
  "timing: the rank is fixed at authoring, not only at review" \
  --regex "$RX_PROSPECT"

# ══════════════════════════════════════════════════════════════════════════════
echo ""
echo "════════════════════════════════════════════════════════════════════════"
echo "SECTION 5 — The top of the ladder names a PROCEDURE, not an intensity"
echo "════════════════════════════════════════════════════════════════════════"
echo ""
# "The top tier gets the most scrutiny" is unfalsifiable: no walk can show it
# complied and no auditor can show it did not. The record's answer is a
# specific act — a fresh reader's produced understanding, honestly labelled
# prior-shifting rather than evidence, plus the adversarial battery on the
# text. Mutant M7 is the intensity-voiced rule, and this is the single case
# that rejects it.
#
# SAME-SENTENCE grain, and unanchored from ALLOC on purpose: a faithful rule
# may state its top rank's procedure several sentences after the allocation
# itself (M3, M4 and M11 all do), while both halves of THIS pair must sit
# together or the procedure is not stated as that rank's procedure.
expect_count red core min 1 \
  "top rank: a named procedure closes it (probe, not 'more care')" \
  --regex "$RX_TIERPROC"

# ══════════════════════════════════════════════════════════════════════════════
echo ""
echo "════════════════════════════════════════════════════════════════════════"
echo "SECTION 6 — A claim its own author will satisfy is called out"
echo "════════════════════════════════════════════════════════════════════════"
echo ""
# The structural feature that made the terminal claim uncloseable: the party
# who set the bar was the party who would meet it, so the claim's backing was
# testimony from the one witness with an interest in it. A rule that ranks by
# stakes and uncloseability without naming this case leaves the exact defect
# that bit unclassified — mutant M8 is that rule, faithful in every other
# respect, and this is the single case that rejects it.
expect_count red core min 1 \
  "self-closure: author-is-satisfier is named with its consequence" \
  --regex "$RX_SELF"

# ══════════════════════════════════════════════════════════════════════════════
echo ""
echo "════════════════════════════════════════════════════════════════════════"
echo "SECTION 7 — It is an OBLIGATION, not a permission"
echo "════════════════════════════════════════════════════════════════════════"
echo ""
# VACUOUS AT THIS BASELINE and declared guard for that reason: with no
# allocation text in core there is nothing for a permission modal to govern, so
# it passes today without verifying anything. It bites the moment an
# implementation writes "scrutiny may be allocated by ..." — which is the most
# likely way to satisfy sections 2 and 3 while shipping the gap, and is mutant
# M2, the one mutant this guard trips on.
expect_count guard core eq 0 \
  "obligation: no permission modal governs the allocation" \
  --regex "$RX_PERMISSION"

# ══════════════════════════════════════════════════════════════════════════════
echo ""
echo "════════════════════════════════════════════════════════════════════════"
echo "SECTION 8 — The record GRAMMAR stays out of the law"
echo "════════════════════════════════════════════════════════════════════════"
# The allocation is POSTURE and binds every walk; the typed-claim grammar and
# the query that computes over it are PROCEDURE and bind only walks that write
# or hold a graded corpus. The sibling discipline suite already rules that
# grammar to the record-writing rungs, and the risk this guard covers is
# specific: an implementation writing the top rank's procedure has every reason
# to reach for the backing vocabulary while doing it, and would put procedure
# in the law whatever else it got right.
#
# Every case here is VACUOUS AT THIS BASELINE — none of these tokens is in core
# today — and all are declared guard for that reason.
echo ""
for token in \
  'grade::' \
  'derives-from::' \
  'discharge::' \
  'closer::' \
  'entries_query.ncl' \
  'extract_entries.py' \
; do
  expect_count guard core eq 0 \
    "grammar: '$token' absent from core (procedure stays out of the law)" \
    --needle "$token"
done

# ══════════════════════════════════════════════════════════════════════════════
echo ""
echo "════════════════════════════════════════════════════════════════════════"
echo "SECTION 9 — One rung, one statement (no second copy at a lower rung)"
echo "════════════════════════════════════════════════════════════════════════"
# Core reaches all 24 surfaces, so a module or persona that also states the
# rule makes the walker read it twice in one prompt — the defect class the
# conditioning-discipline pass exists to remove.
#
# These two guards use the FACTOR-PAIR signature rather than the bare ALLOC
# anchor, and the reason is a measurement, not a preference: RX_ALLOC already
# returns 1 on both composer surfaces at this baseline, on the composer
# persona's own sentence "spends the exact attention the role exists to
# conserve — the same defect as guessing" (`attention` inside eighty
# characters of `the same`). A guard that is red before the edit is not a
# guard. RX_STAKES returns 0 on every delta in both scopes, and a genuine
# second copy of the rule carries the factors with it.
#
# VACUOUS AT THIS BASELINE, hence guard. Strike these two if the architect
# rules a rung needs its own elaboration of the allocation — the composer at
# campaign CLOSE is the plausible candidate.
echo ""
expect_count guard agents-delta eq 0 \
  "one statement: no second copy in any dispatched-role delta" \
  --regex "$RX_STAKES"
expect_count guard composer-delta eq 0 \
  "one statement: no second copy in the composer delta" \
  --regex "$RX_STAKES"

# ══════════════════════════════════════════════════════════════════════════════
echo ""
echo "════════════════════════════════════════════════════════════════════════"
echo "SECTION 10 — Over-cut guards: the rules this one is derived from survive"
echo "════════════════════════════════════════════════════════════════════════"
# Genuinely green at BOTH baselines — unlike sections 7, 8 and 9, these three
# measure text that exists today. This rule is the retrospective read-out of
# the evaluator hierarchy and the per-claim sibling of the per-task ceremony
# rule; an implementation could rewrite either on its way past, and collapsing
# one of them INTO the new rule would look like tightening while removing a
# rung the new rule depends on.
echo ""
expect_count guard core min 1 \
  "survives: the Verification Dual that this rule projects" \
  --needle '**The Verification Dual — verify, then trust.**'
expect_count guard core min 1 \
  "survives: the evaluator hierarchy the ranks are drawn from" \
  --needle 'Hierarchy, strongest first'
expect_count guard core min 1 \
  "survives: the per-task ceremony rule this one sits beside" \
  --needle '## Focus before ceremony'

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
