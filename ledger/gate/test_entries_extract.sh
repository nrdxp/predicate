#!/usr/bin/env bash
# Suite for the typed-claim extractor (ledger/derive/extract_entries.py) and
# the query over its export (ledger/contracts/entries_query.ncl).
#
# The extractor is TRUSTED MACHINERY: a query result is `proved` only relative
# to extractor fidelity, so its fixture suite is golden-vector-driven:
#
#   - CENSUS goldens: graded documents publish their own token census in a §7
#     fenced block (the output of the two commands their legend states). The
#     extractor's --census must reproduce that block byte-for-byte, and the
#     expected block is read FROM THE FIXTURE ITSELF — the golden is the
#     document's own published count, never a second copy that can go stale.
#   - EXTRACTION golden: a synthetic ledger-dialect fixture whose expected
#     JSON is exact by construction; the export must also pass the EXISTING
#     entry_apply.ncl (the extractor never re-implements the law).
#   - REPORT reds: malformed or partially-typed input is REPORTED with exit 3,
#     never silently skipped — a silently dropped node is a query result that
#     is confidently incomplete.
#
# Usage: test_entries_extract.sh
# Exit:  0 = every case matched, 1 = a case mismatched, 2 = environment error.
set -u
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root="$(cd "$here/../.." && pwd)"
fix="$root/ledger/fixtures/extract"
extractor="$root/ledger/derive/extract_entries.py"
query="$root/ledger/contracts/entries_query.ncl"
apply="$root/ledger/contracts/entry_apply.ncl"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

command -v python3 >/dev/null 2>&1 || { echo "ENV: python3 not found on PATH"; exit 2; }
command -v nickel >/dev/null 2>&1 || { echo "ENV: nickel not found on PATH"; exit 2; }
[ -d "$fix" ] || { echo "ENV: fixtures dir missing: $fix"; exit 2; }
[ -f "$apply" ] || { echo "ENV: apply-file missing: $apply"; exit 2; }

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

# published_census FILE — the §7 fenced block the document itself publishes.
published_census() {
  awk '/^## 7/{s=1; next} s && /^```/{f++; next} f==1{print} f>=2{exit}' "$1"
}

# --- census goldens: the published §7 blocks, byte-for-byte ------------------

for doc in ibc-pass1 ibc-pass2b; do
  published_census "$fix/$doc.md" > "$tmp/$doc.golden"
  python3 "$extractor" --census "$fix/$doc.md" > "$tmp/$doc.census" 2>/dev/null
  expect "census golden: $doc reproduces its published §7 block" 0 "" \
    -- diff "$tmp/$doc.golden" "$tmp/$doc.census"
done

# The synthetic fixture has no §7 section: the census covers the whole file,
# fence content included (the published commands count raw text).
cat > "$tmp/ledger-note.golden" <<'EOF'
      3 grade::synthesis
      3 grade::cited
      2 grade::proved
      1 grade::routed
      1 grade::residual
      1 grade::frontier
      1 grade::dispatchable
      1 grade::directive
---
14
EOF
python3 "$extractor" --census "$fix/ledger-note.md" > "$tmp/ledger-note.census" 2>/dev/null
expect "census: whole-file scope when no §7 section exists" 0 "" \
  -- diff "$tmp/ledger-note.golden" "$tmp/ledger-note.census"

# --- extraction golden: the synthetic ledger-dialect fixture -----------------

expect "extract: clean ledger-dialect doc exits 0" 0 "" \
  -- python3 "$extractor" "$fix/ledger-note.md" -o "$tmp/ledger-note.yaml"
expect "extract: output matches the expected JSON exactly" 0 "" \
  -- diff "$fix/ledger-note.expected.json" "$tmp/ledger-note.yaml"
expect "extract: export passes the EXISTING entry contract" 0 "" \
  -- nickel export "$tmp/ledger-note.yaml" --apply-contract "$apply"

# --- report reds: nothing malformed is silently skipped ----------------------

expect "red: unknown grade value is reported, exit 3" 3 "\"kind\": \"unknown-grade\"" \
  -- python3 "$extractor" "$fix/red-unknown-grade.md"
expect "red: unknown grade names the offending marker" 3 "K1" \
  -- python3 "$extractor" "$fix/red-unknown-grade.md"
