#!/usr/bin/env bash
# Suite for ledger/gate/entries_integrity.sh -- the whole-corpus entry-law
# gate closing tech-debt/direction-id-reused.yaml's mechanism gap.
#
# The underlying invariants (target-id uniqueness, discharges/supersedes
# edge resolution) are already pinned at the unit level by
# test_entries_extract.sh (ledger/fixtures/extract/red-dup-marker.md) and
# test_corpus_ids.sh (ledger/fixtures/extract/corpus-ids/plainfall). This
# suite does not re-author those fixtures -- it proves the WRAPPER correctly
# invokes the extractor and the contract and correctly propagates their
# verdict as its own exit code, reusing the same fixtures test_entries_extract.sh
# and test_corpus_ids.sh already carry.
#
# Usage: test_entries_integrity.sh
# Exit:  0 = every case matched, 1 = a case mismatched, 2 = environment error.
set -u
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root="$(cd "$here/../.." && pwd)"
gate="$root/ledger/gate/entries_integrity.sh"
clean="$root/ledger/fixtures/extract/ledger-note.md"
dup="$root/ledger/fixtures/extract/red-dup-marker.md"
plainfall="$root/ledger/fixtures/extract/corpus-ids/plainfall"
ghost="$root/ledger/fixtures/extract/corpus-ids/ghost"

command -v python3 >/dev/null 2>&1 || { echo "ENV: python3 not found on PATH"; exit 2; }
command -v nickel >/dev/null 2>&1 || { echo "ENV: nickel not found on PATH"; exit 2; }
[ -f "$clean" ] || { echo "ENV: clean fixture missing: $clean"; exit 2; }
[ -f "$dup" ] || { echo "ENV: dup fixture missing: $dup"; exit 2; }
[ -d "$plainfall" ] || { echo "ENV: plainfall fixture missing: $plainfall"; exit 2; }
[ -d "$ghost" ] || { echo "ENV: ghost fixture missing: $ghost"; exit 2; }

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

[ -f "$gate" ] || { echo "ENV: gate missing: $gate"; exit 2; }

# --- usage ------------------------------------------------------------------

expect "no arguments is a usage error, not a silent pass" 2 "usage" \
  -- "$gate"

# --- clean: a well-formed one-document corpus exits 0 -----------------------

expect "a clean corpus reports nothing and exits 0" 0 "" \
  -- "$gate" "$clean"

# --- id-uniqueness: the RED this gate exists to surface ---------------------
#
# red-dup-marker.md deliberately extracts clean (0) and is refused ONLY at
# the contract layer -- this is the case tech-debt/direction-id-reused.yaml
# names: nothing previously ran that refusal as a standing gate.

expect "a reused target id is refused, named as EntryStore's own error" 1 \
  "duplicate entry id" \
  -- "$gate" "$dup"

# --- dangling discharges: a PLAIN ref that resolves nowhere -----------------
#
# plainfall/ is two documents; the plain edge stays namespaced to the one
# that wrote it and never falls back to its neighbour's same-named marker --
# entry_apply.ncl refuses it as dangling, and this gate must surface that as
# its own exit 1, not silently accept the corpus.

expect "a plain discharge naming no declared id is refused" 1 \
  "dangling discharges" \
  -- "$gate" "$plainfall"

# --- dangling qualified reference: caught at the extractor, not the contract
#
# ghost/ is the OTHER half: a bracketed [stem:ID] the extractor itself
# cannot place. resolve_qualified drops it and reports a `bad-edge` finding
# before nickel ever runs -- this gate must surface that finding as red too,
# not just the contract's own refusals.

expect "an unplaceable qualified reference is refused at the extractor" 1 \
  "bad-edge" \
  -- "$gate" "$ghost"

# --- mutation: a clean corpus, mechanically broken --------------------------
#
# Proves the gate is not decoration by construction: start from the SAME
# clean fixture that passes above, mechanically duplicate its one marker
# (the red-dup-marker.md docstring's own recipe), and show the identical
# gate flips from PASS to FAIL on the identical invocation shape.

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
{
  cat "$clean"
  printf '\n`[K1] grade::proved` A second bearer of the same marker, added by\nmutation. `check:: true`\n'
} > "$tmp/mutated.md"

expect "the clean fixture, mutated to reuse a marker, goes red" 1 \
  "duplicate entry id" \
  -- "$gate" "$tmp/mutated.md"

echo
if [ "$fails" -eq 0 ]; then echo "test_entries_integrity: ALL PASS"; exit 0; fi
echo "test_entries_integrity: $fails FAILURE(S)"; exit 1
