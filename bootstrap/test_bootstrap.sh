#!/usr/bin/env bash
# test_bootstrap.sh — executable evaluator for the two-phase install bootstrap.
#
# The bootstrap has two scopes, so the tests do too:
#   install (GLOBAL) — registers the plugin via the harness's REAL mechanism and
#                       installs the conditioning output style.
#   init    (PER-REPO) — installs the git hooks + inits the .ledger subrepo.
#
# Everything runs against a throwaway fixture HOME and throwaway fixture repos
# (mktemp + git init), so the user's real global config is never touched.
#
# The load-bearing fixture assertions:
#   - install: the @import managed block is NOT written to CLAUDE.md (the
#     conditioning output style is the single always-on surface).
#   - init:    the hooks are untracked plugin-pointing symlinks, the consumer
#     tree stays clean, the .ledger is a subrepo with a remote but NO push, and a
#     real commit fires the gate resolved FROM the plugin.
#
# The real Claude Code registration (`claude plugin marketplace add` + `claude
# plugin install`) is exercised here IF the `claude` CLI is on PATH (against the
# fixture HOME, so it never touches the real config). If the CLI is absent we do
# NOT fake it: we assert the install script names exactly the documented commands
# and SKIP the live-registration case, which is validated downstream on the real
# harness (the live-reuse validation node).
#
# Usage:  bootstrap/test_bootstrap.sh
# Exit:   0 = all cases pass, non-zero = a case failed.
set -u

here="$(cd "$(dirname "$0")" && pwd)"
install_sh="$here/install.sh"
plugin_root="$(cd "$here/.." && pwd)"
have_claude=0; command -v claude >/dev/null 2>&1 && have_claude=1

pass=0
fail=0
skip=0
note() { printf '  %s\n' "$*"; }
ok()   { pass=$((pass + 1)); printf 'PASS  %s\n' "$1"; }
bad()  { fail=$((fail + 1)); printf 'FAIL  %s\n' "$1"; }
skp()  { skip=$((skip + 1)); printf 'SKIP  %s\n' "$1"; }

# A sandbox HOME for the GLOBAL install phase: an isolated $HOME we remove on
# exit. Pre-create .claude so harness detection resolves to claude-code.
make_home() {
  local box; box="$(mktemp -d)"
  mkdir -p "$box/.claude"
  printf '%s' "$box"
}

# A throwaway repo for the PER-REPO init phase.
make_repo() {
  local r; r="$(mktemp -d)"
  git -C "$r" init -q
  printf '%s' "$r"
}

# Run the install (global) phase with HOME pointed at the sandbox. The plugin
# source is this repo. Harness forced to claude-code.
run_install() {
  local home="$1"; shift
  HOME="$home" \
  PREDICATE_PLUGIN_SRC="$plugin_root" \
    bash "$install_sh" install --harness claude-code "$@"
}

# Run the init (per-repo) phase against a fixture project. A throwaway .ledger
# remote so no real network/push can occur.
run_init() {
  local proj="$1"; shift
  PREDICATE_PLUGIN_SRC="$plugin_root" \
  PREDICATE_LEDGER_REMOTE="git@example.invalid:fixture/ledger.git" \
    bash "$install_sh" init --project "$proj" "$@"
}

# ---------------------------------------------------------------------------
# Phase install — manifests are valid and schema-correct
# ---------------------------------------------------------------------------
case_manifests_valid() {
  local name="manifests: plugin.json + marketplace.json valid JSON with required fields"
  local rc=0
  local pj="$plugin_root/.claude-plugin/plugin.json"
  local mj="$plugin_root/.claude-plugin/marketplace.json"
  [ -f "$pj" ] || { note "missing $pj"; rc=1; }
  [ -f "$mj" ] || { note "missing $mj"; rc=1; }
  # Valid JSON, and the required fields per the Claude Code plugin/marketplace
  # schema are present and correctly shaped.
  python3 - "$pj" "$mj" <<'PY' || rc=1
import json, sys
pj, mj = sys.argv[1], sys.argv[2]
p = json.load(open(pj))
assert p.get("name") == "predicate", "plugin.json name must be 'predicate'"
assert isinstance(p.get("description"), str) and p["description"], "plugin.json needs a description"
# .claude-plugin/plugin.json must NOT carry the old non-schema 'bootstrap' key.
assert "bootstrap" not in p, "plugin.json must not contain the non-schema 'bootstrap' key"
m = json.load(open(mj))
assert m.get("name") == "predicate", "marketplace name must be 'predicate'"
assert isinstance(m.get("owner"), dict) and m["owner"].get("name"), "marketplace owner.name required"
plugins = m.get("plugins")
assert isinstance(plugins, list) and plugins, "marketplace plugins must be a non-empty array"
e = plugins[0]
assert e.get("name") == "predicate", "marketplace plugin entry name must be 'predicate'"
# Self-catalog: the source is the marketplace's own checkout root.
assert e.get("source") == ".", "marketplace plugin source must be '.' (self-catalog)"
print("manifests schema-correct")
PY
  [ "$rc" -eq 0 ] && ok "$name" || bad "$name"
}

