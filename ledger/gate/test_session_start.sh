#!/usr/bin/env bash
# test_session_start.sh — TDD for the SessionStart harness hook
# (harness/session_start.py), which injects candidate_links.py's structural
# surface into a fresh agent's context using what is actually available at
# session start: the record's own recent activity and the branch name.
#
# Every structural assertion below imports the module and inspects the
# `Surface` dataclass directly — never scrapes the rendered additionalContext
# string for a count. The rendered-text assertions that DO appear (checking
# that a stated count is present, checking the full-script JSON envelope
# shape) are checking PRESENCE of the required disclosure, never computing a
# result from parsed prose — the distinction the candidate-links suite's own
# governing rule draws.
#
# Coverage, against constructed fixtures (mktemp, never the live .ledger):
#
#   (a) recent activity + co-citation surfaces a related, non-recent document
#       that the recent document's own citations lead to.
#   (b) branch-name token overlap surfaces a candidate with zero citations
#       anywhere in the corpus (the cold-start cover).
#   (c) no .ledger present -> empty surface, full script emits {} on stdout,
#       exit 0.
#   (d) .ledger present but empty (no .md files) -> empty surface, exit 0.
#   (e) malformed stdin (not JSON) -> script still runs (falls back to cwd),
#       exit 0.
#   (f) cwd is not a git repository at all -> degrades gracefully, exit 0.
#   (g) budget truncation: a tiny budget drops candidates and states the
#       dropped count; included + dropped == total candidates.
#   (h) never a non-zero exit, across every fixture above.
#
#   MUTATION -- the anchor-exclusion filter is broken in a throwaway copy and
#       case (a) is re-run against it: the excluded anchor document itself
#       must now appear as a spurious "candidate", proving the assertion in
#       (a) can fail.
#
# Usage: test_session_start.sh
# Exit:  0 = all cases matched, 1 = a case mismatched, 2 = environment error.
set -u

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root="$(cd "$here/../.." && pwd)"
hook="$root/harness/session_start.py"

[ -f "$hook" ] || { echo "test_session_start: ENVIRONMENT ERROR — missing $hook" >&2; exit 2; }
command -v python3 >/dev/null 2>&1 || { echo "ENV: python3 not found on PATH" >&2; exit 2; }
command -v git >/dev/null 2>&1 || { echo "ENV: git not found on PATH" >&2; exit 2; }

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

fails=0
pass() { echo "PASS  $1"; }
fail() { echo "FAIL  $1"; fails=$((fails + 1)); }

nonzero_exits=0
run_hook() { # project_root_dir  [stdin-json-string]
  local proj="$1" stdin_json="${2-}"
  if [ -n "$stdin_json" ]; then
    printf '%s' "$stdin_json" | python3 "$hook" >"$tmp/stdout.json" 2>"$tmp/stderr.txt"
  else
    printf '{"cwd": "%s"}' "$proj" | python3 "$hook" >"$tmp/stdout.json" 2>"$tmp/stderr.txt"
  fi
  local rc=$?
  [ "$rc" -ne 0 ] && nonzero_exits=$((nonzero_exits + 1))
  return "$rc"
}

# assert_py DESC PYTHON-BODY — imports session_start + candidate_links with
# sys.path already set up, `proj` (str) bound from $1. Must set `ok`.
assert_py() {
  local desc="$1" proj="$2" body="$3"
  python3 - "$proj" <<PY
import sys
sys.path.insert(0, "$root/harness")
sys.path.insert(0, "$root/ledger/derive")
import session_start as ss
from candidate_links import build_corpus, resolved_targets
from pathlib import Path
proj = Path(sys.argv[1])
ledger_root = proj / ".ledger"
ok = False
reason = ""
$body
sys.exit(0 if ok else (print(reason, file=sys.stderr) or 1))
PY
  if [ $? -eq 0 ]; then pass "$desc"; else fail "$desc"; fi
}

make_git_repo() {
  local d; d="$(mktemp -d)"
  git -c user.name=t -c user.email=t@t -c commit.gpgsign=false -C "$d" init -q -b topic/hook-test
  printf '%s' "$d"
}

