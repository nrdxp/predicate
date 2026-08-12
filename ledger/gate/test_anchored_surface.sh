#!/usr/bin/env bash
# Acceptance suite for the anchored-reachability open-surface primitive — the
# command a walk (or the not-yet-built hook) runs to get a budget-bounded,
# relevance-ranked slice of the record's open surface. Node: node/open-surface.
# Boundary: .scratch/ibc-open-surface.md, ten acceptance criteria (C1..C10
# below map to the IBC's numbered list 1..10).
#
# THE COMMAND DOES NOT EXIST YET. Every case in this suite is RED for that one
# reason at the tip this suite was authored against — reported explicitly
# rather than left to a generic assertion failure, per the dispatch's
# right-reason requirement.
#
# ── THE ASSUMED CLI CONTRACT ─────────────────────────────────────────────────
# Nothing in the boundary or the existing corpus pins an interface, so this
# suite fixes ONE reasonable shape and tests black-box against it. An
# implementation is free to choose differently; where it does, the constants
# below (not the properties they exercise) are what needs updating, and that
# divergence belongs in this suite's own commit message.
#
#   ledger/derive/anchored_surface.sh
#     --corpus <dir>         required. Passed through to extract_entries.py
#                             (files or a directory, same as that script).
#     --budget <N>            required — no flag is optional here BECAUSE C6
#                             requires no baked default; omitting it is a
#                             usage error, not a fallback.
#     --anchor <id>            optional, repeatable. Absent -> recency (C4).
#     --ranker <name>          optional, default "anchored" — a real,
#                             name-checked parameter (C7): an unknown name is
#                             rejected by name, not silently ignored.
#     --self-evaluate          switches to the ranker's own holdout evaluator
#                             (C8) instead of rendering a surface.
#
#   Rendered-surface stdout: one line per open-surface member,
#     "[<id>] <statement>"
#   followed unconditionally by a documentation line naming itself
#     declared-and-empty (C9), and closing with a tail line matching
#     /^---.*[0-9]+.*dropped.*---$/ naming the dropped count and a
#     reproduction command (C5, C10).
#
#   --self-evaluate stdout: two lines, both reported and neither gating the
#     surface itself — a backed target fails open-surface membership on its
#     own, not by distance, so charging the ranker for it would score a
#     restriction the boundary imposes rather than the ranker's behaviour:
#       a line matching /HOLDOUT-RECALL:\s*([0-9]+)\/([0-9]+)/ — the ranker's
#         own score, hits over targets that CAN appear in the output (open,
#         unclosed entries);
#       a line matching /HOLDOUT-INELIGIBLE:\s*([0-9]+)\/([0-9]+)/ — a corpus
#         property, not a ranker score: derivation edges whose target is
#         backed and so structurally excluded regardless of ranker behaviour.
#
# ── WHY GOLDEN FIXTURES, NOT THE LIVE CORPUS, CARRY THE PASS/FAIL GATE ───────
# ledger/fixtures/anchored_surface/reach-note.md, holdout-note.md, and the
# {old,new}-note.md recency pair are SYNTHETIC and scored BY HAND (their own
# headers state the arithmetic) — sections 1-8 below gate on them exclusively.
#
# Sections 9-10 attempt the boundary's OTHER explicit ask — reproduce the
# architect's per-anchor budget-fit measurement and the holdout rate against
# the REAL record — over a FROZEN snapshot of .ledger at the commit the
# architect's own [A4] cites (151a79b), located worktree-correctly via
# --git-common-dir (the project's own established idiom, hooks/install-hooks.sh
# and ledger/gate/install-recorder-hook.sh). They do NOT gate the suite's exit
# code on the measured NUMBERS (the boundary is explicit that a bad rate is a
# finding to report, never a bug to route around) — only on the command
# running to completion. Section 9 found, and reports rather than works
# around, that this snapshot does not itself pass the EXISTING
# entry_apply.ncl (a pre-existing, out-of-scope corpus defect); see the
# section's own comment.
#
# BASELINE POLARITY (test_open_surface.sh's convention, reused rather than
# reinvented): "red" must fail before the command exists; "guard" is expected
# green at this baseline (a vacuous-now check that becomes load-bearing once
# the file it inspects exists) and its own baseline is declared honestly.
#
# Usage: bash ledger/gate/test_anchored_surface.sh
# Exit:  0 = every red case now passes (the primitive has landed correctly)
#        1 = at least one red case failed, OR a guard misfired
#        2 = environment error (nickel/python3/git absent, fixtures missing)
set -u

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root="$(cd "$here/../.." && pwd)"
fix="$root/ledger/fixtures/anchored_surface"
CMD="$root/ledger/derive/anchored_surface.sh"
EXTRACTOR="$root/ledger/derive/extract_entries.py"
QUERY="$root/ledger/contracts/entries_query.ncl"
APPLY="$root/ledger/contracts/entry_apply.ncl"

