#!/usr/bin/env bash
# Fixture-driven tests for hooks/pre-merge-commit -- the merge-time gate that
# wires ledger/gate/red_baseline.py into `git merge` itself (composer
# dispatch, node/hook-wiring, defect 2: "nothing fires at merge").
#
# Every fixture repo here is synthetic and disposable, mirroring the
# isolation test_trial_merge.sh and test_red_baseline.sh already use -- a
# defect in the hook can never touch predicate itself while these run. The
# hook is exercised through a REAL SYMLINK into THIS checkout's own
# hooks/pre-merge-commit (never a copy): the hook resolves its own machinery
# ($plugin) via realpath through that symlink, exactly as a real install
# would (hooks/install-hooks.sh's own documented invariant) -- a plain copy
# would resolve $plugin to the fixture's own .git and never find
# red_baseline.py at all.
#
# Cases:
#   (a) REFUSES what it should refuse: a branch with a feat: commit and no
#       preceding test: commit -- `git merge` itself fails, no merge commit
#       is created.
#   (b) PERMITS a clean node: test: precedes feat: -- merge proceeds.
#   (c) PERMITS what it cannot judge -- an octopus merge (3+ parents): the
#       hook exits 0 regardless of ordering; git completes the merge.
#   (d) PERMITS what it cannot judge -- a rebase replaying a merge commit:
#       exercised as a direct invocation (a fabricated rebase-merge marker),
#       since orchestrating a real `git rebase --rebase-merges` collision is
#       unnecessary to prove the guard fires.
#
# Usage: test_pre_merge_commit.sh
# Exit:  0 = every case matched, 1 = a case mismatched, 2 = environment error.
set -u

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
hook_src="$here/../../hooks/pre-merge-commit"

if [[ ! -f "$hook_src" ]]; then
  echo "ENV: hooks/pre-merge-commit missing: $hook_src" >&2
  exit 2
fi

fails=0
FIXED_DATE="2000-01-01T00:00:00+00:00"

