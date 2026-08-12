#!/usr/bin/env bash
# The anchored-reachability open-surface primitive (node/open-surface):
# a budget-bounded, relevance-ranked slice of the record's OPEN surface,
# runnable standalone by a walk or a not-yet-built harness hook — this
# primitive installs no hook and no harness wiring of its own; a caller
# invokes it directly.
#
# Owns: CLI parsing, extraction (extract_entries.py), the entry_apply.ncl
# validation gate every corpus already passes through, and budget-bounded
# rendering/truncation of what the Nickel core computes. The graph walk
# itself — undirected two-hop reachability, the open-surface membership
# filter, per-ranker ordering, and the holdout self-evaluator's two numbers —
# is ledger/derive/anchored_surface_core.ncl (the Nickel-for-value-
# transformation half of this node's convention).
#
# Usage:
#   anchored_surface.sh --corpus <dir-or-file> --budget <N>
#                        [--anchor <id>]... [--ranker anchored|recency]
#                        [--self-evaluate]
#
# --budget has NO baked-in default: omitting it is a usage error, never a
# silent fallback (ruling-open-surface-node.md [U8] names this as one of the
# five bound properties). --anchor is repeatable; naming none falls back to
# recency ranking over the WHOLE open surface, never to an empty result.
# --ranker names a real, checked component (ruling [U8]/[A6]) — an unknown
# name is rejected by name below.
#
# Rendered-surface stdout: one "[<id>] <statement>" line per open-surface
# member the budget keeps, followed unconditionally by a documentation line
# (declared-and-empty — this repository carries no claim-graded documentation
# yet, ruling-hooks-boundary.md B4) and a tail line naming the dropped count
# and a reproduction command, present even when nothing was dropped.
#
# --self-evaluate stdout: two lines instead of a surface — HOLDOUT-RECALL
# (the ranker's own score, over targets that CAN appear in the output) and
# HOLDOUT-INELIGIBLE (a corpus property: derivation targets that are backed
# and so structurally excluded regardless of the ranker). Neither gates the
# other; both come from anchored_surface_core.ncl's `holdout`, which scores
# reachability alone, never a budget or a chosen ranker's truncation
# (ruling-open-surface-node.md [U6]).
#
# Exit: 0 = rendered/evaluated successfully. 1 = the corpus failed
# extraction or entry_apply.ncl validation (this primitive never works
# around that — see the node's own report on the pre-existing corpus
# defect). 2 = usage error (missing/invalid flag).
set -u

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root="$(cd "$here/../.." && pwd)"
EXTRACTOR="$here/extract_entries.py"
CORE="$here/anchored_surface_core.ncl"
APPLY="$root/ledger/contracts/entry_apply.ncl"

usage() {
  echo "usage: anchored_surface.sh --corpus <dir-or-file> --budget <N> [--anchor <id>]... [--ranker anchored|recency] [--self-evaluate]" >&2
}

command -v nickel  >/dev/null 2>&1 || { echo "anchored_surface: nickel not on PATH" >&2; exit 2; }
command -v python3 >/dev/null 2>&1 || { echo "anchored_surface: python3 not on PATH" >&2; exit 2; }
for required in "$EXTRACTOR" "$CORE" "$APPLY"; do
  [ -e "$required" ] || { echo "anchored_surface: missing required file: $required" >&2; exit 2; }
done

corpus=""
budget=""
ranker="anchored"
self_evaluate=0
anchors=()

while [ $# -gt 0 ]; do
  case "$1" in
    --corpus)
      [ $# -ge 2 ] || { echo "anchored_surface: --corpus takes a value" >&2; usage; exit 2; }
      corpus="$2"; shift 2 ;;
    --budget)
      [ $# -ge 2 ] || { echo "anchored_surface: --budget takes a value" >&2; usage; exit 2; }
      budget="$2"; shift 2 ;;
    --anchor)
      [ $# -ge 2 ] || { echo "anchored_surface: --anchor takes a value" >&2; usage; exit 2; }
      anchors+=("$2"); shift 2 ;;
    --ranker)
      [ $# -ge 2 ] || { echo "anchored_surface: --ranker takes a value" >&2; usage; exit 2; }
      ranker="$2"; shift 2 ;;
    --self-evaluate)
      self_evaluate=1; shift ;;
    -h|--help)
      usage; exit 0 ;;
    *)
      echo "anchored_surface: unknown argument: $1" >&2; usage; exit 2 ;;
  esac
done

[ -n "$corpus" ] || { echo "anchored_surface: --corpus is required" >&2; usage; exit 2; }
[ -e "$corpus" ] || { echo "anchored_surface: no such corpus path: $corpus" >&2; exit 2; }

# No baked-in default (C6/[U8]): the flag's own name is in the message so a
# caller sees exactly what was missing, not a generic usage dump.
if [ -z "$budget" ]; then
  echo "anchored_surface: --budget is required (no default budget is baked in)" >&2
  usage
  exit 2
fi
case "$budget" in
  ''|*[!0-9]*)
    echo "anchored_surface: --budget must be a non-negative integer, got '$budget'" >&2
    exit 2 ;;
esac

# The ranker is a real, name-checked parameter (C7): rejecting by name here,
# before anything is extracted, is what proves it is consulted rather than
# silently accepted or ignored.
case "$ranker" in
  anchored|recency) ;;
  *)
    echo "anchored_surface: unknown ranker '$ranker' (known rankers: anchored, recency)" >&2
    exit 2 ;;