# ─── (a) recent activity + co-citation surfaces a related document ─────────
proj="$(make_git_repo)"
mkdir -p "$proj/.ledger/log"
cat > "$proj/.ledger/log/a.md" <<'EOF'
# a doc about hooks
EOF
cat > "$proj/.ledger/log/b.md" <<'EOF'
# b doc about hooks
EOF
cat > "$proj/.ledger/log/other.md" <<'EOF'
# other cites both, an old document
[[log/a]] and [[log/b]] are related.
EOF
touch -d "2018-01-01" "$proj/.ledger/log/other.md" "$proj/.ledger/log/a.md" "$proj/.ledger/log/b.md"
for i in 1 2 3 4 5 6; do
  printf '# filler doc %s\nnothing special.\n' "$i" > "$proj/.ledger/log/filler$i.md"
  touch -d "2019-01-0$i" "$proj/.ledger/log/filler$i.md"
done
cat > "$proj/.ledger/log/recent.md" <<'EOF'
# recent doc, cites a
see [[log/a]] for context.
EOF
assert_py "(a) recent activity's own citations lead to a co-cited candidate" "$proj" '
corpus, _ = build_corpus(ledger_root)
surface = ss.compute_surface(ledger_root, proj)
hit = "log/b" in surface.text and "log/a" not in surface.text.split("dropped for budget")[0].split("Full surface")[0]
ok = surface.candidate_count == 1 and surface.included_count == 1 and "log/b" in surface.text
reason = f"surface={surface}"
'
run_hook "$proj"
assert_py "(a2) full script JSON envelope has the SessionStart hookSpecificOutput shape" "$proj" '
import json
data = json.load(open("'"$tmp"'/stdout.json"))
hso = data.get("hookSpecificOutput", {})
ok = hso.get("hookEventName") == "SessionStart" and "log/b" in hso.get("additionalContext", "")
reason = f"data={data}"
'
rm -rf "$proj"

# ─── (b) branch-name token overlap, zero citations anywhere ────────────────
proj="$(make_git_repo)"
git -C "$proj" checkout -q -b node/write-hook-topic 2>/dev/null || git -C "$proj" branch -m node/write-hook-topic
mkdir -p "$proj/.ledger/log"
# An unrelated, genuinely recent document seeds recent_ids (so it, not the
# interesting fixture doc, is what gets excluded) — the branch-name match
# must come from a document co-citation never touches. Enough OLD filler
# fills every recent_ids slot so write-hook-notes.md is never swept in by
# having too few other candidates for the anchor count.
cat > "$proj/.ledger/log/unrelated-recent.md" <<'EOF'
# unrelated recent doc
no wikilinks, nothing shared with the branch name.
EOF
for i in 1 2 3 4 5 6; do
  printf '# filler doc %s\nnothing special.\n' "$i" > "$proj/.ledger/log/filler$i.md"
  touch -d "2019-01-0$i" "$proj/.ledger/log/filler$i.md"
done
cat > "$proj/.ledger/log/write-hook-notes.md" <<'EOF'
# write hook notes
no wikilinks here at all.
EOF
touch -d "2018-01-01" "$proj/.ledger/log/write-hook-notes.md"
assert_py "(b) branch-name token overlap surfaces a candidate with no citations" "$proj" '
surface = ss.compute_surface(ledger_root, proj)
ok = surface.candidate_count >= 1 and "write-hook-notes" in surface.text
reason = f"surface={surface}"
'
rm -rf "$proj"

# ─── (c) no .ledger present ──────────────────────────────────────────────────
proj="$(make_git_repo)"
run_hook "$proj"
assert_py "(c) no .ledger -> empty surface" "$proj" '
surface = ss.compute_surface(ledger_root, proj)
ok = surface.text == "" and surface.candidate_count == 0
reason = f"surface={surface}"
'
if [ "$(cat "$tmp/stdout.json")" = "{}" ]; then
  pass "(c2) full script emits bare {} on stdout when nothing to inject"
else
  fail "(c2) expected bare {}, got: $(cat "$tmp/stdout.json")"
fi
rm -rf "$proj"

# ─── (d) .ledger present but empty ──────────────────────────────────────────
proj="$(make_git_repo)"
mkdir -p "$proj/.ledger"
assert_py "(d) empty .ledger (no .md files) -> empty surface" "$proj" '
surface = ss.compute_surface(ledger_root, proj)
ok = surface.text == "" and surface.candidate_count == 0
reason = f"surface={surface}"
'
rm -rf "$proj"

