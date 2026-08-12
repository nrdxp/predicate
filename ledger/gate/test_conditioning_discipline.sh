#!/usr/bin/env bash
# ledger/gate/test_conditioning_discipline.sh
#
# Acceptance suite for the conditioning pass that (a) installs the typed-claim
# reporting discipline and (b) applies the minimality audit's cut list.
#
# WHAT IS SWEPT — the materialized install, never the .ncl sources.
# ------------------------------------------------------------------
# This suite runs `conditioning/install.sh --harness all` into a throwaway HOME
# and measures the OUTPUT tree: all persisted subagents, the output style, and
# the agy surface. A source grep cannot see what composition does. A rule
# written once in `core.ncl` and once in a module is one occurrence in each
# source and a DOUBLE carry in every prompt that pulls both — which is the
# defect class this pass exists to remove. Sweeping the composed output makes
# the duplication visible by construction, and it closes the coverage hole two
# prior audit lenses declared (both called their duplicate counts LOWER bounds
# because the persona files were never swept).
#
# HOW A RUNG IS ISOLATED
# ----------------------
# `compose.ncl` places the core law FIRST and verbatim in every prompt, so the
# rendered core is a contiguous substring of every materialized surface —
# section 1 proves it, and every later measurement depends on it. A surface's
# DELTA is that surface with its single core occurrence excised: the modules
# and the persona, isolated from the always-on law. Measuring presence on a
# delta is what makes "carried at the rung AND absent from core" three
# independent conditions instead of two restatements of one.
#
# NORMALIZATION
# -------------
# Every match runs on text with unicode punctuation folded to ASCII and
# whitespace collapsed. Both matter. An absence-by-grep check has already
# passed four separate hands in this repository because prose used an em dash
# where the needle used a hyphen; folding stops a fifth. Collapsing lets a
# needle span a line wrap, which every hard-wrapped rule here does.
#
# BASELINE POLARITY — the anti-vacuity declaration
# ------------------------------------------------
# Every case declares whether it is RED or GUARD against the pre-edit tree:
#
#   red    — MUST fail before the pass lands. A negative check that already
#            passes verifies nothing, so its polarity is stated in the source
#            and the summary reports whether the declaration held.
#   guard  — green before AND after. These protect rules the audit found EARN
#            their place, so the pass cannot over-cut on its way to green.
#
# The suite is therefore expected to exit 1 until the conditioning pass lands,
# with every `red` case failing and every `guard` case passing.
#
# Usage: bash ledger/gate/test_conditioning_discipline.sh
# Exit:  0 = every case passes (the pass has landed)
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

# probe_count SCOPE NEEDLE_OR_REGEX_FLAG VALUE -> "MIN MAX UNITS"
#
# The flag and its value are joined with `=`. Several signatures in this suite
# are themselves option-shaped (`--dry-run` is one), and passed as a separate
# argv word the parser would consume them as flags — a case failing on a usage
# error instead of on the condition it asserts.
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

# The identity anchor. Everything below treats "the core region" as a property
# of the SHIPPED artifact; this is what earns that, and it is a guard because a
# regression here invalidates every later measurement rather than reporting a
# cut that did not happen.
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
echo "SECTION 2 — T1: the typed-claim discipline lands at its ruled scope"
echo "════════════════════════════════════════════════════════════════════════"

# 2a. Reporting POSTURE binds every walk, so it lives in core. The three
# signatures are the three clauses of the rule: do not assert without backing,
# say plainly when you have none, name what would falsify a claim. Alternations
# are used where the clause has more than one natural wording — the check pins
# the rule, not one author's sentence.
echo ""
echo "── 2a. Reporting posture in core (binds every walk) ─────────────────────"
expect_count red core min 1 \
  "posture: core carries the backing vocabulary" \
  --needle 'backing'
expect_count red core min 1 \
  "posture: core states what to do when backing is absent" \
  --regex '(?i)(unbacked|no backing|without backing|absence of backing|lacks backing)'
expect_count red core min 1 \
  "posture: core requires naming what would falsify a claim" \
  --regex '(?i)falsif'

