#!/usr/bin/env bash
# Suite for CORPUS-WIDE reference resolution in the typed-claim extractor
# (ledger/derive/extract_entries.py) and the edges its export hands to
# ledger/contracts/entry_apply.ncl.
#
# test_entries_extract.sh already covers reference handling INSIDE one
# document — that suite's fixtures are single files, and every edge in them
# resolves against the document that wrote it. This suite covers the axis
# that begins at the second document, and nothing else:
#
#   QUALIFIED  `[stem:ID]` is an explicit authorial declaration that the
#              target lives in the corpus. It resolves across documents, in
#              closure edges and derivation edges alike, and an unresolvable
#              one is REPORTED — never filed as external provenance, which
#              would read as a deliberate pointer outside the record rather
#              than as the mistake it is.
#   PLAIN      `[ID]` is doc-local, unconditionally. It does not widen to the
#              corpus when the local lookup misses, and it does not prefer a
#              same-named target next door. A reference whose scope depended
#              on what else the record contained would not be authored.
#   WIKILINK   `[[text]]` is external, ALWAYS — including when its text reads
#              exactly like a corpus id. Auto-resolving it would let an
#              external name colliding with an id flip a question from open
#              to closed with nobody declaring the crossing, and would make
#              resolution depend on extraction scope. Loud dangling beats
#              silent capture.
#
# Fixtures are multi-document corpora under ledger/fixtures/extract/corpus-ids/,
# extracted a DIRECTORY at a time — the smallest record on which crossing a
# document boundary is a question at all. Each corpus is its own directory
# because their expected validity differs: `plainfall/` is a corpus the entry
# contract must REFUSE, and a corpus that cannot export cannot host a query.
#
# Two of them reproduce, in miniature, the two closure attempts the live
# record exports as broken edges — one aimed at an id in another document,
# one at a note outside the corpus. Both are written as wikilinks, so both
# stay reported: the repair for the first is authorial (rewrite it in the
# qualified form), which is exactly the case wikilink/ pins.
#
# Usage: test_corpus_ids.sh
# Exit:  0 = every case matched, 1 = a case mismatched, 2 = environment error.
set -u
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root="$(cd "$here/../.." && pwd)"
fix="$root/ledger/fixtures/extract/corpus-ids"
extractor="$root/ledger/derive/extract_entries.py"
apply="$root/ledger/contracts/entry_apply.ncl"
query="$root/ledger/contracts/entries_query_apply.ncl"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

command -v python3 >/dev/null 2>&1 || { echo "ENV: python3 not found on PATH"; exit 2; }
command -v nickel >/dev/null 2>&1 || { echo "ENV: nickel not found on PATH"; exit 2; }
[ -d "$fix" ] || { echo "ENV: fixtures dir missing: $fix"; exit 2; }
[ -f "$extractor" ] || { echo "ENV: extractor missing: $extractor"; exit 2; }
[ -f "$apply" ] || { echo "ENV: apply-file missing: $apply"; exit 2; }
[ -f "$query" ] || { echo "ENV: query missing: $query"; exit 2; }

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

# Every extractor invocation writes its export to a file rather than stdout.
# The export echoes the very ids the findings name, so a stdout-borne export
# would satisfy a stderr keyword check on its own and the assertion would
# report nothing about whether the finding was made.

# --- xdoc/: a qualified reference crosses; a plain one does not -------------
#
# One corpus, two documents, one marker name (`Q1`) deliberately used in both:
# the plain edge must land on its own document's Q1 while the other stays in
# the work list. The two crossings — a discharge and a supersession — are the
# two closure edges, and the derivation edge crosses beside a local one so
# both branches of a single value are read.

expect "xdoc: a corpus of resolvable references reports nothing" 0 "" \
  -- python3 "$extractor" "$fix/xdoc" -o "$tmp/xdoc.json"
expect "xdoc: the export passes the entry contract" 0 "" \
  -- nickel export "$tmp/xdoc.json" --apply-contract "$apply"

nickel export "$tmp/xdoc.json" --apply-contract "$query" \
  > "$tmp/xdoc-query.json" 2>/dev/null

