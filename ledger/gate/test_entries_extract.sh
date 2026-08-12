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

# The grade word above is spelled in plain letters, and that is the ONLY
# invented grade the marker pattern matches: `grade::([a-z]+)`. A grade word
# carrying a hyphen, a digit, or a capital does not match the pattern at all,
# so the paragraph stops being a node before the vocabulary is ever consulted
# and the report above cannot fire. The case below covers that half.

expect "red: an invented grade word outside [a-z]+ is reported" 3 "" \
  -- python3 "$extractor" "$fix/red-invented-grade.md" -o "$tmp/invented.json"

expect "red: the invented grade is reported ON THE GRADE, not by accident" \
  0 "INVENTED-REPORTED-OK" \
  -- python3 - "$tmp/invented.json" <<'EOF'
import json, sys
export = json.load(open(sys.argv[1]))
findings = export["findings"]
# The accident this refuses: when a marker line fails to parse, its paragraph
# is no longer a node, so any companion span inside it is reported as orphaned
# — an exit 3 that names a stray token and says nothing about the grade, on a
# node the reader is never told was dropped. The fixture carries no token span
# in the offending paragraph so that path cannot fire, and the assertion
# refuses it outright rather than trusting the fixture to stay that way.
assert all(f["kind"] != "orphaned-companion" for f in findings), findings
named = [f for f in findings if f["marker"] == "G1"]
assert named, findings
# A finding the reader cannot act on is not a report: it must name the word.
assert any("self-evident" in f["reason"] for f in named), named
# Preservation, stated as such: the well-formed sibling is untouched. This
# clause is green at the pre-edit tree — it pins the blast radius, not the fix.
assert [e["id"] for e in export["entries"]] == ["red-invented-grade:G2"], \
    export["entries"]
print("INVENTED-REPORTED-OK")
EOF

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
# `backed` is TRUE for every row, and cannot be otherwise in a corpus the
# contract admits: the view selects unclosed claims, and ProvenanceGate
# refuses exactly those with no derivation edge. The field therefore reports
# a property the law already enforces. Asserted over the whole view rather
# than one row so the redundancy is pinned as such — the day ProvenanceGate
# narrows, this is the assertion that fails and says why.
assert all(row["backed"] for row in q["unbacked"]), q["unbacked"]
# X2's external ref sits BESIDE its derivation edge, never in place of one:
# `edges_of` is derivation-only, so a `derives-from::` naming something
# outside the corpus is preserved here and satisfies the gate not at all.
assert unbacked["ledger-note:X2"]["edges"] == ["ledger-note:K2"], unbacked
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

# --- the mixed floor: an external branch BESIDE an internal one --------------
#
# The amendment golden above reaches `external` only from an EDGE-FREE leaf,
# so the branching case stays unpinned: an entry carrying a resolvable
# derivation edge AND an external ref at once. `chain_floor` walks the edges
# through its fixed point and consults the entry's own external refs nowhere
# along that path, so the out-of-corpus branch is dropped and a claim whose
# support genuinely leaves the record reports a clean floor set — the
# overconfident reading this view exists to refuse.
#
# X1 is the direct case: one edge onto a corroborated claim, one wikilink the
# corpus cannot follow. X2 rests on X1 alone, so it pins the union
# PROPAGATING — a repair applied where the rows are assembled, rather than
# inside the fixed point they are read from, would satisfy X1 and lose X2. K1
# is the control: the internal branch really does bottom out `closed`, so a
# failure here is the missing external branch and nothing else.

expect "mixed floor: clean fixture extracts, exit 0" 0 "" \
  -- python3 "$extractor" "$fix/mixed-floor-note.md" -o "$tmp/mixed-floor.yaml"
expect "mixed floor: export passes the entry contract" 0 "" \
  -- nickel export "$tmp/mixed-floor.yaml" --apply-contract "$apply"

nickel export "$tmp/mixed-floor.yaml" --apply-contract "$query" \
  > "$tmp/mixed-floor-query.json" 2>/dev/null
expect "mixed floor: external branch reported beside the internal one" \
  0 "BOTH-BRANCHES-OK" \
  -- python3 - "$tmp/mixed-floor.yaml" "$tmp/mixed-floor-query.json" <<'EOF'
import json, sys
export = json.load(open(sys.argv[1]))
q = json.load(open(sys.argv[2]))
entries = {e["id"]: e for e in export["entries"]}
# The INPUT first: the corpus carries both branches and the query is handed
# both, so a floor assertion below can only be about how they were read —
# never a lost fixture, a dropped edge, or a changed extractor.
assert entries["mixed-floor-note:X1"]["because"] == ["mixed-floor-note:K1"]
assert entries["mixed-floor-note:X2"]["because"] == ["mixed-floor-note:X1"]
assert export["external_refs"] == [
    {"entry": "mixed-floor-note:X1", "refs": ["prior-art/floor-vocabulary"]}
], export["external_refs"]
floors = {row["id"]: sorted(row["floors"]) for row in q["chain_floor"]}
assert floors["mixed-floor-note:K1"] == ["closed"], floors
assert floors["mixed-floor-note:X1"] == ["closed", "external"], floors
assert floors["mixed-floor-note:X2"] == ["closed", "external"], floors
print("BOTH-BRANCHES-OK")
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