expect "red: well-formed sibling still extracted alongside the report" 3 "red-unknown-grade:K2" \
  -- python3 "$extractor" "$fix/red-unknown-grade.md"

expect "red: vocabulary token outside a marker is reported" 3 "\"kind\": \"unplaced-token\"" \
  -- python3 "$extractor" "$fix/red-unplaced-token.md"
expect "red: unknown companion token is reported" 3 "\"kind\": \"unknown-companion\"" \
  -- python3 "$extractor" "$fix/red-unplaced-token.md"

expect "red: pre-standard doc (no signer:: header) is reported whole" 3 "\"kind\": \"pre-standard-doc\"" \
  -- python3 "$extractor" "$fix/ibc-pass1.md"

expect "red: source:: same with no prior source is reported" 3 "\"kind\": \"unresolved-anaphora\"" \
  -- python3 "$extractor" "$fix/red-orphan-same.md"

expect "red: signer kind outside the five modes is reported" 3 "\"kind\": \"bad-header\"" \
  -- python3 "$extractor" "$fix/red-bad-header.md"

expect "red: a companion one paragraph late is reported, exit 3" 3 "\"kind\": \"orphaned-companion\"" \
  -- python3 "$extractor" "$fix/red-orphaned-companion.md"
expect "red: orphaned companion names the marker it cannot attach to" 3 "\"marker\": \"X1\"" \
  -- python3 "$extractor" "$fix/red-orphaned-companion.md"
expect "red: the node itself still extracts, without the dropped edge" 3 "red-orphaned-companion:K1" \
  -- python3 "$extractor" "$fix/red-orphaned-companion.md"

# Duplicate markers: the extractor emits both and the CONTRACT's id-uniqueness
# red catches the collision — the runner never re-implements an invariant.
expect "red: duplicate marker extracts without extractor error" 0 "" \
  -- python3 "$extractor" "$fix/red-dup-marker.md" -o "$tmp/dup.yaml"
expect "red: duplicate marker is EntryStore's red" 1 "duplicate entry id" \
  -- nickel export "$tmp/dup.yaml" --apply-contract "$apply"

# --- the query: a Nickel evaluation over the validated export ----------------
#
# Applying the query IS applying the law first: entries_query.ncl runs the
# corpus through entry_apply.ncl before computing any view, so an invalid
# export never yields a query result. Bash invokes; the assertions on the
# result are decided in python over the parsed JSON, never in shell logic.

expect "query: evaluates over the validated export" 0 "awaiting_human" \
  -- nickel export "$tmp/ledger-note.yaml" --apply-contract "$query"
nickel export "$tmp/ledger-note.yaml" --apply-contract "$query" \
  > "$tmp/query.json" 2>/dev/null
expect "query: the four views carry the fixture's known answers" 0 "VIEWS-OK" \
  -- python3 - "$tmp/query.json" <<'EOF'
import json, sys
q = json.load(open(sys.argv[1]))
ids = lambda view: [row["id"] for row in view]
assert ids(q["awaiting_human"]) == ["ledger-note:R1"], q["awaiting_human"]
assert ids(q["runnable_now"]) == ["ledger-note:Q1"], q["runnable_now"]
assert q["unpaid_cures"]["violations"] == [], q["unpaid_cures"]
assert q["unpaid_cures"]["unassessed"] == [
    f"ledger-note:{m}" for m in ["K1", "K2", "K3", "K4", "X1", "X2", "X3"]
], q["unpaid_cures"]
unbacked = {row["id"]: row for row in q["unbacked"]}
assert sorted(unbacked) == [f"ledger-note:{m}" for m in ["X1", "X2", "X3"]]
assert unbacked["ledger-note:X1"]["backed"] is True
assert unbacked["ledger-note:X2"]["backed"] is False
assert unbacked["ledger-note:X2"]["external_refs"] == [
    "process-feedback/tc-concurrent-writer"
]
print("VIEWS-OK")
EOF

expect "query: an invalid corpus never yields a result" 1 "duplicate entry id" \
  -- nickel export "$tmp/dup.yaml" --apply-contract "$query"

