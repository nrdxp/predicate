#!/usr/bin/env bash
# Fixture-driven suite for ledger/gate/red_baseline.py -- directions:D3-T9's
# second half, checked mechanically: for a landed node branch, does a
# `test:` commit precede the `feat:`/`fix:` commit(s) it verifies, IN THE
# COMMITTED HISTORY.
#
# Every repo built here is synthetic and disposable, unrelated to this
# project's own tree -- the same isolation test_trial_merge.sh uses, and for
# the same reason: a bug in red_baseline.py must never be able to touch
# predicate itself while these run.
#
# Cases (mirroring the dispatch's stated acceptance shapes AC1-4, plus the
# ambiguity and mutation obligations):
#
#   (a) test before implementation                       -> PASS
#   (b) implementation first, no preceding test           -> FAIL, named
#   (c) implementation with NO evaluator commit at all    -> FAIL, named
#   (d) no implementation commit at all                   -> PASS, not a
#       violation (distinct wording from (a) -- nothing to order)
#   (e) an unparseable commit (a bare `Revert "..."` message, no
#       Conventional-Commit type) precedes the implementation and no test:
#       commit already closes the ordering -> AMBIGUOUS, never silently PASS
#   (f) a merge commit (2 parents) inside the range is never itself
#       evaluator or implementation signal -- a merge landing BEFORE the
#       first feat:/fix: does not satisfy the ordering the way a test:
#       commit would
#   (g) --sweep mode over a range containing multiple merges: aggregates
#       PASS/FAIL/AMBIGUOUS/SKIP correctly, including an octopus merge (3
#       parents) reported SKIP rather than folded into any verdict
#   (h) usage/environment errors: bad ref, missing --repo, and the
#       exactly-one-of-<branch-ref>/--sweep usage rule
#
# Case (i), the mutation demonstration, breaks the ordering comparison
# itself and shows case (b)'s fixture read as PASS -- proving the suite can
# fail, per the always-on Verification Dual.
#
# Usage: test_red_baseline.sh
# Exit:  0 = every case matched, 1 = a case mismatched, 2 = environment error.
set -u

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
gate="$here/red_baseline.py"

command -v python3 >/dev/null 2>&1 || { echo "ENV: python3 not found on PATH" >&2; exit 2; }
if [[ ! -f "$gate" ]]; then
  echo "ENV: red_baseline.py missing: $gate" >&2
  exit 2
fi

fails=0
FIXED_DATE="2000-01-01T00:00:00+00:00"

init_repo() {
  local dir="$1"
  mkdir -p "$dir"
  git -C "$dir" init -q -b master
  git -C "$dir" config user.email "test@red-baseline.example"
  git -C "$dir" config user.name  "Red Baseline Test"
}

# commit_msg REPO MESSAGE-FILE  -- commits with a message read from a file,
# so a subject with embedded quotes (the Revert case) is never mangled by
# shell quoting.
commit_with_file() { # repo subject-file
  local repo="$1" msgfile="$2"
  GIT_AUTHOR_DATE="$FIXED_DATE" GIT_COMMITTER_DATE="$FIXED_DATE" \
    git -C "$repo" commit -q -F "$msgfile"
}

commit_all() { # repo subject
  local repo="$1" subject="$2"
  git -C "$repo" add -A
  GIT_AUTHOR_DATE="$FIXED_DATE" GIT_COMMITTER_DATE="$FIXED_DATE" \
    git -C "$repo" commit -q -m "$subject"
}

touch_file() { # repo relpath content
  local repo="$1" rel="$2" content="$3"
  mkdir -p "$(dirname "$repo/$rel")"
  printf '%s\n' "$content" > "$repo/$rel"
}

scratch="$(mktemp -d)"
trap 'rm -rf "$scratch"' EXIT

repo="$scratch/repo"
init_repo "$repo"
touch_file "$repo" root.txt "root"
commit_all "$repo" "chore: seed repo"
root_sha="$(git -C "$repo" rev-parse HEAD)"

run_gate() { # args...
  python3 "$gate" "$@" --repo "$repo" 2>&1
}

