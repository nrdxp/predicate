#!/usr/bin/env bash
# install.sh — one entrypoint, two phases, for the predicate bootstrap.
#
# Predicate has two genuinely different setup scopes, so this script has two
# subcommands. Mixing them was the original bug: plugin registration is GLOBAL
# (once per machine) while git hooks are PER-REPOSITORY (once per consuming repo).
#
#   install   GLOBAL, run once. Registers predicate with the harness via its
#             REAL plugin mechanism, then installs the conditioning output style.
#             No git hooks, no .ledger here.
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
# The conditioning layer generates a structured system prompt for each role and
# delivers it via native harness surfaces: for claude-code, an output-style file
# (<claude-dir>/output-styles/predicate-composer.md) and per-role agent files;
# for agy, a GEMINI.md managed block. No CLAUDE.md conditioning block is written.
#
# Usage:
#   bootstrap/install.sh install   [--harness claude-code|antigravity]
#   bootstrap/install.sh init      [--project DIR]
#   bootstrap/install.sh uninstall [--harness claude-code|antigravity]
#   bootstrap/install.sh deinit    [--project DIR]
#
# Environment overrides (all optional; sensible defaults below):
#   PREDICATE_PLUGIN_SRC    path to this plugin checkout (default: this repo)
#   PREDICATE_LEDGER_REMOTE git remote URL for the .ledger subrepo (init only)
#   HOME                    the harness config lives under $HOME (honored as-is,
#                           which is what makes this testable against a fixture)
#
# Exit: 0 = set up / already current, non-zero = a step could not complete.
set -euo pipefail

self_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# The plugin checkout is the parent of bootstrap/ unless overridden.
plugin_src="${PREDICATE_PLUGIN_SRC:-$(cd "$self_dir/.." && pwd)}"

usage() { sed -n '35,39p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; }

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

# --- conditioning delivery (called from phase_install) -----------------------
# Generates and installs the composer-role conditioning prompt.
# The conditioning/install.sh script is the authority for delivery — this is
# the bootstrap wiring only.  Non-fatal if Nickel is not available: conditioning
# is the single always-on surface; no @import fallback is installed.
inject_conditioning() {
  local harness="$1"
  local conditioning_sh="$plugin_src/conditioning/install.sh"
  if [ ! -f "$conditioning_sh" ]; then
    echo "install: conditioning/install.sh not found at $plugin_src/conditioning/; skipping." >&2
    return 0
  fi
  echo "install: running conditioning delivery for role=composer ..."
  # For claude-code: no --harness arg — conditioning defaults to claude-code (writes
  # native output-style and agent files under $claude_dir). For antigravity the harness
  # name maps to the legacy alias "generic" in conditioning/install.sh.
  local cond_harness=""
  case "$harness" in
    antigravity) cond_harness="generic" ;;
    # claude-code: no --harness passed — conditioning defaults to claude-code.
  esac
  local extra_args=()
  [ -n "$cond_harness" ] && extra_args=(--harness "$cond_harness")
  PREDICATE_SRC="$plugin_src" bash "$conditioning_sh" \
    --role composer "${extra_args[@]+"${extra_args[@]}"}" \
    || echo "install: conditioning delivery exited non-zero (non-fatal)." >&2
}