# --- the amendment: recovered edges, designations, axes ----------------------
#
# amendment-note.md is the amendment's extraction golden: discharges:: and
# supersedes:: parse to corpus-resolved edges, closer:: parses designations
# (machine is a legacy alias for kind-agent-unnamed), and axes::/freshness::
# parse into the contract's Axes shape (polarity tokens: `+determined
# -certifiable`; certifiable omitted where determination fails — the fibering
# must be expressible). The queries over its export prove openness (open = no
# inbound discharges and no inbound supersedes among resolved edges) and the
# chain-floor report. The golden pins entry field ORDER deliberately: the
# existing emission blocks stay where they are, and the new fields append in
# the order axes, freshness, discharges, supersedes.

expect "amendment: clean amendment-dialect doc exits 0" 0 "" \
  -- python3 "$extractor" "$fix/amendment-note.md" -o "$tmp/amendment-note.yaml"
expect "amendment: output matches the expected JSON exactly" 0 "" \
  -- diff "$fix/amendment-note.expected.json" "$tmp/amendment-note.yaml"
expect "amendment: export passes the entry contract" 0 "" \
  -- nickel export "$tmp/amendment-note.yaml" --apply-contract "$apply"

nickel export "$tmp/amendment-note.yaml" --apply-contract "$query" \
  > "$tmp/amendment-query.json" 2>/dev/null
expect "amendment: openness filters the views; chain-floor reports" 0 "AMEND-VIEWS-OK" \
  -- python3 - "$tmp/amendment-query.json" <<'EOF'
import json, sys
q = json.load(open(sys.argv[1]))
ids = lambda view: [row["id"] for row in view]
# R1 discharged by K1, Q3 superseded by R2: both leave awaiting_human.
assert ids(q["awaiting_human"]) == ["amendment-note:R2"], q["awaiting_human"]
# Q2 discharged by K2: it leaves runnable_now.
assert ids(q["runnable_now"]) == ["amendment-note:Q1"], q["runnable_now"]
# The chain-floor: where each claim's support bottoms out, transitively.
floors = {row["id"]: sorted(row["floors"]) for row in q["chain_floor"]}
assert floors["amendment-note:X1"] == ["closed"], floors
assert floors["amendment-note:X2"] == ["closed", "unbacked"], floors
assert floors["amendment-note:X3"] == ["external"], floors
assert floors["amendment-note:X4"] == ["unbacked"], floors
print("AMEND-VIEWS-OK")
EOF

# --- the mention/use rule ----------------------------------------------------
#
# An empty-valued span of ANY MAPPED token is a MENTION in prose, not a use:
# excluded from extraction, never emitted as a field — and never allowed to
# clobber a real use earlier in the node. Whether the extractor additionally
# emits an informational finding is delegated, so the exit is allowed to be
# 0 or 3; the pinned invariants are the export's fields and its validity.
python3 "$extractor" "$fix/mention-empty-companion.md" \
  -o "$tmp/mention.yaml" 2>"$tmp/mention.err"; mrc=$?
nickel export "$tmp/mention.yaml" --apply-contract "$apply" \
  > /dev/null 2>&1; nrc=$?
mention_ok=1
{ [ "$mrc" -eq 0 ] || [ "$mrc" -eq 3 ]; } || mention_ok=0
[ "$nrc" -eq 0 ] || mention_ok=0
python3 - "$tmp/mention.yaml" <<'EOF' || mention_ok=0
import json, sys
doc = json.load(open(sys.argv[1]))
[k1] = [e for e in doc["entries"] if e["id"] == "mention-empty-companion:K1"]
assert "discharge" not in k1, k1
assert "closer" not in k1, k1
assert "witness" not in k1, k1
assert k1["check"]["command"] == "true", k1
EOF
if [ "$mention_ok" -eq 1 ]; then
  echo "PASS  (extract=$mrc nickel=$nrc) mention: empty-valued known tokens are mentions, excluded"
else
  echo "FAIL  (extract=$mrc nickel=$nrc) mention: empty-valued known tokens are mentions, excluded"
  fails=$((fails + 1))
fi

# An unparseable closer designation is REPORTED, never guessed.
expect "red: unparseable closer designation is reported, exit 3" 3 "bad-closer" \
  -- python3 "$extractor" "$fix/red-closer-unparseable.md"
expect "red: unparseable closer names its marker" 3 "\"marker\": \"R1\"" \
  -- python3 "$extractor" "$fix/red-closer-unparseable.md"

echo
if [ "$fails" -eq 0 ]; then echo "test_entries_extract: ALL PASS"; exit 0; fi
echo "test_entries_extract: $fails FAILURE(S)"; exit 1