esac

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

extract_json="$TMP/extract.json"
extract_err="$TMP/extract.err"
if ! python3 "$EXTRACTOR" "$corpus" -o "$extract_json" >/dev/null 2>"$extract_err"; then
  echo "anchored_surface: extraction failed for corpus '$corpus':" >&2
  cat "$extract_err" >&2
  exit 1
fi

# Validation is not re-implemented (entries_query.ncl's own header rule,
# reused here): an invalid corpus never reaches the graph walk. This is
# where the pre-existing, out-of-scope corpus defect
# (audit-typed-claims-campaign:Q5's misplaced `check::`) surfaces on the
# real record — reported here exactly as it is, never routed around.
apply_out="$(nickel export "$extract_json" --apply-contract "$APPLY" 2>&1)"; apply_rc=$?
if [ "$apply_rc" -ne 0 ]; then
  echo "anchored_surface: corpus '$corpus' does not pass entry_apply.ncl (pre-existing corpus defect, not this primitive's to fix):" >&2
  echo "$apply_out" >&2
  exit 1
fi

# Build the core's input record: the validated export's `entries`, plus the
# run's own anchors/ranker. `--self-evaluate` needs neither budget nor
# anchors to score (ruling [U6]: recall is reachability alone) so it is not
# threaded into the core's input at all.
request_json="$TMP/request.json"
python3 - "$extract_json" "$request_json" "$ranker" "${anchors[@]}" <<'PYEOF'
import json, sys
extract_path, request_path, ranker = sys.argv[1], sys.argv[2], sys.argv[3]
anchors = sys.argv[4:]
export = json.load(open(extract_path))
json.dump({"entries": export["entries"], "anchors": anchors, "ranker": ranker},
          open(request_path, "w"))
PYEOF

driver_ncl="$TMP/driver.ncl"
{
  printf 'let core = import "%s" in\n' "$CORE"
  printf 'let req = import "%s" in\n' "$request_json"
  printf 'core req\n'
} > "$driver_ncl"

core_json="$TMP/core.json"
core_out="$(nickel export "$driver_ncl" 2>&1)"; core_rc=$?
if [ "$core_rc" -ne 0 ]; then
  echo "anchored_surface: the reachability core failed:" >&2
  echo "$core_out" >&2
  exit 1
fi
printf '%s' "$core_out" > "$core_json"

# Rendering (line assembly, budget-fit truncation, the two evaluator lines)
# is ordinary string/arithmetic work over an already-computed value, not
# value transformation over the record's graph — Python's job under this
# node's convention, not a second Nickel pass.
python3 - "$core_json" "$budget" "$self_evaluate" "$corpus" <<'PYEOF'
import json, sys

core_path, budget_s, self_evaluate_s, corpus = sys.argv[1:5]
budget = int(budget_s)
self_evaluate = self_evaluate_s == "1"

with open(core_path) as f:
    result = json.load(f)

if self_evaluate:
    recall = result["holdout"]["recall"]
    ineligible = result["holdout"]["ineligible"]
    print(f"HOLDOUT-RECALL: {recall['hits']}/{recall['total']}")
    print(f"HOLDOUT-INELIGIBLE: {ineligible['count']}/{ineligible['total']}")
    sys.exit(0)

candidates = result["candidates"]  # already ranked by the core

# The documentation contribution is a typed EMPTY set, not an absent one
# (ruling-hooks-boundary.md B4): this repository carries no claim-graded
# documentation corpus yet, so the composed surface states that condition
# rather than staying silent about whether the half was built or empty.
# Kept short deliberately: this line is MANDATORY overhead present in every
# render (C9), so its own length eats directly into whatever budget the
# caller gave, however small — a wordier line was what made budget=300 (a
# real, ruled-on acceptance value) unfittable even with zero candidates.
doc_line = (
    "documentation: declared-empty (filling condition: this repository "
    "becomes a claims-register corpus)."
)

# The tail is mandatory overhead too (C5/C10), so it also stays short, and
# it never embeds a second, larger number after the dropped count. The
# earlier draft appended a computed "whole-surface" budget suggestion AFTER
# the dropped count, so a reader (or a test) taking "the last number in the
# output" as the dropped count would pick up that suggestion instead — the
# two numbers coincided only by the accident of both scaling with corpus
# size. The corpus argument can itself contain digits (a dated fixture path,
# for instance), so it is placed BEFORE the dropped count; the dropped count
# is always the last digits this line — and thus the whole render — emits.
def tail_line(dropped):
    return (
        f"--- reproduce via ledger/derive/anchored_surface.sh --corpus "
        f"{corpus} with a larger --budget; {dropped} entries dropped ---"
    )

lines = []
for c in candidates:
    line = f"[{c['id']}] {c['statement']}"
    trial = lines + [line]
    # Stopping HERE means everything not yet in `trial` is dropped — the
    # exact count `tail_line` would report if the walk halts at this
    # candidate, so checking that prospective total is what keeps the tail's
    # own dropped-count digits inside the budget accounting rather than
    # outside it.
    prospective_dropped = len(candidates) - len(trial)
    total = "\n".join(trial + [doc_line, tail_line(prospective_dropped)])
    if len(total) <= budget:
        lines = trial
    else:
        break

dropped = len(candidates) - len(lines)
print("\n".join(lines + [doc_line, tail_line(dropped)]))
PYEOF
exit $?
