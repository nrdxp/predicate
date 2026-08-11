#!/usr/bin/env bash
# install-recorder-hook.sh — wire recorder-pre-commit.sh into a .ledger
# subrepo's own git hooks, in one idempotent command.
#
# Composed from bootstrap/install.sh init (never inlined) — the same pattern
# hooks/install-hooks.sh already establishes for the PROJECT's own hooks.
# This installer targets the RECORDER's hooks instead: a .ledger subrepo is
# its own git repository with its own .git/hooks/, entirely separate from the
# project's git-common-dir.
#
# Worktree-correct: resolves the recorder's git-common-dir (not a bare
# ".git/hooks" assumption), matching hooks/install-hooks.sh's own approach.
#
# Usage (run with cwd inside the .ledger subrepo):
#   ledger/gate/install-recorder-hook.sh              (install)
#   ledger/gate/install-recorder-hook.sh --uninstall   (remove only predicate's own symlink)
# Exit:   0 = installed / already current / removed, non-zero = could not complete.
set -euo pipefail

mode="install"
for arg in "$@"; do
  case "$arg" in
    --uninstall) mode="uninstall" ;;
    *) echo "install-recorder-hook: unknown argument: $arg" >&2; exit 2 ;;
  esac
done

if ! git rev-parse --git-dir >/dev/null 2>&1; then
  echo "install-recorder-hook: not run inside a git repository (expected cwd inside a .ledger subrepo)" >&2
  exit 2
fi

# The gate SOURCE is predicate MACHINERY: resolve from THIS installer's own
# real path, never from the ledger dir being gated.
gate_src_dir="$(cd "$(dirname "$(realpath "${BASH_SOURCE[0]}")")" && pwd)"
gate_src="$gate_src_dir/recorder-pre-commit.sh"

common_git_dir="$(git rev-parse --git-common-dir)"
case "$common_git_dir" in
  /*) : ;;
  *)  common_git_dir="$(cd "$common_git_dir" && pwd)" ;;
esac
hooks_dst="$common_git_dir/hooks"
dst="$hooks_dst/pre-commit"

if [ "$mode" = "uninstall" ]; then
  # Remove ONLY when the existing hook is a symlink resolving to this
  # plugin's recorder-pre-commit.sh. A real (user-owned) hook, or a symlink
  # pointing elsewhere, is NEVER touched.
  if [ ! -e "$dst" ] && [ ! -L "$dst" ]; then
    echo "install-recorder-hook: pre-commit already absent."
    exit 0
  fi
  if [ ! -L "$dst" ]; then
    echo "install-recorder-hook: pre-commit is a real file (not a predicate symlink) — leaving untouched."
    exit 0
  fi
  # realpath -m canonicalises without requiring the target to exist, so a
  # dangling-but-ours link (plugin cleaned up) still matches and is removed —
  # the same dangling-symlink fix hooks/install-hooks.sh already carries.
  resolved="$(realpath -m "$dst" 2>/dev/null)"
  if [ "$resolved" != "$gate_src" ]; then
    echo "install-recorder-hook: pre-commit -> $resolved does not point to this plugin ($gate_src) — leaving untouched."
    exit 0
  fi
  rm "$dst"
  echo "install-recorder-hook: removed pre-commit symlink."
  exit 0
fi

if [ ! -f "$gate_src" ]; then
  echo "install-recorder-hook: missing source gate: $gate_src" >&2
  exit 1
fi

mkdir -p "$hooks_dst"

# Point the git hook at the tracked source via a relative symlink, so updates
# to recorder-pre-commit.sh take effect with no reinstall. Idempotent: if the
# link already resolves to our source, do nothing.
rel="$(realpath --relative-to="$hooks_dst" "$gate_src")"
if [ -L "$dst" ] && [ "$(readlink "$dst")" = "$rel" ]; then
  echo "install-recorder-hook: pre-commit already current (no-op)."
  exit 0
fi

ln -sfn "$rel" "$dst"
chmod +x "$gate_src" 2>/dev/null || true
echo "install-recorder-hook: linked pre-commit -> $rel"
