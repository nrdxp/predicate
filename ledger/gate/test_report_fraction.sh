#!/usr/bin/env bash
# ledger/gate/test_report_fraction.sh
#
# Acceptance suite for the third of the three reporting obligations: every walk
# REPORTS ITS UNCLOSED FRACTION. The sibling obligations shipped — a walk types
# its claims (the `grade::` vocabulary) and names their provenance
# (`derives-from::`, `source::`) — and the fraction is COMPUTABLE from that
# record today (ledger/contracts/entries_query.ncl derives openness from the
# discharge edges and exposes `unbacked`, `awaiting_human`, `runnable_now`).
# Nothing anywhere in the shipped conditioning requires a walk to STATE it.
# Computable-but-unstated is the gap this suite pins.
#
# WHAT IS SWEPT — the materialized install, never the .ncl sources.
# ------------------------------------------------------------------
# Same technique and same engine as test_conditioning_discipline.sh: run
# `conditioning/install.sh --harness all` into a throwaway HOME and measure the
# OUTPUT tree. A source grep cannot see what composition does, and this suite
# makes one claim — "every walk" — that is a statement about the composed
# surfaces and about nothing else. Measuring sources would turn it into a claim
# about one file that happens to be imported.
#
# THE RUNG, AND WHY — the ruling this suite encodes
# -------------------------------------------------
# The obligation goes in the ALWAYS-ON LAW (conditioning/core.ncl), beside the
# per-statement reporting posture it aggregates. Four reasons, the first
# structural and decisive:
#
#   1. `compose.ncl` gives the composer NEITHER `dispatched` NOR `producer` —
#      the composer is the dispatcher, not a dispatched walk. So the
#      record-writing rung the recording grammar sits at does NOT reach the
#      conductor: the grammar had to be written a second time into the composer
#      persona to cover it. Core is the one rung that reaches all 24 surfaces
#      from a single statement, and `HasCore` makes that reach a contract
#      rather than a habit. "Every walk" is the head's word; core is the only
#      placement where "every" is proved instead of maintained.
#   2. It is the AGGREGATE DUAL of a rule already in core. "Reporting posture —
#      carry the backing or name its absence" governs one statement; the
#      fraction is the same rule read over the whole report. Per-statement
#      backing tells a reader about a sentence; the fraction tells them about
#      the report. Splitting the halves across rungs would make a reader join
#      two rungs to recover one rule.
#   3. Its trigger is REPORTING, not RECORDING. The grammar belongs at the
#      record-writing rungs because a `grade::` marker is meaningless to a walk
#      that writes no graded document. The fraction is not so conditioned: a
#      survey worker reporting in prose, a reviewer delivering a verdict, and
#      the composer reporting to the head all owe the reader the unclosed count
#      whether or not anything got a marker.
#   4. The MECHANISM is the part that is procedure, and it is deliberately not
#      pinned here — see section 5, which only holds core clear of it, exactly
#      as the sibling suite holds core clear of `grade::`.
#
# Section 2c encodes the finer placement ruling (co-location with the
# per-statement posture) as ONE case, so the architect can overturn the
# placement without disturbing the rung.
#
# VACUITY — how each case avoids measuring the author instead of the rule
# ----------------------------------------------------------------------
# A bare presence check for "unclosed fraction" passes the moment anyone writes
# that phrase anywhere, in any voice, binding nobody. Every signature here is
# built from two ALTERNATIONS joined by an ORDER-FREE PROXIMITY test:
#
#   FRACTION = an unclosedness word within one sentence of a quantity word
#   VERB     = FRACTION in the same SENTENCE as an active reporting verb
#   DENOM    = FRACTION within a NEIGHBOURHOOD of a totality word
#   SCOPE    = FRACTION within a NEIGHBOURHOOD of a named body of reported work
#
# Order-free, because the ordered-window form tried first (`A[^.]{0,80}B`)
# rejected two faithful phrasings outright: "the proportion of your claims that
# remain unclosed" nests its scope INSIDE the fraction phrase, and an ordered
# window cannot see a term it already consumed. A guard that rejects a faithful
# restatement of its own rule is measuring phrasing.
#
# TWO PROXIMITY GRAINS, and the mutation evidence that forced the split
# ---------------------------------------------------------------------
# Both grains were measured against seven mutants of the real rendered core —
# the rule inserted into the reporting-posture section in each of the shapes an
# implementation might plausibly take. `P` = the case passes.
#
#   mutant                        2a  3a  4a  4b   3b-guard
#   M0  pre-edit (no rule)         f   f   f   f   pass       <- baseline
#   M1  hollow ("report the        P   P   f   f   pass
#       unclosed fraction.")
#   M2  permission ("...may be     P   f   f   P   TRIPS
#       computed from the record")
#   M3  faithful, one sentence     P   P   P   P   pass
#   M4  faithful, two sentences    P   P   P   P   pass
#   M6  faithful, three sentences  P   P   P   P   pass
#   M5  heading only               P   P   f   f   pass
#
# Same-sentence for EVERYTHING was the first design and M4 refuted it: a rule
# that states the fraction in one sentence and names its denominator and scope
# in the next — an entirely faithful shape — failed 4a and 4b. A neighbourhood
# window for EVERYTHING was refuted from the other side by M2: widened to 240
# chars, 3a was satisfied by a reporting verb in the SURROUNDING prose ("say so
# in the same breath", two sentences up), so a permission-voiced rule passed the
# obligation check. Hence the split — the obligation must be governed by a verb
# in its OWN sentence, while the denominator and scope may be named in the
# rule's immediate neighbourhood.
#
# The window is 240 characters. 200, 240 and 320 produce IDENTICAL verdicts on
# every mutant above, so the evidence does not choose between them; 240 is the
# middle, with room for a three-sentence rule (M6) and short of the previous
# section.
#
# DECLARED LIMITATION. An eighth mutant, M7 — the hollow rule of M1 followed by
# unrelated prose that happens to contain "the total number" and "the claims" —
# passes 4a and 4b. A character window cannot tell a denominator that BINDS the
# fraction from a totality word merely near it; only a syntactic reading could,
# and no regex performs one. The exposure is bounded rather than eliminated:
# case 2c confines the rule to the reporting-posture section, and that section's
# real neighbourhood is measurably clean (M1 and M5 both report 0 for 4a and 4b
# against the actual core text), so the only prose that can satisfy these two
# cases hollowly is prose the implementation itself adds. Accepted as the price
# of not rejecting M4, and recorded here so a later hand reads it as a ruling
# rather than an oversight.
#
# BASELINE POLARITY — the anti-vacuity declaration
# ------------------------------------------------
#   red    — MUST fail before the obligation lands. A check that already passes
#            verifies nothing, so its polarity is declared in the source and the
#            summary reports whether the declaration held.
#   guard  — green before AND after. Two kinds here: over-cut guards protecting
#            the per-statement posture this edit sits next to, and vacuous-now
#            guards (sections 3b, 5, 6) that pass today only because the subject
#            text does not exist yet, and bite the moment an implementation
#            writes it in the wrong voice or at the wrong rung. Their baselines
#            are declared honestly rather than counted as verification.
#
# The suite is therefore expected to exit 1 until the obligation lands, with
# every `red` case failing and every `guard` case passing.
#
# Usage: bash ledger/gate/test_report_fraction.sh
# Exit:  0 = every case passes (the obligation has landed)
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

