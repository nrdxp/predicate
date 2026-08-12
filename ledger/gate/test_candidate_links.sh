#!/usr/bin/env bash
# test_candidate_links.sh — TDD for the co-citation / stem-overlap candidate
# surfacing check (ledger/derive/candidate_links.py) and its recorder-gate
# wiring (ledger/gate/recorder-pre-commit.sh).
#
# Every assertion below reads the CLI's STRUCTURED export (`-o out.json`),
# never the rendered text — a candidate SET is a value, and grepping rendered
# prose for it is the "read the tool's numeric output as the last number in
# its rendered prose" class of bug this project has already paid for once.
#
# Coverage:
#
#   1. UNIT (candidate_links.py), against constructed corpora (mktemp, never
#      the live .ledger — .ledger/ is read-only from this walk):
#      (a) co-citation: X cites A, another doc cites A alongside B -> B is
#          surfaced for X.
#      (b) X already cites every candidate -> reported, actionable_count 0.
#      (c) empty ledger root -> status no-corpus, exit 0.
#      (d) absent ledger root -> status no-corpus, exit 0.
#      (e) malformed (non-UTF-8) staged document, alongside a well-formed
#          sibling -> status malformed, exit 0.
#      (f) stem/title overlap surfaces a candidate co-citation cannot (no
#          wikilinks at all in either document).
#      (g) never a non-zero exit, across every fixture above plus a bare
#          usage-error invocation.
#
#   2. MUTATION -- the co-citation detector is broken in a throwaway copy
#      and case (a) is re-run against it: the candidate must NOT appear,
#      proving the assertion in (a) can fail (Verification Dual, one-shot
#      skepticism: an unfalsifiable test is not a test).
#
#   3. WIRING (recorder-pre-commit.sh) -- against a throwaway .ledger-shaped
#      repo (same construction test_recorder_hook.sh uses):
#      (h) staging a plain flight-log .md still PASSES the commit (advisory
#          only, never blocks) and the candidate-links diagnostic appears in
#          the hook's own output.
#      (i) staging a plain .md with python3 stripped from PATH still PASSES
#          the commit (the advisory step degrades, never fails the gate).
#      (j) existing YAML-record behaviour is unchanged: an invalid tech-debt
#          record is still BLOCKED (regression guard on the tier this change
#          shares a file with).
#
# Usage: test_candidate_links.sh
# Exit:  0 = all cases matched, 1 = a case mismatched, 2 = environment error.
set -u

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root="$(cd "$here/../.." && pwd)"
cli="$root/ledger/derive/candidate_links.py"
recorder_gate="$here/recorder-pre-commit.sh"
recorder_installer="$here/install-recorder-hook.sh"

for f in "$cli" "$recorder_gate" "$recorder_installer"; do
  [ -f "$f" ] || { echo "test_candidate_links: ENVIRONMENT ERROR — missing $f" >&2; exit 2; }
done
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

# ─── WIRING: recorder-pre-commit.sh ─────────────────────────────────────────
git_id=(-c user.name=test-candidate-links -c user.email=test@candidate-links -c commit.gpgsign=false)
make_recorder_fixture() {
  local r; r="$(mktemp -d)"
  git "${git_id[@]}" -C "$r" init -q
  mkdir -p "$r/tech-debt" "$r/process-feedback" "$r/log"
  ( cd "$r" && bash "$recorder_installer" ) >/dev/null 2>&1
  printf '%s' "$r"
}
path_without_python3() {
  local clean="" d
  local IFS=":"
  for d in $PATH; do
    [ -x "$d/python3" ] && continue
    clean="$clean:$d"
  done
  printf '%s' "${clean#:}"
}

fx="$(make_recorder_fixture)"
printf '# a flight-log note\nsee [[log/other]] for context.\n' > "$fx/log/note.md"
printf '# another note\n' > "$fx/log/other.md"
git "${git_id[@]}" -C "$fx" add log/note.md log/other.md
out="$(git "${git_id[@]}" -C "$fx" commit -m "docs: add a flight-log note" 2>&1)"
rc=$?
if [ "$rc" -eq 0 ] && printf '%s' "$out" | grep -q "candidate-links:"; then
  pass "(h) staging a plain .md still passes and the candidate-links diagnostic runs"
else
  fail "(h) rc=$rc, diagnostic present=$(printf '%s' "$out" | grep -c 'candidate-links:')"
fi
rm -rf "$fx"

fx="$(make_recorder_fixture)"
printf '# a flight-log note with no python3 on PATH\n' > "$fx/log/note.md"
git "${git_id[@]}" -C "$fx" add log/note.md
no_py_path="$(path_without_python3)"
out="$(PATH="$no_py_path" git "${git_id[@]}" -C "$fx" commit -m "docs: add a note while python3 is absent" 2>&1)"
rc=$?
if [ "$rc" -eq 0 ]; then
  pass "(i) staging a .md with python3 absent still passes (advisory step degrades, never blocks)"
else
  fail "(i) python3-absent commit was blocked (rc=$rc) — the advisory step must never gate"
fi
rm -rf "$fx"

fx="$(make_recorder_fixture)"
cat > "$fx/tech-debt/bad.yaml" <<'EOF'
items:
  - id: bad-debt
    claim: "missing required fields on purpose"
    location: nowhere
    severity: low
    why_deferred: "regression check for the yaml routing this change shares a file with"
    signer: { kind: agent, name: test-candidate-links }
    at: "deadbeef"
EOF
git "${git_id[@]}" -C "$fx" add tech-debt/bad.yaml
out="$(git "${git_id[@]}" -C "$fx" commit -m "feat: stage an invalid tech-debt record" 2>&1)"
rc=$?
if [ "$rc" -ne 0 ]; then
  pass "(j) existing YAML-record validation still blocks an invalid record (no regression)"
else
  fail "(j) invalid tech-debt record was NOT blocked (rc=$rc) — regression in the routing this change shares a file with"
fi
rm -rf "$fx"

# ─── Results ─────────────────────────────────────────────────────────────────
if [ "$fails" -ne 0 ]; then
  echo "FAIL: $fails candidate-links case(s) mismatched"
  exit 1
fi
echo "PASS: all candidate-links cases matched"
exit 0
