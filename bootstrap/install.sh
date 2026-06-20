#!/usr/bin/env bash
# install.sh — one-command, harness-aware predicate bootstrap.
#
# Sets a project up end-to-end on either supported harness:
#   1. registers the predicate plugin into the harness's plugin directory,
#   2. installs the git commit gate by CALLING hooks/install-hooks.sh (a
#      separate, composed step — this script never modifies or inlines it),
#   3. inits the project's .ledger flight-recorder subrepo and configures its
#      remote (but never pushes — the push is a human seam),
#   4. wires always-on rules by APPENDING `@<canonical>/rules.md` and
#      `@<canonical>/ambient.md` to the user's global CLAUDE.md.
#
# Plugins have no install/activation hook and no always-on-rules surface, so the
# CLAUDE.md `@import` is the supported non-clobbering mechanism. The append is
# idempotent and append-safe: it lives inside a sentinel-delimited managed block
# (the rustup/nvm "managed block" pattern), so re-running is a no-op and the
# user's pre-existing config is byte-preserved as a prefix — never overwritten.
#
# Usage:
#   bootstrap/install.sh [--project DIR] [--harness claude-code|antigravity]
#
# Environment overrides (all optional; sensible defaults below):
#   PREDICATE_PLUGIN_SRC    path to this plugin checkout (default: this repo)
#   PREDICATE_LEDGER_REMOTE git remote URL for the .ledger subrepo
#   HOME                    the harness config lives under $HOME (honored as-is,
#                           which is what makes this testable against a fixture)
#
# Exit: 0 = set up / already current, non-zero = a step could not complete.
set -euo pipefail

# --- markers (the managed-block sentinels; do not edit existing ones) --------
readonly BEGIN_MARK='# >>> predicate managed block >>>'
readonly END_MARK='# <<< predicate managed block <<<'

self_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# The plugin checkout is the parent of bootstrap/ unless overridden.
plugin_src="${PREDICATE_PLUGIN_SRC:-$(cd "$self_dir/.." && pwd)}"

# --- argument parsing --------------------------------------------------------
project=""
harness=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    --project) project="${2:?--project needs a value}"; shift 2 ;;
    --harness) harness="${2:?--harness needs a value}"; shift 2 ;;
    -h|--help) sed -n '2,30p' "${BASH_SOURCE[0]}"; exit 0 ;;
    *) echo "install: unknown argument: $1" >&2; exit 2 ;;
  esac
done
project="${project:-$(pwd)}"
project="$(cd "$project" && pwd)"

# --- harness detection -------------------------------------------------------
# Resolve the per-harness config root and plugin directory. Detection mirrors
# how runtime managers (mise/asdf, TPM) discover an install root: probe a known
# per-tool directory, falling back to an explicit selection.
detect_harness() {
  if [ -n "$harness" ]; then printf '%s' "$harness"; return; fi
  if [ -d "$HOME/.claude" ]; then printf 'claude-code'; return; fi
  if [ -d "$HOME/.gemini/antigravity-cli" ]; then printf 'antigravity'; return; fi
  printf 'claude-code'  # default
}

harness="$(detect_harness)"
case "$harness" in
  claude-code)
    harness_root="$HOME/.claude"
    plugins_dir="$harness_root/plugins"
    claude_md="$harness_root/CLAUDE.md"
    ;;
  antigravity)
    harness_root="$HOME/.gemini/antigravity-cli"
    plugins_dir="$harness_root/plugins"
    # Antigravity reads the same global CLAUDE.md @import convention.
    claude_md="$HOME/.claude/CLAUDE.md"
    ;;
  *)
    echo "install: unknown harness: $harness (want claude-code|antigravity)" >&2
    exit 2
    ;;
esac

# --- step 1: register the plugin ---------------------------------------------
# Place the plugin under the harness's plugins dir via a symlink, so the
# canonical install path resolves there and plugin updates need no reinstall.
# The canonical path the @import points at is this resolved location.
register_plugin() {
  mkdir -p "$plugins_dir"
  local dst="$plugins_dir/predicate"
  if [ -L "$dst" ] && [ "$(readlink "$dst")" = "$plugin_src" ]; then
    echo "install: plugin already registered ($dst)."
  else
    ln -sfn "$plugin_src" "$dst"
    echo "install: registered plugin -> $dst"
  fi
  # The canonical path used in the @import lines.
  canonical="$dst"
}