# expect_section POLARITY HEADING METRIC MODE VALUE DESC [FLAG NEEDLE]
expect_section() {
  local polarity="$1" heading="$2" metric="$3" mode="$4" want="$5" desc="$6"
  local flag="${7:-}" needle="${8:-}"
  local out rc
  if [ -n "$flag" ]; then
    out="$(python3 "$probe" --tree "$TEMP_HOME" --core "$CORE_RENDER" \
      section --heading "$heading" --metric "$metric" "$flag=$needle")"; rc=$?
  else
    out="$(python3 "$probe" --tree "$TEMP_HOME" --core "$CORE_RENDER" \
      section --heading "$heading" --metric "$metric")"; rc=$?
  fi
  if [ "$rc" -ne 0 ]; then
    record "$polarity" fail "$desc" "probe exit $rc"
    return
  fi
  local ok=false
  case "$mode" in
    eq)  [ "$out" -eq "$want" ] && ok=true ;;
    min) [ "$out" -ge "$want" ] && ok=true ;;
    max) [ "$out" -le "$want" ] && ok=true ;;
  esac
  if $ok; then
    record "$polarity" pass "$desc"
  else
    record "$polarity" fail "$desc" "'$heading' $metric $mode $want; observed $out"
  fi
}

# ── the signature alternations ────────────────────────────────────────────────
#
# UNC — the unclosedness half. Every natural statement of this rule names the
# thing being counted as not-yet-closed; the vocabulary the typed record
# already uses (`unclosed`, `unbacked`) sits beside the plain-English forms an
# author is equally likely to reach for. The bare word `open` is deliberately
# ABSENT: it matched "touching a shared surface, or opening a longer
# workstream" in the Discovery sweep, so on its own it measures prose, not the
# rule. `open questions?` and `still open` keep the sense without the noise.
UNC='(?:unclosed|unbacked|unresolved|unverified|undischarged|not closed|left open|remains? open|remaining open|still open|open questions?)'