# --- the unmarked assertion, and the prose it must not swallow ---------------
#
# Every report above fires on a claim that was MARKED and then malformed. The
# claim that is never marked at all is invisible by construction, so "simply
# do not mark it" evades the whole discipline at no cost — the one evasion the
# grammar cannot see.
#
# It is detectable because the record has a shape: a claim occupies its own
# paragraph and opens with its marker, and the unmarked claims that remain
# open in the document's own assertive form (a bolded lead). Measured over the
# landed record at the time of writing, that form scopes cleanly ONLY when the
# document is known to grade its claims at all:
#
#   documents carrying >=1 graded node   30 docs,   29 such paragraphs
#   documents with a header, no nodes    40 docs,  350 such paragraphs
#   documents with no header at all       5 docs,   23 such paragraphs
#
# So the scoping predicate is "this document carries a graded node", NOT "the
# extractor could read this document". The header is not the discriminator:
# 350 of the 373 untyped paragraphs sit in documents whose header parses
# perfectly, and a detector scoped on the header reports every one of them.
#
# The two fixtures below are a MINIMAL PAIR — the same assertive paragraph,
# character for character, differing only in whether a graded node precedes
# it. A detector that reports both, or neither, fails one of them.

expect "bare assertion: an unmarked claim in a grading document is reported" 3 "" \
  -- python3 "$extractor" "$fix/red-bare-assertion.md" -o "$tmp/bare.json"

expect "bare assertion: the report is raised and the graded node survives" \
  0 "BARE-REPORTED-OK" \
  -- python3 - "$tmp/bare.json" <<'EOF'
import json, sys
export = json.load(open(sys.argv[1]))
# The finding KIND is this suite's proposal, in the naming convention the
# extractor already uses (unplaced-token, unknown-companion, bad-closer). If
# the implementation lands a different name, this is the one line to change —
# the assertion is about the report existing, not about the word.
assert any(f["kind"] == "unmarked-assertion" for f in export["findings"]), \
    export["findings"]
# Preservation, stated as such and green at the pre-edit tree: the document's
# one properly graded node still extracts. Without it a detector that reported
# the MARKED paragraph as well would satisfy the assertion above.
assert [e["id"] for e in export["entries"]] == ["red-bare-assertion:U1"], \
    export["entries"]
print("BARE-REPORTED-OK")
EOF

expect "ungraded prose: the same shape where nothing is graded is silent" 0 "" \
  -- python3 "$extractor" "$fix/green-ungraded-prose.md" -o "$tmp/ungraded.json"

expect "ungraded prose: no finding is raised against untyped legacy prose" \
  0 "UNGRADED-SILENT-OK" \
  -- python3 - "$tmp/ungraded.json" <<'EOF'
import json, sys
export = json.load(open(sys.argv[1]))
# The false-positive guard. It is GREEN at the pre-edit tree — no detector
# exists to misfire yet — and becomes load-bearing the moment the case above
# is implemented. It is the 350 live paragraphs' only defence.
assert export["findings"] == [], export["findings"]
assert export["entries"] == [], export["entries"]
print("UNGRADED-SILENT-OK")
EOF

# The guard only guards while the pair stays minimal: if the two fixtures drift
# apart, a detector could pass both on a difference nobody intended to test.
# Green at the pre-edit tree, and asserted rather than trusted.
expect "the pair differs only by the presence of a graded node" 0 "PAIR-MINIMAL-OK" \
  -- python3 - "$fix/red-bare-assertion.md" "$fix/green-ungraded-prose.md" <<'EOF'
import re, sys
def blocks(path):
    text = open(path, encoding="utf-8").read()
    return [" ".join(b.split()) for b in re.split(r"\n\s*\n", text) if b.strip()]
red, green = blocks(sys.argv[1]), blocks(sys.argv[2])
shared = [b for b in red if b.startswith("**")]
assert len(shared) == 1, shared
assert shared[0] in green, (shared[0], green)
# And the difference really is the graded node: exactly one side has one.
marked = lambda bs: [b for b in bs if re.match(r"`\[[A-Za-z][A-Za-z0-9-]*\] grade::", b)]
assert marked(red) and not marked(green), (marked(red), marked(green))
print("PAIR-MINIMAL-OK")
EOF

echo
if [ "$fails" -eq 0 ]; then echo "test_entries_extract: ALL PASS"; exit 0; fi
echo "test_entries_extract: $fails FAILURE(S)"; exit 1
