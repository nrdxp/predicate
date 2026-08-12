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

# --- node/provenance-gate: because carries TAGGED refs -----------------------
#
# CORRECTED under ruling-provenance-representation (ledger commit f257f6f),
# which WITHDRAWS the entry-level `external_refs` mirror this fixture
# originally pinned (ruling-provenance-gate, fcf009e) — the head challenged it
# as working around a shape rather than fixing it, and the architect's own
# words on the withdrawal: "the mirror was the hack." See
# 2026-08-12-failure-states [F20]-[F23] for the staleness episode this
# produced when the design changed but the (now-corrected) c13 guard in
# test_entry.sh still asserted the withdrawn shape.
#
# The ruled shape: `because` ALONE carries TAGGED refs, a record
# `{kind: corpus|external, name: ...}` — `depends`, `discharges`, `supersedes`
# stay plain corpus ids. This fixture isolates the case ibc-provenance-gate
# criterion 1 asks for: a `because` ref that is a corpus id and one that is
# external, BOTH on the same entry (X1's derives-from names `[K1]`, a
# declared corpus entry, and a wikilink), so a single golden pins both
# variants at once. TODAY the extractor still emits plain-string `because`
# and a separate `external_refs` sidecar key (the withdrawn shape); the
# golden below is the RULED target, so the diff is genuinely red until the
# extractor lands the tagged form and drops the sidecar. Criterion 1 also
# requires the sidecar key be ABSENT from the export entirely — checked
# directly below, not only implied by the diff.
#
# Criterion 7 ("a depends ref is untagged, if you can pin it, do"): the
# ledger-dialect grammar has NO `depends::` companion token at all — every
# existing fixture and this suite's own extraction goldens confirm the
# extractor has never emitted `depends` from markdown, only from hand-authored
# YAML. There is therefore no extraction-level golden that could pin
# depends-stays-untagged; that boundary is pinned at the contract layer
# instead (test_entry.sh's red-depends-wrongly-tagged.yaml). Noted rather
# than guessed at.
expect "provenance: mixed corpus+external claim extracts, exit 0" 0 "" \
  -- python3 "$extractor" "$fix/external-provenance-note.md" -o "$tmp/external-provenance-note.yaml"
expect "provenance: output carries tagged refs, both variants, one entry" 0 "" \
  -- diff "$fix/external-provenance-note.expected.json" "$tmp/external-provenance-note.yaml"
expect "provenance: no external_refs sidecar key survives in the export" 0 "NO-SIDECAR-OK" \
  -- python3 - "$tmp/external-provenance-note.yaml" <<'PYEOF'
import json, sys
export = json.load(open(sys.argv[1]))
assert "external_refs" not in export, export.keys()
print("NO-SIDECAR-OK")
PYEOF
expect "provenance: export passes the entry contract once tagged refs land" 0 "" \
  -- nickel export "$tmp/external-provenance-note.yaml" --apply-contract "$apply"

# --- resolve_qualified: the tagged branch, bound --------------------------
#
# `resolve_qualified` drops an unresolved QUALIFIED ref from `because` by
# comparing each tagged `{kind, name}` element's `name` — not the element
# itself — against the dangling ref, because `because` alone carries the
# tagged shape (every other edge stays a plain corpus-id list, ruling-
# provenance-representation). Reverting that branch to raw equality
# (`r != qual.ref` over the whole list) restores the exact silent failure a
# prior pass found and left unbound: a dict is never `==` a string, so the
# comparison always keeps every element, the dangling ref is reported but
# never actually removed, and `test_entries_extract.sh` stayed all-green
# across the revert with nothing here to notice. This fixture binds it: one
# qualified ref resolves, one does not, both inside the SAME `because`
# value, so only a correct per-name filter yields the one-element result
# below.
expect "provenance: dangling qualified because ref is reported, exit 3" 3 "nowhere-stem:K9" \
  -- python3 "$extractor" "$fix/dangling-because-note.md" -o "$tmp/dangling-because-note.yaml"
expect "provenance: resolve_qualified drops it from because, tagged branch bound" 0 "DANGLING-BECAUSE-OK" \
  -- python3 - "$tmp/dangling-because-note.yaml" <<'EOF'