# QTY — the quantity half. "Fraction" is the head's word; proportion, share,
# count, number, tally, and ratio are the words a faithful rewrite reaches for,
# and "how many"/"how much" cover the phrasings that state the quantity without
# naming it as a noun. Word-bounded, because `share` inside `shared` and
# `count` inside `accounts` are prose.
QTY='(?:\b(?:fractions?|proportion|share|counts?|number|tally|ratio)\b|how many|how much)'

# FRACTION — the two halves inside one sentence, either order.
FRACTION="(?:${UNC}[^.]{0,60}${QTY}|${QTY}[^.]{0,60}${UNC})"

# VRB — an ACTIVE reporting verb. This is the obligation-not-permission half:
# the difference between "the fraction is computable" and "you report the
# fraction" is that a reporting verb governs the second. The law states its
# obligations in the imperative far more often than with `must`, so pinning
# `must` alone would reject the house voice; pinning the verb catches both.
VRB='(?:reports?|states?|names?|declares?|gives?|says?|reporting|stating|naming|closes? with|closes by)'

# DEN — a totality word. An unclosed count without its denominator is a number
# with no meaning: three unbacked claims out of four is a failing walk, out of
# four hundred is a clean one.
DEN='(?:denominator|out of|of the total|against the total|how many of|drawn from|the total|the whole of|over the total)'

# SCP — a named BODY of reported things. Bare second-person pronouns were tried
# here and dropped: this law is written in the second person throughout, so
# `you`/`your` would be satisfied by any sentence at all and the case would
# verify nothing beyond FRACTION.
SCP='(?:\bthis walk\b|\bthe walk\b|\ba walk\b|\byour (?:report|claims|findings|statements|assertions|questions|work)\b|\b(?:this|its|the) report\b|the claims|the findings|the questions|what you (?:reported|asserted|claimed|told|made)|you (?:made|raised|asserted|reported))'

# PRM — a permission modal. The anti-pattern: "the fraction MAY be computed"
# satisfies a presence check and binds nobody.
PRM='\b(?:may|might|could|optionally|optional|if useful|where helpful|is available|is computable)\b'

# The two proximity grains (see TWO PROXIMITY GRAINS in the header). Both are
# order-free: `(?=<A>)<B>` asserts A is reachable from a position from which B
# is also reachable, which holds whenever both occur in the span regardless of
# their order and even when they overlap.
#
#   SAME SENTENCE — `[^.]*` cannot cross a period, so both terms lie in one
#   period-free run. Used where the term must GOVERN the fraction: a reporting
#   verb and a permission modal both change the rule's force only when they are
#   in its own sentence.
SS_WINDOW='[^.]*'
#   NEIGHBOURHOOD — a bounded character span that MAY cross a sentence
#   boundary. Used where the term merely ACCOMPANIES the fraction: a faithful
#   rule is free to state the quantity in one sentence and name its denominator
#   and scope in the next.
NB_WINDOW='.{0,240}'

RX_FRACTION="(?i)${FRACTION}"
RX_VERB="(?i)(?=${SS_WINDOW}${FRACTION})${SS_WINDOW}\b${VRB}\b"
RX_PERMISSION="(?i)(?=${SS_WINDOW}${FRACTION})${SS_WINDOW}${PRM}"
RX_DENOM="(?i)(?=${NB_WINDOW}${FRACTION})${NB_WINDOW}${DEN}"
RX_SCOPE="(?i)(?=${NB_WINDOW}${FRACTION})${NB_WINDOW}${SCP}"

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