# ─── (e) malformed stdin ─────────────────────────────────────────────────────
proj="$(make_git_repo)"
mkdir -p "$proj/.ledger/log"
printf '# a note\n' > "$proj/.ledger/log/note.md"
printf 'not-json-at-all{{{' | python3 "$hook" >"$tmp/stdout.json" 2>"$tmp/stderr.txt"
rc=$?
if [ "$rc" -eq 0 ]; then
  pass "(e) malformed stdin degrades gracefully, exit 0"
else
  fail "(e) malformed stdin exited $rc"
  nonzero_exits=$((nonzero_exits + 1))
fi
rm -rf "$proj"

# ─── (f) cwd is not a git repository ────────────────────────────────────────
plain="$(mktemp -d)"
mkdir -p "$plain/.ledger/log"
printf '# a note\n' > "$plain/.ledger/log/note.md"
run_hook "$plain"
if [ "$?" -eq 0 ]; then
  pass "(f) non-git cwd degrades gracefully, exit 0"
else
  fail "(f) non-git cwd exited non-zero"
fi
rm -rf "$plain"

# ─── (g) budget truncation states what it dropped ───────────────────────────
proj="$(make_git_repo)"
mkdir -p "$proj/.ledger/log"
cat > "$proj/.ledger/log/anchor.md" <<'EOF'
# anchor doc
EOF
touch -d "2018-01-01" "$proj/.ledger/log/anchor.md"
# 20 documents, each citing "anchor" alongside a UNIQUE sibling — each
# sibling becomes its own co-citation candidate, so the candidate count
# comfortably exceeds any small budget.
for i in $(seq 1 20); do
  cat > "$proj/.ledger/log/sib$i.md" <<EOF
# sibling $i
EOF
  touch -d "2018-01-0$(( (i % 9) + 1 ))" "$proj/.ledger/log/sib$i.md"
  cat > "$proj/.ledger/log/citer$i.md" <<EOF
# citer $i
[[log/anchor]] and [[log/sib$i]] both matter.
EOF
  touch -d "2018-01-0$(( (i % 9) + 1 ))" "$proj/.ledger/log/citer$i.md"
done
cat > "$proj/.ledger/log/recent.md" <<'EOF'
# recent doc, cites anchor
see [[log/anchor]] for context.
EOF
assert_py "(g) a tiny budget drops candidates and states the count honestly" "$proj" '
surface_full = ss.compute_surface(ledger_root, proj, budget=100000)
surface_tiny = ss.compute_surface(ledger_root, proj, budget=400)
ok = (
    surface_full.candidate_count > 5
    and surface_tiny.dropped_count > 0
    and surface_tiny.included_count + surface_tiny.dropped_count == surface_tiny.candidate_count
    and str(surface_tiny.dropped_count) in surface_tiny.text
)
reason = f"full={surface_full}\ntiny={surface_tiny}"
'
rm -rf "$proj"

# ─── (i) second contribution: open claims near the work ────────────────────
# node/surface-injection: a second hook contribution consuming the
# anchored-reachability open-surface primitive's STRUCTURED output
# (ledger/derive/anchored_surface.sh --json) — never its rendered prose.
# THE FUNCTION DOES NOT EXIST YET at the tip this case was authored against
# — red for that reason.
#
# Every corpus document needs a `signer::`/`at::` header here (unlike the
# co-citation-only fixtures above): extract_entries.py reports ANY headerless
# .md file as a pre-standard-doc finding, and anchored_surface.sh treats any
# finding as extraction failure for the WHOLE corpus — a stricter bar than
# candidate_links.py's, which never reads headers at all.
proj="$(make_git_repo)"
mkdir -p "$proj/.ledger/log"
cat > "$proj/.ledger/log/near-claim.md" <<'EOF'
# an older doc holding an open question near the work

`signer:: agent/test` · `at:: 0000000`

`[NEAR1] grade::frontier` An open question sitting near where the work is
about to happen.
`discharge:: whatever eventually answers this` `closer:: agent/test`
EOF
touch -d "2018-01-01" "$proj/.ledger/log/near-claim.md"
for i in 1 2 3 4 5 6; do
  cat > "$proj/.ledger/log/filler$i.md" <<EOF
# filler doc $i

