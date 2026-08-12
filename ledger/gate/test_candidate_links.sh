#!/usr/bin/env bash
# test_candidate_links.sh — TDD for the co-citation / stem-overlap candidate
# surfacing check (ledger/derive/candidate_links.py) — a standalone,
# invocable computation. It has no git-hook wiring: its consumer is a
# harness (SessionStart) hook, tested separately alongside that hook's own
# installer.
#
# Every assertion below reads the CLI's STRUCTURED export (`-o out.json`),
# never the rendered text — a candidate SET is a value, and grepping rendered
# prose for it is the "read the tool's numeric output as the last number in
# its rendered prose" class of bug this project has already paid for once.
#
# Coverage, against constructed corpora (mktemp, never the live .ledger —
# .ledger/ is read-only from this walk):
#
#   (a) co-citation: X cites A, another doc cites A alongside B -> B is
#       surfaced for X.
#   (b) X already cites every candidate -> reported, actionable_count 0.
#   (c) empty ledger root -> status no-corpus, exit 0.
#   (d) absent ledger root -> status no-corpus, exit 0.
#   (e) malformed (non-UTF-8) staged document, alongside a well-formed
#       sibling -> status malformed, exit 0.
#   (f) stem/title overlap surfaces a candidate co-citation cannot (no
#       wikilinks at all in either document).
#   (g) never a non-zero exit, across every fixture above plus a bare
#       usage-error invocation.
#   (k) an ambiguous bare-basename citation (two documents share a
#       filename in different directories) is REPORTED as ambiguous, not
#       silently treated as dangling and dropped — a resolve_target result
#       is a different failure from a genuinely absent target, and
#       collapsing them was a silent-wrong-answer gap on this advisory
#       surface.
#
#   MUTATION -- the co-citation detector is broken in a throwaway copy and
#       case (a) is re-run against it: the candidate must NOT appear,
#       proving the assertion in (a) can fail (Verification Dual, one-shot
#       skepticism: an unfalsifiable test is not a test).
#
# Usage: test_candidate_links.sh
# Exit:  0 = all cases matched, 1 = a case mismatched, 2 = environment error.
set -u

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root="$(cd "$here/../.." && pwd)"
cli="$root/ledger/derive/candidate_links.py"

[ -f "$cli" ] || { echo "test_candidate_links: ENVIRONMENT ERROR — missing $cli" >&2; exit 2; }
command -v python3 >/dev/null 2>&1 || { echo "ENV: python3 not found on PATH" >&2; exit 2; }

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

fails=0
pass() { echo "PASS  $1"; }
fail() { echo "FAIL  $1"; fails=$((fails + 1)); }

# Every CLI invocation across the whole suite is required to exit 0 — logged
# here so case (g) can assert it over the full run, not just a sample.
nonzero_exits=0
run_cli() { # ledger_root out_json staged_path...
  local lr="$1" out="$2"; shift 2
  python3 "$cli" "$lr" "$@" -o "$out" >/dev/null 2>"$tmp/last_stderr.txt"
  local rc=$?
  [ "$rc" -ne 0 ] && nonzero_exits=$((nonzero_exits + 1))
  return "$rc"
}

# assert_json DESC PYTHON-EXPR-BODY (reads $tmp/out.json as `data`; must set
# `ok = True/False` and may print a reason on failure).
assert_json() {
  local desc="$1" body="$2"
  python3 - "$tmp/out.json" <<PY
import json, sys
data = json.load(open(sys.argv[1]))
ok = False
reason = ""
$body
sys.exit(0 if ok else (print(reason, file=sys.stderr) or 1))
PY
  if [ $? -eq 0 ]; then pass "$desc"; else fail "$desc"; fi
}

# ─── (a) co-citation surfaces B for X ───────────────────────────────────────
mkdir -p "$tmp/co/log"
cat > "$tmp/co/log/a.md" <<'EOF'
# a
EOF
cat > "$tmp/co/log/b.md" <<'EOF'
# b
EOF
cat > "$tmp/co/log/other.md" <<'EOF'
# other cites both
[[log/a]] and [[log/b]] are related.
EOF
cat > "$tmp/co/log/x.md" <<'EOF'
# x cites only a
see [[log/a]] for context.
EOF
run_cli "$tmp/co" "$tmp/out.json" log/x.md
assert_json "(a) co-citation surfaces the co-cited sibling for the staged doc" '
cands = data[0]["candidates"]
hit = [c for c in cands if c["kind"] == "co-citation" and c["target"] == "log/b"]
ok = data[0]["status"] == "ok" and len(hit) == 1 and hit[0]["already_linked"] is False and "log/a" in hit[0]["via"]
reason = f"candidates={cands}"
'

# ─── (b) every candidate already linked -> nothing actionable ──────────────
cat > "$tmp/co/log/x_linked.md" <<'EOF'
# x cites both already
[[log/a]] and [[log/b]] are both already here.
EOF
run_cli "$tmp/co" "$tmp/out.json" log/x_linked.md
assert_json "(b) staged doc already linking every candidate reports zero actionable" '
r = data[0]
ok = r["status"] == "ok" and len(r["candidates"]) > 0 and r["actionable_count"] == 0 and r["already_linked_count"] == len(r["candidates"])
reason = f"report={r}"
'

# ─── (c) empty ledger root ───────────────────────────────────────────────────
mkdir -p "$tmp/empty"
run_cli "$tmp/empty" "$tmp/out.json" log/whatever.md
assert_json "(c) empty ledger root -> no-corpus status" '
r = data[0]
ok = r["status"] == "no-corpus" and r["candidates"] == []
reason = f"report={r}"
'