init_repo() { # dir -- also symlinks the REAL hook under test into place
  local dir="$1" common
  mkdir -p "$dir"
  git -C "$dir" init -q -b master
  git -C "$dir" config user.email "test@pre-merge-commit.example"
  git -C "$dir" config user.name  "Pre Merge Commit Test"
  common="$(git -C "$dir" rev-parse --git-common-dir)"
  case "$common" in
    /*) : ;;
    *) common="$(cd "$dir" && cd "$common" && pwd)" ;;
  esac
  mkdir -p "$common/hooks"
  ln -sfn "$hook_src" "$common/hooks/pre-merge-commit"
}

commit_all() { # repo message
  local repo="$1" msg="$2"
  git -C "$repo" add -A
  GIT_AUTHOR_DATE="$FIXED_DATE" GIT_COMMITTER_DATE="$FIXED_DATE" \
    git -C "$repo" commit -q -m "$msg"
}

touch_file() { # repo relpath content
  local repo="$1" rel="$2" content="$3"
  mkdir -p "$(dirname "$repo/$rel")"
  printf '%s\n' "$content" > "$repo/$rel"
}

common_hooks_dir() { # repo
  local repo="$1" common
  common="$(git -C "$repo" rev-parse --git-common-dir)"
  case "$common" in
    /*) : ;;
    *) common="$(cd "$repo" && cd "$common" && pwd)" ;;
  esac
  echo "$common/hooks"
}

scratch="$(mktemp -d)"
trap 'rm -rf "$scratch"' EXIT

# =============================================================================
# Case (a): refuses a branch with an unordered evaluator
# =============================================================================
echo "=== case (a): feat: with no preceding test: -- merge refused ==="
repo_a="$scratch/repo-a"
init_repo "$repo_a"
touch_file "$repo_a" root.txt "root"
commit_all "$repo_a" "chore: seed repo"
head_before_a="$(git -C "$repo_a" rev-parse HEAD)"

git -C "$repo_a" checkout -q -b node-bad
touch_file "$repo_a" bad.txt "impl"
commit_all "$repo_a" "feat: implement the widget, untested"
git -C "$repo_a" checkout -q master

out_a="$(git -C "$repo_a" merge --no-ff -m "merge: land node-bad" node-bad 2>&1)"
rc_a=$?
head_after_a="$(git -C "$repo_a" rev-parse HEAD)"
git -C "$repo_a" merge --abort >/dev/null 2>&1 || true

if [[ "$rc_a" -ne 0 ]] && [[ "$head_after_a" == "$head_before_a" ]]; then
  echo "PASS  case (a): merge refused (rc=$rc_a), no merge commit created"
else
  echo "FAIL  case (a): rc=$rc_a, head moved from $head_before_a to $head_after_a (want refused, head unchanged)" >&2
  echo "$out_a" >&2
  fails=$((fails + 1))
fi

# =============================================================================
# Case (b): permits a clean node
# =============================================================================
echo "=== case (b): test: precedes feat: -- merge permitted ==="
git -C "$repo_a" checkout -q -b node-good master
touch_file "$repo_a" good-test.txt "test"
commit_all "$repo_a" "test: red the gadget before it exists"
touch_file "$repo_a" good-impl.txt "impl"
commit_all "$repo_a" "feat: implement the gadget"
git -C "$repo_a" checkout -q master

head_before_b="$(git -C "$repo_a" rev-parse HEAD)"
out_b="$(git -C "$repo_a" merge --no-ff -m "merge: land node-good" node-good 2>&1)"
rc_b=$?
head_after_b="$(git -C "$repo_a" rev-parse HEAD)"

if [[ "$rc_b" -eq 0 ]] && [[ "$head_after_b" != "$head_before_b" ]]; then
  echo "PASS  case (b): merge permitted, merge commit created"
else
  echo "FAIL  case (b): rc=$rc_b, head_before=$head_before_b head_after=$head_after_b" >&2
  echo "$out_b" >&2
  fails=$((fails + 1))
fi

# =============================================================================
# Case (c): permits what it cannot judge -- an octopus merge
# =============================================================================
echo "=== case (c): octopus merge -- cannot judge a single tip, permitted ==="
repo_c="$scratch/repo-c"
init_repo "$repo_c"
touch_file "$repo_c" root.txt "root"
commit_all "$repo_c" "chore: seed repo"

git -C "$repo_c" checkout -q -b side-a
touch_file "$repo_c" a.txt "a"
commit_all "$repo_c" "feat: side branch a, untested"
git -C "$repo_c" checkout -q master
git -C "$repo_c" checkout -q -b side-b master
touch_file "$repo_c" b.txt "b"
commit_all "$repo_c" "feat: side branch b, untested"
git -C "$repo_c" checkout -q master

out_c="$(git -C "$repo_c" merge --no-ff -m "merge: octopus land a+b" side-a side-b 2>&1)"
rc_c=$?
if [[ "$rc_c" -eq 0 ]]; then
  echo "PASS  case (c): octopus merge permitted despite untested feat: commits"
else
  echo "FAIL  case (c): rc=$rc_c (want 0 -- cannot judge, must not block)" >&2
  echo "$out_c" >&2
  fails=$((fails + 1))
fi

# =============================================================================
# Case (d): permits what it cannot judge -- a rebase replaying a merge
# =============================================================================
echo "=== case (d): rebase in progress -- cannot judge a replay, permitted ==="
repo_d="$scratch/repo-d"
init_repo "$repo_d"
touch_file "$repo_d" root.txt "root"
commit_all "$repo_d" "chore: seed repo"
common_hooks_d="$(common_hooks_dir "$repo_d")"
mkdir -p "$(dirname "$common_hooks_d")/rebase-merge"
out_d="$(cd "$repo_d" && bash "$common_hooks_d/pre-merge-commit" 2>&1)"
rc_d=$?
rmdir "$(dirname "$common_hooks_d")/rebase-merge"
if [[ "$rc_d" -eq 0 ]] && grep -qi "rebase" <<<"$out_d"; then
  echo "PASS  case (d): rebase-in-progress permitted, and named as the reason"
else
  echo "FAIL  case (d): rc=$rc_d (want 0, mentioning rebase)" >&2
  echo "$out_d" >&2
  fails=$((fails + 1))
fi

echo "---"
if [[ "$fails" -ne 0 ]]; then
  echo "FAIL: $fails case(s) mismatched" >&2
  exit 1
fi
echo "PASS: all pre-merge-commit cases behave as specified"
exit 0
