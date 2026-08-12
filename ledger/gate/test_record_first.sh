#!/usr/bin/env bash
# ledger/gate/test_record_first.sh
#
# Acceptance suite for the composer's RECORD-FIRST ordering: the record is the
# conductor's first-order task, conversational output is minimal and is drift
# potential, and prose to the head is warranted when the head approaches
# conversationally rather than as a running commentary on work in flight.
#
# WHAT IS ALREADY SHIPPED, AND WHY THIS SUITE STILL HAS FOUR REDS
# ---------------------------------------------------------------
# The ORDERING ITSELF IS ALREADY IN THE COMPOSER SURFACE and is not a gap. The
# persona's seven-rule discipline opens with, verbatim:
#
#     1. **Write, then report.** The ledger write happens first; the report is
#        generated from what was written. Never the reverse order, which
#        produces prose that the record must then chase.
#
# Measured, not recalled: `Write, then report` counts 1 in BOTH composer
# surfaces pre-edit (min=1 max=1 over 2 units), as do `The ledger write happens
# first`, `Report at junctures, not at events`, and `Cite the record; do not
# reproduce it`. A red asserting "an ordering is stated" would therefore be
# GREEN before the edit, and a check that already passes verifies nothing. That
# requirement is carried here as an OVER-CUT GUARD (section 6), not as a red,
# and mutant M15 — today's shipped ordering inserted verbatim as if it were the
# whole rule — is measured against every red and rejected by all five.
#
# The live defect is not that the ordering is missing. It is that the ordering
# is stated WITHOUT ITS GROUND and without a bound on the prose it competes
# with, and it was traded away under time pressure twice in one campaign. A
# rule whose reason is unstated is a rule the next reader discounts, so the
# reds here pin the parts that are absent — the bound and its occasion, the two
# grounds — and pin them TO the ordering that already exists (section 4a), so
# the ground cannot land in some unrelated corner of the persona.
#
# WHAT IS SWEPT — the materialized install, never the .ncl sources.
# ------------------------------------------------------------------
# Same technique and same engine as test_conditioning_discipline.sh,
# test_report_fraction.sh, test_scrutiny_allocation.sh and
# test_open_surface.sh: run `conditioning/install.sh --harness all` into a
# throwaway HOME and measure the OUTPUT tree. A source grep cannot see what
# composition does, and this suite's central claim is a claim about REACH — the
# rule present in one composed surface and absent from twenty-two others — which
# is a statement about the composed prompts and about nothing else.
#
# THE RUNG, AND WHY — and here the argument INVERTS its siblings'
# ---------------------------------------------------------------
# The rule goes at the PERSONA rung (`conditioning/personas/composer.ncl`), NOT
# in the always-on law. The three sibling suites place their rules in core, and
# their argument was re-read at `conditioning/compose.ncl` rather than taken on
# their word. It holds, verbatim:
#
#     composer | HasCore = compose [council_render] personas.composer
#
# The composer receives core, the rendered constitution table, and its own
# persona — NOT `dispatched`, NOT `producer`, NOT `council_module`. Every other
# role receives `dispatched`. That single line supports BOTH conclusions,
# because it says two things at once:
#
#   * core is the only rung the conductor SHARES with the walks it dispatches
#     — which is why a rule binding every walk must sit there; and
#   * `personas/composer.ncl` is the only rung the conductor does NOT share
#     with them — which is why a rule binding ONLY the conductor must sit HERE.
#     There is no third option: the composer pulls no module at all.
#
# A rule that binds one role has the OPPOSITE requirement to one that binds
# every walk, so it takes the other half of the same fact. Three further
# reasons, the first two checked against the shipped text rather than asserted:
#
#   1. THE RULE'S SUBJECT IS FALSE OF THE OTHER TWENTY-TWO SURFACES. "The
#      composer's first-order task is the record" and "composer coherence is
#      upstream of every walk it dispatches" are both claims about the
#      conductor. A dispatched walk's first-order task is its artifact, and it
#      dispatches nothing for its coherence to be upstream of. At core the
#      rule would reach 24 prompts to bind 2.
#   2. THE OCCASION DOES NOT EXIST FOR A DISPATCHED WALK. "Prose to the head is
#      warranted when the head approaches conversationally" presumes a head
#      channel. `conditioning/modules/dispatched.ncl` — carried by every role
#      except the composer — says the opposite in its opening bullets: "No
#      human is at your console... asking 'the user' for confirmation is asking
#      nobody" and "The composer is the ONLY channel to the head". A core-rung
#      occasion clause would contradict a module 22 of 24 surfaces carry.
#   3. THE GENERIC FORM IS ALREADY IN CORE AND ALREADY REACHES EVERYONE.
#      "## Minimal representation" bounds output for every walk on the same
#      drift ground ("unjustified prose is drift surface"), and "## Outcome-first
#      communication" governs report shape. This rule is that rule's
#      ROLE-SPECIFIC specialization. Restating the specialization at the rung
#      that already carries the general form makes the walker read a rule and
#      its one-role special case in the same segment — the double-carry the
#      conditioning-discipline pass exists to remove.
#
# THE REACH CASE IS THE INVERSE OF THE SIBLINGS', which is the interesting half
# of this suite. Theirs assert presence in `core` and in every one of the 24
# materialized `surfaces`, with the deltas guarded empty. This one asserts:
#
#   PRESENT  in `composer-delta` — the composer surfaces with their core region
#            excised. Presence in a DELTA cannot be satisfied by text living in
#            core, so this is what proves persona-rung placement rather than
#            core reach. Mode `min` over both units, so BOTH composer surfaces
#            (the Claude output style and GEMINI.md) must carry it — the two
#            files the install writes the composer prompt into.
#   ABSENT   from `core` (4b) — it is not in the always-on law; and
#   ABSENT   from every `agents-delta` (4c) — no dispatched role restates it.
#
# 4b and 4c are the halves that make the rung ruling FALSIFIABLE rather than
# decorative: without them "at the persona rung" would be satisfied by a rule
# written at BOTH rungs. Both are declared guard, because absence is trivially
# true before the edit; they bite the moment an implementation broadcasts the
# rule to all 24 prompts.
#
# THIS SUITE'S SCOPE *IS* ITS RUNG RULING. Unlike the siblings — which could
# isolate a placement ruling to one case ("strike THIS case, not the rung") —
# every red here is scoped to `composer-delta`, so the ruling is not separable
# from the measurement. If the architect overturns it and rules core, the
# amendment is mechanical and total: rescope sections 2–4a from
# `composer-delta` to `core`, and invert 4b/4c into a presence case over
# `surfaces`. Stated here so the overturn is a rewrite with a known shape
# rather than a discovery.
#
# WHAT THIS SUITE DELIBERATELY DOES NOT PIN
# -----------------------------------------
#   * THE SECTION AND ANY HEADING. The persona already holds two plausible
#     homes — the seven-rule discipline under "You hold the synthesis pen", and
#     "Your output is a view; the record is the source" directly above it — and
#     an implementation that extends either is as faithful as one that opens a
#     section. Pinning a heading would be this suite guessing at layout and
#     calling the guess a ruling.
#   * THE FRAMING WORDS. "First-order task", "drift potential", "upstream" are
#     the head's vocabulary, not phrases the shipped text owes a reader. Every
#     signature is an alternation precisely so a rule that binds the same thing
#     in its own words passes; seven faithful variants in seven voices are
#     measured below.
#   * THE MECHANISM, and section 5/6 of the siblings is ABSENT here for a
#     measured reason rather than an omission — see MEASURED EXCLUSIONS (5).
#
# VACUITY — how each case avoids measuring the author instead of the rule
# ----------------------------------------------------------------------
# A bare presence check for "the record comes first" passes the moment anyone
# writes the phrase — and here it would pass on text that SHIPPED MONTHS AGO.
# Every signature is built from ALTERNATIONS joined by ORDER-FREE PROXIMITY:
#
#   BOUND     = head-facing output within a NEIGHBOURHOOD of a bound
#   OCCASION  = a conversational-approach term in the same SENTENCE as a
#               warrant/timing term
#   DRIFT     = head-facing output within a NEIGHBOURHOOD of a drift term
#   UPSTREAM  = a propagation term in the same SENTENCE as the dispatched walks
#   ONERULE   = the shipped ORDERING within a NEIGHBOURHOOD of either ground
#   PERMISSION= a permission modal over the obligation's OWN verbs
#
# Order-free in the two-branch form `A<window>B|B<window>A` rather than the
# lookahead form, following the scrutiny sibling's measurement: over prompts
# this size the lookahead form re-tries the alternation at every window offset
# at every position and does not finish.
#
# MEASURED EXCLUSIONS — dropped by counting, not by taste
# -------------------------------------------------------
#   1. `never the reverse` is ABSENT from the ORDERING alternation, though the
#      composer's own rule ends with "Never the reverse order". It counts 1 in
#      the rendered core, on the three-stores clause "the recorder may cite the
#      repo and the forge (public, durable); never the reverse" — and the
#      core-absence guard (4b) is a statement about the ORDERING half being
#      absent from core, so admitting a core-side match would spend the guard's
#      whole margin. It costs nothing measurable: the composer delta still
#      carries three ORDERING hits without it.
#   2. Bare `drift`/`drifts` is ABSENT from the drift alternation, and it is the
#      word a reader would most expect there. It counts 10 in core, 3 in the
#      COMPOSER DELTA PRE-EDIT ("Over-convening a settled leaf edit is its own
#      drift", "an unrecorded process change is composer drift"), and 3 in the
#      widest agent delta. A DRIFT red admitting it is GREEN BEFORE THE EDIT.
#      The compound forms (`drift potential`, `drift surface`, `source of
#      drift`, `invites drift`, …) all count 0 in the composer delta.
#   3. Bare `downstream` is ABSENT from the propagation alternation: it counts 1
#      in the composer delta pre-edit, on the T4 "downstream pivot" trigger.
#      Only `downstream of you|the composer|it` is admitted.
#   4. `suffices` was tried in the bound alternation and dropped: 1 in the
#      composer delta pre-edit, on "where a summary-level read suffices".
#   5. THE SIBLINGS' "MECHANISM STAYS OUT OF THE LAW" SECTION IS ABSENT, and the
#      measurement is the reason. Those suites guard core clear of the
#      typed-claim grammar; at THIS rung the grammar is the composer's own
#      discipline — `grade::`, `signer::` and `derives-from::` each count 1 in
#      the composer delta today, so the guard would be red at baseline and
#      would be asserting the opposite of the shipped design. `entries_query.ncl`
#      and `extract_entries.py` do count 0, but a guard over two tokens no
#      implementation of THIS rule would reach for buys nothing, so the section
#      is dropped rather than padded to look like its siblings.
#
# A DECLARED NEAR-MISS. The composer delta carries "the pen question was
# upstream > of the output question" inside a blockquote, and the `> ` marker
# survives normalization, so the phrase `upstream of` measures 0 there today.
# That is an accident of layout, not a property of the rule, so the UPSTREAM
# case never rests on `upstream of` alone: it is paired, same-sentence, with a
# term naming THE DISPATCHED WALKS, and that quote names "the output question".
# Recorded so that reflowing the quote is read as a non-event rather than a
# regression.
#
# THE MUTANT TABLE — twenty shapes at three insertion points
# ----------------------------------------------------------
# Every candidate was measured against mutants of the REAL rendered composer
# delta, at THREE insertion points each the worst case for a different
# neighbouring vocabulary: P1 immediately after the seven-rule discipline
# (`report`, `record`, `ledger` dense), P2 after the ceremony-scaling section
# (`drift`, `proportionality` dense), P3 before "You hold outsized power"
# (`dispatch`, `convene` dense). `P` = the case passes. Every verdict below is
# IDENTICAL at all three insertion points.
#
#   mutant                              2a   2b   3a   3b   4a  | PRM-guard
#   M0  pre-edit (no rule)               f    f    f    f    f  | pass  <- baseline
#   M1  hollow ("keep it short")         P    f    f    f    f  | pass
#   M2  permission voice throughout      P    P    P    P    P  | TRIPS
#   M3  faithful, dense                  P    P    P    P    P  | pass
#   M4  faithful, bulleted               P    P    P    P    P  | pass
#   M5  heading only                     f    f    f    f    f  | pass
#   M6  ordering + drift, no upstream    P    P    P    f    P  | pass
#   M7  ordering + upstream, no drift    P    P    f    P    P  | pass
#   M8  grounds only, no ordering        P    P    P    P    f  | pass
#   M9  bound with no occasion           P    f    P    P    P  | pass
#   M10 faithful, imperative voice       P    P    P    P    P  | pass
#   M11 faithful, third-person voice     P    P    P    P    P  | pass
#   M12 faithful, terse                  P    P    P    P    P  | pass
#   M13 hollow + bearing prose           P    f    P    P    f  | pass
#   M14 two rules, stated far apart      P    P    P    P    f  | pass
#   M15 SHIPPED ordering, verbatim       f    f    f    f    f  | pass
#   M16 faithful, should/must voice      P    P    P    P    P  | pass
#   M17 faithful, "may be warranted"     P    P    P    P    P  | pass
#   M18 permission over the ORDERING     P    P    P    P    P  | TRIPS
#   M19 faithful but output unbounded    f    P    P    P    P  | pass
#
# SEVEN faithful variants in seven voices — M3, M4, M10, M11, M12, M16, M17 —
# pass every red. Each red is INDIVIDUALLY NECESSARY, and one mutant isolates
# each: M19 is rejected by 2a alone, M9 by 2b alone, M7 by 3a alone, M6 by 3b
# alone, M8 and M14 by 4a alone. No red here is carried by another.
#
# M15 IS THE LOAD-BEARING ROW. It inserts the shipped "Write, then report" rule
# verbatim, as though it were the whole of this rule, and it fails all five
# reds — which is what earns the claim that these reds measure the gap rather
# than the text that has been in the surface since `d7a16f5`.
#
# THE PERMISSION GUARD AND THE TRAP IT WAS BUILT AROUND. The bare-modal form
# was tried first and M17 refuted it: "Prose to the head MAY be warranted when
# the head approaches conversationally" is not merely faithful, it is the
# rule's own most natural sentence — the rule GRANTS a permission for prose
# while OBLIGING an ordering. A guard that trips there measures the author. The
# modal is therefore pinned to the OBLIGATION's own verbs (`come before`,
# `precede`, `written first`, `reported`, `deferred`, `skipped`, `kept
# minimal/short/brief/terse`), which keeps the anti-patterns — M2's "the record
# may come before the report" and M18's "the ledger write may be deferred until
# the report is sent" — and drops the false positive.
#
# TWO PROXIMITY GRAINS, each chosen by refutation
# -----------------------------------------------
# NEIGHBOURHOOD wherever the term merely ACCOMPANIES; SAME SENTENCE wherever it
# must GOVERN.
#
#   * NEIGHBOURHOOD for 2a, 3a and 4a: at the same-sentence grain the bulleted
#     faithful rule M4 fails 4a outright — it states the ordering in one bullet
#     and its ground in the next — and M19 fails 3a, which names the output in
#     one sentence and calls it drift potential in another.
#   * SAME SENTENCE for 2b's pair and 3b's pair, because both are governance
#     claims. The occasion must govern the warrant, and the propagation must
#     govern the walks; a widened grain lets a warrant term two sentences away
#     supply the occasion, which is how a bound with no occasion (M9) would
#     pass a case built to reject it.
#
# THE WINDOW IS 320 CHARACTERS, and the mutants bound it from both sides.
# Sweeping 40 → 2400, verdicts are CONSTANT across 220–400 and break outside
# it on both edges:
#
#   * Below 220 faithful variants start failing. M4's 4a is the last to clear,
#     between 180 and 220; M19's 3a needs 180; M3's, M12's and M14's 4a need
#     100.
#   * At 500 the co-location case stops doing its job: M14 — both grounds and
#     the ordering present but stated a page apart — goes from rejected to
#     insertion-point-dependent on 4a.
#   * At 1000 the BOUND red goes GREEN ON THE PRE-EDIT DELTA (M0 passes 2a),
#     which would make it not a red at all.
#
# 320 is the middle of the 220–400 plateau, roughly 1.5x the faithful floor and
# 1.5x under the first false acceptance. Within the plateau the evidence does
# not choose between 220, 240, 320 and 400 — the tables are byte-identical —
# and that is stated here rather than left implied.
#
# DECLARED LIMITATION. Mutant M13 — the hollow "keep the conversational output
# short" followed by unrelated prose that happens to carry "drift surface" and
# "upstream of every walk you dispatch" — passes 3a and 3b. A character window
# cannot tell a ground that BINDS the rule from ground vocabulary merely near
# it; only a syntactic reading could, and no regex performs one. The exposure is
# bounded rather than eliminated: M13 is still rejected by 2b and 4a, so the
# suite as a whole refuses it, and the only prose that can satisfy 3a/3b
# hollowly is prose the implementation itself adds. Recorded here so a later
# hand reads it as a ruling, not an oversight.
#
# A SECOND, NARROWER BOUND. Case 4a proves the ground sits near the ORDERING,
# not that the implementation did not ALSO leave a second ungrounded copy of
# the ordering elsewhere in the persona. That is the right grain for the
# question 4a asks, but it is a bound, and it is named rather than left for a
# reader to discover.
#
# BASELINE POLARITY — the anti-vacuity declaration
# ------------------------------------------------
#   red    — MUST fail before the rule lands. A check that already passes
#            verifies nothing, so its polarity is declared in the source and
#            the summary reports whether the declaration held.
#   guard  — green before AND after. Two kinds here: VACUOUS-NOW guards (4b, 4c,
#            section 5) that pass only because the subject text does not exist
#            yet and bite the moment an implementation broadcasts the rule to
#            core or to the dispatched roles, or writes it in the permissive
#            voice; and OVER-CUT guards (section 6) that measure text shipped
#            today — including the ordering clause this suite refuses to claim
#            as a red. Their baselines are declared honestly rather than
#            counted as verification.
#
# The suite is therefore expected to exit 1 until the rule lands, with every
# `red` case failing and every `guard` case passing.
#
# Usage: bash ledger/gate/test_record_first.sh
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
# PRS — the OUTPUT this rule bounds: what the conductor says to the head, as
# distinct from what it writes to the record. The conversational or head-facing
# qualifier is mandatory in every member. Bare `report`/`output` were tried and
# are unusable: the composer delta carries dozens of each, most of them about
# the LEDGER side of the very ordering this rule states, so a case built on them
# would count the rule's own subject matter as its own satisfaction.
PRS='(?:conversational output|conversational (?:prose|reply|response|turn|text)|prose to the head|output to the head|user-facing output|what you (?:say|write|tell) (?:to )?the head|your (?:conversational )?prose|talking to the head|head-facing (?:output|prose|text)|what reaches the head)'