import json, sys
export = json.load(open(sys.argv[1]))
entries = {e["id"]: e for e in export["entries"]}
because = entries["dangling-because-note:X1"].get("because", [])
# The resolvable ref survives, tagged; the dangling one is GONE, not merely
# unreported -- a raw-equality filter would leave both (see header above).
assert because == [
    {"kind": "corpus", "name": "dangling-because-note:K1"}], because
print("DANGLING-BECAUSE-OK")
EOF
expect "provenance: export passes the entry contract with the dangling ref dropped" 0 "" \
  -- nickel export "$tmp/dangling-because-note.yaml" --apply-contract "$apply"

# --- report reds: nothing malformed is silently skipped ----------------------

expect "red: unknown grade value is reported, exit 3" 3 "\"kind\": \"unknown-grade\"" \
  -- python3 "$extractor" "$fix/red-unknown-grade.md"
expect "red: unknown grade names the offending marker" 3 "K1" \
  -- python3 "$extractor" "$fix/red-unknown-grade.md"
expect "red: well-formed sibling still extracted alongside the report" 3 "red-unknown-grade:K2" \
  -- python3 "$extractor" "$fix/red-unknown-grade.md"

# The grade word above is spelled in plain letters; the one below carries a
# hyphen. The marker's grade capture is `grade::([^\s`]*)` — any non-space run
# — so both are read as nodes and both are reported through the same
# vocabulary check. What the case below adds is the WIDTH of that capture: its
# grade is the only one in this suite outside `[a-z]+`, and under a narrower
# capture its paragraph would stop being a node before the vocabulary was ever
# consulted and be dropped with nothing said.

expect "red: an invented grade word outside [a-z]+ is reported" 3 "" \
  -- python3 "$extractor" "$fix/red-invented-grade.md" -o "$tmp/invented.json"

expect "red: the invented grade is reported ON THE GRADE, not by accident" \
  0 "INVENTED-REPORTED-OK" \
  -- python3 - "$tmp/invented.json" <<'EOF'
import json, sys
export = json.load(open(sys.argv[1]))
findings = export["findings"]
# The accident this refuses: a paragraph whose marker line does not parse is
# no longer a node, and a companion span inside it is then reported as orphaned
# — an exit 3 that names a stray token and says nothing about the grade, on a
# node the reader is never told was dropped. The widened capture keeps this
# fixture off that path, and the offending paragraph carries no token span
# either; the assertion refuses the substitution outright rather than trusting
# both of those to hold.
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

# --- node/tags: the tags:: companion, and the four tag views -----------------
#
# tagged-note.md is the tags companion's extraction golden: four claims, one
# tagging a single direction, one tagging two (the co-occurrence case), one
# tagging the other direction alone, and one carrying no tags:: at all (the
# absence control). ledger/log/2026-08-12-tagging-hypothesis.md [G4]: ten of
# eleven wanted queries are tag SET OPERATIONS — by_tag, by_direction,
# co_occurrence and untagged answer them without ever traversing an edge.

expect "tags: clean tags-dialect doc exits 0" 0 "" \
  -- python3 "$extractor" "$fix/tagged-note.md" -o "$tmp/tagged-note.yaml"
expect "tags: output matches the expected JSON exactly" 0 "" \
  -- diff "$fix/tagged-note.expected.json" "$tmp/tagged-note.yaml"
expect "tags: export passes the entry contract" 0 "" \
  -- nickel export "$tmp/tagged-note.yaml" --apply-contract "$apply"

nickel export "$tmp/tagged-note.yaml" --apply-contract "$query" \
  > "$tmp/tagged-note-query.json" 2>/dev/null
expect "tags: the four views carry the fixture's known answers" 0 "TAG-VIEWS-OK" \
  -- python3 - "$tmp/tagged-note-query.json" <<'EOF'
import json, sys
q = json.load(open(sys.argv[1]))
# by_tag: keyed over the WHOLE registry (D1, D2, D3), not just what the
# corpus uses — D3 answers [] rather than being absent as a key.
assert q["by_tag"] == {
    "D1": ["tagged-note:K1", "tagged-note:K2"],
    "D2": ["tagged-note:K2", "tagged-note:K3"],
    "D3": [],
}, q["by_tag"]
# by_direction: today every registered tag IS a direction, so this coincides
# with by_tag exactly — the honest state of a registry with no non-direction
# tag yet (tag_registry.ncl's own header states this is expected, not a bug).
assert q["by_direction"] == q["by_tag"], (q["by_direction"], q["by_tag"])
# co_occurrence: only K2 carries both D1 and D2; no entry carries D3 at all.
assert q["co_occurrence"] == {
    "D1+D2": ["tagged-note:K2"],
    "D1+D3": [],
    "D2+D3": [],
}, q["co_occurrence"]
# untagged: the absence query. K4 alone carries no tags field.
assert q["untagged"] == ["tagged-note:K4"], q["untagged"]
print("TAG-VIEWS-OK")
EOF