# The CLI's own validator agrees the manifests are well-formed (strict mode).
# Skipped (not faked) when the CLI is unavailable.
case_cli_validate() {
  local name="manifests: 'claude plugin validate --strict' accepts the manifests"
  if [ "$have_claude" -ne 1 ]; then
    skp "$name (claude CLI unavailable; validated downstream on the real harness)"; return
  fi
  local home; home="$(make_home)"
  local out rc
  out="$(HOME="$home" claude plugin validate "$plugin_root" --strict 2>&1)"; rc=$?
  rm -rf "$home"
  if [ "$rc" -ne 0 ]; then note "validate failed: $out"; bad "$name"; else ok "$name"; fi
}

# ---------------------------------------------------------------------------
# Phase install — does NOT write the @import managed block to CLAUDE.md.
# The conditioning output style is the single always-on surface.
# ---------------------------------------------------------------------------
case_install_does_not_write_import_block() {
  local name="install: does NOT write the @import managed block to CLAUDE.md"
  local home; home="$(make_home)"
  local claude_md="$home/.claude/CLAUDE.md"

  cat >"$claude_md" <<'EOF'
# My global config

1. Always address me by name.
2. Never add co-author trailers.
EOF

  run_install "$home" >/dev/null 2>&1

  local rc=0
  # The @import managed block markers must NOT appear.
  if grep -qxF '# >>> predicate managed block >>>' "$claude_md" 2>/dev/null; then
    note "managed @import block BEGIN marker found in CLAUDE.md (must not be written)"; rc=1
  fi
  if grep -qxF '# <<< predicate managed block <<<' "$claude_md" 2>/dev/null; then
    note "managed @import block END marker found in CLAUDE.md (must not be written)"; rc=1
  fi
  # Bare standalone @import lines for rules.md or ambient.md must NOT appear.
  if grep -qE "^@.*/rules\.md$" "$claude_md" 2>/dev/null; then
    note "bare @import for rules.md found in CLAUDE.md (must not be written by install)"; rc=1
  fi
  if grep -qE "^@.*/ambient\.md$" "$claude_md" 2>/dev/null; then
    note "bare @import for ambient.md found in CLAUDE.md (must not be written by install)"; rc=1
  fi

  rm -rf "$home"
  [ "$rc" -eq 0 ] && ok "$name" || bad "$name"
}

# ---------------------------------------------------------------------------
# Phase install — REAL plugin registration via the marketplace/install CLI
# ---------------------------------------------------------------------------
case_real_registration() {
  local name="install: real 'marketplace add' + 'install' registers predicate@predicate"
  if [ "$have_claude" -ne 1 ]; then
    # Do not fake it. Assert the script names the documented commands verbatim,
    # then SKIP the live execution (validated downstream on the real harness).
    local rc=0
    grep -qF 'claude plugin marketplace add' "$install_sh" || { note "script omits 'claude plugin marketplace add'"; rc=1; }
    grep -qF 'claude plugin install predicate@predicate' "$install_sh" || { note "script omits 'claude plugin install predicate@predicate'"; rc=1; }
    [ "$rc" -eq 0 ] || { bad "$name"; return; }
    skp "$name (claude CLI unavailable; documented commands present, live registration validated downstream)"
    return
  fi
  local home; home="$(make_home)"
  run_install "$home" >/dev/null 2>&1
  local rc=0
  # The plugin is registered, enabled, at user scope.
  if ! HOME="$home" claude plugin list 2>/dev/null | grep -qF 'predicate@predicate'; then
    note "predicate@predicate not present in 'claude plugin list'"; rc=1
  fi
  # The marketplace is declared in the (fixture) user settings.
  if ! grep -qF '"predicate"' "$home/.claude/settings.json" 2>/dev/null; then
    note "predicate marketplace not declared in fixture settings.json"; rc=1
  fi
  if ! grep -qF '"predicate@predicate"' "$home/.claude/settings.json" 2>/dev/null; then
    note "predicate@predicate not enabled in fixture settings.json"; rc=1
  fi
  rm -rf "$home"
  [ "$rc" -eq 0 ] && ok "$name" || bad "$name"
}