# BND — the bound. "Minimal" is the head's word; brief, terse, sparing, short,
# bounded and "not an essay" are what a faithful rewrite reaches for, and the
# last of those is already the persona's own idiom for the same idea one rule
# down. `suffices` was tried and dropped by measurement (see MEASURED
# EXCLUSIONS 4).
BND='(?:\bminimal\b|\bminimum\b|\bminimis\w+|\bminimiz\w+|\bbrief\b|\bterse\b|\bsparing\w*|\bbounded\b|not an essay|as little as|\bshort\b|kept (?:short|to)|no more than|\bfewest words\b|pared (?:down|back))'

# DRF — output as drift. This is the first of the two grounds, and it is the
# one the law already states generically: core's "## Minimal representation"
# opens "unjustified prose is drift surface like unjustified code", so
# `drift surface` is admitted as the phrasing a faithful author is most likely
# to echo. See MEASURED EXCLUSIONS 2 for why the bare word is not.
DRF='(?:drift potential|drift surface|source of drift|invites? drift|\bis drift\b|becomes drift|risk of drift|drift risk|where drift enters|drift-prone|is itself drift|a vector for drift|room for drift|breeds drift)'

# PRP — propagation: the composer's state travelling outward. See the DECLARED
# NEAR-MISS on `upstream of`; every use of PRP is paired with DSP.
PRP='(?:upstream of|propagat\w+|reaches (?:every|each|all)|flows? (?:down|in)?to (?:every|each|all)|inherited by (?:every|each)|carried into (?:every|each)|shows up in (?:every|each)|is felt (?:by|in) (?:every|each)|compounds? (?:through|across)|downstream of (?:you|the composer|it))'

