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
# Usage:  hooks/install-hooks.sh        (run from anywhere inside the repo)
# Exit:   0 = installed / already current, non-zero = could not install.
set -euo pipefail

root="$(git rev-parse --show-toplevel)"
common_git_dir="$(git rev-parse --git-common-dir)"
# --git-common-dir may be relative to cwd; normalize to an absolute path.
case "$common_git_dir" in
  /*) : ;;
  *)  common_git_dir="$(cd "$common_git_dir" && pwd)" ;;
esac

hooks_src="$root/hooks"
hooks_dst="$common_git_dir/hooks"
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
