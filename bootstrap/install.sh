#!/usr/bin/env bash
# install.sh — one entrypoint, two phases, for the predicate bootstrap.
#
# Predicate has two genuinely different setup scopes, so this script has two
# subcommands. Mixing them was the original bug: plugin registration is GLOBAL
# (once per machine) while git hooks are PER-REPOSITORY (once per consuming repo).
#
#   install   GLOBAL, run once. Registers predicate with the harness via its
#             REAL plugin mechanism, then wires the always-on rules into the
#             user's global CLAUDE.md. No git hooks, no .ledger here.
#
#   init      PER-PROJECT, run inside each repo you want governed. Installs the
#             git commit gate into that repo's .git/hooks (by COMPOSING
#             hooks/install-hooks.sh, never inlining it) and inits the project's
#             .ledger flight-recorder subrepo. No plugin registration here.
#
# Harness mechanisms differ and are detected, not assumed:
#   - claude-code: registers via the real Claude Code CLI — `claude plugin
#     marketplace add <checkout>` then `claude plugin install predicate@predicate`
#     (idempotent, CLI-scriptable). The marketplace + manifest live in
#     .claude-plugin/. Copying files into ~/.claude/plugins does NOT register a
#     plugin; the marketplace/install path is the supported mechanism.
#   - antigravity: a file-based plugin dir convention (~/.gemini/antigravity-cli/
#     plugins/), so a symlink of the checkout IS the registration there.
#
# Claude Code plugins expose skills/hooks/agents but have no always-on-rules
# surface, so the global CLAUDE.md `@import` is the supported non-clobbering
# mechanism for rules.md + ambient.md. The append is idempotent and append-safe:
# it lives inside a sentinel-delimited managed block (the rustup/nvm "managed
# block" pattern), so re-running is a no-op and any pre-existing config is
# byte-preserved as a prefix — never overwritten. The @import points at the live
# CHECKOUT (not the version-pinned plugin cache), so it is stable across cache
# clears and auto-propagates a `git pull`.
#
# Usage:
#   bootstrap/install.sh install [--harness claude-code|antigravity]
#   bootstrap/install.sh init    [--project DIR]
#
# Environment overrides (all optional; sensible defaults below):
#   PREDICATE_PLUGIN_SRC    path to this plugin checkout (default: this repo)
#   PREDICATE_LEDGER_REMOTE git remote URL for the .ledger subrepo (init only)
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