# DSP — the things downstream: the walks the conductor dispatches. This is what
# makes 3b a claim about the CONDUCTOR's coherence rather than about
# propagation in general — a rule that says drift propagates without saying
# into what has named no consequence.
DSP='(?:every walk (?:you|it) dispatch\w*|the walks (?:you|it) dispatch\w*|every dispatch\w*|each dispatch\w*|every (?:sub)?agent you (?:launch|dispatch|send)|all the work below|everything below you|every node|the whole campaign|every walk)'

# OCC — the occasion: the head arriving conversationally. `conversational`
# counts 0 in both composer deltas pre-edit (and 1 in core, on Invariant 5's
# "a trivial or conversational turn", which the delta scope excises).
OCC='(?:conversational\w*|in conversation|converses?|a conversation|the head (?:approaches|opens|asks|starts)|opens conversationally)'

# WRT — the warrant or the timing that governs it. This is 2b's discriminator
# against a vague call for brevity: a bound with no occasion tells a walk to be
# short and never tells it when prose is the right answer.
WRT='(?:warrant\w*|justif\w*|earns? (?:its|a)|is for\b|belongs|called for|appropriate|the occasion|reserved for|only when|when the head|approach\w*|once work)'

# ORD — the ORDERING, which is the half already shipped. A short modal gap is
# tolerated (`record (?:\w+ ){0,3}written first`) so that "the record must be
# written first" and "the record may be written first" both register as the
# ordering — measuring its PRESENCE is ORD's job, and measuring its FORCE is
# the permission guard's. `never the reverse` is excluded by measurement (1).
ORD='(?:write,? then report|record (?:\w+ ){0,3}written first|writes? the record first|record (?:comes|goes) first|\brecord first\b|write happens first|precedes the report|report is generated from what was written|first-order task is the record|record before (?:the )?report|before (?:you )?report\b|ledger (?:write|entry) (?:comes |happens )?first)'