\`signer:: agent/test\` · \`at:: 0000000\`

nothing special.
EOF
  touch -d "2019-01-0$i" "$proj/.ledger/log/filler$i.md"
done
cat > "$proj/.ledger/log/recent.md" <<'EOF'
# recent doc, derives from a nearby open question

`signer:: agent/test` · `at:: 0000000`

`[WORK1] grade::synthesis` A claim just written, derived from the open
question sitting nearby.
`derives-from:: [near-claim:NEAR1]`
EOF
assert_py "(i) an entry near a just-touched document's own claim surfaces" "$proj" '
claims = ss.compute_claim_surface(ledger_root)
ok = claims.candidate_count >= 1 and "near-claim:NEAR1" in claims.text
reason = f"claims={claims}"
'
rm -rf "$proj"

# ─── (i2) full envelope: both contributions land in one additionalContext ──
# Reuses (i)'s fixture, adding co-citation content so BOTH contributions are
# non-empty at once — pinning the two-contribution shape structurally (each
# section is checked for its own header presence in the merged text, never
# by re-deriving a count from parsed prose).
proj="$(make_git_repo)"
mkdir -p "$proj/.ledger/log"
cat > "$proj/.ledger/log/near-claim.md" <<'EOF'
# an older doc holding an open question near the work

`signer:: agent/test` · `at:: 0000000`

`[NEAR1] grade::frontier` An open question sitting near where the work is
about to happen.
`discharge:: whatever eventually answers this` `closer:: agent/test`
EOF
touch -d "2018-01-01" "$proj/.ledger/log/near-claim.md"
cat > "$proj/.ledger/log/a.md" <<'EOF'
# a doc about hooks

`signer:: agent/test` · `at:: 0000000`
EOF
cat > "$proj/.ledger/log/b.md" <<'EOF'
# b doc about hooks

`signer:: agent/test` · `at:: 0000000`
EOF
cat > "$proj/.ledger/log/other.md" <<'EOF'
# other cites both, an old document

`signer:: agent/test` · `at:: 0000000`

[[log/a]] and [[log/b]] are related.
EOF
touch -d "2018-01-01" "$proj/.ledger/log/other.md" "$proj/.ledger/log/a.md" "$proj/.ledger/log/b.md"
for i in 1 2 3 4 5 6; do
  cat > "$proj/.ledger/log/filler$i.md" <<EOF
# filler doc $i

\`signer:: agent/test\` · \`at:: 0000000\`

nothing special.
EOF
  touch -d "2019-01-0$i" "$proj/.ledger/log/filler$i.md"
done
cat > "$proj/.ledger/log/recent.md" <<'EOF'
# recent doc, cites a and derives from a nearby open question

`signer:: agent/test` · `at:: 0000000`

see [[log/a]] for context.

`[WORK1] grade::synthesis` A claim just written, derived from the open
question sitting nearby.
`derives-from:: [near-claim:NEAR1]`
EOF
run_hook "$proj"
assert_py "(i2) the merged additionalContext carries both contributions' own headers" "$proj" '
import json
data = json.load(open("'"$tmp"'/stdout.json"))
ctx = data.get("hookSpecificOutput", {}).get("additionalContext", "")
ok = "## Record open surface" in ctx and "## Open claims near the work" in ctx and "near-claim:NEAR1" in ctx and "log/b" in ctx
reason = f"ctx={ctx}"
'
rm -rf "$proj"

# ─── (h) never a non-zero exit, across every fixture above ──────────────────
if [ "$nonzero_exits" -eq 0 ]; then
  pass "(h) every full-script invocation across the fixture set exits 0"
else
  fail "(h) $nonzero_exits invocation(s) exited non-zero — a SessionStart hook must never block a session"
fi

# ─── MUTATION: prove case (a) can fail ──────────────────────────────────────
# Breaks the anchor-exclusion filter so a recently-touched document's own
# citations are no longer excluded from the candidate output — the mutant
# must surface "log/a" (an excluded anchor) where the real hook does not.
mutant="$tmp/mutant_session_start.py"
sed 's/exclude_from_output = recent_ids | anchors/exclude_from_output = frozenset()/' "$hook" > "$mutant"
proj="$(make_git_repo)"
mkdir -p "$proj/.ledger/log"
cat > "$proj/.ledger/log/a.md" <<'EOF'
# a doc about hooks
EOF
cat > "$proj/.ledger/log/b.md" <<'EOF'
# b doc about hooks
EOF
cat > "$proj/.ledger/log/other.md" <<'EOF'
# other cites both, an old document
[[log/a]] and [[log/b]] are related.
EOF
touch -d "2018-01-01" "$proj/.ledger/log/other.md" "$proj/.ledger/log/a.md" "$proj/.ledger/log/b.md"
for i in 1 2 3 4 5 6; do
  printf '# filler doc %s\nnothing special.\n' "$i" > "$proj/.ledger/log/filler$i.md"
  touch -d "2019-01-0$i" "$proj/.ledger/log/filler$i.md"
done
cat > "$proj/.ledger/log/recent.md" <<'EOF'
# recent doc, cites a
see [[log/a]] for context.
EOF
python3 - "$proj" "$mutant" <<'PY'
import sys, importlib.util
sys.path.insert(0, "/var/home/nrd/git/wt/write-hook/ledger/derive")
proj_path, mutant_path = sys.argv[1], sys.argv[2]
spec = importlib.util.spec_from_file_location("mutant_ss", mutant_path)
mutant_ss = importlib.util.module_from_spec(spec)
sys.modules["mutant_ss"] = mutant_ss  # dataclasses needs the module registered before exec
spec.loader.exec_module(mutant_ss)
from pathlib import Path
proj = Path(proj_path)
surface = mutant_ss.compute_surface(proj / ".ledger", proj)
sys.exit(0 if "log/a" in surface.text else 1)
PY
mutant_shows_excluded_anchor=$?
if [ "$mutant_shows_excluded_anchor" -eq 0 ]; then
  pass "(mutation) breaking the anchor-exclusion filter leaks an excluded anchor into output"
else
  fail "(mutation) mutant still excludes log/a — assertion (a) cannot discriminate this defect"
fi
rm -rf "$proj"

# ─── MUTATION 2: prove case (i) can fail ────────────────────────────────────
# Breaks the entry-anchor stem match in _entry_anchors_near_recent (node/
# surface-injection's own addition) so a recently-touched document's own
# declared entries are never recognized as anchors — the mutant must find
# ZERO candidates where the real hook finds NEAR1, proving (i) can
# discriminate this defect rather than passing by construction.
mutant2="$tmp/mutant2_session_start.py"
sed 's/if stem in recent_stems:/if False:/' "$hook" > "$mutant2"
proj="$(make_git_repo)"
mkdir -p "$proj/.ledger/log"
cat > "$proj/.ledger/log/near-claim.md" <<'EOF'
# an older doc holding an open question near the work

`signer:: agent/test` · `at:: 0000000`

`[NEAR1] grade::frontier` An open question sitting near where the work is
about to happen.
`discharge:: whatever eventually answers this` `closer:: agent/test`
EOF
touch -d "2018-01-01" "$proj/.ledger/log/near-claim.md"
for i in 1 2 3 4 5 6; do
  cat > "$proj/.ledger/log/filler$i.md" <<EOF
# filler doc $i

\`signer:: agent/test\` · \`at:: 0000000\`

nothing special.
EOF
  touch -d "2019-01-0$i" "$proj/.ledger/log/filler$i.md"
done
cat > "$proj/.ledger/log/recent.md" <<'EOF'
# recent doc, derives from a nearby open question

`signer:: agent/test` · `at:: 0000000`

`[WORK1] grade::synthesis` A claim just written, derived from the open
question sitting nearby.
`derives-from:: [near-claim:NEAR1]`
EOF
python3 - "$proj" "$mutant2" <<PY
import sys, importlib.util
sys.path.insert(0, "$root/ledger/derive")
proj_path, mutant_path = sys.argv[1], sys.argv[2]
spec = importlib.util.spec_from_file_location("mutant2_ss", mutant_path)
mutant_ss = importlib.util.module_from_spec(spec)
sys.modules["mutant2_ss"] = mutant_ss
spec.loader.exec_module(mutant_ss)
from pathlib import Path
proj = Path(proj_path)
claims = mutant_ss.compute_claim_surface(proj / ".ledger")
sys.exit(0 if claims.candidate_count == 0 else 1)
PY
mutant_finds_nothing=$?
if [ "$mutant_finds_nothing" -eq 0 ]; then
  pass "(mutation 2) breaking the entry-anchor stem match empties out the claim surface"
else
  fail "(mutation 2) mutant still finds a candidate — assertion (i) cannot discriminate this defect"
fi
rm -rf "$proj"

# ─── Results ─────────────────────────────────────────────────────────────────
if [ "$fails" -ne 0 ]; then
  echo "FAIL: $fails session-start case(s) mismatched"
  exit 1
fi
echo "PASS: all session-start cases matched"
exit 0