# The identity anchor. Section 2b's "every surface" claim and section 4's
# delta-scoped guards both treat "the core region" as a property of the SHIPPED
# artifact; this is what earns that. Guard, because a regression here
# invalidates the measurements rather than reporting an obligation that did not
# land.
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
echo "SECTION 2 — The obligation EXISTS, at the always-on rung"
echo "════════════════════════════════════════════════════════════════════════"
echo ""

# 2a. The rung ruling itself: the obligation is carried by the always-on law.
expect_count red core min 1 \
  "obligation: core states an unclosed quantity" \
  --regex "$RX_FRACTION"

# 2b. The head's word is EVERY walk, and that is a claim about the composed
# surfaces. Stated as a separate case rather than inferred from 2a: 2a proves
# the text is in core, and this proves core's reach is intact for it across all
# 24 materialized prompts — the two are one condition only for as long as
# `HasCore` holds on every field, which is precisely what section 1 verifies
# and not something this case should assume on its own.
expect_count red surfaces min 1 \
  "obligation: it reaches EVERY materialized surface (every walk)" \
  --regex "$RX_FRACTION"

# 2c. THE PLACEMENT RULING, isolated to one case on purpose. The fraction is
# the aggregate of the per-statement backing rule, so it belongs in that rule's
# section rather than in a section of its own — one rule, read once, at one
# rung. The heading is matched by PREFIX, so the implementation stays free to
# retitle the section's subtitle; only a genuinely separate home fails here.
# Strike THIS case, not the rung, if the architect rules the obligation earns a
# section of its own.
expect_section red 'Reporting posture' contains min 1 \
  "placement: it sits with the per-statement posture it aggregates" \
  --regex "$RX_FRACTION"

# ══════════════════════════════════════════════════════════════════════════════
echo ""
echo "════════════════════════════════════════════════════════════════════════"
echo "SECTION 3 — It is an OBLIGATION, not a permission"
echo "════════════════════════════════════════════════════════════════════════"
echo ""

# 3a. The discriminator. "The fraction may be computed" and "the fraction is
# derivable from the record" both satisfy section 2 and bind nobody; an active
# reporting verb is what makes the walk the actor. SAME-SENTENCE grain, and
# mutant M2 is why: widened to the neighbourhood window this case was satisfied
# by a verb in the surrounding prose, and a permission-voiced rule passed.
expect_count red core min 1 \
  "obligation: a reporting verb governs it (stated, not merely computable)" \
  --regex "$RX_VERB"

# 3b. The anti-pattern, from the other side. VACUOUS AT THIS BASELINE and
# declared guard for that reason: with no fraction text in core there is
# nothing for a permission modal to govern, so it passes today without
# verifying anything. It bites the moment an implementation writes the rule in
# the permissive voice — which is the single most likely way to satisfy 2a
# while shipping the gap.
expect_count guard core eq 0 \
  "obligation: no permission modal governs it (may/optional/if useful)" \
  --regex "$RX_PERMISSION"

# ══════════════════════════════════════════════════════════════════════════════
echo ""
echo "════════════════════════════════════════════════════════════════════════"
echo "SECTION 4 — It NAMES what it reports: denominator and scope"
echo "════════════════════════════════════════════════════════════════════════"
echo ""

# Both cases use the NEIGHBOURHOOD grain: a rule is free to state the quantity
# in one sentence and name its denominator and scope in the next, and mutant M4
# proved the same-sentence grain rejects exactly that shape.

# 4a. A fraction without its denominator is a number with no meaning: three
# unbacked claims out of four is a failing walk and out of four hundred is a
# clean one, and a bare "3 unbacked" is indistinguishable between them.
expect_count red core min 1 \
  "names it: the denominator the count is drawn from" \
  --regex "$RX_DENOM"

# 4b. And a denominator without a scope is a total over nothing in particular.
# The scope is what tells a reader WHICH body of statements was counted — this
# walk's report, its claims, its open questions — and it is the difference
# between a figure they can act on and a figure they must interrogate.
expect_count red core min 1 \
  "names it: the body of reported work the count ranges over" \
  --regex "$RX_SCOPE"