# PRM — a permission modal over the OBLIGATION's own verbs. See THE PERMISSION
# GUARD AND THE TRAP IT WAS BUILT AROUND: the bare-modal form was refuted by a
# faithful mutant, because this rule legitimately PERMITS prose on an occasion
# while OBLIGING an ordering.
PRM='(?:(?:may|might|could|can) (?:be )?(?:come before|precede|written first|reported|deferred|skipped|kept (?:minimal|short|brief|terse))|\boptionally\b|at your discretion|\bif useful\b|\bwhere useful\b|\bwhere helpful\b|\bis optional\b|\bare optional\b|as you see fit)'

# The two proximity grains (see TWO PROXIMITY GRAINS in the header).
#
#   SAME SENTENCE — `[^.]*` cannot cross a period, so both terms lie in one
#   period-free run. Used where the term must GOVERN the other: the occasion
#   governs the warrant, and the propagation governs the walks.
SS='[^.]*'
#   NEIGHBOURHOOD — a bounded span that MAY cross sentence and list boundaries.
#   Used where the term merely ACCOMPANIES: a faithful rule names the output in
#   one sentence or bullet and bounds or grounds it in the next.
NB='.{0,320}'

UPSTREAM_PAIR="(?:${PRP}${SS}${DSP}|${DSP}${SS}${PRP})"
GROUND="(?:${DRF}|${UPSTREAM_PAIR})"

