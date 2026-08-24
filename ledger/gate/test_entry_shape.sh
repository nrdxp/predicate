#!/usr/bin/env bash
# Suite for ledger/derive/entry_shape.py -- the shape-discovery command that
# stops a walk guessing what an entry's fields look like when querying the
# corpus with `jq`.
#
# WHY THIS SUITE EXISTS
# ----------------------
# Two measured mistakes from one session, both from guessing rather than
# reading the law: `closer` was treated as a string (`.closer=="human"`
# silently returned 0; the correct form is `.closer.kind=="human"`), and
# openness was treated as a field (filtering questions by `closer` alone
# returned 76 over the real corpus; openness-aware filtering returned 61 --
# the extra fifteen were already answered). entry_shape.py closes this by
# DERIVING the stored shape from entry.ncl's live Entry record and the
# computed-view set from actually running entries_query_apply.ncl, never
# from a hand-copied list -- so this suite pins the two properties that
# matter: `closer` is reported as a RECORD with a `kind` sub-field (never
# collapsed to a bare string), and `is_open`/openness is named explicitly as
# NOT a stored field, distinct from every view name.
#
# Usage: test_entry_shape.sh
# Exit:  0 = every case matched, 1 = a case mismatched, 2 = environment error.
set -u
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root="$(cd "$here/../.." && pwd)"
tool="$root/ledger/derive/entry_shape.py"

command -v python3 >/dev/null 2>&1 || { echo "ENV: python3 not found on PATH"; exit 2; }
command -v nickel  >/dev/null 2>&1 || { echo "ENV: nickel not found on PATH"; exit 2; }
[ -f "$tool" ] || { echo "ENV: entry_shape.py missing: $tool"; exit 2; }

fails=0
assert_py() {
  local desc="$1"; shift
  local out
  if out="$(python3 - "$@" 2>&1)"; then
    echo "PASS  $desc"
  else
    echo "FAIL  $desc"
    printf '%s\n' "$out" | tail -10
    fails=$((fails + 1))
  fi
}

tmp_json_file=""
cleanup() { [ -n "$tmp_json_file" ] && rm -f "$tmp_json_file"; }
trap cleanup EXIT

# --- basic invocation --------------------------------------------------------
out_text="$(python3 "$tool")"; rc_text=$?
if [ "$rc_text" -eq 0 ]; then
  echo "PASS  (0) text mode exits 0"
else
  echo "FAIL  (rc=$rc_text) text mode exits 0"; fails=$((fails + 1))
fi

out_json="$(python3 "$tool" --json)"; rc_json=$?
if [ "$rc_json" -eq 0 ]; then
  echo "PASS  (0) --json mode exits 0"
else
  echo "FAIL  (rc=$rc_json) --json mode exits 0"; fails=$((fails + 1))
fi
json_file="$(mktemp)"; tmp_json_file="$json_file"; printf '%s' "$out_json" > "$json_file"

# --- closer is reported as a RECORD, never a bare string --------------------
# THE mistake this tool exists to prevent: `.closer=="human"` silently
# returning 0 over real corpus data. The shape command must say `closer` is
# a record with a `kind` sub-field so a reader reaches for `.closer.kind`.
assert_py "closer is a RECORD (has a kind sub-field), not a bare scalar" \
  "$json_file" <<'EOF'
import json, sys
data = json.load(open(sys.argv[1]))
closer = data["stored"]["closer"]
assert closer["subfields"] is not None, closer
names = {s["name"] for s in closer["subfields"]}
assert "kind" in names, closer
assert "name" in names, closer
EOF

assert_py "the text rendering shows closer's .kind sub-field, not just the bare name" "" <<EOF
text = """$out_text"""
assert "closer" in text, text
assert ".kind" in text, text
EOF

# --- is_open is named as NOT a field, distinct from the view set ------------
# THE other mistake: treating openness as though it lived on the entry.
# is_open must be reported, and it must be reported OUTSIDE the stored field
# set -- never as one of entry.ncl's own Entry fields.
assert_py "is_open is reported as a computed attribute, never a stored field" \
  "$json_file" <<'EOF'
import json, sys
data = json.load(open(sys.argv[1]))
assert "is_open" in data["computed"], data["computed"]
assert "is_open" not in data["stored"], data["stored"]
EOF

assert_py "is_open's note says it is NOT a field and names the discharges/supersedes fold" \
  "$json_file" <<'EOF'
import json, sys
data = json.load(open(sys.argv[1]))
note = data["computed"]["is_open"]
assert "NOT A FIELD" in note, note
assert "discharges" in note and "supersedes" in note, note
EOF

# --- the computed view set is the REAL, live output of entries_query_apply --
# Derived, not hand-copied: this suite pins the current, known view names as
# a floor. If entries_query.ncl adds a view tomorrow, this command reports it
# without being told to -- because it is measured by actually running the
# contract, not by a list this file repeats.
assert_py "the computed view set names every currently-known view" \
  "$json_file" <<'EOF'
import json, sys
data = json.load(open(sys.argv[1]))
views = set(data["computed"]["views"])
expected = {
    "awaiting_human", "runnable_now", "unpaid_cures", "unbacked",
    "chain_floor", "dependents_of", "refutations", "impeachment_queue",
    "untagged",
}
missing = expected - views
assert not missing, f"missing views: {missing} (got {views})"
EOF

assert_py "with_tags is named separately (never in the plain output-key set)" \
  "$json_file" <<'EOF'
import json, sys
data = json.load(open(sys.argv[1]))
assert "with_tags" in data["computed"], data["computed"]
assert "with_tags" not in data["computed"]["views"], data["computed"]["views"]
EOF

# --- every Entry field entry.ncl declares is reported (self-updating) -------
# Derived from the SAME nickel query this tool itself uses, independently
# re-run here rather than a hard-coded list -- if this ever drifts it means
# nickel query's own output changed shape, not that a field was forgotten.
assert_py "every entry.ncl Entry field appears in the stored set" \
  "$json_file" "$root/ledger/contracts/entry.ncl" <<'EOF'
import json, subprocess, sys
data = json.load(open(sys.argv[1]))
out = subprocess.run(
    ["nickel", "query", "--field", "Entry", "--format", "json", sys.argv[2]],
    capture_output=True, text=True,
)
live_fields = set(json.loads(out.stdout)["sub_fields"])
reported = set(data["stored"])
assert live_fields == reported, (live_fields, reported)
EOF

echo
if [ "$fails" -eq 0 ]; then echo "test_entry_shape: ALL PASS"; exit 0; fi
echo "test_entry_shape: $fails FAILURE(S)"; exit 1