expect "xdoc: a qualified discharge closes across documents" 0 "XDOC-QUALIFIED-OK" \
  -- python3 - "$tmp/xdoc.json" "$tmp/xdoc-query.json" <<'EOF'
import json, sys
export = json.load(open(sys.argv[1]))
q = json.load(open(sys.argv[2]))
entries = {e["id"]: e for e in export["entries"]}
# The edge is carried VERBATIM: a qualified ref already names its document,
# so re-namespacing it would produce `xdoc-closer:xdoc-open:R1` and resolve
# to nothing. The declared stem is the answer, not a prefix for one.
assert entries["xdoc-closer:K1"].get("discharges") == ["xdoc-open:R1"], \
    entries["xdoc-closer:K1"]
# Openness is derived from the edges, so the crossing is only real if the
# target actually leaves the work list. R1's closer is human, so awaiting_human
# is the view it sits in until something discharges it.
awaiting = [row["id"] for row in q["awaiting_human"]]
assert "xdoc-open:R1" not in awaiting, awaiting
print("XDOC-QUALIFIED-OK")
EOF

expect "xdoc: a qualified supersession retires across documents" 0 "XDOC-SUPERSEDE-OK" \
  -- python3 - "$tmp/xdoc.json" "$tmp/xdoc-query.json" <<'EOF'
import json, sys
export = json.load(open(sys.argv[1]))
q = json.load(open(sys.argv[2]))
entries = {e["id"]: e for e in export["entries"]}
assert entries["xdoc-closer:R9"].get("supersedes") == ["xdoc-open:Q2"], \
    entries["xdoc-closer:R9"]
awaiting = [row["id"] for row in q["awaiting_human"]]
assert "xdoc-open:Q2" not in awaiting, awaiting
# R9 itself is retired by nothing, so it stays: the survivor a supersession
# chain must reach. Without this the case would also pass on a query that
# emptied the view wholesale.
assert "xdoc-closer:R9" in awaiting, awaiting
print("XDOC-SUPERSEDE-OK")
EOF

expect "xdoc: a qualified derivation edge crosses beside a local one" 0 "XDOC-DERIVE-OK" \
  -- python3 - "$tmp/xdoc.json" <<'EOF'
import json, sys
export = json.load(open(sys.argv[1]))
entries = {e["id"]: e for e in export["entries"]}
# Order within the value is the author's and not pinned here; membership is.
# The local ref namespaces to THIS document and the qualified one does not,
# from one comma-separated value — so a resolver handling only one form, or
# applying one rule to both, cannot satisfy this. `because` is the tagged
# ref shape (ruling-provenance-representation): a corpus-resolved ref is a
# `{kind: corpus, name: ...}` record, not a bare string.
because = entries["xdoc-closer:X1"].get("because", [])
assert {r["name"] for r in because} == {
    "xdoc-closer:K2", "xdoc-open:K1"}, because
# A resolved reference is an EDGE and nothing else: every ref here is
# `corpus`-tagged, none `external` — there is no second sidecar left to
# double-file it into.
assert all(r["kind"] == "corpus" for r in because), because
print("XDOC-DERIVE-OK")
EOF

expect "xdoc: a plain reference stays inside its own document" 0 "XDOC-PLAIN-LOCAL-OK" \
  -- python3 - "$tmp/xdoc.json" "$tmp/xdoc-query.json" <<'EOF'
import json, sys
export = json.load(open(sys.argv[1]))
q = json.load(open(sys.argv[2]))
entries = {e["id"]: e for e in export["entries"]}
# Both documents declare a `Q1`. The plain edge names the one that wrote it.
assert entries["xdoc-closer:K2"].get("discharges") == ["xdoc-closer:Q1"], \
    entries["xdoc-closer:K2"]
runnable = [row["id"] for row in q["runnable_now"]]
assert "xdoc-open:Q1" in runnable, runnable
assert "xdoc-closer:Q1" not in runnable, runnable
print("XDOC-PLAIN-LOCAL-OK")
EOF

# --- wikilink/: the silent-capture case, refused --------------------------
#
# The live record's two broken closure edges, reproduced in shape. Neither
# resolves; the record's obligation is to say so about both, and to leave the
# question one of them names visibly open.