RX_BOUND="(?i)(?:${PRS}${NB}${BND}|${BND}${NB}${PRS})"
RX_OCCASION="(?i)(?:${OCC}${SS}${WRT}|${WRT}${SS}${OCC})"
RX_DRIFT="(?i)(?:${PRS}${NB}${DRF}|${DRF}${NB}${PRS})"
RX_UPSTREAM="(?i)${UPSTREAM_PAIR}"
RX_ONERULE="(?i)(?:${ORD}${NB}${GROUND}|${GROUND}${NB}${ORD})"
RX_PERMISSION="(?i)${PRM}"

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

# The identity anchor, and this suite leans on it harder than its siblings do.
# EVERY red here is measured on a DELTA — a surface with its core occurrence
# excised — so if the core region were not a verbatim single occurrence, the
# excision would be wrong and every measurement below would be meaningless
# rather than merely imprecise. Guard, because a regression here invalidates
# the measurements rather than reporting a rule that did not land.
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
echo "SECTION 2 — Conversational output is BOUNDED, on a stated OCCASION"
echo "════════════════════════════════════════════════════════════════════════"
echo ""

# 2a. THE BOUND. The shipped rule bounds a REPORT ("not an essay", "at
# junctures, not at events") and says nothing about the running conversational
# prose that displaced the record for an entire campaign. Mutant M19 is the
# rule that states the ordering, both grounds and the occasion and never bounds
# the output, and this is the single case that rejects it.
expect_count red composer-delta min 1 \
  "bound: conversational output to the head is held to a minimum" \
  --regex "$RX_BOUND"