expect_rc() { # desc expected-rc keyword -- args...
  local desc="$1" exp="$2" kw="$3"; shift 3
  [[ "$1" == "--" ]] && shift
  local out rc ok=1
  out="$(run_gate "$@")"; rc=$?
  [[ "$rc" -eq "$exp" ]] || ok=0
  if [[ -n "$kw" ]]; then grep -qF -- "$kw" <<<"$out" || ok=0; fi
  if [[ "$ok" -eq 1 ]]; then
    echo "PASS  (rc=$rc) $desc"
  else
    echo "FAIL  (got rc=$rc want $exp; want-substr='$kw') $desc" >&2
    printf '%s\n' "$out" | sed 's/^/    /' >&2
    fails=$((fails + 1))
  fi
}

# =============================================================================
# (a) test before implementation -> PASS
# =============================================================================
echo "=== (a) test: precedes feat: -> PASS ==="
git -C "$repo" checkout -q -b node-a "$root_sha"
touch_file "$repo" a-test.txt "test"
commit_all "$repo" "test: red the widget before it exists"
touch_file "$repo" a-impl.txt "impl"
commit_all "$repo" "feat: implement the widget"
expect_rc "(a) exit 0" 0 "" -- node-a --against master
expect_rc "(a) reports PASS" 0 "PASS" -- node-a --against master
git -C "$repo" checkout -q master

# =============================================================================
# (b) implementation first, no preceding test -> FAIL
# =============================================================================
echo "=== (b) feat: with no preceding test: -> FAIL ==="
git -C "$repo" checkout -q -b node-b "$root_sha"
touch_file "$repo" b-impl.txt "impl"
commit_all "$repo" "feat: implement the gadget, untested"
expect_rc "(b) exit 1" 1 "" -- node-b --against master
expect_rc "(b) names the offending commit's subject" 1 \
  "implement the gadget, untested" -- node-b --against master
expect_rc "(b) reports FAIL" 1 "FAIL" -- node-b --against master
git -C "$repo" checkout -q master

# =============================================================================
# (c) implementation, no evaluator commit at all -> FAIL
# =============================================================================
echo "=== (c) fix: with zero test: commits in range -> FAIL ==="
git -C "$repo" checkout -q -b node-c "$root_sha"
touch_file "$repo" c-doc.txt "doc"
commit_all "$repo" "docs: describe the widget"
touch_file "$repo" c-impl.txt "impl"
commit_all "$repo" "fix: repair the widget"
expect_rc "(c) exit 1" 1 "" -- node-c --against master
expect_rc "(c) says no evaluator commit at all" 1 \
  "no evaluator commit at all in range" -- node-c --against master
git -C "$repo" checkout -q master

# =============================================================================
# (c2) implementation, evaluator exists but lands AFTER it -> FAIL, distinct
# wording from (c) -- and the fixture the mutation demonstration (i) below
# targets: a defect that stops checking ORDER and starts checking mere
# PRESENCE of a test: commit would read this branch as satisfied.
# =============================================================================
echo "=== (c2) fix: with a test: commit that lands AFTER it -> FAIL ==="
git -C "$repo" checkout -q -b node-c2 "$root_sha"
touch_file "$repo" c2-impl.txt "impl"
commit_all "$repo" "feat: implement the sprocket, tested only after"
touch_file "$repo" c2-test.txt "test"
commit_all "$repo" "test: cover the sprocket post-hoc"
expect_rc "(c2) exit 1" 1 "" -- node-c2 --against master
expect_rc "(c2) says the evaluator lands after it, not 'at all'" 1 \
  "lands after it" -- node-c2 --against master
git -C "$repo" checkout -q master

# =============================================================================
# (d) no implementation commit at all -> PASS, not a violation, distinct
# wording from (a)
# =============================================================================
echo "=== (d) no feat:/fix: at all -> PASS, nothing to order ==="
git -C "$repo" checkout -q -b node-d "$root_sha"
touch_file "$repo" d-doc.txt "doc"
commit_all "$repo" "docs: only documentation on this branch"
touch_file "$repo" d-test.txt "test"
commit_all "$repo" "test: a test with nothing yet to satisfy"
expect_rc "(d) exit 0" 0 "" -- node-d --against master
expect_rc "(d) reports nothing-to-order, not a satisfied ordering" 0 \
  "nothing to order" -- node-d --against master
git -C "$repo" checkout -q master

