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

# --- markers (the managed-block sentinels; do not edit existing ones) --------
readonly BEGIN_MARK='# >>> predicate managed block >>>'
readonly END_MARK='# <<< predicate managed block <<<'

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

# --- conditioning delivery (called from phase_install) -----------------------
# Generates and installs the architect-role conditioning prompt.  Additive to
# the existing inject_imports step; preserves all existing install behaviour.
# The conditioning/install.sh script is the authority for delivery — this is
# the bootstrap wiring only.  Non-fatal if Nickel is not available (the
# CLAUDE.md @import from inject_imports remains the Tier 2 floor).
inject_conditioning() {
  local harness="$1"
  local conditioning_sh="$plugin_src/conditioning/install.sh"
  if [ ! -f "$conditioning_sh" ]; then
    echo "install: conditioning/install.sh not found at $plugin_src/conditioning/; skipping." >&2
    return 0
  fi
  echo "install: running conditioning delivery for role=architect ..."
  # For claude-code: let conditioning auto-detect Tier 1 vs Tier 2 (probes
  # whether the CLI supports --append-system-prompt at runtime). Passing
  # --harness claude-code explicitly would short-circuit that probe and force
  # Tier 2 even on a Tier-1-capable installation. For antigravity the mapping
  # is unambiguous (always generic), so we carry it through.
  local cond_harness=""
  case "$harness" in
    antigravity) cond_harness="generic" ;;
    # claude-code: intentionally absent — conditioning auto-detects Tier 1 / Tier 2.
  esac
  local extra_args=()
  [ -n "$cond_harness" ] && extra_args=(--harness "$cond_harness")
  PREDICATE_SRC="$plugin_src" bash "$conditioning_sh" \
    --role architect "${extra_args[@]+"${extra_args[@]}"}" \
    || echo "install: conditioning delivery exited non-zero (non-fatal; Tier 2 @import still active)." >&2
}

# --- conditioning teardown (called from phase_uninstall) ---------------------
# Symmetric counterpart to inject_conditioning: strips the conditioning managed
# block from CLAUDE.md and removes conditioning/generated/.  Non-fatal if
# conditioning/install.sh is absent (nothing to undo).
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
  inject_imports
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

# --- step: install predicate's project-local gates from templates/ -----------
# Copies all files from templates/project-gates/ into the project's
# .ledger/gates/ directory and marks each copy executable. The copy is
# idempotent: a gate with the same name that already exists in .ledger/gates/
# (whether user-authored or a prior install) is skipped without modification.
# This ensures a fresh clone of predicate gets its own project-local checks
# (the colocation gate, etc.) on the first `init` run, rather than only after
# an agent session that happened to write them previously.
install_project_gates() {
  local project="$1"
  local gates_dir="$project/.ledger/gates"
  local templates_dir="$plugin_src/templates/project-gates"

  if [ ! -d "$templates_dir" ]; then
    echo "init: templates/project-gates/ not found at $templates_dir; skipping project-gate install." >&2
    return 0
  fi

  mkdir -p "$gates_dir"
  local installed=0
  local skipped=0
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
  done < <(find "$templates_dir" -maxdepth 1 -type f | LC_ALL=C sort)

  echo "init: project-gates installed=$installed skipped=$skipped"
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
  install_project_gates "$project"
  ensure_gitignore "$project"
  echo "init: done. Next (human seam): push the .ledger remote when ready."
}

# --- strip_managed_block: remove the delimited block from a file, in-place ---
# Strips exactly the span between BEGIN_MARK and END_MARK (inclusive); content
# outside the markers is passed through byte-for-byte. Idempotent: a file with
# no managed block is left unchanged.
strip_managed_block() {
  local file="$1"
  [ -f "$file" ] || return 0
  local body
  body="$(awk -v b="$BEGIN_MARK" -v e="$END_MARK" '
    $0 == b { skip = 1; next }
    $0 == e { skip = 0; next }
    !skip   { print }
  ' "$file")"
  printf '%s\n' "$body" >"$file.tmp"
  mv "$file.tmp" "$file"
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
# Reverses phase_install: strip the managed block from CLAUDE.md and deregister
# the plugin. PRESERVES all user content outside the managed block.
# Idempotent: a second run detects the absence and is a clean no-op.
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

  # Strip the managed @import block from the global CLAUDE.md.
  local claude_md="$HOME/.claude/CLAUDE.md"
  if [ -f "$claude_md" ]; then
    if grep -qxF "$BEGIN_MARK" "$claude_md"; then
      strip_managed_block "$claude_md"
      echo "uninstall: removed predicate managed block from $claude_md."
    else
      echo "uninstall: no predicate managed block found in $claude_md (already clean)."
    fi
  else
    echo "uninstall: $claude_md does not exist (already clean)."
  fi

  # Strip the conditioning managed block from CLAUDE.md (symmetric to inject_conditioning).
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