# 2b/2c. GRAMMAR binds only walks that write records, so it lives at two rungs
# and NOWHERE ELSE. Each token gets three independent conditions:
#
#   A  carried by the dispatched rung's delta
#   B  carried by the composer rung's delta
#   C  absent from core
#
# C is the one that makes this pass unable to ship the defect it exists to
# remove. Without it, the grammar could be dropped into the always-on layer:
# every surface contains core, so A and B would still read as satisfied on a
# whole-file measurement. Measuring A and B on the DELTA and asserting C keeps
# the three conditions independent — grammar in core fails C, grammar nowhere
# fails A and B, and only the ruled placement passes all three.
#
# At the pre-edit tree the vocabulary is absent everywhere, so A and B are the
# red half and C passes vacuously. C is declared `guard` for exactly that
# reason: it is honest about its own baseline, and it bites the moment an
# implementation reaches for the always-on layer.
GRAMMAR_TOKENS=(
  # header spans — the document-level designation and anchor
  'signer::'
  '`at::'
  # the node marker
  'grade::'
  # companion tokens
  'check::'
  'source::'
  'derives-from::'
  'discharge::'
  'closer::'
  # the cell vocabulary, backticked so each names a unique site: the bare words
  # (`proved`, `routed`, `synthesis`, `cited`) already occur as ordinary prose
  # across these prompts and would match a case other than their own.
  '`proved`'
  '`cited`'
  '`synthesis`'
  '`dispatchable`'
  '`routed`'
  '`frontier`'
  '`residual`'
)

echo ""
echo "── 2b. Grammar carried at both record-writing rungs ─────────────────────"
for token in "${GRAMMAR_TOKENS[@]}"; do
  expect_count red agents-delta min 1 \
    "grammar A: '$token' in the dispatched rung's delta" --needle "$token"
  expect_count red composer-delta min 1 \
    "grammar B: '$token' in the composer rung's delta" --needle "$token"
done

echo ""
echo "── 2c. Grammar ABSENT from the always-on layer ──────────────────────────"
for token in "${GRAMMAR_TOKENS[@]}"; do
  expect_count guard core eq 0 \
    "grammar C: '$token' absent from core (procedure stays out of the law)" \
    --needle "$token"
done

# ══════════════════════════════════════════════════════════════════════════════
echo ""
echo "════════════════════════════════════════════════════════════════════════"
echo "SECTION 3 — The cut list"
echo "════════════════════════════════════════════════════════════════════════"

# 3a. DEDUPE — the pen law's namespace mechanics. The deposits path survives at
# the rungs that act on it and leaves the always-on layer. The expected count is
# deliberately NOT uniform: a seat prompt carries the path from two segments
# (the dispatched station and the council station), which is a sanctioned double
# carry, so asserting `== 1` everywhere would demand a cut nobody ruled.
echo ""
echo "── 3a. Dedupe: pen-law namespace mechanics ──────────────────────────────"
expect_count red core eq 0 \
  "pen law: deposits path gone from core" \
  --needle '.ledger/deposits/<topic>/<signer>/'
expect_count guard nonseat-delta eq 1 \
  "pen law: deposits path survives once in each non-seat delta" \
  --needle '.ledger/deposits/<topic>/<signer>/'
expect_count guard seats-delta min 2 \
  "pen law: deposits path survives in each seat delta (dispatched + council)" \
  --needle '.ledger/deposits/<topic>/<signer>/'
expect_count guard composer-delta eq 1 \
  "pen law: deposits path survives once in the composer delta" \
  --needle '.ledger/deposits/<topic>/<signer>/'

# 3b. DEDUPE — the commit rail's standing-authorization clause. The dispatched
# module states it more completely than core does: it carries the read-only
# carve-out (reviewers and seats never commit to the project repository) that
# core's copy omits, so the module's statement is the one that survives.
echo ""
echo "── 3b. Dedupe: dispatched-producer commit authorization ─────────────────"
expect_count red core eq 0 \
  "commit rail: standing-authorization clause gone from core" \
  --needle 'STANDING authorization for the dispatched walk'
expect_count red core eq 0 \
  "commit rail: uncommitted-diff restatement gone from core" \
  --needle 'leaving finished work uncommitted in the worktree'
expect_count guard agents-delta min 1 \
  "commit rail: the complete clause survives at the dispatched rung" \
  --needle 'standing authorization the commit rail requires'
expect_count guard agents-delta min 1 \
  "commit rail: the read-only carve-out core omits survives" \
  --regex 'Read-only roles'

# 3c. TIGHTEN — the team substrate. Exactly two sentences survive: the
# cost-metric declaration (what a hit and a miss are measured against, the term
# nothing else in the law closes) and the sentence naming stability as the
# attractor that metric reads. Everything arguing the selection rule already
# implies this compresses to nothing — if it is already implied, saying so IS
# the bloat. The absolute "never cheaper" quantifier goes with its paragraph; it
# overclaims a comparative parent.
#
# The sentence count is asserted directly rather than through a proxy, and the
# two content anchors keep it from being satisfied by retaining the WRONG two
# sentences. The anchors are concept words, not phrasings, so the pass is free
# to write the two survivors in its own words.
echo ""
echo "── 3c. Tighten: the team substrate ──────────────────────────────────────"
expect_count guard core min 1 \
  "team substrate: the section itself survives" \
  --needle '## The team substrate'
