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
# DISPLAY vs CLOSURE (architect-seat ruling, store-topology [ST38]/[ST47]):
# the caller's paths select what is DISPLAYED -- which questions it is
# asking about -- but a question's OPENNESS is a corpus-wide fact. A ruling
# routinely closes questions across topics (one carrier discharging
# questions asked in a different document is the normal case, not an
# edge case -- tech-debt/close-answered-questions-unconditioned.yaml's own
# finding: a head ruling in `.ledger/state/` and the deposit testimony it
# answers already live in two different stores), so computing closure only
# from edges INSIDE the caller's scope reports a question open when it
# cannot see the edge that closed it -- not because it disagrees, but
# because it cannot see it ([ST35]/[ST36]). The fix: extract the caller's
# scope to know what to DISPLAY, separately extract the whole ledger root
# (plus the caller's scope, in case it lies outside that root -- the test
# seam below) to know what is CLOSED, then restrict the corpus-wide answer
# down to the ids the caller's own scope declares. No index is persisted
# ([ST41]: a whole-corpus extraction measured 0.111s over 2260 entries,
# cheaper than maintaining a second thing to keep true) and no convention
# governs where a carrier must be filed relative to the topic it closes
# ([ST42]: unenforceable, and would make WHERE a node was filed load-bearing
# for WHAT the corpus knows).
#
# TOPIC_QUERY_LEDGER_ROOT overrides the ledger root used for the
# closure-only pass. It defaults to "$root/.ledger" (the project's real
# ledger) and exists so tests can point at a small fixture root instead of
# the live, ever-growing corpus -- ledger/fixtures/topic_query/xtopic/
# is such a fixture. Production callers never need to set it.
#
# Usage: topic_query.sh <view> <path> [path...]
#   view: one of entries_query.ncl's exported views --
#         awaiting_human | runnable_now | unpaid_cures | unbacked |
#         chain_floor | untagged
# Exit: 0  the query ran (an empty array is a real answer, not a failure).
#       1  the extractor reported findings over the caller's own scope, or
#          that scope's export did not satisfy the entry contract -- the
#          query result printed, if any, is over data the corpus itself
#          flags as incomplete or invalid.
#       2  usage or environment error, INCLUDING a corpus-wide closure pass
#          that could not be verified -- reported rather than silently
#          computed as if nothing were closed.
set -u
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root="$(cd "$here/../.." && pwd)"
extractor="$root/ledger/derive/extract_entries.py"
law_dir="$root/ledger/contracts"
query="$law_dir/entries_query.ncl"
compose_helper="$here/compose_tag_registry.sh"
ledger_root="${TOPIC_QUERY_LEDGER_ROOT:-$root/.ledger}"
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
[ -f "$law_dir/entry.ncl" ] || { echo "ENV: law missing: $law_dir/entry.ncl"; exit 2; }
[ -f "$law_dir/entry_apply.ncl" ] || { echo "ENV: apply-file missing: $law_dir/entry_apply.ncl"; exit 2; }
[ -f "$compose_helper" ] || { echo "ENV: compose helper missing: $compose_helper"; exit 2; }
[ -d "$ledger_root" ] || { echo "ENV: ledger root missing: $ledger_root"; exit 2; }
# shellcheck source=/dev/null
. "$compose_helper"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

# --- project-local tag registry composition ----------------------------------
# tag_registry.ncl ships EMPTY
# (.ledger/tech-debt/tag-registry-ships-predicate-vocabulary.yaml). A
# consuming project declares its own vocabulary at
# <ledger-root>/tag_registry.ncl -- $ledger_root above, never the caller's
# own DISPLAY-scope paths ("$@"), since closure is computed over
# $ledger_root and that is the corpus a registry is properly sibling to.
# Composed by the SAME shared idiom entries_integrity.sh uses
# (compose_tag_registry.sh) rather than a second copy of it.
registry=""
[ -f "$ledger_root/tag_registry.ncl" ] && registry="$ledger_root/tag_registry.ncl"
compose_tag_registry "$law_dir" "$registry" "$tmp/lawreg"
query="$COMPOSED_QUERY"

# Resolve two file sets: SCOPE is exactly the caller's own paths (what gets
# displayed); CORPUS is scope UNION the ledger root, de-duplicated by
# resolved path so a caller path already inside the ledger root never gets
# extracted twice into one contract-checked export (which would collide on
# entry ids). Reuses extract_entries.py's own collect_files rather than
# reimplementing directory-walk semantics.
python3 - "$(dirname "$extractor")" "$ledger_root" "$@" \
  >"$tmp/filesets.json" 2>"$tmp/filesets.err" <<'PY'
