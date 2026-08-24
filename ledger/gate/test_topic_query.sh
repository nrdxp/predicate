#!/usr/bin/env bash
# Suite for ledger/gate/topic_query.sh -- formalizes the ad hoc
# extract-then-query invocation into one reusable command
# (tech-debt/close-answered-questions-unconditioned.yaml's mechanism half:
# "a discharge carrier the topic scope reads").
#
# ledger/fixtures/topic_query/open/ carries one human-routed open question.
# ledger/fixtures/topic_query/carrier/ carries a SEPARATE entry (never an
# edit to the question's own document) that discharges it by a qualified
# bracket reference, `discharges:: [question:Q1]` -- the same cross-document
# pattern test_corpus_ids.sh's xdoc/ fixture already proves the underlying
# extractor/contract honour. This suite is not re-proving that; it proves
# the WRAPPER surfaces it correctly as a scope-dependent answer: the
# question reads open when only its own document is in scope, and closed
# once the carrier is added to that same scope -- nothing about either
# document changes between the two invocations.
#
# ledger/fixtures/topic_query/xtopic/ reproduces the real defect this suite
# was extended for (architect-seat ruling [ST47]): the caller's scope selects
# what is DISPLAYED, but the closed set must be computed over the WHOLE
# corpus, never just the paths the caller happened to pass. xtopic/asking/
# carries the question; xtopic/elsewhere/ carries its carrier, in a
# DIFFERENT topic the caller never names. TOPIC_QUERY_LEDGER_ROOT is the
# test seam standing in for the real ledger root ($root/.ledger in
# production) so this proves the mechanism without depending on -- or
# writing into -- the live corpus.
#
# Usage: test_topic_query.sh
# Exit:  0 = every case matched, 1 = a case mismatched, 2 = environment error.
set -u
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root="$(cd "$here/../.." && pwd)"
tool="$root/ledger/gate/topic_query.sh"
open="$root/ledger/fixtures/topic_query/open"
carrier="$root/ledger/fixtures/topic_query/carrier"
xtopic="$root/ledger/fixtures/topic_query/xtopic"
asking="$xtopic/asking"
elsewhere="$xtopic/elsewhere"
tagreg="$root/ledger/fixtures/topic_query/tagreg"

command -v python3 >/dev/null 2>&1 || { echo "ENV: python3 not found on PATH"; exit 2; }
command -v nickel >/dev/null 2>&1 || { echo "ENV: nickel not found on PATH"; exit 2; }
[ -d "$open" ] || { echo "ENV: open fixture missing: $open"; exit 2; }
[ -d "$carrier" ] || { echo "ENV: carrier fixture missing: $carrier"; exit 2; }
[ -d "$asking" ] || { echo "ENV: xtopic/asking fixture missing: $asking"; exit 2; }
[ -d "$elsewhere" ] || { echo "ENV: xtopic/elsewhere fixture missing: $elsewhere"; exit 2; }
[ -d "$tagreg" ] || { echo "ENV: tagreg fixture missing: $tagreg"; exit 2; }

fails=0
# expect DESC EXPECTED-RC KEYWORD -- COMMAND...
#   KEYWORD="" skips the message check.
expect() {
  local desc="$1" exp="$2" kw="$3"; shift 3
  [ "$1" = "--" ] && shift
  local out rc ok=1
  out="$("$@" 2>&1)"; rc=$?
  [ "$rc" -eq "$exp" ] || ok=0
  if [ -n "$kw" ]; then printf '%s' "$out" | grep -q -- "$kw" || ok=0; fi
  if [ "$ok" -eq 1 ]; then
    echo "PASS  ($rc) $desc"
  else
    echo "FAIL  (got rc=$rc want $exp; want-kw='$kw') $desc"
    printf '%s\n' "$out" | tail -8
    fails=$((fails + 1))
  fi
}

[ -f "$tool" ] || { echo "ENV: tool missing: $tool"; exit 2; }

expect "too few arguments is a usage error" 2 "usage" \
  -- "$tool" awaiting_human

expect "an unknown view is a usage error" 2 "unknown view" \
  -- "$tool" no_such_view "$open"

expect "the question, scoped alone, reads open" 0 "question:Q1" \
  -- "$tool" awaiting_human "$open"

expect "the same question, scoped with its carrier, reads closed" 0 "" \
  -- "$tool" awaiting_human "$open" "$carrier"

# The negative case above only proves Q1 is ABSENT; confirm the view still
# ran (an empty array is `[]`, not silence) by checking the raw output shape.
out="$("$tool" awaiting_human "$open" "$carrier" 2>&1)"
if [ "$(printf '%s' "$out" | tr -d '[:space:]')" = "[]" ]; then
  echo "PASS  (0) the closed view is an explicit empty array, not silence"
else
  echo "FAIL  the closed view did not print an explicit []: $out"
  fails=$((fails + 1))
fi

# Cross-topic closure (architect-seat ruling [ST47]). The carrier lives in a
# topic the caller never names; scoping to the question's own topic ALONE
# must still see it closed once the corpus root spans both.
expect "the cross-topic question, scoped alone with the default (real) ledger root, stays open (control)" 0 "asked:Q9" \
  -- "$tool" awaiting_human "$asking"

expect "the same question, scoped to its own topic alone, closes once the corpus root spans its carrier's topic too" 0 "" \
  -- env TOPIC_QUERY_LEDGER_ROOT="$xtopic" "$tool" awaiting_human "$asking"

out="$(env TOPIC_QUERY_LEDGER_ROOT="$xtopic" "$tool" awaiting_human "$asking" 2>&1)"
if [ "$(printf '%s' "$out" | tr -d '[:space:]')" = "[]" ]; then
  echo "PASS  (0) the cross-topic closed view is an explicit empty array, not silence"
else
  echo "FAIL  the cross-topic closed view did not print an explicit []: $out"
  fails=$((fails + 1))
fi


# --- project-local tag registry (tag-registry-ships-predicate-vocabulary.yaml) --
#
# ledger/contracts/tag_registry.ncl ships EMPTY, so a corpus carrying a tag
# only a PROJECT's own registry admits must not be refused merely for
# running through this wrapper rather than entries_integrity.sh — both
# compose the project registry sibling to the ledger root the same way
# (ledger/gate/compose_tag_registry.sh). tagreg/ carries one entry tagged
# with a tag ONLY its own sibling tag_registry.ncl admits; TOPIC_QUERY_LEDGER_ROOT
# points the tool at it directly (this is a hermetic fixture, not the live
# corpus, per this suite's own xtopic/ convention above).
expect "a tag only the project-local registry admits is not refused" 0 "" \
  -- env TOPIC_QUERY_LEDGER_ROOT="$tagreg" "$tool" untagged "$tagreg"

echo
if [ "$fails" -eq 0 ]; then echo "test_topic_query: ALL PASS"; exit 0; fi
echo "test_topic_query: $fails FAILURE(S)"; exit 1