# ══════════════════════════════════════════════════════════════════════════════
echo ""
echo "════════════════════════════════════════════════════════════════════════"
echo "SECTION 5 — The MECHANISM stays out of the law"
echo "════════════════════════════════════════════════════════════════════════"
# The obligation is posture and binds every walk; the way the number is
# computed is PROCEDURE and binds only walks that hold a typed corpus. This
# section is the exact analogue of the sibling suite's "grammar absent from
# core" guards, and it is what keeps the rung ruling honest: an implementation
# that drops the query invocation into the always-on layer has put procedure in
# the law, whatever else it got right.
#
# Every case here is VACUOUS AT THIS BASELINE — none of these tokens is in core
# today — and all are declared guard for that reason. Where the mechanism SHOULD
# live is deliberately unpinned: the head's goal names the obligation, not a
# mechanism, and pinning a home for text nobody has been asked to write would be
# this suite inventing scope.
echo ""
for token in \
  'entries_query.ncl' \
  'extract_entries.py' \
  '--apply-contract' \
  'awaiting_human' \
  'runnable_now' \
  'chain_floor' \
  'unpaid_cures' \
; do
  expect_count guard core eq 0 \
    "mechanism: '$token' absent from core (procedure stays out of the law)" \
    --needle "$token"
done

# ══════════════════════════════════════════════════════════════════════════════
echo ""
echo "════════════════════════════════════════════════════════════════════════"
echo "SECTION 6 — One rung, one statement (no second copy at a lower rung)"
echo "════════════════════════════════════════════════════════════════════════"
# Core reaches all 24 surfaces, so a module or persona that also states the
# obligation makes the walker read the same rule twice in one prompt — the
# defect class the conditioning-discipline pass exists to remove, and a
# duplication its unbounded k-gram sweep would report as UNDECLARED. These
# guards say the same thing at this suite's own grain, on the DELTA so a
# surface's core occurrence cannot satisfy them.
#
# VACUOUS AT THIS BASELINE (the text exists nowhere), hence guard. Strike these
# two if the architect rules a rung needs its own elaboration of the fraction —
# the composer at campaign CLOSE is the plausible candidate.
echo ""
expect_count guard agents-delta eq 0 \
  "one statement: no second copy in any dispatched-role delta" \
  --regex "$RX_FRACTION"
expect_count guard composer-delta eq 0 \
  "one statement: no second copy in the composer delta" \
  --regex "$RX_FRACTION"

# ══════════════════════════════════════════════════════════════════════════════
echo ""
echo "════════════════════════════════════════════════════════════════════════"
echo "SECTION 7 — Over-cut guards: the posture this edit sits inside survives"
echo "════════════════════════════════════════════════════════════════════════"
# Genuinely green at BOTH baselines — unlike sections 3b, 5 and 6, these three
# measure text that exists today. An implementation adding the aggregate to
# this section could rewrite the per-statement rule on its way past; these hold
# the two clauses that carry it.
echo ""
expect_count guard core min 1 \
  "survives: the reporting-posture section itself" \
  --needle '## Reporting posture'
expect_section guard 'Reporting posture' contains min 1 \
  "survives: the per-statement backing clause" --regex '(?i)backing'
expect_section guard 'Reporting posture' contains min 1 \
  "survives: the name-what-would-falsify-it clause" --regex '(?i)falsif'

# ══════════════════════════════════════════════════════════════════════════════
echo ""
echo "════════════════════════════════════════════════════════════════════════"
echo "SUMMARY"
echo "════════════════════════════════════════════════════════════════════════"
echo "  PASS: $PASS_COUNT"
echo "  FAIL: $FAIL_COUNT"
echo "  cases declared red (must fail pre-obligation):   $RED_DECLARED  — currently failing: $RED_FAILING"
echo "  cases declared guard (green pre and post):       $GUARD_DECLARED"

if [ "$RED_DECLARED" -gt 0 ] && [ "$RED_FAILING" -eq "$RED_DECLARED" ]; then
  echo "  BASELINE: every red case is failing — the suite is a valid red baseline."
elif [ "$RED_FAILING" -eq 0 ]; then
  echo "  BASELINE: no red case is failing — the obligation has landed."
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