usage() { sed -n '35,37p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; }

# --- harness detection -------------------------------------------------------
# Resolve which harness we are registering against. Detection mirrors how runtime
# managers (mise/asdf, TPM) discover an install root: probe a known per-tool
# directory, falling back to an explicit selection.
detect_harness() {
  local explicit="$1"
  if [ -n "$explicit" ]; then printf '%s' "$explicit"; return; fi
  if [ -d "$HOME/.claude" ]; then printf 'claude-code'; return; fi
  if [ -d "$HOME/.gemini/antigravity-cli" ]; then printf 'antigravity'; return; fi
  printf 'claude-code'  # default
}

# --- register: claude-code via the real marketplace/install CLI --------------
# The supported registration is `claude plugin marketplace add <checkout>` then
# `claude plugin install predicate@predicate`. Both are idempotent: re-adding a
# same-named marketplace replaces it, and re-installing is a no-op. We honor
# $HOME so this runs against a fixture in tests. If the `claude` CLI is absent we
# fail loudly rather than silently miswiring — registration is the whole point of
# `install`, and there is no correct file-copy fallback for this harness.
register_claude_code() {
  if ! command -v claude >/dev/null 2>&1; then
    echo "install: the 'claude' CLI is required to register the plugin but was not found on PATH." >&2
    echo "install: install Claude Code (https://code.claude.com), then re-run 'install'." >&2
    exit 1
  fi
  echo "install: adding marketplace from $plugin_src"
  claude plugin marketplace add "$plugin_src"
  echo "install: installing predicate@predicate"
  claude plugin install predicate@predicate
  echo "install: registered predicate via the Claude Code marketplace/install path."
}

# --- register: antigravity via a file-based plugin-dir symlink ---------------
# Antigravity discovers plugins from a file-based directory, so a symlink of the
# checkout into that dir IS the registration (idempotent: relink only if wrong).
register_antigravity() {
  local plugins_dir="$HOME/.gemini/antigravity-cli/plugins"
  mkdir -p "$plugins_dir"
  local dst="$plugins_dir/predicate"
  if [ -L "$dst" ] && [ "$(readlink "$dst")" = "$plugin_src" ]; then
    echo "install: plugin already registered ($dst)."
  else
    ln -sfn "$plugin_src" "$dst"
    echo "install: registered plugin -> $dst"
  fi
}

# --- wire rules via an append-safe, idempotent @import block -----------------
# The managed block is rewritten atomically: strip any prior block, then append a
# fresh one. Stripping-then-appending is what makes re-runs a true no-op while
# tolerating a moved checkout. Content OUTSIDE the markers is never touched, so a
# pre-existing config is preserved as a byte-prefix. The imports point at the
# live CHECKOUT ($plugin_src), the stable always-on source — not the volatile,
# version-pinned plugin cache.
inject_imports() {
  local claude_md="$HOME/.claude/CLAUDE.md"
  mkdir -p "$(dirname "$claude_md")"
  [ -f "$claude_md" ] || : >"$claude_md"

  local rules_import="@$plugin_src/rules.md"
  local ambient_import="@$plugin_src/ambient.md"

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

# --- phase: install (GLOBAL, once) -------------------------------------------
phase_install() {
  local harness=""
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --harness) harness="${2:?--harness needs a value}"; shift 2 ;;
      -h|--help) usage; exit 0 ;;
      *) echo "install: unknown argument: $1" >&2; exit 2 ;;
    esac
  done
  harness="$(detect_harness "$harness")"
  echo "install: harness=$harness plugin=$plugin_src"
  case "$harness" in
    claude-code) register_claude_code ;;
    antigravity) register_antigravity ;;
    *) echo "install: unknown harness: $harness (want claude-code|antigravity)" >&2; exit 2 ;;
  esac
  inject_imports
  echo "install: done. Next: run 'init' inside each repo you want governed."
}

# --- step: install the git hooks (COMPOSED, never inlined) -------------------
# install-hooks.sh self-locates the PLUGIN's hooks from its own real path and
# installs them — as symlinks back to the plugin — into the gated repo's
# git-common-dir/hooks. So the project's only hook footprint is the untracked
# .git/hooks/ symlinks; no `hooks/` appears in the project's working tree. We run
# the installer from inside the project (so it resolves THIS repo's git dir as
# the destination); the installer is invoked by path and never modified.
install_hooks() {
  local project="$1"
  local hooks_installer="$plugin_src/hooks/install-hooks.sh"
  if [ ! -f "$hooks_installer" ]; then
    echo "init: missing $hooks_installer" >&2; exit 1
  fi
  ( cd "$project" && bash "$hooks_installer" )
}

