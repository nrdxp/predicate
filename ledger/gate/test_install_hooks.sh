#!/usr/bin/env bash
# Fixture-driven tests for hooks/install-hooks.sh's SOURCE resolution
# (composer dispatch, node/hook-wiring, defect 1: "the installer lets a
# worktree capture the shared hooks").
#
# The installer resolved its hooks SOURCE from its own real path
# unconditionally. Running it from a LINKED WORKTREE of the very repo it
# gates (the self-host case) then points the shared git-common-dir hook
# symlink at that transient worktree's checked-out copy of hooks/ -- every
# commit, in every worktree, depends on whatever that one branch contains,
# and the link dangles the moment the worktree is removed. Observed for
# real: a worker ran the installer from a node worktree and captured the
# shared commit-msg/pre-commit hooks there.
#
# Every fixture repo built here is synthetic and disposable, mirroring the
# isolation test_trial_merge.sh and test_red_baseline.sh already use -- a bug
# in the fix can never touch predicate itself while these run.
#
# Cases:
#   (a) SELF-HOST, LINKED WORKTREE -- the installer, run from a linked
#       worktree of the repo it gates, must source hooks from the MAIN
#       worktree, not its own checked-out copy.
#   (b) SELF-HOST, MAIN WORKTREE -- run from the main worktree, unaffected:
#       sources its own hooks/, same as before the fix.
#   (c) CONSUMING REPO -- the installer's own repo differs from the repo
#       being gated (the ordinary downstream-plugin shape) -- unaffected,
#       sources the plugin's own hooks/ regardless of worktree topology.
#   (d) UNINSTALL, REAL FILE PRESERVED -- a real (non-symlink) hook file at
#       the destination, ours or a user's own, is never removed by
#       --uninstall, for every hook name the installer manages (a regression
#       check covering the third hook, pre-merge-commit, added alongside
#       this fix).
#
# Usage: test_install_hooks.sh
# Exit:  0 = every case matched, 1 = a case mismatched, 2 = environment error.
set -u

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
installer_src="$here/../../hooks/install-hooks.sh"

if [[ ! -f "$installer_src" ]]; then
  echo "ENV: hooks/install-hooks.sh not found at $installer_src" >&2
  exit 2
fi

fails=0
FIXED_DATE="2000-01-01T00:00:00+00:00"

init_repo() {
  local dir="$1"
  mkdir -p "$dir"
  git -C "$dir" init -q -b master
  git -C "$dir" config user.email "test@install-hooks.example"
  git -C "$dir" config user.name  "Install Hooks Test"
}

commit_all() { # repo message
  local repo="$1" msg="$2"
  git -C "$repo" add -A
  GIT_AUTHOR_DATE="$FIXED_DATE" GIT_COMMITTER_DATE="$FIXED_DATE" \
    git -C "$repo" commit -q -m "$msg"
}

# Build a fake "predicate-like" repo: hooks/install-hooks.sh (copied from the
# installer under test, so a mutant copy is drop-in swappable) plus three
# dummy hook scripts. What proves WHICH copy a symlink resolves to is the
# absolute path, not the content -- the checked-out content is byte-identical
# between the main worktree and any linked worktree of it.
seed_selfhost_repo() { # dir installer-path
  local dir="$1" installer="$2"
  init_repo "$dir"
  mkdir -p "$dir/hooks"
  cp "$installer" "$dir/hooks/install-hooks.sh"
  chmod +x "$dir/hooks/install-hooks.sh"
  for hook in commit-msg pre-commit pre-merge-commit; do
    printf '#!/usr/bin/env bash\nexit 0\n' > "$dir/hooks/$hook"
    chmod +x "$dir/hooks/$hook"
  done
  commit_all "$dir" "chore: seed hooks/"
}

