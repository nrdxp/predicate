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
# Usage: test_topic_query.sh
# Exit:  0 = every case matched, 1 = a case mismatched, 2 = environment error.
set -u
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root="$(cd "$here/../.." && pwd)"
tool="$root/ledger/gate/topic_query.sh"
open="$root/ledger/fixtures/topic_query/open"
carrier="$root/ledger/fixtures/topic_query/carrier"

command -v python3 >/dev/null 2>&1 || { echo "ENV: python3 not found on PATH"; exit 2; }
command -v nickel >/dev/null 2>&1 || { echo "ENV: nickel not found on PATH"; exit 2; }
[ -d "$open" ] || { echo "ENV: open fixture missing: $open"; exit 2; }
[ -d "$carrier" ] || { echo "ENV: carrier fixture missing: $carrier"; exit 2; }

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

echo
if [ "$fails" -eq 0 ]; then echo "test_topic_query: ALL PASS"; exit 0; fi
echo "test_topic_query: $fails FAILURE(S)"; exit 1