import sys, json
from pathlib import Path

extractor_dir, ledger_root, *scope_args = sys.argv[1:]
sys.path.insert(0, extractor_dir)
import extract_entries as ee

try:
    scope_files = [str(Path(f).resolve()) for f in ee.collect_files(scope_args)]
    root_files = [str(Path(f).resolve()) for f in ee.collect_files([ledger_root])]
except FileNotFoundError as err:
    print(f"extract_entries: no such file: {err}", file=sys.stderr)
    sys.exit(2)

seen = set(scope_files)
corpus_files = list(scope_files)
for f in root_files:
    if f not in seen:
        seen.add(f)
        corpus_files.append(f)

json.dump({"scope": scope_files, "corpus": corpus_files}, sys.stdout)
PY
filesets_rc=$?
if [ "$filesets_rc" -ne 0 ]; then
  echo "topic_query: resolving scope/corpus file sets failed (exit $filesets_rc)"
  cat "$tmp/filesets.err" >&2
  exit 2
fi

readarray -d '' scope_files < <(python3 -c "
import json, sys
with open('$tmp/filesets.json') as fh:
    data = json.load(fh)
sys.stdout.write('\0'.join(data['scope']))
")
readarray -d '' corpus_files < <(python3 -c "
import json, sys
with open('$tmp/filesets.json') as fh:
    data = json.load(fh)
sys.stdout.write('\0'.join(data['corpus']))
")

python3 "$extractor" "${scope_files[@]}" -o "$tmp/scope_export.json" \
  >"$tmp/scope.out" 2>"$tmp/scope.err"
scope_rc=$?
if [ "$scope_rc" -ne 0 ] && [ "$scope_rc" -ne 3 ]; then
  echo "topic_query: extractor environment error over the caller's scope (exit $scope_rc)"
  cat "$tmp/scope.err" >&2
  exit 2
fi

python3 "$extractor" "${corpus_files[@]}" -o "$tmp/corpus_export.json" \
  >"$tmp/corpus.out" 2>"$tmp/corpus.err"
corpus_rc=$?
if [ "$corpus_rc" -ne 0 ] && [ "$corpus_rc" -ne 3 ]; then
  echo "topic_query: corpus-wide extraction failed (exit $corpus_rc) -- closure cannot be verified corpus-wide"
  cat "$tmp/corpus.err" >&2
  exit 2
fi

nickel export "$tmp/scope_export.json" --apply-contract "$query" \
  >"$tmp/scope_query.json" 2>"$tmp/scope_query.err"
scope_apply_rc=$?
if [ "$scope_apply_rc" -ne 0 ]; then
  echo "topic_query: the caller's scope export does not satisfy the entry contract:"
  cat "$tmp/scope_query.err" >&2
  exit 1
fi

nickel export "$tmp/corpus_export.json" --apply-contract "$query" \
  >"$tmp/corpus_query.json" 2>"$tmp/corpus_query.err"
corpus_apply_rc=$?
if [ "$corpus_apply_rc" -ne 0 ]; then
  echo "topic_query: the corpus-wide export does not satisfy the entry contract -- closure cannot be verified corpus-wide:"
  cat "$tmp/corpus_query.err" >&2
  exit 2
fi

# DISPLAY: restrict the corpus-wide (correctly-closed) view down to the ids
# the caller's own scope declares. Generic over view shape: a flat id list
# (untagged), a nested {violations, unassessed} record (unpaid_cures), or
# the common list-of-{id, ...} shape every other view returns.
python3 -c "
import json, sys

view = '$view'
with open('$tmp/scope_export.json') as fh:
    scope_export = json.load(fh)
allowed = {e['id'] for e in scope_export['entries']}

with open('$tmp/corpus_query.json') as fh:
    corpus_result = json.load(fh)
value = corpus_result[view]

if view == 'untagged':
    restricted = [i for i in value if i in allowed]
elif view == 'unpaid_cures':
    restricted = {
        'violations': [v for v in value['violations'] if v['id'] in allowed],
        'unassessed': [i for i in value['unassessed'] if i in allowed],
    }
else:
    restricted = [v for v in value if v['id'] in allowed]

json.dump(restricted, sys.stdout, indent=2)
print()
"

if [ "$scope_rc" -eq 3 ]; then
  echo "topic_query: extractor reported findings over the caller's scope:" >&2
  cat "$tmp/scope.err" >&2
  exit 1
fi
exit 0
