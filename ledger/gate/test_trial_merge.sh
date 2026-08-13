#!/usr/bin/env bash
# Fixture-driven tests for trial_merge.sh — the merge gate.
#
# Every fixture repo built here is synthetic, disposable, and unrelated to
# this project's own tree, so a bug in trial_merge.sh can never touch
# predicate itself while these run. Cases:
#
#   (a) CROSS-BRANCH REGRESSION — the fixture this gate exists for. Branch
#       "already-merged" (simulating a prior landing) adds a consumer of a
#       binding; branch "under-test" (from an OLDER base, before that
#       landing) renames the binding away — disjoint files, clean merge,
#       branch alone still green because the consumer does not exist on its
#       tree at all. -> rc 1, names the regression, does not report the new
#       failure as pre-existing.
#   (b) CLEAN — an unrelated branch merges and stays green.             -> rc 0
#   (c) CONFLICT — a branch edits the same line master diverged on.     -> rc 3
#   (d) PRE-EXISTING FAILURE CARRIED FORWARD — a branch whose OWN suite
#       already fails a test; the merge changes nothing about that test.
#       -> rc 0 (not reported as a regression, even though non-zero appears
#       in the transcript)
#
# Case (e), the real-repository-untouched demonstration, is not a fixture: it
# snapshots THIS repo's `git status --short` and `git worktree list` around a
# real invocation of trial_merge.sh against this repo's own master.
#
# Usage: test_trial_merge.sh
# Exit:  0 = every case matched, 1 = a case mismatched, 2 = environment error.
set -u

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
gate="$here/trial_merge.sh"
root="$(cd "$here/../.." && pwd)"

if [[ ! -x "$gate" ]]; then
  echo "ERROR: trial_merge.sh not found or not executable at $gate" >&2
  exit 2
fi

fails=0
FIXED_DATE="2000-01-01T00:00:00+00:00"

init_repo() {
  local dir="$1"
  mkdir -p "$dir"
  git -C "$dir" init -q -b master
  git -C "$dir" config user.email "test@trial-merge.example"
  git -C "$dir" config user.name  "Trial Merge Test"
}

commit_all() { # repo message
  local repo="$1" msg="$2"
  git -C "$repo" add -A
  GIT_AUTHOR_DATE="$FIXED_DATE" GIT_COMMITTER_DATE="$FIXED_DATE" \
    git -C "$repo" commit -q -m "$msg"
}