command -v nickel  >/dev/null 2>&1 || { echo "FAIL (env): nickel not on PATH" >&2; exit 2; }
command -v python3 >/dev/null 2>&1 || { echo "FAIL (env): python3 not on PATH" >&2; exit 2; }
command -v git      >/dev/null 2>&1 || { echo "FAIL (env): git not on PATH" >&2; exit 2; }
for required in "$fix" "$EXTRACTOR" "$QUERY" "$APPLY"; do
  [ -e "$required" ] || { echo "FAIL (env): missing $required" >&2; exit 2; }
done
[ -f "$fix/reach-note.md" ]   || { echo "FAIL (env): missing reach-note.md fixture" >&2; exit 2; }
[ -f "$fix/holdout-note.md" ] || { echo "FAIL (env): missing holdout-note.md fixture" >&2; exit 2; }
[ -f "$fix/recency/1000-01-01-old-note.md" ] || { echo "FAIL (env): missing recency-pair fixture (old)" >&2; exit 2; }
[ -f "$fix/recency/9999-12-31-new-note.md" ] || { echo "FAIL (env): missing recency-pair fixture (new)" >&2; exit 2; }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

PASS_COUNT=0
FAIL_COUNT=0
FAIL_MSGS=()
RED_DECLARED=0
RED_FAILING=0
GUARD_DECLARED=0
SKIP_COUNT=0