python3 "$extractor" "$fix/wikilink" -o "$tmp/wikilink.json" 2>/dev/null
expect "wikilink: the export passes the entry contract" 0 "" \
  -- nickel export "$tmp/wikilink.json" --apply-contract "$apply"

nickel export "$tmp/wikilink.json" --apply-contract "$query" \
  > "$tmp/wikilink-query.json" 2>/dev/null

expect "wikilink: a corpus-id-shaped wikilink is still external" 0 "WIKI-STAYS-EXTERNAL-OK" \
  -- python3 - "$tmp/wikilink.json" "$tmp/wikilink-query.json" <<'EOF'
import json, sys
export = json.load(open(sys.argv[1]))
q = json.load(open(sys.argv[2]))
entries = {e["id"]: e for e in export["entries"]}
reasons = {f["marker"]: f["reason"] for f in export["findings"]}
# K1's wikilink text IS an id this very corpus declares. It still does not
# become an edge — an external name that happens to collide is not a
# declaration, and the collision is invisible to whoever wrote either half.
assert "discharges" not in entries["wikicap-closer:K1"], entries["wikicap-closer:K1"]
assert "wikicap-open:R1" in reasons.get("K1", ""), export["findings"]
# K2 names a note outside the corpus: the same treatment, for the reason that
# was never in doubt.
assert "discharges" not in entries["wikicap-closer:K2"], entries["wikicap-closer:K2"]
assert "nowhere-note" in reasons.get("K2", ""), export["findings"]
# Neither is filed as provenance. A closure edge's external remainder is
# only ever reported (bad-edge, above) and never attached to any field —
# `because` tagging (ruling-provenance-representation) applies to
# `derives-from::` alone, and neither K1 nor K2 declares one.
assert "because" not in entries["wikicap-closer:K1"], entries["wikicap-closer:K1"]
assert "because" not in entries["wikicap-closer:K2"], entries["wikicap-closer:K2"]
# And the target is still open, which is the whole of what silent capture
# would have cost: a question reported answered that nobody answered.
assert "wikicap-open:R1" in [row["id"] for row in q["awaiting_human"]], q["awaiting_human"]
print("WIKI-STAYS-EXTERNAL-OK")
EOF

# --- ghost/: a qualified id resolving nowhere ------------------------------
#
# The closure-edge half of this is already reported today. The derivation-edge
# half is the gap: a bracketed id the resolver cannot place is filed as
# external provenance and the run exits clean, so a mistyped stem reads as a
# deliberate pointer out of the record.

expect "ghost: an unplaceable qualified derivation ref is reported" 3 "nowhere-doc:K9" \
  -- python3 "$extractor" "$fix/ghost" -o "$tmp/ghost-report.json"
expect "ghost: an unplaceable qualified closure ref is reported" 3 "nowhere-doc:Q9" \
  -- python3 "$extractor" "$fix/ghost" -o "$tmp/ghost-report.json"

python3 "$extractor" "$fix/ghost" -o "$tmp/ghost.json" 2>/dev/null
expect "ghost: the export passes the entry contract" 0 "" \
  -- nickel export "$tmp/ghost.json" --apply-contract "$apply"

expect "ghost: an unplaceable ref is reported, never filed external" 0 "GHOST-REPORTED-OK" \
  -- python3 - "$tmp/ghost.json" <<'EOF'
import json, sys
export = json.load(open(sys.argv[1]))
entries = {e["id"]: e for e in export["entries"]}
# Not provenance. Free prose and wikilinks are external because their author
# wrote them that way; a bracketed id asserts the opposite, and collapsing the
# two turns a typo into a pointer nobody will question. `resolve_qualified`
# drops an unresolved qualified ref outright (never files it anywhere), so
# the check is against `because` itself, the tagged ref shape's only home
# (ruling-provenance-representation).
because = entries["ghost-ref:X1"].get("because", [])
assert all("nowhere-doc" not in r["name"] for r in because), because
# Reported, and reported against the node that wrote it — a finding naming no
# marker is a defect the reader cannot locate.
assert any(f["marker"] == "X1" and "nowhere-doc:K9" in f["reason"]
           for f in export["findings"]), export["findings"]
# The resolvable half of the same value survives: reporting one reference is
# not a reason to drop the edges beside it, and dropping them would take a
# claim's whole provenance with the typo.
assert because == [{"kind": "corpus", "name": "ghost-ref:K1"}], \
    entries["ghost-ref:X1"]