# ─── (d) absent ledger root ──────────────────────────────────────────────────
run_cli "$tmp/does-not-exist" "$tmp/out.json" log/whatever.md
assert_json "(d) absent ledger root -> no-corpus status, no crash" '
r = data[0]
ok = r["status"] == "no-corpus"
reason = f"report={r}"
'

# ─── (e) malformed (non-UTF-8) staged document ───────────────────────────────
mkdir -p "$tmp/mal/log"
cat > "$tmp/mal/log/good.md" <<'EOF'
# a good sibling document
EOF
printf '\xff\xfe not utf8 at all' > "$tmp/mal/log/bad.md"
run_cli "$tmp/mal" "$tmp/out.json" log/bad.md
assert_json "(e) malformed staged document -> malformed status, exit 0" '
r = data[0]
ok = r["status"] == "malformed"
reason = f"report={r}"
'

# ─── (f) stem/title overlap where co-citation has nothing to work with ──────
mkdir -p "$tmp/stem/log"
cat > "$tmp/stem/log/record-search-rule.md" <<'EOF'
# a rule with no wikilinks at all
EOF
cat > "$tmp/stem/log/record-search-followup.md" <<'EOF'
# a followup with no wikilinks at all
EOF
cat > "$tmp/stem/log/unrelated-topic.md" <<'EOF'
# something entirely else
EOF
run_cli "$tmp/stem" "$tmp/out.json" log/record-search-rule.md
assert_json "(f) stem overlap surfaces a candidate with zero citations present" '
r = data[0]
cands = r["candidates"]
hit = [c for c in cands if c["kind"] == "stem" and c["target"] == "log/record-search-followup"]
unrelated = [c for c in cands if c["target"] == "log/unrelated-topic"]
ok = len(hit) == 1 and hit[0]["strength"] >= 2 and unrelated == []
reason = "candidates=" + repr(cands)
'

# ─── (k) an ambiguous bare-basename citation is reported, not dropped ───────
mkdir -p "$tmp/ambig/log" "$tmp/ambig/deposits"
cat > "$tmp/ambig/log/dup.md" <<'EOF'
# dup in log
EOF
cat > "$tmp/ambig/deposits/dup.md" <<'EOF'
# dup in deposits
EOF
cat > "$tmp/ambig/log/x.md" <<'EOF'
# x cites a bare, ambiguous basename
see [[dup]] for context.
EOF
run_cli "$tmp/ambig" "$tmp/out.json" log/x.md
assert_json "(k) an ambiguous bare-basename citation is reported, not silently dropped" '
r = data[0]
ok = r["status"] == "ok" and r["ambiguous"] == ["dup"] and r["candidates"] == []
reason = f"report={r}"
'

# ─── (g) never a non-zero exit, across every case above + a bare usage error ─
python3 "$cli" >/dev/null 2>&1
usage_rc=$?
[ "$usage_rc" -ne 0 ] && nonzero_exits=$((nonzero_exits + 1))
if [ "$nonzero_exits" -eq 0 ]; then
  pass "(g) every invocation across the fixture set (incl. bare usage error) exits 0"
else
  fail "(g) $nonzero_exits invocation(s) exited non-zero — an advisory check must never block a commit"
fi

# ─── MUTATION: prove case (a) can fail ──────────────────────────────────────
# Breaks co-citation by short-circuiting before any candidate is ever
# recorded — the mutant must find NOTHING where the unmutated detector found
# log/b. A test that cannot go red on a broken implementation is not a test.
mutant="$tmp/mutant_candidate_links.py"
sed 's/for b in d_targets:/for b in ():/' "$cli" > "$mutant"
python3 "$mutant" "$tmp/co" log/x.md -o "$tmp/mutant_out.json" >/dev/null 2>&1
mutant_rc=$?
python3 - "$tmp/mutant_out.json" <<'PY'
import json, sys
data = json.load(open(sys.argv[1]))
cands = data[0]["candidates"]
hit = [c for c in cands if c["kind"] == "co-citation" and c["target"] == "log/b"]
sys.exit(0 if len(hit) == 0 else 1)
PY
mutant_killed=$?
if [ "$mutant_rc" -eq 0 ] && [ "$mutant_killed" -eq 0 ]; then
  pass "(mutation) breaking co-citation makes case (a)'s assertion fail on the mutant"
else
  fail "(mutation) mutant still finds log/b (mutant_rc=$mutant_rc, still-detects=$([ $mutant_killed -eq 0 ] && echo no || echo yes)) — assertion (a) cannot discriminate this defect"
fi

# ─── MUTATION: prove case (k) can fail ──────────────────────────────────────
# Silently resolves an ambiguous basename to its first match instead of
# reporting it — the mutant must report ZERO ambiguous targets where the
# real detector reports "dup".
mutant2="$tmp/mutant2_candidate_links.py"
sed 's/return None, True/return matches[0], False/' "$cli" > "$mutant2"
python3 "$mutant2" "$tmp/ambig" log/x.md -o "$tmp/mutant2_out.json" >/dev/null 2>&1
mutant2_rc=$?
python3 - "$tmp/mutant2_out.json" <<'PY'
import json, sys
data = json.load(open(sys.argv[1]))
sys.exit(0 if data[0]["ambiguous"] == [] else 1)
PY
mutant2_silenced=$?
if [ "$mutant2_rc" -eq 0 ] && [ "$mutant2_silenced" -eq 0 ]; then
  pass "(mutation) silently resolving ambiguity makes case (k)'s assertion fail on the mutant"
else
  fail "(mutation) mutant still reports the ambiguity — assertion (k) cannot discriminate this defect"
fi

# ─── Results ─────────────────────────────────────────────────────────────────
if [ "$fails" -ne 0 ]; then
  echo "FAIL: $fails candidate-links case(s) mismatched"
  exit 1
fi
echo "PASS: all candidate-links cases matched"
exit 0