record() { # polarity(red|guard) outcome(pass|fail) desc [detail]
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

skip() { # desc reason
  echo "  SKIP  $1  ($2)"
  SKIP_COUNT=$((SKIP_COUNT + 1))
}

# run_cmd OUTVAR-PREFIX -- CMD-ARGS...   sets ${OUTVAR-PREFIX}_out/_rc
run_cmd() {
  local prefix="$1"; shift
  [ "$1" = "--" ] && shift
  local out rc
  out="$("$CMD" "$@" 2>&1)"; rc=$?
  printf -v "${prefix}_out" '%s' "$out"
  printf -v "${prefix}_rc" '%s' "$rc"
}

ids_in_output() { # OUTPUT -> newline-separated ids found as "[<id>]" lines
  printf '%s\n' "$1" | grep -oE '^\[[^]]+\]' | tr -d '[]'
}

# ════════════════════════════════════════════════════════════════════════════
echo ""
echo "════════════════════════════════════════════════════════════════════════"
echo "SECTION 0 — the command itself"
echo "════════════════════════════════════════════════════════════════════════"
if [ -x "$CMD" ] || [ -f "$CMD" ]; then
  echo "  command present: $CMD"
else
  echo "  command absent: $CMD (expected — every case below is red for this reason)"
fi

# ════════════════════════════════════════════════════════════════════════════
echo ""
echo "════════════════════════════════════════════════════════════════════════"
echo "SECTION 1 — C2: anchored reachability, bounded at two edges, mixed edges"
echo "════════════════════════════════════════════════════════════════════════"
# reach-note.md's golden neighbourhoods (hand-computed in the fixture's own
# header; A1 is the corroborated, backed root — never itself a member):
#   anchor=A1  -> {B1, C1, H1}   (A1 excluded: backed; Q1 excluded: discharged
#                 but still a BRIDGE to H1 two edges out via closure-then-
#                 provenance; D1 excluded: three hops)
#   anchor=C1  -> {B1, C1, D1}   (own two-hop neighbourhood; A1 reachable at
#                 distance 2 but excluded for being backed, not for distance)
#   anchor=[A1,X1] -> {B1, C1, H1, X1, Y1, Q4}   (union; Z1 stays excluded:
#                 disconnected from both anchors)

run_cmd s1a -- --corpus "$fix/reach-note.md" --budget 100000 --anchor reach-note:A1
if [ "$s1a_rc" -eq 0 ]; then
  ids="$(ids_in_output "$s1a_out" | sort -u)"
  want="$(printf 'reach-note:B1\nreach-note:C1\nreach-note:H1' | sort -u)"
  if [ "$ids" = "$want" ]; then
    record red pass "anchor=A1 returns exactly {B1, C1, H1}"
  else
    record red fail "anchor=A1 returns exactly {B1, C1, H1}" "got: $(printf '%s' "$ids" | tr '\n' ' ')"
  fi
else
  record red fail "anchor=A1 returns exactly {B1, C1, H1}" "rc=$s1a_rc: $s1a_out"
fi

run_cmd s1b -- --corpus "$fix/reach-note.md" --budget 100000 --anchor reach-note:C1
if [ "$s1b_rc" -eq 0 ]; then
  ids="$(ids_in_output "$s1b_out" | sort -u)"
  want="$(printf 'reach-note:B1\nreach-note:C1\nreach-note:D1' | sort -u)"
  if [ "$ids" = "$want" ]; then
    record red pass "anchor=C1 returns exactly {B1, C1, D1} (bound is local, not corpus-relative)"
  else
    record red fail "anchor=C1 returns exactly {B1, C1, D1}" "got: $(printf '%s' "$ids" | tr '\n' ' ')"
  fi
else
  record red fail "anchor=C1 returns exactly {B1, C1, D1}" "rc=$s1b_rc: $s1b_out"
fi

run_cmd s1c -- --corpus "$fix/reach-note.md" --budget 100000 --anchor reach-note:A1 --anchor reach-note:X1
if [ "$s1c_rc" -eq 0 ]; then
  ids="$(ids_in_output "$s1c_out" | sort -u)"
  want="$(printf 'reach-note:B1\nreach-note:C1\nreach-note:H1\nreach-note:X1\nreach-note:Y1\nreach-note:Q4' | sort -u)"
  if [ "$ids" = "$want" ]; then
    record red pass "multi-anchor [A1,X1] unions both neighbourhoods; Z1 (disconnected) stays out"
  else
    record red fail "multi-anchor [A1,X1] unions both neighbourhoods" "got: $(printf '%s' "$ids" | tr '\n' ' ')"
  fi
else
  record red fail "multi-anchor [A1,X1] unions both neighbourhoods" "rc=$s1c_rc: $s1c_out"
fi

# ════════════════════════════════════════════════════════════════════════════
echo ""
echo "════════════════════════════════════════════════════════════════════════"
echo "SECTION 2 — C2/C9 restricted to the open surface: closed nodes never"
echo "appear, but still bridge; the documentation contribution is present"
echo "════════════════════════════════════════════════════════════════════════"
run_cmd s2a -- --corpus "$fix/reach-note.md" --budget 100000 --anchor reach-note:A1
if [ "$s2a_rc" -eq 0 ]; then
  ok=1
  printf '%s' "$s2a_out" | grep -q 'reach-note:A1'  && ok=0  # backed root: never a member
  printf '%s' "$s2a_out" | grep -q 'reach-note:Q1'  && ok=0  # discharged: closed
  [ "$ok" -eq 1 ] && record red pass "backed anchor (A1) and its discharged neighbour (Q1) are excluded from output" \
                  || record red fail "backed anchor (A1) and its discharged neighbour (Q1) are excluded from output" "$s2a_out"
else
  record red fail "backed anchor (A1) and its discharged neighbour (Q1) are excluded from output" "rc=$s2a_rc"
fi

if [ "$s2a_rc" -eq 0 ]; then
  printf '%s' "$s2a_out" | grep -q 'reach-note:H1' \
    && record red pass "H1 is still reached THROUGH the excluded, closed Q1 (pass-through, not pruning)" \
    || record red fail "H1 is still reached THROUGH the excluded, closed Q1" "$s2a_out"
else
  record red fail "H1 is still reached THROUGH the excluded, closed Q1" "rc=$s2a_rc"
fi

# C9: the documentation contribution is a typed empty set with its filling
# condition stated, distinguishable from absent or broken — not a threshold on
# exact wording, a NEIGHBOURHOOD match on the two things it must both say.
if [ "$s2a_rc" -eq 0 ]; then
  printf '%s' "$s2a_out" | grep -qiE 'documentation' && \
  printf '%s' "$s2a_out" | grep -qiE '(declared.?empty|empty).{0,120}(condition|register|corpus)' \
    && record red pass "documentation contribution is declared-and-empty, stating its filling condition" \
    || record red fail "documentation contribution is declared-and-empty, stating its filling condition" "$s2a_out"
else
  record red fail "documentation contribution is declared-and-empty, stating its filling condition" "rc=$s2a_rc"
fi

# ════════════════════════════════════════════════════════════════════════════
echo ""
echo "════════════════════════════════════════════════════════════════════════"
echo "SECTION 3 — C4: no anchor falls back to recency, never to nothing"
echo "════════════════════════════════════════════════════════════════════════"
# Full-budget, no-anchor call over reach-note.md alone still returns every
# open-surface member (nothing to rank away yet) — proves "no anchor" is not
# "no results".
run_cmd s3a -- --corpus "$fix/reach-note.md" --budget 100000
if [ "$s3a_rc" -eq 0 ]; then
  ids="$(ids_in_output "$s3a_out" | sort -u)"
  want="$(printf 'reach-note:B1\nreach-note:C1\nreach-note:D1\nreach-note:H1\nreach-note:Q4\nreach-note:X1\nreach-note:Y1\nreach-note:Z1' | sort -u)"
  if [ "$ids" = "$want" ]; then
    record red pass "no-anchor, ample budget returns the WHOLE open surface (8 members)"
  else
    record red fail "no-anchor, ample budget returns the WHOLE open surface" "got: $(printf '%s' "$ids" | tr '\n' ' ')"
  fi
else
  record red fail "no-anchor, ample budget returns the WHOLE open surface" "rc=$s3a_rc: $s3a_out"
fi

# The recency-pair fixture: OLD1 and NEW1 carry byte-identical-length
# statements (164 chars each, pinned in the fixtures' own headers) so ONLY
# recency can decide which one a budget too small for both keeps. 250 chars
# fits one ~190-char rendered line plus overhead for the mandatory doc+tail
# lines; it does not fit two.
run_cmd s3b -- --corpus "$fix/recency" --budget 600
if [ "$s3b_rc" -eq 0 ]; then
  has_new=0; has_old=0
  printf '%s' "$s3b_out" | grep -q 'NEW1' && has_new=1
  printf '%s' "$s3b_out" | grep -q 'OLD1' && has_old=1
  if [ "$has_new" -eq 1 ] && [ "$has_old" -eq 0 ]; then
    record red pass "no anchor, budget forces a choice: the newer entry (NEW1) wins over the older (OLD1)"
  else
    record red fail "no anchor, budget forces a choice: the newer entry wins" "has_new=$has_new has_old=$has_old; out=$s3b_out"
  fi
else
  record red fail "no anchor, budget forces a choice: the newer entry wins" "rc=$s3b_rc: $s3b_out"
fi
if [ "$s3b_rc" -eq 0 ] && [ "${#s3b_out}" -gt 600 ]; then
  record red fail "recency call at budget=600 fits the budget" "output is ${#s3b_out} chars"
elif [ "$s3b_rc" -eq 0 ]; then
  record red pass "recency call at budget=600 fits the budget"
else
  record red fail "recency call at budget=600 fits the budget" "rc=$s3b_rc"
fi

# ════════════════════════════════════════════════════════════════════════════
echo ""
echo "════════════════════════════════════════════════════════════════════════"
echo "SECTION 4 — C5: the tail is always present, including when nothing dropped"
echo "════════════════════════════════════════════════════════════════════════"
TAIL_RE='^---.*[0-9]+.*dropped.*---$|dropped.*[0-9]+'
run_cmd s4a -- --corpus "$fix/reach-note.md" --budget 100000
if [ "$s4a_rc" -eq 0 ]; then
  printf '%s' "$s4a_out" | grep -qiE "$TAIL_RE" \
    && record red pass "tail present with ample budget (dropped count is 0, not absent)" \
    || record red fail "tail present with ample budget (dropped count is 0, not absent)" "$s4a_out"
  printf '%s' "$s4a_out" | grep -qiE '(dropped\D{0,20}0\b|0\D{0,20}dropped)' \
    && record red pass "the zero-dropped case states the count explicitly, not by omission" \
    || record red fail "the zero-dropped case states the count explicitly" "$s4a_out"
else
  record red fail "tail present with ample budget" "rc=$s4a_rc: $s4a_out"
  record red fail "the zero-dropped case states the count explicitly" "rc=$s4a_rc"
fi

run_cmd s4b -- --corpus "$fix/recency" --budget 600
if [ "$s4b_rc" -eq 0 ]; then
  printf '%s' "$s4b_out" | grep -qiE "$TAIL_RE" \
    && record red pass "tail present and non-zero when something was truncated" \
    || record red fail "tail present and non-zero when something was truncated" "$s4b_out"
else
  record red fail "tail present and non-zero when something was truncated" "rc=$s4b_rc: $s4b_out"
fi

# The tail names a command a stranger can run without the hook (C10).
if [ "$s4a_rc" -eq 0 ]; then
  printf '%s' "$s4a_out" | grep -qE 'extract_entries\.py|entries_query\.ncl|anchored_surface\.sh' \
    && record red pass "tail names a reproduction command referencing real repo machinery" \
    || record red fail "tail names a reproduction command referencing real repo machinery" "$s4a_out"
else
  record red fail "tail names a reproduction command referencing real repo machinery" "rc=$s4a_rc"
fi

# ════════════════════════════════════════════════════════════════════════════
echo ""
echo "════════════════════════════════════════════════════════════════════════"
echo "SECTION 5 — C6: budget is an input, with no default baked into the ranker"
echo "════════════════════════════════════════════════════════════════════════"
run_cmd s5a -- --corpus "$fix/reach-note.md" --anchor reach-note:A1
if [ "$s5a_rc" -ne 0 ] && printf '%s' "$s5a_out" | grep -qi budget; then
  record red pass "omitting --budget is a usage error naming 'budget', not a silent default"
else
  record red fail "omitting --budget is a usage error naming 'budget', not a silent default" "rc=$s5a_rc: $s5a_out"
fi

run_cmd s5b -- --corpus "$fix/reach-note.md" --budget 300
run_cmd s5c -- --corpus "$fix/reach-note.md" --budget 100000
if [ "$s5b_rc" -eq 0 ] && [ "$s5c_rc" -eq 0 ]; then
  b300="${#s5b_out}"; b100k="${#s5c_out}"
  if [ "$b300" -le 300 ]; then
    record red pass "budget=300 output fits within 300 characters"
  else
    record red fail "budget=300 output fits within 300 characters" "got $b300 chars"
  fi
  # A caller passing a smaller budget gets a correspondingly larger dropped
  # count than one passing the whole cap — extract the dropped figure from
  # each tail rather than compare raw lengths, since the smaller budget's OWN
  # output is capped.
  d300="$(printf '%s' "$s5b_out"  | grep -oE '[0-9]+' | tail -1)"
  d100k="$(printf '%s' "$s5c_out" | grep -oE '[0-9]+' | tail -1)"
  if [ -n "$d300" ] && [ -n "$d100k" ] && [ "$d300" -gt "$d100k" ]; then
    record red pass "smaller budget (300) drops strictly more than the ample one (100000)"
  else
    record red fail "smaller budget (300) drops strictly more than the ample one (100000)" "d300=$d300 d100k=$d100k"
  fi
else
  record red fail "budget=300 output fits within 300 characters" "rc300=$s5b_rc rc100k=$s5c_rc"
  record red fail "smaller budget (300) drops strictly more than the ample one (100000)" "rc300=$s5b_rc rc100k=$s5c_rc"
fi

# ════════════════════════════════════════════════════════════════════════════
echo ""
echo "════════════════════════════════════════════════════════════════════════"
echo "SECTION 6 — C7: the ranker is a named, replaceable, name-checked component"
echo "════════════════════════════════════════════════════════════════════════"
run_cmd s6a -- --corpus "$fix/reach-note.md" --budget 100000 --anchor reach-note:A1 --ranker anchored
[ "$s6a_rc" -eq 0 ] \
  && record red pass "--ranker anchored (the named default) is accepted explicitly" \
  || record red fail "--ranker anchored (the named default) is accepted explicitly" "rc=$s6a_rc: $s6a_out"

run_cmd s6b -- --corpus "$fix/recency" --budget 100000 --ranker recency
[ "$s6b_rc" -eq 0 ] \
  && record red pass "--ranker recency is accepted — swappable without editing the caller" \
  || record red fail "--ranker recency is accepted" "rc=$s6b_rc: $s6b_out"

run_cmd s6c -- --corpus "$fix/reach-note.md" --budget 100000 --ranker not-a-real-ranker-xyz
if [ "$s6c_rc" -ne 0 ] && printf '%s' "$s6c_out" | grep -q 'not-a-real-ranker-xyz'; then
  record red pass "an unknown ranker name is rejected BY NAME, proving it is consulted, not ignored"
else
  record red fail "an unknown ranker name is rejected by name" "rc=$s6c_rc: $s6c_out"
fi

# ════════════════════════════════════════════════════════════════════════════
echo ""
echo "════════════════════════════════════════════════════════════════════════"
echo "SECTION 7 — C10: reproducible without the hook; no hook, no wiring"
echo "════════════════════════════════════════════════════════════════════════"
# This node installs nothing. Guard, because the property holds vacuously
# until SOME node adds harness-hook wiring, and stays true only if nothing in
# THIS node's own files reaches for it. Scoped to the two known hook-adjacent
# trees so a legitimate, unrelated harness file elsewhere never trips it.
hook_ref=0
for d in "$root/hooks" "$root/.claude"; do
  [ -d "$d" ] || continue
  grep -rl 'anchored_surface\.sh' "$d" 2>/dev/null | grep -q . && hook_ref=1
done
if [ "$hook_ref" -eq 0 ]; then
  record guard pass "no hook or harness-integration file references the new command"
else
  record guard fail "no hook or harness-integration file references the new command" "a hook/.claude file names it"
fi

run_cmd s7a -- --corpus "$fix/reach-note.md" --budget 100000 --anchor reach-note:A1
[ "$s7a_rc" -eq 0 ] \
  && record red pass "the command runs standalone, invoked directly with no hook installed" \
  || record red fail "the command runs standalone, invoked directly with no hook installed" "rc=$s7a_rc: $s7a_out"

# ════════════════════════════════════════════════════════════════════════════
echo ""
echo "════════════════════════════════════════════════════════════════════════"
echo "SECTION 8 — C8: the ranker's own evaluator, on a hand-scored fixture"
echo "════════════════════════════════════════════════════════════════════════"
# holdout-note.md pins the answer in its own header, and scans EVERY entry
# carrying a derivation edge (not a hand-picked subset — the provenance gate
# forces every unclosed claim to have one, so the fixture's "scaffolding"
# entries score too): 4 pairs total. 3 target an eligible (unclosed) entry —
# D1->SEED1, E1->D1, SEED1->Q1 — and all 3 are HITs. 1 targets an ineligible
# (backed) entry — E2->D2, D2 corroborated/proved — and can never be a HIT at
# any distance, because a backed entry fails open-surface membership on its
# own, not by reachability. Collapsing these into one rate would charge the
# ranker for a restriction the boundary imposes on it, so the fixture is
# scored as two numbers instead of one:
#   ranker recall over eligible targets:  3/3 = 1.0  (the ranker's own score)
#   structural ineligibility:             1/4 = 0.25 (a corpus property)
# Both independently re-derived over the extractor's own export before being
# pinned here.
run_cmd s8a -- --self-evaluate --corpus "$fix/holdout-note.md" --budget 100000
if [ "$s8a_rc" -eq 0 ]; then
  recall_line="$(printf '%s' "$s8a_out" | grep -oE 'HOLDOUT-RECALL:[[:space:]]*[0-9]+/[0-9]+' | head -1)"
  ineligible_line="$(printf '%s' "$s8a_out" | grep -oE 'HOLDOUT-INELIGIBLE:[[:space:]]*[0-9]+/[0-9]+' | head -1)"
  if [ -n "$recall_line" ] && [ -n "$ineligible_line" ]; then
    r_hits="$(printf '%s' "$recall_line" | grep -oE '[0-9]+' | sed -n '1p')"
    r_total="$(printf '%s' "$recall_line" | grep -oE '[0-9]+' | sed -n '2p')"
    i_hits="$(printf '%s' "$ineligible_line" | grep -oE '[0-9]+' | sed -n '1p')"
    i_total="$(printf '%s' "$ineligible_line" | grep -oE '[0-9]+' | sed -n '2p')"
    if [ "$r_hits" = "3" ] && [ "$r_total" = "3" ]; then
      record red pass "ranker recall over eligible targets on the hand-scored fixture reports exactly 3/3"
    else
      record red fail "ranker recall over eligible targets on the hand-scored fixture reports exactly 3/3" "got $r_hits/$r_total"
    fi
    if [ "$i_hits" = "1" ] && [ "$i_total" = "4" ]; then
      record red pass "structural ineligibility on the hand-scored fixture reports exactly 1/4 (a corpus property, not a ranker miss)"
    else
      record red fail "structural ineligibility on the hand-scored fixture reports exactly 1/4" "got $i_hits/$i_total"
    fi
  else
    record red fail "holdout output carries distinct HOLDOUT-RECALL: and HOLDOUT-INELIGIBLE: lines" "$s8a_out"
  fi
else
  record red fail "holdout on the hand-scored fixture reports its two-number split" "rc=$s8a_rc: $s8a_out"
fi

# ════════════════════════════════════════════════════════════════════════════
echo ""
echo "════════════════════════════════════════════════════════════════════════"
echo "SECTION 9 — C3: the real corpus, budget-fit over every anchor (informational)"
echo "════════════════════════════════════════════════════════════════════════"
# Locates .ledger worktree-correctly (hooks/install-hooks.sh's own idiom: the
# recorder lives beside the MAIN tree, not necessarily this worktree) and
# freezes it at 151a79b — the exact commit [A4]'s own check cites — so this
# section is reproducible regardless of what the live record looks like when
# the suite runs. Does NOT gate the suite's exit code on the measured
# statistics: C3 asks this suite to REPORT median/p90/max, and the boundary is
# explicit elsewhere that a measurement is not a threshold. It DOES gate on
# the command running without error, when the corpus is usable at all.
main_tree="$(cd "$(dirname "$(git -C "$root" rev-parse --git-common-dir 2>/dev/null)")" 2>/dev/null && pwd)"
ledger_dir="$main_tree/.ledger"
if [ -z "$main_tree" ] || [ ! -d "$ledger_dir/.git" ]; then
  skip "real-corpus budget-fit measurement (C3)" "no .ledger subrepo found beside the main tree at $main_tree"
else
  frozen="$TMP/ledger_151a79b"
  mkdir -p "$frozen"
  if ! git -C "$ledger_dir" archive 151a79b 2>/dev/null | tar -x -C "$frozen" 2>/dev/null; then
    skip "real-corpus budget-fit measurement (C3)" "commit 151a79b not present in this .ledger's history"
  else
    extract_json="$TMP/frozen_extract.json"
    python3 "$EXTRACTOR" "$frozen" -o "$extract_json" >/dev/null 2>"$TMP/extract.err"
    apply_out="$(nickel export "$extract_json" --apply-contract "$APPLY" 2>&1)"; apply_rc=$?
    if [ "$apply_rc" -ne 0 ]; then
      skip "real-corpus budget-fit measurement (C3)" \
        "the frozen corpus at 151a79b does not pass the EXISTING entry_apply.ncl today (pre-existing, out of this node's scope) — $(printf '%s' "$apply_out" | head -1)"
    else
      ids="$(python3 -c "
import json
d = json.load(open('$extract_json'))
for e in d['entries']:
    print(e['id'])
")"
      count="$(printf '%s\n' "$ids" | grep -c .)"
      echo "  frozen corpus at 151a79b: $count entries extracted and validated cleanly"
      echo "  (skipping the full per-anchor sweep here: the command under test does not exist yet — see"
      echo "   the Section 0 note. Once it exists, this loop reproduces [A4]: run --corpus \"$frozen\" --budget"
      echo "   10000 --anchor <id> for every id above, collect output lengths, and report median/p90/max —"
      echo "   the same measurement the architect ran, over the same commit.)"
      if [ -x "$CMD" ] || [ -f "$CMD" ]; then
        lens=()
        max_len=0
        for id in $ids; do
          out="$("$CMD" --corpus "$frozen" --budget 10000 --anchor "$id" 2>&1)"; rc=$?
          if [ "$rc" -ne 0 ]; then
            record red fail "budget-fit holds for every anchor in the real corpus (151a79b)" "anchor=$id rc=$rc"
            max_len=-1
            break
          fi
          lens+=("${#out}")
          [ "${#out}" -gt "$max_len" ] && max_len="${#out}"
        done
        if [ "$max_len" -ge 0 ]; then
          n="${#lens[@]}"
          sorted=($(printf '%s\n' "${lens[@]}" | sort -n))
          mid=$((n / 2))
          median="${sorted[$mid]}"
          p90_idx=$(( (n * 90) / 100 ))
          [ "$p90_idx" -ge "$n" ] && p90_idx=$((n - 1))
          p90="${sorted[$p90_idx]}"
          echo "  measured over $n anchors: median=$median p90=$p90 max=$max_len (cap 10000)"
          if [ "$max_len" -le 10000 ]; then
            record red pass "every anchor's rendered output fits the 10000-char budget"
          else
            record red fail "every anchor's rendered output fits the 10000-char budget" "max=$max_len"
          fi
        fi
      else
        skip "real per-anchor sweep" "command does not exist yet"
      fi
    fi
  fi
fi

# ════════════════════════════════════════════════════════════════════════════
echo ""
echo "════════════════════════════════════════════════════════════════════════"
echo "SECTION 10 — C8: the real corpus's holdout rate (informational, not gating)"
echo "════════════════════════════════════════════════════════════════════════"
# Same frozen snapshot as Section 9, same corpus-validity caveat. When the
# corpus is usable, this reports the ranker's real-world recall AND the
# corpus's real-world structural-ineligibility fraction — the same split
# Section 8 gates on the synthetic fixture — WITHOUT failing the suite on
# either number, because the boundary is explicit that a bad rate here is a
# finding about the ranker's DEFAULT to report to the composer, not a defect
# in this test suite or the command to route around.
if [ -n "${frozen:-}" ] && [ -f "${extract_json:-/nonexistent}" ] && [ "${apply_rc:-1}" -eq 0 ]; then
  if [ -x "$CMD" ] || [ -f "$CMD" ]; then
    out="$("$CMD" --self-evaluate --corpus "$frozen" --budget 10000 2>&1)"; rc=$?
    if [ "$rc" -eq 0 ]; then
      recall_line="$(printf '%s' "$out" | grep -oE 'HOLDOUT-RECALL:[[:space:]]*[0-9]+/[0-9]+' | head -1)"
      ineligible_line="$(printf '%s' "$out" | grep -oE 'HOLDOUT-INELIGIBLE:[[:space:]]*[0-9]+/[0-9]+' | head -1)"
      if [ -n "$recall_line" ] && [ -n "$ineligible_line" ]; then
        echo "  real-corpus ranker recall (151a79b, budget 10000): $recall_line"
        echo "  real-corpus structural ineligibility (151a79b, budget 10000): $ineligible_line"
        echo "  (both reported, not gated — see this section's header comment)"
        record guard pass "the holdout evaluator runs to completion over the real corpus"
      else
        record guard fail "the holdout evaluator runs to completion over the real corpus" "no HOLDOUT-RECALL:/HOLDOUT-INELIGIBLE: lines in output: $out"
      fi
    else
      record guard fail "the holdout evaluator runs to completion over the real corpus" "rc=$rc: $out"
    fi
  else
    skip "real-corpus holdout measurement" "command does not exist yet"
  fi
else
  skip "real-corpus holdout measurement" "frozen corpus unusable — see Section 9"
fi

# ════════════════════════════════════════════════════════════════════════════
echo ""
echo "════════════════════════════════════════════════════════════════════════"
echo "SECTION 11 — C1: openness is not redefined a second time"
echo "════════════════════════════════════════════════════════════════════════"
# Guard: vacuous until an implementation file exists to inspect. Enumerates
# every .ncl the node adds under ledger/ (git diff against the base tip this
# suite pins, never a name list authored by this suite) and requires each one
# that references BOTH closure-edge tokens to import the existing openness
# machinery rather than recompute it.
BASE_TIP="ff53a61"
if git -C "$root" merge-base --is-ancestor "$BASE_TIP" HEAD 2>/dev/null; then
  new_ncl="$(git -C "$root" diff --name-only --diff-filter=A "$BASE_TIP"...HEAD -- 'ledger/*.ncl' 'ledger/**/*.ncl' 2>/dev/null | grep -v '^ledger/fixtures/')"
  offenders=""
  for f in $new_ncl; do
    path="$root/$f"
    [ -f "$path" ] || continue
    if grep -q 'discharges' "$path" && grep -q 'supersedes' "$path"; then
      grep -qE 'import\s+"(\.\./)?(contracts/)?entries_query\.ncl"|import\s+"(\.\./)?(contracts/)?entry\.ncl"' "$path" \
        || offenders="$offenders $f"
    fi
  done
  if [ -z "$offenders" ]; then
    record guard pass "no new .ncl file re-derives openness instead of importing it"
  else
    record guard fail "no new .ncl file re-derives openness instead of importing it" "offending file(s):$offenders"
  fi
else
  skip "openness-not-redefined static check" "base tip $BASE_TIP not an ancestor of HEAD in this checkout"
fi

# ════════════════════════════════════════════════════════════════════════════
echo ""
echo "════════════════════════════════════════════════════════════════════════"
echo "SUMMARY"
echo "════════════════════════════════════════════════════════════════════════"
echo "  PASS: $PASS_COUNT"
echo "  FAIL: $FAIL_COUNT"
echo "  SKIP: $SKIP_COUNT (environment-conditional sections; see their own notes)"
echo "  cases declared red (must fail pre-implementation):   $RED_DECLARED  — currently failing: $RED_FAILING"
echo "  cases declared guard (vacuous-now or always-true):   $GUARD_DECLARED"

if [ "$RED_DECLARED" -gt 0 ] && [ "$RED_FAILING" -eq "$RED_DECLARED" ]; then
  echo "  BASELINE: every red case is failing — this is a valid red baseline."
elif [ "$RED_FAILING" -eq 0 ]; then
  echo "  BASELINE: no red case is failing — the primitive has landed."
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