print("GHOST-REPORTED-OK")
EOF

# --- datestem/: the stem a real document carries ---------------------------
#
# Every other corpus here spells its stems in letters. No document in the
# landed record does — a stem is a file stem and file stems lead with a date
# (`2026-08-11-state-typed`). So a stem class narrowed back to letters would
# strand every cross-document reference the record actually writes while every
# alphabetic fixture above stayed green, and the two edge kinds would fail
# differently: the closure edge reported, the derivation edge filed as
# external provenance and passed in silence. Both cross by a dated stem here.

expect "datestem: a dated-stem corpus reports nothing" 0 "" \
  -- python3 "$extractor" "$fix/datestem" -o "$tmp/datestem.json"
expect "datestem: the export passes the entry contract" 0 "" \
  -- nickel export "$tmp/datestem.json" --apply-contract "$apply"

nickel export "$tmp/datestem.json" --apply-contract "$query" \
  > "$tmp/datestem-query.json" 2>/dev/null

expect "datestem: a digit-leading stem resolves both edge kinds" 0 "DATESTEM-CROSSES-OK" \
  -- python3 - "$tmp/datestem.json" "$tmp/datestem-query.json" <<'EOF'
import json, sys
export = json.load(open(sys.argv[1]))
q = json.load(open(sys.argv[2]))
entries = {e["id"]: e for e in export["entries"]}
open_doc = "2026-08-11-datestem-open"
closer = "2026-08-12-datestem-closer"
# The loud half: a stem class that rejected the leading digit would leave this
# edge unbracketed, hence unresolvable, hence reported.
assert entries[f"{closer}:K1"].get("discharges") == [f"{open_doc}:R1"], \
    entries[f"{closer}:K1"]
# The quiet half, and the reason both are asserted: a derivation ref the
# bracket pattern does not match is filed as external provenance and the run
# still exits clean, so nothing but this assertion would notice. `because`
# is the tagged ref shape (ruling-provenance-representation): both crossings
# resolve to `corpus`-tagged records, none `external`.
because = entries[f"{closer}:X1"].get("because", [])
assert {r["name"] for r in because} == {
    f"{closer}:K1", f"{open_doc}:K1"}, because
assert all(r["kind"] == "corpus" for r in because), because
# And the crossing is real rather than merely recorded: R1's closer is human,
# so it sits in awaiting_human until something discharges it.
assert f"{open_doc}:R1" not in [row["id"] for row in q["awaiting_human"]], \
    q["awaiting_human"]
print("DATESTEM-CROSSES-OK")
EOF

# --- plainfall/: no fallback from local to corpus --------------------------
#
# The resolution rule's last escape. A plain ref matching nothing locally,
# with a document next door carrying exactly that marker: falling back would
# make plain refs doc-scoped-until-they-are-not. The corpus is REFUSED here,
# and that refusal is the point — the edge stays namespaced to the document
# that wrote it and the contract calls it dangling.

python3 "$extractor" "$fix/plainfall" -o "$tmp/plainfall.json" 2>/dev/null
expect "plainfall: a plain ref is namespaced to its own document" 0 "PLAIN-NO-FALLBACK-OK" \
  -- python3 - "$tmp/plainfall.json" <<'EOF'
import json, sys
export = json.load(open(sys.argv[1]))
entries = {e["id"]: e for e in export["entries"]}
assert entries["plainfall-closer:K1"].get("discharges") == \
    ["plainfall-closer:Z9"], entries["plainfall-closer:K1"]
# The document next door really does declare that marker, so the assertion
# above is about the RULE and not about an absent target.
assert "plainfall-open:Z9" in entries, sorted(entries)
print("PLAIN-NO-FALLBACK-OK")
EOF
expect "plainfall: the unresolved edge is refused, not absorbed" 1 "dangling discharges" \
  -- nickel export "$tmp/plainfall.json" --apply-contract "$apply"

echo
if [ "$fails" -eq 0 ]; then echo "test_corpus_ids: ALL PASS"; exit 0; fi
echo "test_corpus_ids: $fails FAILURE(S)"; exit 1