pass_test() { echo "#!/usr/bin/env bash
echo OK
exit 0"; }

scratch="$(mktemp -d)"
trap 'rm -rf "$scratch"' EXIT

# =============================================================================
# Case (a): cross-branch regression on disjoint files (the D79-81 fixture)
# =============================================================================
echo "=== case (a): cross-branch regression (disjoint files, clean merge) ==="
repo_a="$scratch/repo-a"
init_repo "$repo_a"
mkdir -p "$repo_a/ledger/gate"

cat > "$repo_a/ledger/gate/lib.sh" <<'EOF'
greet() { echo hello; }
EOF
cat > "$repo_a/ledger/gate/test_greet.sh" <<'EOF'
#!/usr/bin/env bash
set -e
here="$(cd "$(dirname "$0")" && pwd)"
source "$here/lib.sh"
[ "$(greet)" = "hello" ] || { echo "greet broken"; exit 1; }
echo OK
EOF
chmod +x "$repo_a/ledger/gate/test_greet.sh"
commit_all "$repo_a" "root: lib.sh + test_greet.sh"
root_sha="$(git -C "$repo_a" rev-parse HEAD)"

# "already-merged": adds a consumer of greet(), landed on master.
cat > "$repo_a/ledger/gate/consumer.sh" <<'EOF'
here="$(cd "$(dirname "$0")" && pwd)"
source "$here/lib.sh"
consumer() { greet; }
EOF
cat > "$repo_a/ledger/gate/test_consumer.sh" <<'EOF'
#!/usr/bin/env bash
set -e
here="$(cd "$(dirname "$0")" && pwd)"
source "$here/consumer.sh"
[ "$(consumer)" = "hello" ] || { echo "consumer broken"; exit 1; }
echo OK
EOF
chmod +x "$repo_a/ledger/gate/test_consumer.sh"
commit_all "$repo_a" "master: add consumer.sh depending on greet()"
master_sha="$(git -C "$repo_a" rev-parse HEAD)"

# "under-test": branched from the ROOT (before consumer.sh existed), renames
# greet -> salute. Its own tree never saw consumer.sh, so its own battery is
# just test_greet.sh, which it keeps green.
git -C "$repo_a" checkout -q -b under-test "$root_sha"
cat > "$repo_a/ledger/gate/lib.sh" <<'EOF'
salute() { echo hello; }
EOF
cat > "$repo_a/ledger/gate/test_greet.sh" <<'EOF'
#!/usr/bin/env bash
set -e
here="$(cd "$(dirname "$0")" && pwd)"
source "$here/lib.sh"
[ "$(salute)" = "hello" ] || { echo "salute broken"; exit 1; }
echo OK
EOF
commit_all "$repo_a" "under-test: rename greet -> salute"
git -C "$repo_a" checkout -q master

out_a="$("$gate" under-test --against master --repo "$repo_a" --timeout 30 2>&1)"
rc_a=$?
if [[ "$rc_a" -eq 1 ]] && grep -q "test_consumer.sh.*REGRESSION" <<<"$out_a" \
   && ! grep -q "test_consumer.sh.*pre-existing" <<<"$out_a"; then
  echo "PASS  case (a): rc=1, test_consumer.sh named as a REGRESSION"
else
  echo "FAIL  case (a): rc=$rc_a (want 1), or test_consumer.sh not named as a regression" >&2
  echo "$out_a" >&2
  fails=$((fails + 1))
fi

# =============================================================================
# Case (b): clean merge, stays green
# =============================================================================
echo "=== case (b): clean merge, stays green ==="
git -C "$repo_a" checkout -q -b clean-addition master
cat > "$repo_a/ledger/gate/test_extra.sh" <<EOF
$(pass_test)
EOF
chmod +x "$repo_a/ledger/gate/test_extra.sh"
commit_all "$repo_a" "clean-addition: add an unrelated passing test"
git -C "$repo_a" checkout -q master

out_b="$("$gate" clean-addition --against master --repo "$repo_a" --timeout 30 2>&1)"
rc_b=$?
if [[ "$rc_b" -eq 0 ]] && grep -q "VERDICT: PASS" <<<"$out_b"; then
  echo "PASS  case (b): rc=0, VERDICT: PASS"
else
  echo "FAIL  case (b): rc=$rc_b (want 0)" >&2
  echo "$out_b" >&2
  fails=$((fails + 1))
fi

# =============================================================================
# Case (c): conflict — reported distinctly from a battery failure
# =============================================================================
echo "=== case (c): conflict, reported distinctly ==="
git -C "$repo_a" checkout -q -b conflicting master
sed -i 's/echo hello/echo bonjour/' "$repo_a/ledger/gate/consumer.sh" 2>/dev/null || true
echo "consumer() { echo bonjour; }" > "$repo_a/ledger/gate/consumer.sh"
commit_all "$repo_a" "conflicting: change consumer.sh"
git -C "$repo_a" checkout -q master
echo "consumer() { echo bonsoir; }" > "$repo_a/ledger/gate/consumer.sh"
commit_all "$repo_a" "master: also change consumer.sh (diverging edit)"

out_c="$("$gate" conflicting --against master --repo "$repo_a" --timeout 30 2>&1)"
rc_c=$?
if [[ "$rc_c" -eq 3 ]] && grep -q "VERDICT: CONFLICT" <<<"$out_c"; then
  echo "PASS  case (c): rc=3, VERDICT: CONFLICT (distinct from rc=1 battery failure)"
else
  echo "FAIL  case (c): rc=$rc_c (want 3)" >&2
  echo "$out_c" >&2
  fails=$((fails + 1))
fi

# =============================================================================
# Case (d): pre-existing failure on the branch itself is not reported as a
# merge regression
# =============================================================================
echo "=== case (d): pre-existing branch failure is not a regression ==="
git -C "$repo_a" checkout -q -b already-broken master
cat > "$repo_a/ledger/gate/test_broken.sh" <<'EOF'
#!/usr/bin/env bash
echo "was already broken on this branch"
exit 1
EOF
chmod +x "$repo_a/ledger/gate/test_broken.sh"
commit_all "$repo_a" "already-broken: add a test that already fails on this branch"
git -C "$repo_a" checkout -q master

out_d="$("$gate" already-broken --against master --repo "$repo_a" --timeout 30 2>&1)"
rc_d=$?
if [[ "$rc_d" -eq 0 ]] && grep -q "test_broken.sh.*pre-existing" <<<"$out_d" \
   && ! grep -q "test_broken.sh.*REGRESSION" <<<"$out_d"; then
  echo "PASS  case (d): rc=0, test_broken.sh reported pre-existing, not a regression"
else
  echo "FAIL  case (d): rc=$rc_d (want 0), or test_broken.sh mis-classified" >&2
  echo "$out_d" >&2
  fails=$((fails + 1))
fi

# =============================================================================
# Case (e): the real repository is byte-identical before and after
# =============================================================================
echo "=== case (e): real repository untouched by an invocation against itself ==="
before_status="$(git -C "$root" status --short)"
before_worktrees="$(git -C "$root" worktree list --porcelain)"
before_branches="$(git -C "$root" for-each-ref --format='%(refname)' refs/heads)"

# Gate this worktree's own current branch against its own merge-base with
# master — always resolvable, always a real invocation against a real repo.
self_branch="$(git -C "$root" rev-parse --abbrev-ref HEAD)"
"$gate" "$self_branch" --against master --repo "$root" --timeout 20 >/dev/null 2>&1 || true

after_status="$(git -C "$root" status --short)"
after_worktrees="$(git -C "$root" worktree list --porcelain)"
after_branches="$(git -C "$root" for-each-ref --format='%(refname)' refs/heads)"

if [[ "$before_status" == "$after_status" ]] \
   && [[ "$before_worktrees" == "$after_worktrees" ]] \
   && [[ "$before_branches" == "$after_branches" ]]; then
  echo "PASS  case (e): git status, worktree list, and refs/heads unchanged"
else
  echo "FAIL  case (e): the real repository changed across an invocation" >&2
  diff <(echo "$before_status") <(echo "$after_status") >&2 || true
  diff <(echo "$before_worktrees") <(echo "$after_worktrees") >&2 || true
  diff <(echo "$before_branches") <(echo "$after_branches") >&2 || true
  fails=$((fails + 1))
fi

echo "---"
if [[ "$fails" -ne 0 ]]; then
  echo "FAIL: $fails case(s) mismatched" >&2
  exit 1
fi
echo "PASS: all trial_merge.sh cases behave as specified"
exit 0
