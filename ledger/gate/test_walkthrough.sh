#!/usr/bin/env bash
# Suite for ledger/examples/walkthrough/README.md -- the worked example's own
# claim that "the commands below are the actual commands, and the outputs
# shown are what they actually print."
#
# That claim has no other evaluator: nothing under ledger/gate/ referenced
# ledger/examples/ before this suite, and test_fixture_sweep.sh's glob is
# ledger/fixtures/*.ncl, which structurally cannot reach a directory of
# markdown. Without this gate, a change to the extractor, the query contract,
# or convergence.py can silently invalidate the walkthrough's prose and
# nothing red would ever say so.
#
# Each case below runs the README's documented command VERBATIM (the same
# argv, from the repo root) and asserts the exact output the README states.
# A mismatch here means one of two things broke: the README drifted from the
# tool, or the tool drifted from the README -- either way the prose is now
# lying to a reader who pastes the command.
#
# Usage: test_walkthrough.sh
# Exit:  0 = every case matched, 1 = a case mismatched, 2 = environment error.
set -u
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root="$(cd "$here/../.." && pwd)"
wt="$root/ledger/examples/walkthrough"
extractor="$root/ledger/derive/extract_entries.py"
convergence="$root/ledger/derive/convergence.py"
law_dir="$root/ledger/contracts"
query="$law_dir/entries_query_apply.ncl"
compose_helper="$root/ledger/gate/compose_tag_registry.sh"
wt_registry="$wt/tag_registry.ncl"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

command -v python3 >/dev/null 2>&1 || { echo "ENV: python3 not found on PATH"; exit 2; }
command -v nickel >/dev/null 2>&1 || { echo "ENV: nickel not found on PATH"; exit 2; }
[ -d "$wt" ] || { echo "ENV: walkthrough dir missing: $wt"; exit 2; }
[ -f "$extractor" ] || { echo "ENV: extractor missing: $extractor"; exit 2; }
[ -f "$convergence" ] || { echo "ENV: convergence.py missing: $convergence"; exit 2; }
[ -f "$query" ] || { echo "ENV: query contract missing: $query"; exit 2; }
[ -f "$compose_helper" ] || { echo "ENV: compose helper missing: $compose_helper"; exit 2; }
[ -f "$wt_registry" ] || { echo "ENV: walkthrough tag registry missing: $wt_registry"; exit 2; }
# shellcheck source=/dev/null
. "$compose_helper"

# deposit.md/directions.md carry the walkthrough's own project-local tags
# ("perf", "gate-mechanism"), admitted the same way any adopting project's
# would be: composed in beside a scratch copy of the law
# (ledger/gate/compose_tag_registry.sh, shared with entries_integrity.sh and
# topic_query.sh) rather than by the plugin's own tag_registry.ncl, which
# ships empty by design (tech-debt/tag-registry-ships-predicate-vocabulary.yaml).
# refused/unadmitted-tag.md has no sibling registry of its own, so it stays
# checked against the plugin's bare (empty) $query below.
compose_tag_registry "$law_dir" "$wt_registry" "$tmp/wt-law"
wt_query="$COMPOSED_QUERY"

fails=0
# expect DESC EXPECTED-RC KEYWORD -- COMMAND...
#   KEYWORD="" skips the message check.
expect() {
  local desc="$1" exp="$2" kw="$3"; shift 3
  [ "$1" = "--" ] && shift
  local out rc ok=1
  out="$( cd "$root" && "$@" 2>&1 )"; rc=$?
  [ "$rc" -eq "$exp" ] || ok=0
  if [ -n "$kw" ]; then printf '%s' "$out" | grep -q -- "$kw" || ok=0; fi
  if [ "$ok" -eq 1 ]; then
    echo "PASS  ($rc) $desc"
  else
    echo "FAIL  (got rc=$rc want $exp; want-kw='$kw') $desc"
    printf '%s\n' "$out" | tail -5
    fails=$((fails + 1))
  fi
}

# --- "Run it": the extraction command, scoped to the corpus proper ---------

expect "run-it: scoped extract exits 0" 0 "" \
  -- python3 "$extractor" "$wt/deposit.md" "$wt/directions.md" -o "$tmp/wt.json"

expect "run-it: scoped extract counts 11/5/0" 0 "COUNTS-OK" \
  -- python3 - "$tmp/wt.json" <<'EOF'
import json, sys
d = json.load(open(sys.argv[1]))
assert len(d["entries"]) == 11, len(d["entries"])
assert len(d["directives"]) == 5, len(d["directives"])
assert len(d["findings"]) == 0, d["findings"]
print("COUNTS-OK")
EOF

# The README's parenthetical: pointing the extractor at the whole directory
# instead sweeps up README.md and refused/ too, and that costs a finding.
expect "run-it: unscoped (whole-dir) extract is INCOMPLETE, exit 3" 3 "pre-standard-doc" \
  -- python3 "$extractor" "$wt" -o "$tmp/wt-unscoped.json"

# --- "Ask what is open ...": the query over the scoped export ---------------

expect "run-it: query over the scoped export exits 0" 0 "" \
  -- bash -c "nickel export '$tmp/wt.json' --apply-contract '$wt_query' > '$tmp/q.json'"

expect "run-it: awaiting_human/runnable_now/unbacked are 1/1/1" 0 "QUERY-OK" \
  -- python3 - "$tmp/q.json" <<'EOF'
import json, sys
q = json.load(open(sys.argv[1]))
assert [r["id"] for r in q["awaiting_human"]] == ["deposit:W8"], q["awaiting_human"]
assert [r["id"] for r in q["runnable_now"]] == ["deposit:W12"], q["runnable_now"]
assert [r["id"] for r in q["unbacked"]] == ["deposit:W6"], q["unbacked"]
print("QUERY-OK")
EOF

# --- "Ask how far the work has got": convergence.py -------------------------

expect "run-it: convergence reports 1/5 (20.0%)" 0 "CORPUS: 1/5 questions discharged (20.0%)" \
  -- python3 "$convergence" "$tmp/wt.json"

expect "run-it: convergence names the one open terminal question" 0 "open  directions:W1-T1  \\[directive\\]" \
  -- python3 "$convergence" "$tmp/wt.json"

# --- "What it refuses": both demonstrations ---------------------------------

expect "refuses: unadmitted-tag extracts clean, exit 0" 0 "" \
  -- python3 "$extractor" "$wt/refused/unadmitted-tag.md" -o "$tmp/bad.json"
expect "refuses: unadmitted-tag is rejected by the tag registry, exit 1" 1 \
  "not in the admissible tag registry" \
  -- nickel export "$tmp/bad.json" --apply-contract "$query"

expect "refuses: dangling-reference is reported, exit 3" 3 \
  "qualified reference to an id the corpus does not declare" \
  -- python3 "$extractor" "$wt/refused/dangling-reference.md" -o "$tmp/bad2.json"

echo
if [ "$fails" -eq 0 ]; then echo "test_walkthrough: ALL PASS"; exit 0; fi
echo "test_walkthrough: $fails FAILURE(S)"; exit 1
