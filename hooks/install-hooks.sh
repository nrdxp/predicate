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
# DESTINATION is the gated repo's git dir, resolved with git. In the self-host case
# the two coincide.
hooks_src="$(cd "$(dirname "$(realpath "${BASH_SOURCE[0]}")")" && pwd)"
common_git_dir="$(git rev-parse --git-common-dir)"
# --git-common-dir may be relative to cwd; normalize to an absolute path.
case "$common_git_dir" in
  /*) : ;;
  *)  common_git_dir="$(cd "$common_git_dir" && pwd)" ;;
esac

hooks_dst="$common_git_dir/hooks"

if [ "$mode" = "uninstall" ]; then
  # Uninstall: remove hook symlinks ONLY when they resolve to this plugin's hooks.
  # A real (user-owned) hook file or a symlink pointing elsewhere is NEVER touched.
  removed=0
  for hook in commit-msg pre-commit; do
    dst="$hooks_dst/$hook"
    if [ ! -e "$dst" ] && [ ! -L "$dst" ]; then
      echo "install-hooks: $hook already absent."
      continue
    fi
    if [ ! -L "$dst" ]; then
      echo "install-hooks: $hook is a real file (not a predicate symlink) — leaving untouched."
      continue
    fi
    # Resolve symlink via realpath to get the absolute target for comparison.
    resolved="$(realpath "$dst" 2>/dev/null || true)"
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
for hook in commit-msg pre-commit; do
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
chmod +x "$hooks_src/commit-msg" "$hooks_src/pre-commit" "$hooks_src/install-hooks.sh" 2>/dev/null || true

if [ "$changed" -eq 0 ]; then
  echo "install-hooks: hooks already current (no-op)."
else
  echo "install-hooks: done. Hooks are effective in this checkout and all linked worktrees."
fi
