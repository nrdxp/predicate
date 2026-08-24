#!/usr/bin/env bash
# Whole-corpus entry-law gate (tech-debt/direction-id-reused.yaml).
#
# The underlying law already exists and is already tested: EntryStore
# (entry.ncl) decides target-id uniqueness and discharges/supersedes edge
# resolution over an aggregate corpus, and ledger/README.md states the
# design bar directly — "a runner must never re-implement an invariant".
# extract_entries.py deliberately does not deduplicate markers itself
# (ledger/fixtures/extract/red-dup-marker.md's own docstring: "the extractor
# emits both and EntryStore's id-uniqueness red catches the collision").
#
# What was missing was not the law but its INVOCATION: nothing ran this pair
# — extract, then apply-contract — over a real corpus as a standing,
# reusable gate. This script is that wiring, nothing else: it takes the
# extractor's own multi-path corpus argument (a document, a directory, or
# several of either) and reports two failure classes at that scope —
#
#   - a QUALIFIED reference (`[stem:ID]`) the extractor itself could not
#     place (its own `bad-edge` finding — a corpus_ids.py/ghost-class typo);
#   - anything EntryStore's own corpus-level checks refuse: a reused
#     target id, or a discharges/supersedes edge (qualified or the
#     doc-local PLAIN form) that does not resolve within the given scope.
#
# It does not narrow EntryStore to only those two conditions — the contract
# is the law and this gate defers to all of it, exactly as the design bar
# above requires — so a run may also go red on an unrelated per-entry
# defect (a malformed axes block, an unverified corroboration, ...). That is
# not a false positive: it is the same corpus-integrity gate refusing a
# corpus for a different, still-real reason. Its own diagnostic names which.
#
# Usage: entries_integrity.sh <path> [path...]
# Exit:  0 clean; 1 the extractor reported a dangling qualified reference or
#        the entry contract refused the corpus; 2 usage/environment error.
set -u
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root="$(cd "$here/../.." && pwd)"
extractor="$root/ledger/derive/extract_entries.py"
law="$root/ledger/contracts/entry.ncl"
apply="$root/ledger/contracts/entry_apply.ncl"

[ $# -ge 1 ] || { echo "usage: entries_integrity.sh <path> [path...]"; exit 2; }
command -v python3 >/dev/null 2>&1 || { echo "ENV: python3 not found on PATH"; exit 2; }
command -v nickel >/dev/null 2>&1 || { echo "ENV: nickel not found on PATH"; exit 2; }
[ -f "$extractor" ] || { echo "ENV: extractor missing: $extractor"; exit 2; }
[ -f "$law" ] || { echo "ENV: law-file missing: $law"; exit 2; }
[ -f "$apply" ] || { echo "ENV: apply-file missing: $apply"; exit 2; }

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

# --- project-local tag registry composition ----------------------------------
# tag_registry.ncl ships EMPTY
# (.ledger/tech-debt/tag-registry-ships-predicate-vocabulary.yaml — entry.ncl's
# own comment on `tag_registry` explains why). A consuming project declares
# its own vocabulary at <ledger-root>/tag_registry.ncl, sibling to the corpus
# it tags — the SAME "if present" convention `.ledger/config.sh` already
# establishes. Nickel's import is static and cannot conditionally resolve a
# file that may not exist, so composition happens HERE, before nickel ever
# runs: for each given path, its GOVERNING directory (itself if a directory,
# else its parent) is checked for a sibling tag_registry.ncl; the first one
# found is materialized beside a scratch copy of the law (the exact
# copy-the-law idiom test_entry.sh's own mutation cases already use to vary
# it), and $apply is repointed at that copy. Absent any project registry,
# $apply stays the plugin's own file, importing the empty default above —
# no tag admitted, the safe baseline.
registry=""
for p in "$@"; do
  if [ -d "$p" ]; then
    gov="$p"
  else
    gov="$(dirname "$p")"
  fi
  if [ -f "$gov/tag_registry.ncl" ]; then
    registry="$gov/tag_registry.ncl"
    break
  fi
done
if [ -n "$registry" ]; then
  mkdir -p "$tmp/lawreg"
  cp "$law" "$tmp/lawreg/entry.ncl"
  cp "$registry" "$tmp/lawreg/tag_registry.ncl"
  cp "$apply" "$tmp/lawreg/entry_apply.ncl"
  apply="$tmp/lawreg/entry_apply.ncl"
fi

python3 "$extractor" "$@" -o "$tmp/export.json" >"$tmp/extract.out" 2>"$tmp/extract.err"
extract_rc=$?
# 0 = clean, 3 = the extractor reported findings (an export was still
# written — extract_entries.py's own contract). Anything else is an
# environment problem (a bad path, a missing file) this gate cannot decide.
if [ "$extract_rc" -ne 0 ] && [ "$extract_rc" -ne 3 ]; then
  echo "entries_integrity: extractor environment error (exit $extract_rc)"
  cat "$tmp/extract.err"
  exit 2
fi

status=0
if grep -q 'bad-edge' "$tmp/extract.err" 2>/dev/null; then
  echo "entries_integrity: dangling qualified reference(s) reported by the extractor:"
  grep 'bad-edge' "$tmp/extract.err"
  status=1
fi

nickel export "$tmp/export.json" --apply-contract "$apply" >"$tmp/apply.out" 2>&1
apply_rc=$?
if [ "$apply_rc" -ne 0 ]; then
  echo "entries_integrity: the entry contract refused this corpus:"
  cat "$tmp/apply.out"
  status=1
fi

exit "$status"