# install must NOT touch git hooks or .ledger (those are init's job).
case_install_no_hooks_no_ledger() {
  local name="install: does NOT install git hooks or a .ledger (those are init's job)"
  local home; home="$(make_home)"
  # Run install from inside a throwaway repo to catch any stray hook/ledger writes.
  local repo; repo="$(make_repo)"
  ( cd "$repo" && HOME="$home" PREDICATE_PLUGIN_SRC="$plugin_root" \
      bash "$install_sh" install --harness claude-code ) >/dev/null 2>&1
  local rc=0
  local common; common="$(git -C "$repo" rev-parse --git-common-dir 2>/dev/null)"
  case "$common" in /*) : ;; *) common="$repo/$common" ;; esac
  if [ -e "$common/hooks/commit-msg" ] && [ -L "$common/hooks/commit-msg" ]; then
    note "install installed a commit-msg hook (should be init-only)"; rc=1
  fi
  if [ -d "$repo/.ledger" ]; then
    note "install created a .ledger (should be init-only)"; rc=1
  fi
  rm -rf "$home" "$repo"
  [ "$rc" -eq 0 ] && ok "$name" || bad "$name"
}

# ---------------------------------------------------------------------------
# Phase init — .ledger subrepo init with a configured remote and NO push
# ---------------------------------------------------------------------------
case_ledger_init_no_push() {
  local name="init: ledger subrepo + configured remote, no push"
  local repo; repo="$(make_repo)"

  run_init "$repo" >/dev/null 2>&1
  local rc=0
  local ledger="$repo/.ledger"
  if ! git -C "$ledger" rev-parse --git-dir >/dev/null 2>&1; then
    note ".ledger is not a git repo"; rc=1
  fi
  local remote; remote="$(git -C "$ledger" config --get remote.origin.url 2>/dev/null || true)"
  if [ "$remote" != "git@example.invalid:fixture/ledger.git" ]; then
    note "remote = '$remote' (want the configured URL)"; rc=1
  fi
  # No push: the script must contain no `git push`.
  if grep -qE 'git[^#]*push' "$install_sh"; then
    note "install.sh contains a git push (forbidden)"; rc=1
  fi

  rm -rf "$repo"
  [ "$rc" -eq 0 ] && ok "$name" || bad "$name"
}

# init emits a documented .ledger/config.sh.example (commented template, NOT an
# active config) that is itself valid bash.
case_config_example_emitted() {
  local name="init: ledger config.sh.example emitted + valid bash, no active config.sh"
  local repo; repo="$(make_repo)"

  run_init "$repo" >/dev/null 2>&1
  local rc=0
  local example="$repo/.ledger/config.sh.example"
  if [ ! -f "$example" ]; then
    note ".ledger/config.sh.example was not emitted"; rc=1
  else
    if ! bash -n "$example" 2>/dev/null; then note "config.sh.example is not valid bash"; rc=1; fi
    for var in SELFCONTAINED_PAT ORPHAN_TARGETS ORPHAN_EXCLUDE SKILLS_DIR REMOVED; do
      grep -qF "$var" "$example" || { note "config.sh.example omits $var"; rc=1; }
    done
  fi
  if [ -f "$repo/.ledger/config.sh" ]; then
    note "an active .ledger/config.sh was written (must stay opt-in)"; rc=1
  fi

  rm -rf "$repo"
  [ "$rc" -eq 0 ] && ok "$name" || bad "$name"
}

# init must NOT register a plugin or touch the global CLAUDE.md (install's job).
case_init_no_registration() {
  local name="init: does NOT register a plugin or touch the global CLAUDE.md"
  local home; home="$(make_home)"
  local claude_md="$home/.claude/CLAUDE.md"
  printf '# untouched\n' >"$claude_md"
  local before; before="$(cat "$claude_md")"
  local repo; repo="$(make_repo)"

  HOME="$home" PREDICATE_PLUGIN_SRC="$plugin_root" \
  PREDICATE_LEDGER_REMOTE="git@example.invalid:fixture/ledger.git" \
    bash "$install_sh" init --project "$repo" >/dev/null 2>&1
  local rc=0
  if [ "$(cat "$claude_md")" != "$before" ]; then
    note "init mutated the global CLAUDE.md (should be install-only)"; rc=1
  fi
  if grep -qF '/rules.md' "$claude_md"; then
    note "init wired the @import (should be install-only)"; rc=1
  fi

  rm -rf "$home" "$repo"
  [ "$rc" -eq 0 ] && ok "$name" || bad "$name"
}

# ---------------------------------------------------------------------------
# Phase init — self-contained footprint: hooks live ONLY as untracked .git/hooks/
# symlinks back to the plugin; the consumer working tree carries NO predicate
# machinery; and a real commit fires the gate resolving machinery from the PLUGIN.
# ---------------------------------------------------------------------------
case_self_contained_footprint() {
  local name="init: hooks are untracked plugin-pointing symlinks, clean consumer tree, gate fires from plugin"
  local proj; proj="$(make_repo)"

  run_init "$proj" >/dev/null 2>&1
  local rc=0

  local common; common="$(git -C "$proj" rev-parse --git-common-dir 2>/dev/null)"
  case "$common" in /*) : ;; *) common="$proj/$common" ;; esac
  for hook in pre-commit commit-msg; do
    local link="$common/hooks/$hook"
    if [ ! -L "$link" ]; then
      note ".git/hooks/$hook is not a symlink (self-contained model installs symlinks)"; rc=1; continue
    fi
    local resolved; resolved="$(realpath "$link" 2>/dev/null || true)"
    if [ "$resolved" != "$plugin_root/hooks/$hook" ]; then
      note ".git/hooks/$hook resolves to '$resolved' (want '$plugin_root/hooks/$hook')"; rc=1
    fi
  done

  # The consumer working tree carries NO predicate machinery.
  if [ -e "$proj/hooks" ] || [ -L "$proj/hooks" ]; then
    note "consumer tree has a 'hooks' entry (the dropped project-tree symlink leaked back)"; rc=1
  fi
  for vendored in gates skills ledger; do
    if [ -e "$proj/$vendored" ]; then
      note "consumer tree has vendored predicate machinery: $vendored"; rc=1
    fi
  done

  # A real commit fires the gate, resolving machinery from the PLUGIN. Configure a
  # local identity + disable signing in THIS throwaway repo only.
  git -C "$proj" config user.email fixture@example.invalid
  git -C "$proj" config user.name 'Fixture Consumer'
  git -C "$proj" config commit.gpgsign false
  printf 'hello\n' >"$proj/file.txt"
  git -C "$proj" add file.txt

  if git -C "$proj" commit -m 'this is not a conventional commit message at all' >/dev/null 2>&1; then
    note "malformed commit was NOT blocked — the commit-msg gate did not fire from the plugin"; rc=1
    git -C "$proj" reset --soft HEAD~1 >/dev/null 2>&1 || true
  fi
  if ! git -C "$proj" commit -m 'feat: add a file' >/dev/null 2>&1; then
    note "conforming commit was blocked — the gate misfired"; rc=1
  fi

  rm -rf "$proj"
  [ "$rc" -eq 0 ] && ok "$name" || bad "$name"
}

# install-hooks.sh must be composed, never modified: init references it by path.
case_hooks_composed_by_path() {
  local name="init: install-hooks.sh composed by path, not inlined"
  local rc=0
  if ! grep -qF 'install-hooks.sh' "$install_sh"; then
    note "install.sh does not reference install-hooks.sh"; rc=1
  fi
  if grep -qF 'Worktree-correct' "$install_sh"; then
    note "install.sh appears to inline install-hooks.sh body"; rc=1
  fi
  [ "$rc" -eq 0 ] && ok "$name" || bad "$name"
}

# Phase install
case_manifests_valid
case_cli_validate
case_install_does_not_write_import_block
case_real_registration
case_install_no_hooks_no_ledger
# Phase init
case_ledger_init_no_push
case_config_example_emitted
case_init_no_registration
case_self_contained_footprint
case_hooks_composed_by_path

printf '\n%d passed, %d failed, %d skipped\n' "$pass" "$fail" "$skip"
[ "$fail" -eq 0 ]