expect_section red 'The team substrate' sentences max 2 \
  "team substrate: exactly two sentences survive"
expect_section guard 'The team substrate' contains min 1 \
  "team substrate: the stability attractor survives" --regex '(?i)attractor'
expect_section guard 'The team substrate' contains min 1 \
  "team substrate: the cost metric's hit term survives" --regex '(?i)\bhit\b'
expect_section guard 'The team substrate' contains min 1 \
  "team substrate: the cost metric's miss term survives" --regex '(?i)\bmiss\b'
expect_count red core eq 0 \
  "team substrate: the absolute 'never cheaper' quantifier is gone" \
  --needle 'never cheaper'
expect_count red core eq 0 \
  "team substrate: the already-implied argument is gone" \
  --needle 'already imply this'
expect_count red core eq 0 \
  "team substrate: the vacuum preamble is gone" \
  --needle 'No walk happens in a vacuum'

# 3d. RESCOPE — structured user queries. A halt-and-query is a composer act;
# the rule binds the seat that performs it, not every walk.
echo ""
echo "── 3d. Rescope: structured user queries → the composer ──────────────────"
expect_count red core eq 0 \
  "structured queries: heading gone from core" \
  --needle 'Structured user queries'
expect_count red core eq 0 \
  "structured queries: rule text gone from core" \
  --needle 'structured-question features'
expect_count red composer-delta min 1 \
  "structured queries: rule lands in the composer delta" \
  --regex '(?i)structured[- ]question'

# 3e. RESCOPE — persona sourcing. The harness-agnostic PRINCIPLE (dispatch a
# role under its persona, never a generic agent) binds every walk and stays in
# core. The MECHANISM — filesystem paths and installer flags — is procedure for
# the two rungs that dispatch: the composer, and the council station, because
# seats summon reviewers. It reaches no other rung; a worker or a reviewer
# dispatches nobody, so the non-seat delta expecting ZERO is the point of this
# case, not an oversight.
echo ""
echo "── 3e. Rescope: persona-sourcing mechanism → composer + council ─────────"
expect_count red core eq 0 \
  "persona sourcing: agent-file path gone from core" \
  --needle '~/.claude/agents/predicate-<role>.md'
expect_count red core eq 0 \
  "persona sourcing: installer dry-run flag gone from core" \
  --needle '--dry-run'
expect_count red core eq 0 \
  "persona sourcing: generator filename gone from core" \
  --needle 'compose.ncl'
expect_count red composer-delta min 1 \
  "persona sourcing: mechanism lands in the composer delta" \
  --needle '~/.claude/agents/predicate-<role>.md'
expect_count red seats-delta min 1 \
  "persona sourcing: mechanism lands in the council station (seats summon)" \
  --needle '~/.claude/agents/predicate-<role>.md'
expect_count guard nonseat-delta eq 0 \
  "persona sourcing: mechanism reaches no non-seat rung" \
  --needle '~/.claude/agents/predicate-<role>.md'
expect_count guard core min 1 \
  "persona sourcing: the harness-agnostic principle stays in core" \
  --regex '(?i)generic'
expect_count guard core min 1 \
  "persona sourcing: the principle still names the persona" \
  --regex '(?i)persona'

# 3f. TIGHTEN — enumerate-the-universe. Two statements, two genuine triggers
# (walk start, and any coverage claim); neither is deletable. Only the shared
# mechanism repeats, so the two merge into one statement carrying both triggers.
#
# The coverage-claim trigger is guarded by an ALTERNATION for the reason 2a
# gives: the clause has more than one natural wording, and pinning a single
# token measures the author instead of the rule. The bare token `coverage`
# would have FAILED on the base text's own words — "any claim of exhaustive
# scope" — so a faithful preservation of the rule would have been rejected
# while a narrowing paraphrase passed. The alternation requires a claim word
# adjacent to an exhaustiveness word in either order, which is what every
# natural statement of this trigger has in common, and it reports 0 when the
# clause is deleted.
echo ""
echo "── 3f. Tighten: enumerate-the-universe stated once, two triggers ────────"
expect_count red core eq 1 \
  "universe: the sample-not-population mechanism is stated once" \
  --regex '(?i)is a sample, not the population'