# --- conditioning teardown (called from phase_uninstall) ---------------------
# Symmetric counterpart to inject_conditioning: removes native conditioning surfaces
# (output-style file, agent files, GEMINI.md block) and strips any legacy conditioning
# block from CLAUDE.md.  Non-fatal if conditioning/install.sh is absent.
remove_conditioning() {
  local conditioning_sh="$plugin_src/conditioning/install.sh"
  if [ ! -f "$conditioning_sh" ]; then
    echo "uninstall: conditioning/install.sh not found; skipping conditioning teardown." >&2
    return 0
  fi
  echo "uninstall: running conditioning teardown ..."
  PREDICATE_SRC="$plugin_src" bash "$conditioning_sh" --uninstall \
    || echo "uninstall: conditioning teardown exited non-zero (non-fatal)." >&2
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
  inject_conditioning "$harness"
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

# --- step: install predicate's own project-local gates (SELF-HOST ONLY) -----
# Copies all files from templates/project-gates/ into PREDICATE'S OWN
# .ledger/gates/ directory and marks each copy executable.
#
# This is called ONLY when predicate is initializing itself (the "self-host"
# case: $project == $plugin_src). Consumer projects are NEVER given predicate's
# project-specific gates: those gates check predicate-internal invariants
# (the skill-contract colocation decision) that are meaningless and would
# false-fire in any downstream project that legitimately uses the same contract
# names (e.g., a project with its own state_machine.ncl in ledger/contracts/).
#
# A consumer project writes its OWN project-local gates in .ledger/gates/ using
# exactly the same per-project mechanism. The templates/project-gates/ directory
# serves as:
#   (a) predicate's tracked self-host gate source, and
#   (b) opt-in examples a consumer may copy — never auto-installed.
#
# Copy is idempotent: skip-if-exists (never clobbers a user-authored gate).
install_selfhost_gates() {
  local project="$1"
  local gates_dir="$project/.ledger/gates"
  local templates_dir="$plugin_src/templates/project-gates"

  if [ ! -d "$templates_dir" ]; then
    echo "init: templates/project-gates/ not found at $templates_dir; skipping self-host gate install." >&2
    return 0
  fi

  mkdir -p "$gates_dir"
  local installed=0
  local skipped=0
  # Install only *.sh scripts — documentation files in templates/project-gates/
  # (README.md, etc.) belong in the tracked source, not in the runtime gates dir.
  while IFS= read -r src; do
    local name; name="$(basename "$src")"
    local dst="$gates_dir/$name"
    if [ -e "$dst" ]; then
      echo "init: project-gate $name already present — skipping (skip-if-exists)."
      skipped=$((skipped + 1))
    else
      cp "$src" "$dst"
      chmod +x "$dst"
      echo "init: installed project-gate $name -> $dst"
      installed=$((installed + 1))
    fi
  done < <(find "$templates_dir" -maxdepth 1 -name '*.sh' -type f | LC_ALL=C sort)

  echo "init: self-host project-gates installed=$installed skipped=$skipped"
}

# --- step: ensure .gitignore contains the predicate subrepo entries ----------
# .ledger/ is an untracked subrepo; without a .gitignore entry, `git add -A`
# in the consuming repo hits the "embedded gitlink" error.  .scratch/ holds
# volatile campaign state and must also stay untracked.
# Appends each missing entry exactly once (idempotent); never clobbers or
# reorders existing content.
ensure_gitignore() {
  local project="$1"
  local gitignore="$project/.gitignore"
  local changed=0
  for entry in '.ledger/' '.scratch/'; do
    if grep -qxF "$entry" "$gitignore" 2>/dev/null; then
      echo "init: $entry already in .gitignore (no-op)."
    else
      printf '%s\n' "$entry" >>"$gitignore"
      echo "init: appended $entry to .gitignore."
      changed=1
    fi
  done
  [ "$changed" -eq 0 ] || echo "init: .gitignore updated."
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
  # Install predicate's own project-local gates ONLY when predicate is gating
  # itself (the self-host case). Consumer projects must not receive predicate's
  # gates: they check predicate-internal invariants that false-fire in any
  # downstream project that legitimately uses the same contract names.
  # A consumer writes its own .ledger/gates/ via the same per-project mechanism.
  if [ "$project" = "$plugin_src" ]; then
    install_selfhost_gates "$project"
  else
    echo "init: consumer project — predicate-specific gates are not installed (self-host only)."
    echo "init: to add project-local gates, write executables in $project/.ledger/gates/"
    echo "init: see templates/project-gates/ in the predicate checkout for opt-in examples."
  fi
  ensure_gitignore "$project"
  echo "init: done. Next (human seam): push the .ledger remote when ready."
}

# --- deregister: claude-code via the CLI ------------------------------------
# Reverses register_claude_code. Uses `claude plugin uninstall` then
# `claude plugin marketplace remove` — both idempotent (the CLI is a no-op when
# already absent). Non-fatal if the CLI is absent: by definition the plugin is
# not registered if there is no CLI to register it with.
deregister_claude_code() {
  if ! command -v claude >/dev/null 2>&1; then
    echo "uninstall: 'claude' CLI not found — plugin registration already absent."
    return 0
  fi
  echo "uninstall: uninstalling predicate@predicate"
  claude plugin uninstall predicate@predicate 2>/dev/null || true
  echo "uninstall: removing predicate marketplace"
  claude plugin marketplace remove predicate 2>/dev/null || true
  echo "uninstall: deregistered predicate from the Claude Code marketplace/install path."
}

# --- deregister: antigravity via symlink removal -----------------------------
# Reverses register_antigravity: removes the symlink ONLY if it resolves to
# THIS plugin_src. A symlink to a different target is foreign; we never touch it.
deregister_antigravity() {
  local plugins_dir="$HOME/.gemini/antigravity-cli/plugins"
  local dst="$plugins_dir/predicate"
  if [ ! -e "$dst" ] && [ ! -L "$dst" ]; then
    echo "uninstall: plugin symlink already absent ($dst)."
    return 0
  fi
  if [ ! -L "$dst" ]; then
    echo "uninstall: $dst is not a symlink — foreign file, leaving untouched." >&2
    return 0
  fi
  local target; target="$(readlink "$dst")"
  if [ "$target" != "$plugin_src" ]; then
    echo "uninstall: $dst -> $target does not resolve to this plugin ($plugin_src) — leaving untouched." >&2
    return 0
  fi
  rm "$dst"
  echo "uninstall: removed plugin symlink $dst."
}

# --- phase: uninstall (GLOBAL, once) -----------------------------------------
# Reverses phase_install: removes native conditioning surfaces (output-style, agent
# files, GEMINI.md block) and deregisters the plugin. PRESERVES all user content
# in CLAUDE.md/GEMINI.md. Idempotent: a second run detects absence and is a clean no-op.
phase_uninstall() {
  local harness=""
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --harness) harness="${2:?--harness needs a value}"; shift 2 ;;
      -h|--help) usage; exit 0 ;;
      *) echo "uninstall: unknown argument: $1" >&2; exit 2 ;;
    esac
  done
  harness="$(detect_harness "$harness")"
  echo "uninstall: harness=$harness plugin=$plugin_src"

  # Remove native conditioning surfaces (symmetric to inject_conditioning).
  remove_conditioning

  # Deregister the plugin for the detected harness.
  case "$harness" in
    claude-code) deregister_claude_code ;;
    antigravity) deregister_antigravity ;;
    *) echo "uninstall: unknown harness: $harness (want claude-code|antigravity)" >&2; exit 2 ;;
  esac

  echo "uninstall: done."
}