# The live, still-untagged corpus's own honest starting state: ledger-note.md
# (this suite's pre-existing extraction golden) carries no tags:: anywhere, so
# `untagged` must return every one of its entries and both tag indices must be
# all-empty — never a silently dropped view over a corpus with nothing tagged.
nickel export "$tmp/ledger-note.yaml" --apply-contract "$query" \
  > "$tmp/ledger-note-tags-query.json" 2>/dev/null
expect "tags: an untagged corpus reports every entry as untagged" 0 "UNTAGGED-CORPUS-OK" \
  -- python3 - "$tmp/ledger-note.yaml" "$tmp/ledger-note-tags-query.json" <<'EOF'
import json, sys
export = json.load(open(sys.argv[1]))
q = json.load(open(sys.argv[2]))
all_ids = sorted(e["id"] for e in export["entries"])
assert sorted(q["untagged"]) == all_ids, (sorted(q["untagged"]), all_ids)
assert q["by_tag"] == {"D1": [], "D2": [], "D3": []}, q["by_tag"]
assert q["co_occurrence"] == {"D1+D2": [], "D1+D3": [], "D2+D3": []}, q["co_occurrence"]
print("UNTAGGED-CORPUS-OK")
EOF

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
# RETARGETED under ruling-provenance-representation (ledger commit f257f6f):
# because carries TAGGED refs now, and the external_refs sidecar is deleted
# entirely — see external-provenance-note's own header for the full account.
# Genuinely red today: the extractor still emits bare strings plus the
# sidecar.
assert entries["mixed-floor-note:X1"]["because"] == [
    {"kind": "corpus", "name": "mixed-floor-note:K1"},
    {"kind": "external", "name": "prior-art/floor-vocabulary"},
], entries["mixed-floor-note:X1"]
assert entries["mixed-floor-note:X2"]["because"] == [
    {"kind": "corpus", "name": "mixed-floor-note:X1"}
], entries["mixed-floor-note:X2"]
assert "external_refs" not in export, export.keys()
floors = {row["id"]: sorted(row["floors"]) for row in q["chain_floor"]}
assert floors["mixed-floor-note:K1"] == ["closed"], floors
assert floors["mixed-floor-note:X1"] == ["closed", "external"], floors
assert floors["mixed-floor-note:X2"] == ["closed", "external"], floors
print("BOTH-BRANCHES-OK")
EOF

# --- node/provenance-gate: unbacked view demonstration (criterion 9, 3/3) ----
#
# ruling-provenance-representation [SR2]: the `unbacked` view reassembles by
# hand, at read time, what the extractor split at write time — an O(corpus)
# scan over the `external_refs` sidecar per entry. That join is deleted; the
# view reads a because-tagged entry's own external share directly. But the
# repair visible from OUTSIDE the view is upstream of it: TODAY an unclosed
# claim whose sole provenance is external cannot pass `entry_apply.ncl` at
# all (ProvenanceGate refuses it), so it can never REACH `unbacked` — refused
# by structural unreachability, not by any computation of the view's own.
# Post-fix the whole corpus validates and the entry appears in `unbacked`'s
# rows.
#
# Hand-authored corpus (ledger/fixtures/entry/corpus-unbacked-external-demo.
# yaml, not routed through the extractor — a direct Nickel contract
# application over a constructed value, per the binding constraint), three
# entries: a closed leaf (e-closed), a because-tagged-CORPUS control
# (e-walkable), and the because-tagged-EXTERNAL demo (e-external-only).
#
# TODAY this whole query fails at SHAPE (NonEmptyString on the tagged
# `because` element) before any view is computed — verified directly.
# Post-fix it must succeed, and the three assertions below are pinned with
# DIFFERING confidence, stated as such rather than uniformly asserted:
#   - e-external-only appears in unbacked's rows at all: HIGH confidence —
#     this is the repair itself, and any design failing to reach it fails
#     the node's own goal.
#   - e-walkable is `backed: true`, e-external-only is `backed: false`: HIGH
#     confidence — [SR8] names `unbacked` a consumer of `corpus_edges_of`
#     specifically (the walkable subset), not `provenance_of`, so `backed`
#     keeping its current meaning ("has a corpus edge") rather than becoming
#     a now-redundant always-true field is the reading that makes the field
#     still worth having.
#   - the external citation ("docs/entries.md") is visible SOMEWHERE in
#     e-external-only's row: LOWER confidence on the exact field name (the
#     ruling describes the COMPUTATION simplifying, not the output shape
#     changing, so keeping the existing `external_refs` key is the
#     assumption here) — checked by substring over the row's own JSON
#     rendering rather than a specific key path, so a reasonable rename
#     still satisfies it.
nickel export "$root/ledger/fixtures/entry/corpus-unbacked-external-demo.yaml" \
  --apply-contract "$query" > "$tmp/unbacked-demo.json" 2>"$tmp/unbacked-demo.err"