expect_count red core eq 1 \
  "universe: the git ls-files mechanism is stated once" \
  --needle 'git ls-files'
expect_count red core eq 1 \
  "universe: the semantic-search mechanism is stated once" \
  --needle 'semantic search'
expect_count guard core min 1 \
  "universe: the walk-start trigger survives" \
  --needle 'establish-universe'
expect_count guard core min 1 \
  "universe: the coverage-claim trigger survives" \
  --regex '(?i)claim\w*[^.]{0,30}(exhaustive|coverage)|(exhaustive|coverage)[^.]{0,30}claim\w*'

# 3g. TIGHTEN — terminal cross-references. Each of these closes a section by
# naming another section and binds nothing on its own.
echo ""
echo "── 3g. Tighten: terminal cross-reference sentences ──────────────────────"
expect_count red core eq 0 \
  "cross-ref: the goals-nest closer is gone" \
  --needle 'read at the scale of goals rather than artifacts'
expect_count red core eq 0 \
  "cross-ref: the recover-the-purpose closer is gone" \
  --needle 'This is the dual of state-tracking'
expect_count red core eq 0 \
  "cross-ref: the action-caution closer is gone" \
  --needle 'The commit-gate rails above are the specific'

# 3h. TIGHTEN — address the human by name. The audit measured this rule at five
# lines and ruled it should be two. Read here as the section BODY: a heading and
# a blank line are structure, not the rule, and the rule's prose is what was
# measured. The binding content — use the harness's preferred name — survives.
echo ""
echo "── 3h. Tighten: address the human by name ───────────────────────────────"
expect_section red 'Address the human by name' body-lines max 2 \
  "address-by-name: the rule fits in two lines"
expect_section guard 'Address the human by name' contains min 1 \
  "address-by-name: the preferred-name binding survives" --regex '(?i)preferred name'

# ══════════════════════════════════════════════════════════════════════════════
echo ""
echo "════════════════════════════════════════════════════════════════════════"
echo "SECTION 4 — Over-cut guards: rules the audit found EARN their place"
echo "════════════════════════════════════════════════════════════════════════"
# A cutting pass measured only by what it removes will remove too much. These
# five were examined and kept: grounded critique because two modules cite it as
# core's bar and moving it orphans live references, and the other four because
# nothing else in the layer states them.
echo ""
expect_count guard core min 1 \
  "survives: grounded critique (two modules cite it as core's bar)" \
  --needle '**Grounded critique.**'
expect_count guard reviewers-delta min 1 \
  "survives: the reviewer rung's live citation of that bar" \
  --needle 'A finding is admissible only when'
expect_count guard core min 1 \
  "survives: the code-edit floor" --needle '## Code-edit floor'
expect_count guard core min 1 \
  "survives: the external-source trust boundary" \
  --needle '## External-source trust boundary'
expect_count guard core min 1 \
  "survives: the dual-use security floor" --needle '## Dual-use security floor'
expect_count guard core min 1 \
  "survives: the Discovery sweep" --needle '## Discovery'

# ══════════════════════════════════════════════════════════════════════════════
echo ""
echo "════════════════════════════════════════════════════════════════════════"
echo "SECTION 5 — Unbounded duplication sweep (no signature enumerated)"
echo "════════════════════════════════════════════════════════════════════════"
#
# The enumerated half above can only find duplication somebody already named.
# This half names nothing: it reports every k-word phrase carried by BOTH a
# prompt's core region and that same prompt's delta — a rule the walker reads
# twice in one prompt, which is the property class the pass targets.
#
# Whole-SENTENCE identity was measured first and rejected on evidence: it finds
# zero duplicates across this tree, because core and a module state the same
# rule in different words. They share a phrase, never a sentence. Shingling at
# k=5 recovers exactly the duplications the audit found by hand, so that is the
# grain used.
#
# RESIDUAL, not sanctioned-away. The list below is every phrase the sweep
# reports today MINUS the four this pass's ruled cuts remove. Those four are
# absent from the list, which is what makes this case red now and green when
# the cuts land. Everything remaining is a real core↔delta duplication that
# this pass was not scoped to touch, and each is a standing finding.
#
# The manifest is an EXACT SET, compared by equality in BOTH directions —
# never a tolerance band. A phrase the sweep reports that the manifest does
# not declare is a duplication that got introduced. A phrase the manifest
# declares that the sweep no longer reports is a finding resolved without
# anyone saying so, and that direction is the one a tolerance loses: cut a
# rule outright — both copies — and the count merely drops, which a one-sided
# comparison reads as an improvement rather than as the deletion it is. A
# member therefore leaves this list only in the commit that resolves it, with
# the cause recorded in that commit's body.
echo ""
cat >"$TEMP_HOME/residual.txt" <<'RESIDUAL'
a finding is admissible only
a stale comment is a
and neither is its absence
any boundary is not what
boundary is not what but
boundary mass scales inversely with
confidence is not evidence and
disciplines load they are not
evidence and neither is its
first question of any boundary
internal confidence is not evidence
is not evidence and neither
is not what but how
is the chronological process log
log/ is the chronological process
mass scales inversely with walker
named disciplines load they are
no access to this conversation
not evidence and neither is
not what but how much
of any boundary is not
question of any boundary is
setup should have allowlisted it
synthesis decision and narrative nodes
the chronological process log and
the first question of any
what but how much ceremony
RESIDUAL