# =============================================================================
# (e) unparseable commit precedes implementation, no test: closes it ->
# AMBIGUOUS (never silently PASS)
# =============================================================================
echo "=== (e) unparseable commit before feat:, no test: -> AMBIGUOUS ==="
git -C "$repo" checkout -q -b node-e "$root_sha"
touch_file "$repo" e-a.txt "a"
git -C "$repo" add -A
printf 'Revert "test: something that might have been the evaluator"\n' > "$scratch/msg-e"
commit_with_file "$repo" "$scratch/msg-e"
touch_file "$repo" e-impl.txt "impl"
commit_all "$repo" "feat: implement after the unparseable revert"
expect_rc "(e) exit 3" 3 "" -- node-e --against master
expect_rc "(e) reports AMBIGUOUS, never PASS" 3 "AMBIGUOUS" -- node-e --against master
out_e="$(run_gate node-e --against master)"
if grep -q '^PASS' <<<"$out_e"; then
  echo "FAIL  (e) ambiguous case was reported as PASS -- the flattering direction" >&2
  fails=$((fails + 1))
else
  echo "PASS  (e) ambiguous case never reported as PASS"
fi
git -C "$repo" checkout -q master

# =============================================================================
# (f) a merge commit before the first feat: does not itself satisfy the
# ordering the way a test: commit would
# =============================================================================
echo "=== (f) a merge commit is not evaluator signal -> still FAIL ==="
git -C "$repo" checkout -q -b node-f-side "$root_sha"
touch_file "$repo" f-side.txt "side"
commit_all "$repo" "chore: side branch with nothing evaluator-shaped"
side_sha="$(git -C "$repo" rev-parse HEAD)"
git -C "$repo" checkout -q -b node-f "$root_sha"
touch_file "$repo" f-main.txt "main"
commit_all "$repo" "chore: main line before the merge"
git -C "$repo" merge --no-ff -q -m "merge: bring in the side branch" "$side_sha"
touch_file "$repo" f-impl.txt "impl"
commit_all "$repo" "feat: implement after an unrelated merge"
expect_rc "(f) exit 1 -- the merge commit does not count as a test:" 1 "" -- node-f --against master
git -C "$repo" checkout -q master

# =============================================================================
# (g) --sweep mode: aggregate PASS/FAIL/AMBIGUOUS/SKIP over multiple merges,
# including an octopus merge reported SKIP
# =============================================================================
echo "=== (g) --sweep aggregates over a range, octopus merge -> SKIP ==="
sweep_repo="$scratch/sweep-repo"
init_repo "$sweep_repo"
touch_file "$sweep_repo" root.txt "root"
commit_all "$sweep_repo" "chore: seed sweep repo"
sweep_root="$(git -C "$sweep_repo" rev-parse HEAD)"

# node/pass: test then feat, merged cleanly (PASS)
git -C "$sweep_repo" checkout -q -b node/pass "$sweep_root"
touch_file "$sweep_repo" pass-test.txt "t"
commit_all "$sweep_repo" "test: red before the pass-node feature"
touch_file "$sweep_repo" pass-impl.txt "i"
commit_all "$sweep_repo" "feat: the pass-node feature"
git -C "$sweep_repo" checkout -q master
git -C "$sweep_repo" merge --no-ff -q -m "merge: land the pass node" node/pass

# node/fail: bare feat:, no test: (FAIL)
git -C "$sweep_repo" checkout -q -b node/fail master
touch_file "$sweep_repo" fail-impl.txt "i"
commit_all "$sweep_repo" "feat: the fail-node feature, untested"
git -C "$sweep_repo" checkout -q master
git -C "$sweep_repo" merge --no-ff -q -m "merge: land the fail node" node/fail

# an octopus merge of two more branches -- structurally has no single node
# tip, must be reported SKIP, never silently counted as PASS or FAIL
git -C "$sweep_repo" checkout -q -b node/oct-a master
touch_file "$sweep_repo" oct-a.txt "a"
commit_all "$sweep_repo" "docs: octopus branch a"
git -C "$sweep_repo" checkout -q -b node/oct-b master
touch_file "$sweep_repo" oct-b.txt "b"
commit_all "$sweep_repo" "docs: octopus branch b"
git -C "$sweep_repo" checkout -q master
git -C "$sweep_repo" merge --no-ff -q -m "merge: octopus land a+b" node/oct-a node/oct-b >/dev/null