# 2b. THE OCCASION, and this is what separates the rule from a call for
# brevity. "Be concise" tells a walk nothing it can be shown to have failed;
# "prose is warranted when the head approaches conversationally, and the record
# is written first once work is underway" names the two states and assigns each
# an answer. Mutant M9 bounds the output faithfully and names no occasion; this
# is the single case that rejects it.
#
# SAME-SENTENCE grain: the occasion must GOVERN the warrant. At the
# neighbourhood grain a warrant term elsewhere in the paragraph supplies it,
# and M9 passes a case built to reject it.
expect_count red composer-delta min 1 \
  "occasion: prose is warranted when the head approaches conversationally" \
  --regex "$RX_OCCASION"

# ══════════════════════════════════════════════════════════════════════════════
echo ""
echo "════════════════════════════════════════════════════════════════════════"
echo "SECTION 3 — The GROUND is named, on both of its halves"
echo "════════════════════════════════════════════════════════════════════════"
echo ""

# 3a. OUTPUT IS DRIFT POTENTIAL. The ordering shipped without this and was
# traded away twice under time pressure, which is the whole argument for
# pinning it: a rule that reads as a filing preference loses to the felt need
# to explain, and a rule that names output as drift surface does not. Core
# already states the general form for every walk ("unjustified prose is drift
# surface like unjustified code"); this is the conductor's case of it. Mutant
# M7 is faithful in every other respect and silent here; this is the single
# case that rejects it.
expect_count red composer-delta min 1 \
  "ground: head-facing output is named as drift potential" \
  --regex "$RX_DRIFT"

