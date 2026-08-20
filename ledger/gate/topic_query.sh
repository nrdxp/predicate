#!/usr/bin/env bash
# Topic-scoped corpus query (tech-debt/close-answered-questions-unconditioned.yaml).
#
# Formalizes the ad hoc invocation seats have been running by hand --
# `extract_entries.py <paths> -o export.json && nickel export export.json
# --apply-contract entries_query.ncl` (e.g.
# .ledger/log/2026-08-19-the-boundary-had-the-defect-it-named.md [C13],
# [C15]) -- into one reusable, testable command, so "run the topic-scoped
# query before depositing" names something invocable rather than a
# by-hand recipe reconstructed differently each time.
#
# Scope composition is the CALLER's: pass every path relevant to the
# question being asked, same as extract_entries.py's own multi-path
# argument always allowed. A discharge carrier only closes a question if
# BOTH the question's own document and the carrier's are in the scope
# passed here -- this script does not guess a topic from one directory
# name, because nothing about the corpus declares "topic" as a directory
# boundary (tech-debt/close-answered-questions-unconditioned.yaml's own
# finding: a head ruling in `.ledger/state/` and the deposit testimony it
# answers already live in two different stores; a rigid one-directory scope
# would make closing a question depend on where its carrier happened to be
# filed).
#
# Usage: topic_query.sh <view> <path> [path...]
#   view: one of entries_query.ncl's exported views --
#         awaiting_human | runnable_now | unpaid_cures | unbacked |
#         chain_floor | untagged
# Exit: 0  the query ran (an empty array is a real answer, not a failure).
#       1  the extractor reported findings over the given scope, or the
#          export did not satisfy the entry contract -- the query result
#          printed, if any, is over data the corpus itself flags as
#          incomplete or invalid.
#       2  usage or environment error.
set -u
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root="$(cd "$here/../.." && pwd)"
extractor="$root/ledger/derive/extract_entries.py"
query="$root/ledger/contracts/entries_query.ncl"
views="awaiting_human runnable_now unpaid_cures unbacked chain_floor untagged"

if [ $# -lt 2 ]; then
  echo "usage: topic_query.sh <view> <path> [path...]"
  echo "views: $views"
  exit 2
fi
view="$1"; shift
case " $views " in
  *" $view "*) ;;
  *) echo "topic_query: unknown view '$view' -- want one of: $views"; exit 2 ;;
esac
command -v python3 >/dev/null 2>&1 || { echo "ENV: python3 not found on PATH"; exit 2; }
command -v nickel >/dev/null 2>&1 || { echo "ENV: nickel not found on PATH"; exit 2; }
[ -f "$extractor" ] || { echo "ENV: extractor missing: $extractor"; exit 2; }
[ -f "$query" ] || { echo "ENV: query missing: $query"; exit 2; }

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

python3 "$extractor" "$@" -o "$tmp/export.json" >"$tmp/extract.out" 2>"$tmp/extract.err"
extract_rc=$?
if [ "$extract_rc" -ne 0 ] && [ "$extract_rc" -ne 3 ]; then
  echo "topic_query: extractor environment error (exit $extract_rc)"
  cat "$tmp/extract.err" >&2
  exit 2
fi

nickel export "$tmp/export.json" --apply-contract "$query" \
  >"$tmp/query.json" 2>"$tmp/query.err"
apply_rc=$?
if [ "$apply_rc" -ne 0 ]; then
  echo "topic_query: the export does not satisfy the entry contract:"
  cat "$tmp/query.err" >&2
  exit 1
fi

python3 -c "
import json, sys
with open('$tmp/query.json') as fh:
    result = json.load(fh)
json.dump(result['$view'], sys.stdout, indent=2)
print()
"

if [ "$extract_rc" -eq 3 ]; then
  echo "topic_query: extractor reported findings over this scope:" >&2
  cat "$tmp/extract.err" >&2
  exit 1
fi
exit 0