python3 "$probe" --tree "$TEMP_HOME" --core "$CORE_RENDER" dupes --k 5 \
  >"$TEMP_HOME/dupes.raw" 2>"$TEMP_HOME/dupes.err"
dupes_rc=$?
sweep_desc="unbounded sweep: reported residuals equal the declared manifest"
if [ "$dupes_rc" -ne 0 ]; then
  record red fail "$sweep_desc" "probe exit $dupes_rc"
  sed 's/^/    /' "$TEMP_HOME/dupes.err"
else
  cut -f2 "$TEMP_HOME/dupes.raw" | LC_ALL=C sort -u >"$TEMP_HOME/dupes.txt"
  LC_ALL=C sort -u "$TEMP_HOME/residual.txt" >"$TEMP_HOME/residual.sorted"
  # Set equality, both differences. UNDECLARED is duplication that appeared
  # without being declared; STALE is a declared member the sweep no longer
  # reports — a resolution nobody recorded, and the direction a one-sided
  # comparison silently accepts.
  LC_ALL=C comm -23 "$TEMP_HOME/dupes.txt" "$TEMP_HOME/residual.sorted" \
    >"$TEMP_HOME/undeclared.txt"
  LC_ALL=C comm -13 "$TEMP_HOME/dupes.txt" "$TEMP_HOME/residual.sorted" \
    >"$TEMP_HOME/stale.txt"
  echo "  reported phrases: $(wc -l <"$TEMP_HOME/dupes.txt" | tr -d ' ')" \
       " declared residual: $(wc -l <"$TEMP_HOME/residual.sorted" | tr -d ' ')"
  echo "  full report (surface-count, phrase):"
  sed 's/^/    /' "$TEMP_HOME/dupes.raw"
  undeclared="$(wc -l <"$TEMP_HOME/undeclared.txt" | tr -d ' ')"
  stale="$(wc -l <"$TEMP_HOME/stale.txt" | tr -d ' ')"
  if [ "$undeclared" -eq 0 ] && [ "$stale" -eq 0 ]; then
    record red pass "$sweep_desc"
  else
    detail=""
    if [ "$undeclared" -ne 0 ]; then
      echo "  UNDECLARED (reported, not in the manifest):"
      sed 's/^/    + /' "$TEMP_HOME/undeclared.txt"
      detail="$undeclared undeclared"
    fi
    if [ "$stale" -ne 0 ]; then
      echo "  STALE (declared, no longer reported — resolve it in the manifest):"
      sed 's/^/    - /' "$TEMP_HOME/stale.txt"
      detail="${detail:+$detail, }$stale stale"
    fi
    record red fail "$sweep_desc" "$detail"
  fi
fi

# ══════════════════════════════════════════════════════════════════════════════
echo ""
echo "════════════════════════════════════════════════════════════════════════"
echo "SUMMARY"
echo "════════════════════════════════════════════════════════════════════════"
echo "  PASS: $PASS_COUNT"
echo "  FAIL: $FAIL_COUNT"
echo "  cases declared red (must fail pre-pass):   $RED_DECLARED  — currently failing: $RED_FAILING"
echo "  cases declared guard (green pre and post): $GUARD_DECLARED"

if [ "$RED_DECLARED" -gt 0 ] && [ "$RED_FAILING" -eq "$RED_DECLARED" ]; then
  echo "  BASELINE: every red case is failing — the suite is a valid red baseline."
elif [ "$RED_FAILING" -eq 0 ]; then
  echo "  BASELINE: no red case is failing — the conditioning pass has landed."
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