# 3b. COMPOSER COHERENCE IS UPSTREAM. The second half, and the one that makes
# the first non-arbitrary: the conductor's prose is not merely wasteful, it is
# the input every dispatched walk is conditioned from, so incoherence here is
# not contained here. A rule that says output is drift without saying what the
# drift reaches has named a cost with no blast radius. Mutant M6 is faithful in
# every other respect and silent here; this is the single case that rejects it.
#
# SAME-SENTENCE grain: the propagation must GOVERN the walks, not merely sit
# near a mention of dispatching — and the composer delta mentions dispatching
# constantly.
expect_count red composer-delta min 1 \
  "ground: the conductor's coherence is upstream of the walks it dispatches" \
  --regex "$RX_UPSTREAM"

# ══════════════════════════════════════════════════════════════════════════════
echo ""
echo "════════════════════════════════════════════════════════════════════════"
echo "SECTION 4 — ONE rule at ONE rung: the composer surface, and nowhere else"
echo "════════════════════════════════════════════════════════════════════════"
echo ""

# 4a. THE GROUND IS ATTACHED TO THE ORDERING — and this case is also the
# PRESENCE half of the inverse reach claim, which is why it is scoped to the
# composer DELTA in `min` mode: a delta cannot be satisfied by text living in
# core, so passing here proves persona-rung placement, and `min` over both
# units proves BOTH composer surfaces carry it (the Claude output style and
# GEMINI.md — the two files the install writes the composer prompt into).
#
# Sections 2 and 3 prove the bound, the occasion and both grounds are present;
# none of them proves the grounds belong to the ordering. A reader who meets
# "write, then report" in one section and "output is drift potential" three
# pages later has been handed two rules and will honour the cheaper one —
# which is the failure this whole node exists for. Mutant M8 states both
# grounds faithfully and never states the ordering; M14 states everything
# faithfully as two rules a page apart; this is the single case that rejects
# both.
expect_count red composer-delta min 1 \
  "one rule: the ground is stated with the ordering, on both composer surfaces" \
  --regex "$RX_ONERULE"