resolve_common_hooks_dir() { # repo
  local repo="$1" common
  common="$(git -C "$repo" rev-parse --git-common-dir)"
  case "$common" in
    /*) : ;;
    *) common="$(cd "$repo" && cd "$common" && pwd)" ;;
  esac
  echo "$common/hooks"
}

resolved_symlink_target() { # hooks-dir hook-name
  local hooks_dir="$1" hook="$2" target
  target="$(readlink "$hooks_dir/$hook" 2>/dev/null || true)"
  [[ -n "$target" ]] || { echo ""; return; }
  (cd "$hooks_dir" && realpath -m "$target" 2>/dev/null) || echo ""
}

scratch="$(mktemp -d)"
trap 'rm -rf "$scratch"' EXIT

# =============================================================================
# Case (a): self-host, run from a LINKED WORKTREE -- sources the MAIN
# worktree's hooks/, not its own.
# =============================================================================
echo "=== case (a): self-host from a linked worktree -- sources the main worktree ==="
main_repo="$scratch/selfhost-main"
seed_selfhost_repo "$main_repo" "$installer_src"
git -C "$main_repo" worktree add -q -b node/fixture "$scratch/selfhost-wt" >/dev/null 2>&1

out_a="$(cd "$scratch/selfhost-wt" && bash hooks/install-hooks.sh 2>&1)"
rc_a=$?
common_hooks_a="$(resolve_common_hooks_dir "$main_repo")"
resolved_a="$(resolved_symlink_target "$common_hooks_a" "pre-commit")"

if [[ "$rc_a" -eq 0 ]] && [[ "$resolved_a" == "$main_repo/hooks/pre-commit" ]]; then
  echo "PASS  case (a): symlink resolves to the MAIN worktree's hooks/"
else
  echo "FAIL  case (a): rc=$rc_a, resolved='$resolved_a' (want '$main_repo/hooks/pre-commit')" >&2
  echo "$out_a" >&2
  fails=$((fails + 1))
fi

# =============================================================================
# Case (b): self-host, run from the MAIN worktree -- unaffected.
# =============================================================================
echo "=== case (b): self-host from the main worktree -- unaffected ==="
main_repo_b="$scratch/selfhost-main-b"
seed_selfhost_repo "$main_repo_b" "$installer_src"
out_b="$(cd "$main_repo_b" && bash hooks/install-hooks.sh 2>&1)"
rc_b=$?
common_hooks_b="$(resolve_common_hooks_dir "$main_repo_b")"
resolved_b="$(resolved_symlink_target "$common_hooks_b" "pre-commit")"
if [[ "$rc_b" -eq 0 ]] && [[ "$resolved_b" == "$main_repo_b/hooks/pre-commit" ]]; then
  echo "PASS  case (b): symlink resolves to its own hooks/ (no redirection needed)"
else
  echo "FAIL  case (b): rc=$rc_b, resolved='$resolved_b' (want '$main_repo_b/hooks/pre-commit')" >&2
  echo "$out_b" >&2
  fails=$((fails + 1))
fi

# =============================================================================
# Case (c): consuming repo -- installer's own repo differs from the repo
# being gated; unaffected regardless of the installer's own worktree state.
# =============================================================================
echo "=== case (c): consuming repo -- sources the plugin's own hooks/ ==="
plugin_repo="$scratch/plugin"
seed_selfhost_repo "$plugin_repo" "$installer_src"   # the "plugin", itself a git repo
project_repo="$scratch/project"
init_repo "$project_repo"
printf 'consuming project\n' > "$project_repo/README.md"
commit_all "$project_repo" "chore: seed consuming project"

out_c="$(cd "$project_repo" && bash "$plugin_repo/hooks/install-hooks.sh" 2>&1)"
rc_c=$?
common_hooks_c="$(resolve_common_hooks_dir "$project_repo")"
resolved_c="$(resolved_symlink_target "$common_hooks_c" "pre-commit")"
if [[ "$rc_c" -eq 0 ]] && [[ "$resolved_c" == "$plugin_repo/hooks/pre-commit" ]]; then
  echo "PASS  case (c): symlink resolves to the plugin's own hooks/ (different repo, unaffected)"
else
  echo "FAIL  case (c): rc=$rc_c, resolved='$resolved_c' (want '$plugin_repo/hooks/pre-commit')" >&2
  echo "$out_c" >&2
  fails=$((fails + 1))
fi

# =============================================================================
# Case (d): uninstall never removes a real (non-symlink) hook file -- ours or
# a user's own -- for every hook name the installer manages, including the
# third hook (pre-merge-commit) added alongside this fix.
# =============================================================================
echo "=== case (d): uninstall preserves a real hook file, every managed hook name ==="
proj_d="$scratch/uninstall-project"
init_repo "$proj_d"
printf 'root\n' > "$proj_d/root.txt"
commit_all "$proj_d" "chore: seed project"
common_hooks_d="$(resolve_common_hooks_dir "$proj_d")"
mkdir -p "$common_hooks_d"
for hook in commit-msg pre-commit pre-merge-commit; do
  printf '#!/usr/bin/env bash\n# a real, user-owned hook -- never a predicate symlink\nexit 0\n' \
    > "$common_hooks_d/$hook"
  chmod +x "$common_hooks_d/$hook"
done

out_d="$(cd "$proj_d" && bash "$installer_src" --uninstall 2>&1)"
rc_d=$?
d_ok=1
for hook in commit-msg pre-commit pre-merge-commit; do
  if [[ -L "$common_hooks_d/$hook" ]] || [[ ! -f "$common_hooks_d/$hook" ]]; then
    d_ok=0
  fi
done
if [[ "$rc_d" -eq 0 ]] && [[ "$d_ok" -eq 1 ]]; then
  echo "PASS  case (d): all three real hook files survive --uninstall untouched"
else
  echo "FAIL  case (d): rc=$rc_d, real hook file(s) touched or removed" >&2
  echo "$out_d" >&2
  fails=$((fails + 1))
fi

echo "---"
if [[ "$fails" -ne 0 ]]; then
  echo "FAIL: $fails case(s) mismatched" >&2
  exit 1
fi
echo "PASS: all install-hooks.sh source-resolution cases behave as specified"
exit 0