sweep_head="$(git -C "$sweep_repo" rev-parse HEAD)"
out_g="$(python3 "$gate" --sweep "${sweep_root}..${sweep_head}" --repo "$sweep_repo" 2>&1)"
rc_g=$?
if [[ "$rc_g" -eq 1 ]] \
   && grep -q "1 PASS, 1 FAIL, 0 AMBIGUOUS, 1 SKIP" <<<"$out_g"; then
  echo "PASS  (g) sweep: rc=1, counts 1 PASS / 1 FAIL / 0 AMBIGUOUS / 1 SKIP"
else
  echo "FAIL  (g) sweep: rc=$rc_g, or counts did not match" >&2
  printf '%s\n' "$out_g" | sed 's/^/    /' >&2
  fails=$((fails + 1))
fi

# =============================================================================
# (h) usage / environment errors
# =============================================================================
echo "=== (h) usage and environment errors ==="
expect_rc "(h) nonexistent branch ref: exit 2, ENV" 2 "ENV:" -- does-not-exist-xyz --against master
out_h1="$(python3 "$gate" --repo "$repo" 2>&1)"; rc_h1=$?
if [[ "$rc_h1" -eq 2 ]]; then
  echo "PASS  (h) neither branch-ref nor --sweep given: exit 2"
else
  echo "FAIL  (h) neither branch-ref nor --sweep given: rc=$rc_h1 (want 2)" >&2
  fails=$((fails + 1))
fi
out_h2="$(python3 "$gate" node-a --sweep "master..master" --repo "$repo" 2>&1)"; rc_h2=$?
if [[ "$rc_h2" -eq 2 ]]; then
  echo "PASS  (h) both branch-ref and --sweep given: exit 2"
else
  echo "FAIL  (h) both branch-ref and --sweep given: rc=$rc_h2 (want 2)" >&2
  fails=$((fails + 1))
fi

# =============================================================================
# (i) mutation: break the ordering comparison, show (c2)'s FAIL fixture
# (implementation, evaluator only after) read as PASS -- the suite must be
# ABLE to fail, per the Verification Dual.
# =============================================================================
echo "=== (i) mutation: ordering comparison broken -> case (c2) goes green ==="
mutant="$scratch/red_baseline_mutant.py"
cp "$gate" "$mutant"
# Stop checking ORDER, start checking mere PRESENCE of a test: commit
# anywhere in range -- exactly the class of defect this suite exists to
# catch: an evaluator committed AFTER the implementation it claims to cover
# would still read as satisfied.
python3 - "$mutant" <<'PYEOF'
import sys
path = sys.argv[1]
src = open(path, encoding="utf-8").read()
needle = (
    "    preceding_tests = [i for i in test_idx if i < first_impl]\n"
    "    if preceding_tests:\n"
    "        t = commits[preceding_tests[-1]]\n"
)
replacement = (
    "    preceding_tests = [i for i in test_idx if i < first_impl]\n"
    "    if test_idx:\n"
    "        t = commits[test_idx[-1]]\n"
)
assert needle in src, "mutation target not found -- red_baseline.py's ordering check moved"
src = src.replace(needle, replacement, 1)
open(path, "w", encoding="utf-8").write(src)
PYEOF
out_mut="$(python3 "$mutant" node-c2 --against master --repo "$repo" 2>&1)"
rc_mut=$?
if [[ "$rc_mut" -eq 0 ]] && grep -q '^PASS' <<<"$out_mut"; then
  echo "PASS  (i) mutant: case (c2) (evaluator only after) read as PASS -- suite can fail"
else
  echo "FAIL  (i) mutant did not flip case (c2) to PASS as expected (rc=$rc_mut)" >&2
  printf '%s\n' "$out_mut" | sed 's/^/    /' >&2
  fails=$((fails + 1))
fi
# Confirm the UNMUTATED gate still correctly fails case (c2) -- the negative
# control alongside the mutant's positive one.
out_orig="$(run_gate node-c2 --against master)"
if grep -q '^FAIL' <<<"$out_orig"; then
  echo "PASS  (i) unmutated gate still reports FAIL for case (c2)"
else
  echo "FAIL  (i) unmutated gate no longer reports FAIL for case (c2)" >&2
  fails=$((fails + 1))
fi

echo "---"
if [[ "$fails" -ne 0 ]]; then
  echo "FAIL: $fails case(s) mismatched" >&2
  exit 1
fi
echo "PASS: all red_baseline.py cases behave as specified"
exit 0