# 4b. ABSENT FROM THE ALWAYS-ON LAW. The inverse of the siblings' reach case,
# and the half that makes the rung ruling falsifiable: without it, "at the
# persona rung" would be satisfied by a rule written at BOTH rungs, and the
# 22 dispatched prompts would each carry a rule about a head channel they do
# not have and a downstream they do not dispatch to.
#
# VACUOUS AT THIS BASELINE and declared guard for that reason — the ordering
# alternation counts 0 in the rendered core today, so nothing is being verified
# until an implementation writes something. It bites the moment one broadcasts
# the rule to all 24 prompts.
expect_count guard core eq 0 \
  "rung: absent from the always-on law (it binds one role, not every walk)" \
  --regex "$RX_ONERULE"

# 4c. ABSENT FROM EVERY DISPATCHED ROLE. The same claim measured from the other
# side, and not implied by 4b: a rule could be kept out of core and still be
# copied into the worker, reviewer and seat deltas one at a time. Twenty-two
# units, `eq 0` on each.
#
# VACUOUS AT THIS BASELINE, hence guard. Strike 4b and 4c together, not
# separately, if the architect overturns the rung — and see THIS SUITE'S SCOPE
# *IS* ITS RUNG RULING for what else that overturn requires.
expect_count guard agents-delta eq 0 \
  "rung: absent from every dispatched-role delta (worker, reviewer, seat)" \
  --regex "$RX_ONERULE"

# ══════════════════════════════════════════════════════════════════════════════
echo ""
echo "════════════════════════════════════════════════════════════════════════"
echo "SECTION 5 — It is an OBLIGATION, not a permission"
echo "════════════════════════════════════════════════════════════════════════"
echo ""
# The anti-pattern is specific and it is the likeliest way to satisfy sections
# 2–4 while shipping the gap: "the record may come before the report" (M2) and
# "the ledger write may be deferred until the report is sent" (M18) both read
# as the rule and bind nobody. The modal is pinned to the obligation's own
# verbs so that the rule's OWN permission — prose to the head, on its occasion
# — is not mistaken for the anti-pattern; mutant M17 is that sentence, and this
# guard passes on it.
#
# VACUOUS AT THIS BASELINE and declared guard for that reason: the alternation
# counts 0 in both composer deltas today, so it verifies nothing until an
# implementation writes the rule.
expect_count guard composer-delta eq 0 \
  "obligation: no permission modal governs the record-first duties" \
  --regex "$RX_PERMISSION"

# ══════════════════════════════════════════════════════════════════════════════
echo ""
echo "════════════════════════════════════════════════════════════════════════"
echo "SECTION 6 — Over-cut guards: the shipped ordering and its siblings survive"
echo "════════════════════════════════════════════════════════════════════════"
# Genuinely green at BOTH baselines — unlike 4b, 4c and section 5, these measure
# text that exists today. The first is the requirement this suite refuses to
# carry as a red, held here in the only honest form available to it: the
# ordering is ALREADY STATED, so the risk this node introduces is not that it
# will be missing but that an implementation adding the ground will rewrite the
# rule it is grounding, or fold the surrounding discipline into the new text
# and call the loss tightening.
echo ""
expect_count guard composer-delta min 1 \
  "survives: the shipped ordering itself (the requirement that is not a red)" \
  --needle 'Write, then report'
expect_count guard composer-delta min 1 \
  "survives: the ordering's operative clause" \
  --needle 'The ledger write happens first'
expect_count guard composer-delta min 1 \
  "survives: the section the ordering is grounded in" \
  --needle 'Your output is a view; the record is the source'
expect_count guard composer-delta min 1 \
  "survives: the seven-rule discipline the ordering opens" \
  --needle 'The discipline, seven rules'
expect_count guard composer-delta min 1 \
  "survives: report at junctures, not at events" \
  --needle 'Report at junctures, not at events'
expect_count guard composer-delta min 1 \
  "survives: cite the record, do not reproduce it" \
  --needle 'Cite the record; do not reproduce it'
expect_count guard composer-delta min 1 \
  "survives: nothing load-bearing lives only in a report" \
  --needle 'nothing load-bearing may live only in a report'

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