unbacked_demo_rc=$?
unbacked_demo_ok=1
if [ "$unbacked_demo_rc" -ne 0 ]; then
  unbacked_demo_ok=0
else
  python3 - "$tmp/unbacked-demo.json" <<'EOF' || unbacked_demo_ok=0
import json, sys
q = json.load(open(sys.argv[1]))
rows = {row["id"]: row for row in q["unbacked"]}
assert "e-external-only" in rows, sorted(rows)
assert rows["e-walkable"]["backed"] is True, rows["e-walkable"]
assert rows["e-external-only"]["backed"] is False, rows["e-external-only"]
assert "docs/entries.md" in json.dumps(rows["e-external-only"]), rows["e-external-only"]
print("UNBACKED-DEMO-OK")
EOF
fi
if [ "$unbacked_demo_ok" -eq 1 ]; then
  echo "PASS  (rc=$unbacked_demo_rc) unbacked: external-only claim now reachable and correctly classified"
else
  echo "FAIL  (rc=$unbacked_demo_rc) unbacked: external-only claim now reachable and correctly classified"
  tail -5 "$tmp/unbacked-demo.err" "$tmp/unbacked-demo.json" 2>/dev/null
  fails=$((fails + 1))
fi

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

# The assertive form arrives MALFORMED as often as not, and the detector is
# measured against "the paragraph OPENS with the marker" — never "the paragraph
# contains a closed pair". The two readings agree on every fixture above, so
# neither the pair nor the census goldens can tell them apart: the case below is
# the only one in this suite that separates them. Matching on the closing pair
# drops an unmarked claim unreported, which is precisely the evasion the report
# exists to see, and a writer declining to type a claim is not thereby careful
# about closing its emphasis.
#
# This case is red against the pair-matching form
# (`if (lead := BOLD_LEAD_RE.match(block)) is not None`) and green against the
# committed `block.startswith("**")`. Verified in both directions rather than
# assumed: the suite ran green over an exact reversal of that fix, so a case
# here that does not discriminate is worth nothing at all.

expect "unclosed lead: an unclosed bold lead is still reported" 3 "" \
  -- python3 "$extractor" "$fix/red-unclosed-lead.md" -o "$tmp/unclosed.json"

expect "unclosed lead: reported from the whole-paragraph fallback" \
  0 "UNCLOSED-LEAD-OK" \
  -- python3 - "$tmp/unclosed.json" <<'EOF'
import json, sys
export = json.load(open(sys.argv[1]))
findings = export["findings"]
unmarked = [f for f in findings if f["kind"] == "unmarked-assertion"]
assert [f["doc"] for f in unmarked] == ["red-unclosed-lead"], findings
# The excerpt keeps its literal asterisks. The bold-lead branch strips them
# through its capture group, so their presence is the proof that the report
# came from the whole-paragraph fallback — not from a pair that closed
# somewhere further along and made the case green for the wrong reason.
[reason] = [f["reason"] for f in unmarked]
assert reason.startswith("`**Unclosed emphasis is still emphasis"), reason
# Nothing else fired, so the exit 3 above is THIS finding and not an unplaced
# token or an orphaned companion arriving by accident.
assert len(findings) == 1, findings
# Preservation, stated as such: the document's one graded node still extracts.
assert [e["id"] for e in export["entries"]] == ["red-unclosed-lead:U1"], \
    export["entries"]
print("UNCLOSED-LEAD-OK")
EOF

