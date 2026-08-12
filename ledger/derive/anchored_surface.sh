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
# filter, per-ranker ordering, and the backed-exclusion count — is
# ledger/derive/anchored_surface_core.ncl (the Nickel-for-value-
# transformation half of this node's convention).
#
# Usage:
#   anchored_surface.sh --corpus <dir-or-file> --budget <N>
#                        [--anchor <id>]... [--ranker anchored|recency]
#                        [--self-evaluate] [--json]
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
# --self-evaluate stdout: one line instead of a surface — EXCLUDED-BACKED (a
# corpus property, not a ranker score: derivation edges whose target is
# backed and so structurally excluded from the open surface regardless of
# anchor, ranker, or budget). This primitive previously also shipped a
# ranker "recall" number here; it is CUT, not renamed alongside this one
# (ruling-holdout-fate.md [HV4]/[HV6]) — the label named ordering quality,
# which needs relevance ground truth no corpus in this system carries, and
# every label-free construction of it either degenerated into a
# self-consistency check or restated the two-hop walk this suite already
# binds directly. EXCLUDED-BACKED comes from anchored_surface_core.ncl's
# `excluded_backed`, decidable from the corpus alone, with no graph walk
# required.
#
# --json stdout: the core's structured value verbatim — {candidates:
# [{id, statement, distance}, ...], excluded_backed: {count, total}} — for a
# caller that consumes fields rather than prose (node/surface-injection: the
# SessionStart hook parses this rather than the rendered lines above). This
# is exposure only: --budget is still required (unchanged validation) but
# does not bound this mode's output, exactly as the core itself is not
# budget-bounded — truncation is the renderer's job, not the core's, and a
# structured caller does its own bounding over the parsed value. --json
# takes precedence over --self-evaluate when both are given, since the
# structured value already carries everything --self-evaluate's one line
# reports (and more).
#
# Exit: 0 = rendered/evaluated successfully — including a corpus that
# extracted with findings (extract_entries.py's own exit 3: incomplete only
# where the findings point, never a reason to discard what DID extract
# cleanly, node/surface-injection). 1 = extraction failed outright (no
# export at all) or the corpus failed entry_apply.ncl validation (this
# primitive never works around that — see the node's own report on the
# pre-existing corpus defect). 2 = usage error (missing/invalid flag).
set -u

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root="$(cd "$here/../.." && pwd)"
EXTRACTOR="$here/extract_entries.py"
CORE="$here/anchored_surface_core.ncl"
APPLY="$root/ledger/contracts/entry_apply.ncl"

usage() {
  echo "usage: anchored_surface.sh --corpus <dir-or-file> --budget <N> [--anchor <id>]... [--ranker anchored|recency] [--self-evaluate] [--json]" >&2
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
json_mode=0
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
    --json)
      json_mode=1; shift ;;
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
python3 "$EXTRACTOR" "$corpus" -o "$extract_json" >/dev/null 2>"$extract_err"
extract_rc=$?
# extract_entries.py's own exit convention (its own --help/docstring): 0 =
# clean, 2 = usage/environment error (no export ever written), 3 = findings
# present but the export IS still written, incomplete only where the
# findings themselves point (node/surface-injection). Collapsing exit 3 into
# hard failure made one incomplete document (a missing header, common on the
# real record) void an entire corpus, including every document that parsed
# cleanly — so only 3 is tolerated here; anything else (2, a crash, no
# export) stays a hard failure.
case "$extract_rc" in
  0) ;;
  3)
    echo "anchored_surface: corpus '$corpus' extracted with findings (proceeding on the partial export):" >&2
    cat "$extract_err" >&2
    ;;
  *)
    echo "anchored_surface: extraction failed for corpus '$corpus':" >&2
    cat "$extract_err" >&2
    exit 1 ;;
esac

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
# run's own anchors/ranker (unconditionally — this call is not special-cased
# for `--self-evaluate`). `excluded_backed` ignores anchors/ranker/budget:
# it is a corpus property, computed the same regardless of what a caller
# passed for any of the three.
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

# --json: the core's structured value, unmodified, in place of any render
# (see the header comment). Checked before --self-evaluate's own render
# path, per the precedence documented there.
if [ "$json_mode" -eq 1 ]; then
  cat "$core_json"
  exit 0
fi

# Rendering (line assembly, budget-fit truncation, the two evaluator lines)
# is ordinary string/arithmetic work over an already-computed value, not
# value transformation over the record's graph — Python's job under this
# node's convention, not a second Nickel pass.
python3 - "$core_json" "$budget" "$self_evaluate" <<'PYEOF'
import json, sys

core_path, budget_s, self_evaluate_s = sys.argv[1:4]
budget = int(budget_s)
self_evaluate = self_evaluate_s == "1"

with open(core_path) as f:
    result = json.load(f)

if self_evaluate:
    excluded = result["excluded_backed"]
    print(f"EXCLUDED-BACKED: {excluded['count']}/{excluded['total']}")
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

# The tail is mandatory overhead too (C5/C10), so it also stays short and,
# unlike the doc line, FIXED length: it never embeds the caller's --corpus
# argument. That argument's length is caller-controlled and unbounded — the
# same corpus produced a 288-char render at one checkout path and a 371-char
# render at another checkout 83 characters longer, purely from the absolute
# path's own length — so embedding it made the budget=300 acceptance
# criterion (C6) pass or fail according to where the repository happened to
# sit on disk, never the corpus content. Shortening this line's wording
# cannot fix that: the unbounded part was the embedded argument, not the
# words around it. A stranger reproducing the render already knows the
# corpus path they invoked with, so the tail names the flag without
# repeating an arbitrary-length value back at them, and the dropped count
# stays the only number this line emits.
def tail_line(dropped):
    return (
        "--- reproduce via ledger/derive/anchored_surface.sh --corpus "
        f"<the corpus you passed> with a larger --budget; {dropped} entries "
        "dropped ---"
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