# --- phase: deinit (PER-PROJECT) ---------------------------------------------
# Reverses phase_init: removes the hook symlinks from the project's git-common-dir
# ONLY IF they resolve to this plugin's hooks/. PRESERVES .ledger/ entirely —
# the flight-recorder history, decisions, and sketches belong to the human.
# Idempotent: a second run detects absence and is a clean no-op.
phase_deinit() {
  local project=""
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --project) project="${2:?--project needs a value}"; shift 2 ;;
      -h|--help) usage; exit 0 ;;
      *) echo "deinit: unknown argument: $1" >&2; exit 2 ;;
    esac
  done
  project="${project:-$(pwd)}"
  project="$(cd "$project" && pwd)"
  echo "deinit: project=$project plugin=$plugin_src"

  local hooks_uninstaller="$plugin_src/hooks/install-hooks.sh"
  if [ ! -f "$hooks_uninstaller" ]; then
    echo "deinit: missing $hooks_uninstaller" >&2; exit 1
  fi
  ( cd "$project" && bash "$hooks_uninstaller" --uninstall )

  echo "deinit: .ledger/ PRESERVED (flight-recorder history belongs to the human)."
  echo "deinit: done."
}

# --- dispatch ----------------------------------------------------------------
main() {
  local sub="${1:-}"
  case "$sub" in
    install)   shift; phase_install "$@" ;;
    init)      shift; phase_init "$@" ;;
    uninstall) shift; phase_uninstall "$@" ;;
    deinit)    shift; phase_deinit "$@" ;;
    -h|--help|"") usage; [ -z "$sub" ] && exit 2 || exit 0 ;;
    *) echo "install: unknown subcommand: $sub (want install|init|uninstall|deinit)" >&2; usage; exit 2 ;;
  esac
}

main "$@"