# The scoping rule is decided over the WHOLE document, and the report is held
# back until the document has been read for exactly that reason: whether an
# untyped claim is a defect depends on whether the file grades anything, which
# is unknown at the paragraph where the claim is written. Every fixture above
# places its untyped claim AFTER the graded node, where a detector deciding
# scope at the paragraph agrees with one deciding it at the end — so none of
# them can tell the two readings apart, and the deferral rides on all of them
# unpinned.
#
# The fixture below inverts the order. It is red against the inline-decision
# form (reporting each lead as it is read, under the flag's value at that
# point) and green against the committed deferral. Verified in both directions
# in a scratch copy rather than assumed, on the standard this node adopted when
# the suite ran green over an exact reversal of the fix above.

expect "preceding assertion: an untyped claim above the first node is reported" \
  3 "" \
  -- python3 "$extractor" "$fix/red-preceding-assertion.md" -o "$tmp/preceding.json"

expect "preceding assertion: scope is decided over the whole document" \
  0 "PRE-NODE-REPORTED-OK" \
  -- python3 - "$tmp/preceding.json" <<'EOF'
import json, sys
export = json.load(open(sys.argv[1]))
findings = export["findings"]
unmarked = [f for f in findings if f["kind"] == "unmarked-assertion"]
assert [f["doc"] for f in unmarked] == ["red-preceding-assertion"], findings
# The excerpt names the claim standing ABOVE the node, so the report is about
# that paragraph and not about some later one the fixture also carries.
[reason] = [f["reason"] for f in unmarked]
assert reason.startswith("`Scope is a property of the document, not of the "
                         "reader.`"), reason
# Nothing else fired, so the exit 3 above is THIS finding and not an unplaced
# token or an orphaned companion arriving by accident.
assert len(findings) == 1, findings
# What the deferral costs, stated rather than left implicit: by the time the
# report is raised the paragraph's position is gone, so the finding can name no
# marker — unlike orphaned-companion, which attributes to the nearest preceding
# one. Green at this tip; it is the clause that speaks up if attribution is
# ever added without moving the decision back to the paragraph.
assert [f["marker"] for f in unmarked] == [None], unmarked
# Preservation, stated as such: the document's one graded node still extracts.
assert [e["id"] for e in export["entries"]] == ["red-preceding-assertion:U1"], \
    export["entries"]
print("PRE-NODE-REPORTED-OK")
EOF

# --- the grading flag: set from the marker parse, not from a passing grade ---
#
# extract_entries.py sets `grades_its_claims = True` as soon as a marker
# parses, BEFORE its grade word is checked against the vocabulary. So a
# document whose only marker carries a REJECTED grade still counts as
# grading its claims, and an unmarked assertion elsewhere in it is still
# reported rather than falling silent alongside the failed node.
#
# The merge gate ruled this placement correct, on evidence: reporting
# over-reports on a document that typed nothing — noise, visible,
# actionable. Not reporting lets a document that ATTEMPTS the discipline and
# fails silence the detector across all its prose, and the exit code is 3
# either way, so no exit-code gate can see that loss. It did not block only
# because the affected class was empty at the time (185 documents, 66
# graded, zero with every marker invalid) — this case is the pin the gate
# queued rather than assumed.

expect "invalid-only doc: the failed marker is reported" 3 "unknown-grade" \
  -- python3 "$extractor" "$fix/red-invalid-grade-unmarked.md" -o "$tmp/invalid-only.json"

expect "invalid-only doc: the unmarked assertion below it is reported too" \
  0 "INVALID-ONLY-GRADES-OK" \
  -- python3 - "$tmp/invalid-only.json" <<'EOF'
import json, sys
export = json.load(open(sys.argv[1]))
findings = export["findings"]
# The pin: the document's ONLY marker failed the vocabulary check, and the
# unmarked paragraph is reported anyway — proof the flag was set from the
# marker parse, not from a grade that passed the vocabulary check.
assert any(f["kind"] == "unknown-grade" for f in findings), findings
assert any(f["kind"] == "unmarked-assertion" for f in findings), findings
assert len(findings) == 2, findings
assert export["entries"] == [], export["entries"]
print("INVALID-ONLY-GRADES-OK")
EOF

echo
if [ "$fails" -eq 0 ]; then echo "test_entries_extract: ALL PASS"; exit 0; fi
echo "test_entries_extract: $fails FAILURE(S)"; exit 1