# --- step 2: install the git hooks (COMPOSED, never inlined) ------------------
# install-hooks.sh is worktree-correct WITHIN one repo: run from the project, it
# links `<project>/hooks/{commit-msg,pre-commit}` into the project's git hooks
# dir. So the composition gives the project a `hooks/` that resolves to the
# plugin's tracked hook scripts (a symlink, so plugin updates propagate), then
# invokes the installer from inside the project. The installer itself is run by
# path and never modified.
install_hooks() {
  local hooks_installer="$plugin_src/hooks/install-hooks.sh"
  if [ ! -f "$hooks_installer" ]; then
    echo "install: missing $hooks_installer" >&2; exit 1
  fi
  local project_hooks="$project/hooks"
  # Point the project's hooks/ at the plugin's hook sources (idempotent). If a
  # project already has a real hooks/ dir we don't own, leave it and warn.
  if [ -L "$project_hooks" ] || [ ! -e "$project_hooks" ]; then
    ln -sfn "$plugin_src/hooks" "$project_hooks"
  elif [ ! -f "$project_hooks/commit-msg" ]; then
    echo "install: $project_hooks exists and lacks the gate hooks; skipping link." >&2
  fi
  ( cd "$project" && bash "$hooks_installer" )
}

# --- step 3: init the .ledger subrepo (+ remote, NO push) --------------------
init_ledger() {
  local ledger="$project/.ledger"
  if ! git -C "$ledger" rev-parse --git-dir >/dev/null 2>&1; then
    git -C "$project" init -q "$ledger" 2>/dev/null || ( mkdir -p "$ledger" && git -C "$ledger" init -q )
    echo "install: initialized .ledger subrepo at $ledger"
  else
    echo "install: .ledger subrepo already present."
  fi
  # Seed the topology the gates expect (a flight-recorder log dir).
  mkdir -p "$ledger/log" "$ledger/state"
  # Configure the remote idempotently. The push is a human seam — never here.
  if [ -n "${PREDICATE_LEDGER_REMOTE:-}" ]; then
    if git -C "$ledger" remote | grep -qx origin; then
      git -C "$ledger" remote set-url origin "$PREDICATE_LEDGER_REMOTE"
    else
      git -C "$ledger" remote add origin "$PREDICATE_LEDGER_REMOTE"
    fi
    echo "install: configured .ledger remote origin (no push performed)."
  fi
}

# --- step 4: wire rules via an append-safe, idempotent @import block ----------
# The managed block is rewritten atomically: strip any prior block, then append
# a fresh one. Stripping-then-appending is what makes re-runs a true no-op while
# tolerating a moved <canonical> path. Content OUTSIDE the markers is never
# touched, so the user's pre-existing config is preserved as a byte-prefix.
inject_imports() {
  mkdir -p "$(dirname "$claude_md")"
  [ -f "$claude_md" ] || : >"$claude_md"

  local rules_import="@$canonical/rules.md"
  local ambient_import="@$canonical/ambient.md"

  # Body = the file with any existing managed block removed. awk drops the
  # marker-delimited span inclusively; everything else is passed through byte
  # for byte (no reflow, no reorder).
  local body
  body="$(awk -v b="$BEGIN_MARK" -v e="$END_MARK" '
    $0 == b { skip = 1; next }
    $0 == e { skip = 0; next }
    !skip   { print }
  ' "$claude_md")"

  # Reassemble: preserved body, then exactly one managed block. printf adds the
  # trailing newline the body may lack, so the block never glues onto the user's
  # last line (append-safety even when the original had no final newline).
  {
    if [ -n "$body" ]; then printf '%s\n' "$body"; fi
    printf '%s\n' "$BEGIN_MARK"
    printf '# Auto-loads the predicate always-on layers. Managed by bootstrap/install.sh.\n'
    printf '# Edits inside this block are overwritten on re-run; edit OUTSIDE it.\n'
    printf '%s\n' "$rules_import"
    printf '%s\n' "$ambient_import"
    printf '%s\n' "$END_MARK"
  } >"$claude_md.tmp"
  mv "$claude_md.tmp" "$claude_md"
  echo "install: wired @import rules+ambient into $claude_md (idempotent)."
}

# --- orchestration -----------------------------------------------------------
main() {
  echo "install: harness=$harness project=$project plugin=$plugin_src"
  register_plugin
  install_hooks
  init_ledger
  inject_imports
  echo "install: done. Next (human seam): push the .ledger remote when ready."
}

main