# Write the documented override-surface template. Each variable is the one the
# parameterized gates/hooks read (sourced from .ledger/config.sh if present);
# the values shown ARE predicate's own defaults, so the file is both accurate
# documentation and valid bash. Overwritten on re-run (it is a generated doc,
# not user state); a maintainer's edits belong in the copied config.sh.
emit_config_example() {
  local out="$1"
  cat >"$out" <<'EOF'
# .ledger/config.sh.example — gate & hook override surface (generated).
#
# Copy to .ledger/config.sh and uncomment/edit a line to override a default.
# This file is sourced by the predicate gates and git hooks IF .ledger/config.sh
# exists; absent that file, the gates use the predicate defaults shown below.
# Leaving config.sh absent keeps every default — that is the intended baseline.

# SELFCONTAINED_PAT — regex of internal references a commit message may not
# contain (campaign node IDs, layer tags, AC/constraint ids). check_selfcontained.sh.
# SELFCONTAINED_PAT='\bP[1-9][0-9]*\b|\bnode P[0-9]|\bL[0-9]\b|\bAC-?P?[0-9]+|\bC-P[0-9]+'

# ORPHAN_TARGETS — bash array of files/dirs the orphan gate scans for dead
# references to removed/demoted workflows. check_orphans.sh.
# ORPHAN_TARGETS=(skills templates ambient.md README.md AGENTS.md rules.md docs/authoring.md docs/getting-started.md)

# ORPHAN_EXCLUDE — grep -vE pattern suffix; paths matching it are ignored by the
# orphan scan (e.g. a vendored copy of the plugin). check_orphans.sh.
# ORPHAN_EXCLUDE='plugins/predicate'

# SKILLS_DIR — directory holding skills, used to build the orphan-reference
# pattern (matches SKILLS_DIR/<name>/). check_orphans.sh.
# SKILLS_DIR='skills'

# REMOVED — bash array of demoted/removed workflow names the pre-commit hook
# checks the staged surface does not reference as if still live. hooks/pre-commit.
# REMOVED=(plan charter plan-review continue personalization sketch dialectic predicate planning)
EOF
}

# --- step: init the .ledger subrepo (+ remote, NO push) ----------------------
init_ledger() {
  local project="$1"
  local ledger="$project/.ledger"
  if ! git -C "$ledger" rev-parse --git-dir >/dev/null 2>&1; then
    git -C "$project" init -q "$ledger" 2>/dev/null || ( mkdir -p "$ledger" && git -C "$ledger" init -q )
    echo "init: initialized .ledger subrepo at $ledger"
  else
    echo "init: .ledger subrepo already present."
  fi
  # Seed the topology the gates expect (a flight-recorder log dir).
  mkdir -p "$ledger/log" "$ledger/state"
  # Document the gate/hook override surface. This is an EXAMPLE template, never
  # an active config: the gates are optional-with-fallback (absent config.sh →
  # predicate defaults), so emitting an active config.sh would silently freeze
  # those defaults. The example lets a downstream maintainer discover every
  # overridable variable (and its predicate default) without reading the gate
  # scripts; copy it to config.sh and edit to override.
  emit_config_example "$ledger/config.sh.example"
  # Configure the remote idempotently. The push is a human seam — never here.
  if [ -n "${PREDICATE_LEDGER_REMOTE:-}" ]; then
    if git -C "$ledger" remote | grep -qx origin; then
      git -C "$ledger" remote set-url origin "$PREDICATE_LEDGER_REMOTE"
    else
      git -C "$ledger" remote add origin "$PREDICATE_LEDGER_REMOTE"
    fi
    echo "init: configured .ledger remote origin (no push performed)."
  fi
}

# --- phase: init (PER-PROJECT) -----------------------------------------------
phase_init() {
  local project=""
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --project) project="${2:?--project needs a value}"; shift 2 ;;
      -h|--help) usage; exit 0 ;;
      *) echo "init: unknown argument: $1" >&2; exit 2 ;;
    esac
  done
  project="${project:-$(pwd)}"
  project="$(cd "$project" && pwd)"
  echo "init: project=$project plugin=$plugin_src"
  install_hooks "$project"
  init_ledger "$project"
  echo "init: done. Next (human seam): push the .ledger remote when ready."
}

# --- dispatch ----------------------------------------------------------------
main() {
  local sub="${1:-}"
  case "$sub" in
    install) shift; phase_install "$@" ;;
    init)    shift; phase_init "$@" ;;
    -h|--help|"") usage; [ -z "$sub" ] && exit 2 || exit 0 ;;
    *) echo "install: unknown subcommand: $sub (want install|init)" >&2; usage; exit 2 ;;
  esac
}

main "$@"
