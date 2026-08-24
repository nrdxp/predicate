#!/usr/bin/env bash
# install-hooks.sh — wire the tracked hooks into git, in one idempotent command.
#
# Installs the tracked hooks/ (commit-msg, pre-commit) into the repository's
# git hooks directory. Safe to re-run: an already-correct hook is left as-is.
#
# Worktree-correct: git stores hooks in the COMMON git dir (shared by the main
# checkout and every linked worktree), so installing once makes the hooks
# effective everywhere. We resolve that dir with `git rev-parse
# --git-common-dir` rather than assuming `.git/hooks`.
#
# Usage:
#   hooks/install-hooks.sh              (install — run from anywhere inside the repo)
#   hooks/install-hooks.sh --uninstall  (remove only predicate's hook symlinks)
# Exit:   0 = installed / already current / removed, non-zero = could not complete.
set -euo pipefail

# The tracked hooks this installer manages, in one place so install and
# uninstall (and every fixture) enumerate the identical set.
HOOK_NAMES=(commit-msg pre-commit)

# Parse args: support --uninstall mode.
mode="install"
for arg in "$@"; do
  case "$arg" in
    --uninstall) mode="uninstall" ;;
    *) echo "install-hooks: unknown argument: $arg" >&2; exit 2 ;;
  esac
done

# The hooks SOURCE is predicate MACHINERY: resolve it from THIS installer's own
# real path (it is <plugin>/hooks/install-hooks.sh), not from the git toplevel, so
# the installer wires the plugin's hooks even when run inside a consuming repo. The
# DESTINATION is the gated repo's git dir, resolved with git.
hooks_src="$(cd "$(dirname "$(realpath "${BASH_SOURCE[0]}")")" && pwd)"
common_git_dir="$(git rev-parse --git-common-dir)"
# --git-common-dir may be relative to cwd; normalize to an absolute path.
case "$common_git_dir" in
  /*) : ;;
  *)  common_git_dir="$(cd "$common_git_dir" && pwd)" ;;
esac

# Self-host wrinkle: predicate gates its OWN development, so "this installer's
# own real path" can be a LINKED WORKTREE's checked-out copy of hooks/ rather
# than the main worktree's -- a transient node worktree spun up for one piece
# of work. Symlinking the shared hook at that copy ties every commit, in
# every worktree, to whatever that one branch happens to contain, and the
# link dangles the moment the worktree is removed (observed: a worker ran
# this installer from a node worktree and captured the shared hooks there).
# A CONSUMING repo is never affected -- its plugin checkout is a different
# repository from the project being gated, so the check below never fires.
#
# Detection: does hooks_src belong to the SAME repository as the DESTINATION
# ($common_git_dir)? If so, and hooks_src's own git-dir is not the common
# dir (i.e. it sits in a linked, not the main, worktree), redirect the
# source to the MAIN worktree's hooks/ -- `git worktree list --porcelain`
# always lists the main worktree first (git's own documented ordering).
resolve_git_dir() { # dir  rev-parse-flag
  local d="$1" flag="$2" out
  out="$(cd "$d" && git rev-parse "$flag" 2>/dev/null)" || return 1
  case "$out" in
    /*) printf '%s\n' "$out" ;;
    *)  (cd "$d" && cd "$out" && pwd) ;;
  esac
}

hooks_src_common="$(resolve_git_dir "$hooks_src" --git-common-dir || true)"
if [ -n "$hooks_src_common" ] && [ "$hooks_src_common" = "$common_git_dir" ]; then
  hooks_src_own="$(resolve_git_dir "$hooks_src" --git-dir || true)"
  if [ -n "$hooks_src_own" ] && [ "$hooks_src_own" != "$common_git_dir" ]; then
    main_worktree="$(git -C "$hooks_src" worktree list --porcelain 2>/dev/null \
      | awk '/^worktree /{print $2; exit}')"
    if [ -n "$main_worktree" ] && [ -d "$main_worktree/hooks" ]; then
      echo "install-hooks: self-host from a linked worktree — sourcing hooks from the main worktree: $main_worktree/hooks" >&2
      hooks_src="$main_worktree/hooks"
    fi
  fi
fi

hooks_dst="$common_git_dir/hooks"

if [ "$mode" = "uninstall" ]; then
  # Uninstall: remove hook symlinks ONLY when they resolve to this plugin's hooks.
  # A real (user-owned) hook file or a symlink pointing elsewhere is NEVER touched.
  removed=0
  for hook in "${HOOK_NAMES[@]}"; do
    dst="$hooks_dst/$hook"
    if [ ! -e "$dst" ] && [ ! -L "$dst" ]; then
      echo "install-hooks: $hook already absent."
      continue
    fi
    if [ ! -L "$dst" ]; then
      echo "install-hooks: $hook is a real file (not a predicate symlink) — leaving untouched."
      continue
    fi
    # Resolve symlink via realpath -m (no-existence canonicalization) to get the
    # absolute target for comparison.  Plain `realpath` returns empty for a
    # dangling link whose parent directory is also missing (e.g. the plugin was
    # cleaned up), so the old comparison would fail and the symlink would be
    # orphaned.  `realpath -m` canonicalises the encoded path without requiring
    # the target to exist, so a dangling-but-ours link still matches $expected
    # and is correctly removed.
    resolved="$(realpath -m "$dst" 2>/dev/null)"
    expected="$hooks_src/$hook"
    if [ "$resolved" != "$expected" ]; then
      echo "install-hooks: $hook -> $resolved does not point to this plugin ($expected) — leaving untouched."
      continue
    fi
    rm "$dst"
    removed=$((removed + 1))
    echo "install-hooks: removed $hook symlink."
  done
  if [ "$removed" -eq 0 ]; then
    echo "install-hooks: no predicate hook symlinks found (already clean)."
  else
    echo "install-hooks: uninstall done ($removed symlink(s) removed)."
  fi
  exit 0
fi

mkdir -p "$hooks_dst"

changed=0
for hook in "${HOOK_NAMES[@]}"; do
  src="$hooks_src/$hook"
  dst="$hooks_dst/$hook"
  if [ ! -f "$src" ]; then
    echo "install-hooks: missing source hook: $src" >&2
    exit 1
  fi
  # Point the git hook at the tracked source via a relative symlink, so updates
  # to hooks/ take effect with no reinstall. Idempotent: if the link already
  # resolves to our source, do nothing.
  rel="$(realpath --relative-to="$hooks_dst" "$src")"
  if [ -L "$dst" ] && [ "$(readlink "$dst")" = "$rel" ]; then
    continue
  fi
  ln -sfn "$rel" "$dst"
  changed=1
  echo "install-hooks: linked $hook -> $rel"
done

# Source hooks are tracked with the +x bit; ensure it (no-op if already set).
for hook in "${HOOK_NAMES[@]}"; do
  chmod +x "$hooks_src/$hook" 2>/dev/null || true
done
chmod +x "$hooks_src/install-hooks.sh" 2>/dev/null || true

if [ "$changed" -eq 0 ]; then
  echo "install-hooks: hooks already current (no-op)."
else
  echo "install-hooks: done. Hooks are effective in this checkout and all linked worktrees."
fi
