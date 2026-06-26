#!/usr/bin/env bash
# test_uninstall.sh — round-trip tests for the uninstall/deinit subcommands.
#
# Every test uses a throwaway fixture HOME (temp dir with a pre-created .claude/)
# and throwaway git repos; the real $HOME and real repos are never touched.
#
# Round-trip invariants under test:
#   install → uninstall
#     - managed @import block is NEVER written by install (output style is the
#       single always-on surface)
#     - user content in CLAUDE.md is preserved byte-for-byte through install + uninstall
#     - second uninstall is a clean no-op (exit 0, no mutation)
#     - antigravity symlink is removed only when it resolves to this plugin
#
#   init → deinit
#     - hook symlinks are removed
#     - .ledger/ and its contents SURVIVE untouched
#     - a real (non-predicate) pre-existing hook is NOT removed
#     - second deinit is a clean no-op
#
# Usage:  bootstrap/test_uninstall.sh
# Exit:   0 = all cases pass, non-zero = a case failed.
set -u

here="$(cd "$(dirname "$0")" && pwd)"
install_sh="$here/install.sh"
plugin_root="$(cd "$here/.." && pwd)"

pass=0
fail=0
note() { printf '  %s\n' "$*"; }
ok()   { pass=$((pass + 1)); printf 'PASS  %s\n' "$1"; }
bad()  { fail=$((fail + 1)); printf 'FAIL  %s\n' "$1"; }

# Create a sandbox HOME; pre-create .claude so harness detection resolves to
# claude-code (matching the behavior the existing test_bootstrap.sh relies on).
make_home() {
  local box; box="$(mktemp -d)"
  mkdir -p "$box/.claude"
  printf '%s' "$box"
}

# Create a throwaway git repo.
make_repo() {
  local r; r="$(mktemp -d)"
  git -C "$r" init -q
  printf '%s' "$r"
}

# Run the install (global) phase against a fixture HOME.
run_install() {
  local home="$1"; shift
  HOME="$home" \
  PREDICATE_PLUGIN_SRC="$plugin_root" \
    bash "$install_sh" install --harness claude-code "$@"
}

# Run the uninstall (global) phase against a fixture HOME.
run_uninstall() {
  local home="$1"; shift
  HOME="$home" \
  PREDICATE_PLUGIN_SRC="$plugin_root" \
    bash "$install_sh" uninstall --harness claude-code "$@"
}

# Run the init (per-repo) phase against a fixture project.
run_init() {
  local proj="$1"; shift
  PREDICATE_PLUGIN_SRC="$plugin_root" \
  PREDICATE_LEDGER_REMOTE="git@example.invalid:fixture/ledger.git" \
    bash "$install_sh" init --project "$proj" "$@"
}

# Run the deinit (per-repo) phase against a fixture project.
run_deinit() {
  local proj="$1"; shift
  PREDICATE_PLUGIN_SRC="$plugin_root" \
    bash "$install_sh" deinit --project "$proj" "$@"
}

# ---------------------------------------------------------------------------
# install → uninstall: @import block is never written; user content is preserved
# ---------------------------------------------------------------------------
case_install_uninstall_preserves_user_content() {
  local name="install+uninstall: @import block never written; user content preserved; no-op on second uninstall"
  local home; home="$(make_home)"
  local claude_md="$home/.claude/CLAUDE.md"

  # Pre-populate with user content before install.
  cat >"$claude_md" <<'EOF'
# My global config

1. Always address me by name.
2. Never add co-author trailers.
EOF
  local original; original="$(cat "$claude_md")"

  run_install "$home" >/dev/null 2>&1

  # The managed @import block must NOT have been written by install.
  local rc=0
  if grep -qxF '# >>> predicate managed block >>>' "$claude_md"; then
    note "managed @import block written by install (must not be written)"; rc=1
  fi

  run_uninstall "$home" >/dev/null 2>&1

  # The @import block markers must remain absent.
  if grep -qxF '# >>> predicate managed block >>>' "$claude_md"; then
    note "managed @import block BEGIN marker present after uninstall"; rc=1
  fi
  if grep -qxF '# <<< predicate managed block <<<' "$claude_md"; then
    note "managed @import block END marker present after uninstall"; rc=1
  fi
  # Bare @import lines for rules.md / ambient.md must be absent.
  if grep -qE "^@.*/rules\.md$" "$claude_md" 2>/dev/null; then
    note "bare @import for rules.md present after uninstall"; rc=1
  fi
  if grep -qE "^@.*/ambient\.md$" "$claude_md" 2>/dev/null; then
    note "bare @import for ambient.md present after uninstall"; rc=1
  fi
  # Original user content must survive.
  if ! grep -qxF '# My global config' "$claude_md" 2>/dev/null; then
    note "original user content not preserved after install + uninstall"; rc=1
  fi

  # Second uninstall must be a clean no-op (same file, exit 0).
  local before_second; before_second="$(cat "$claude_md")"
  run_uninstall "$home" >/dev/null 2>&1
  local after_second; after_second="$(cat "$claude_md")"
  if [ "$before_second" != "$after_second" ]; then
    note "second uninstall mutated the file (not idempotent)"; rc=1
  fi

  rm -rf "$home"
  [ "$rc" -eq 0 ] && ok "$name" || bad "$name"
}

# ---------------------------------------------------------------------------
# uninstall: works cleanly when there is no managed block (already clean)
# ---------------------------------------------------------------------------
case_uninstall_already_clean() {
  local name="uninstall: no-op and exit 0 when managed block was never installed"
  local home; home="$(make_home)"
  local claude_md="$home/.claude/CLAUDE.md"
  printf '# user config\nno predicate block here\n' >"$claude_md"
  local original; original="$(cat "$claude_md")"

  run_uninstall "$home" >/dev/null 2>&1
  local rc=0
  if [ "$(cat "$claude_md")" != "$original" ]; then
    note "uninstall mutated a file that had no managed block"; rc=1
  fi

  rm -rf "$home"
  [ "$rc" -eq 0 ] && ok "$name" || bad "$name"
}

# ---------------------------------------------------------------------------
# uninstall: antigravity symlink removed only when it resolves to this plugin
# ---------------------------------------------------------------------------
case_uninstall_antigravity_symlink() {
  local name="uninstall: antigravity symlink removed only when it resolves to this plugin"
  local home; home="$(make_home)"
  mkdir -p "$home/.gemini/antigravity-cli/plugins"
  local dst="$home/.gemini/antigravity-cli/plugins/predicate"

  # Install via antigravity (creates symlink to plugin_root).
  HOME="$home" PREDICATE_PLUGIN_SRC="$plugin_root" \
    bash "$install_sh" install --harness antigravity >/dev/null 2>&1

  local rc=0
  if [ ! -L "$dst" ]; then
    note "symlink was not created by install (test precondition failure)"; rc=1
    bad "$name"; rm -rf "$home"; return
  fi

  # Uninstall must remove the symlink.
  HOME="$home" PREDICATE_PLUGIN_SRC="$plugin_root" \
    bash "$install_sh" uninstall --harness antigravity >/dev/null 2>&1
  if [ -e "$dst" ] || [ -L "$dst" ]; then
    note "symlink not removed by uninstall"; rc=1
  fi

  # A symlink to a FOREIGN target must be left untouched.
  ln -s /tmp/other-plugin "$dst"
  HOME="$home" PREDICATE_PLUGIN_SRC="$plugin_root" \
    bash "$install_sh" uninstall --harness antigravity >/dev/null 2>&1
  if [ ! -L "$dst" ]; then
    note "foreign symlink was incorrectly removed by uninstall"; rc=1
  fi
  rm -f "$dst"

  # A real (non-symlink) file at that path must be left untouched.
  printf 'not a symlink\n' >"$dst"
  HOME="$home" PREDICATE_PLUGIN_SRC="$plugin_root" \
    bash "$install_sh" uninstall --harness antigravity >/dev/null 2>&1
  if [ ! -f "$dst" ]; then
    note "real file was incorrectly removed by uninstall"; rc=1
  fi

  rm -rf "$home"
  [ "$rc" -eq 0 ] && ok "$name" || bad "$name"
}

# ---------------------------------------------------------------------------
# deinit: hook symlinks removed; .ledger survives untouched
# ---------------------------------------------------------------------------
case_deinit_removes_hooks_preserves_ledger() {
  local name="deinit: hook symlinks removed; .ledger/ and its contents survive untouched"
  local proj; proj="$(make_repo)"

  run_init "$proj" >/dev/null 2>&1

  local common; common="$(git -C "$proj" rev-parse --git-common-dir 2>/dev/null)"
  case "$common" in /*) : ;; *) common="$proj/$common" ;; esac

  # Confirm hooks are symlinks pointing to the plugin after init.
  local rc=0
  for hook in commit-msg pre-commit; do
    local link="$common/hooks/$hook"
    if [ ! -L "$link" ]; then
      note "$hook is not a symlink after init (test precondition failure)"; rc=1
    fi
  done
  if [ "$rc" -ne 0 ]; then bad "$name"; rm -rf "$proj"; return; fi

  # Record .ledger state before deinit.
  local ledger="$proj/.ledger"
  local ledger_is_git=0
  git -C "$ledger" rev-parse --git-dir >/dev/null 2>&1 && ledger_is_git=1
  local example_present=0
  [ -f "$ledger/config.sh.example" ] && example_present=1

  run_deinit "$proj" >/dev/null 2>&1

  # Hook symlinks must be gone.
  for hook in commit-msg pre-commit; do
    local link="$common/hooks/$hook"
    if [ -e "$link" ] || [ -L "$link" ]; then
      note "$hook symlink still present after deinit"; rc=1
    fi
  done

  # .ledger must survive completely untouched.
  if [ ! -d "$ledger" ]; then
    note ".ledger/ directory removed by deinit (must be preserved)"; rc=1
  fi
  if [ "$ledger_is_git" -eq 1 ] && ! git -C "$ledger" rev-parse --git-dir >/dev/null 2>&1; then
    note ".ledger git subrepo destroyed by deinit"; rc=1
  fi
  if [ "$example_present" -eq 1 ] && [ ! -f "$ledger/config.sh.example" ]; then
    note ".ledger/config.sh.example removed by deinit"; rc=1
  fi
  if [ ! -d "$ledger/log" ]; then
    note ".ledger/log/ removed by deinit"; rc=1
  fi

  rm -rf "$proj"
  [ "$rc" -eq 0 ] && ok "$name" || bad "$name"
}

# ---------------------------------------------------------------------------
# deinit: a real (non-predicate) pre-existing hook is NOT removed
# ---------------------------------------------------------------------------
case_deinit_preserves_user_hook() {
  local name="deinit: a real user-owned hook file is NOT removed"
  local proj; proj="$(make_repo)"

  run_init "$proj" >/dev/null 2>&1

  local common; common="$(git -C "$proj" rev-parse --git-common-dir 2>/dev/null)"
  case "$common" in /*) : ;; *) common="$proj/$common" ;; esac

  # Replace the predicate commit-msg symlink with a real user-owned file.
  local real_hook="$common/hooks/commit-msg"
  rm -f "$real_hook"
  printf '#!/bin/sh\n# my real hook\nexit 0\n' >"$real_hook"
  chmod +x "$real_hook"

  run_deinit "$proj" >/dev/null 2>&1

  local rc=0
  if [ ! -f "$real_hook" ]; then
    note "user's real commit-msg hook was removed by deinit"; rc=1
  fi
  # The predicate pre-commit symlink should have been removed (it still resolves
  # to the plugin).
  local pre_commit="$common/hooks/pre-commit"
  if [ -e "$pre_commit" ] || [ -L "$pre_commit" ]; then
    note "predicate pre-commit symlink was NOT removed (it should have been)"; rc=1
  fi

  rm -rf "$proj"
  [ "$rc" -eq 0 ] && ok "$name" || bad "$name"
}

# ---------------------------------------------------------------------------
# deinit: a symlink pointing to a FOREIGN target is NOT removed
# ---------------------------------------------------------------------------
case_deinit_preserves_foreign_symlink() {
  local name="deinit: a symlink to a foreign target is NOT removed"
  local proj; proj="$(make_repo)"

  run_init "$proj" >/dev/null 2>&1

  local common; common="$(git -C "$proj" rev-parse --git-common-dir 2>/dev/null)"
  case "$common" in /*) : ;; *) common="$proj/$common" ;; esac

  # Replace the predicate pre-commit symlink with a foreign symlink.
  local foreign="$common/hooks/pre-commit"
  rm -f "$foreign"
  ln -s /usr/local/bin/some-other-hook "$foreign"

  run_deinit "$proj" >/dev/null 2>&1

  local rc=0
  if [ ! -L "$foreign" ]; then
    note "foreign pre-commit symlink was removed by deinit (safety violation)"; rc=1
  fi

  rm -rf "$proj"
  [ "$rc" -eq 0 ] && ok "$name" || bad "$name"
}

# ---------------------------------------------------------------------------
# deinit: idempotent — second run is a clean no-op
# ---------------------------------------------------------------------------
case_deinit_idempotent() {
  local name="deinit: second run is a clean no-op (idempotent)"
  local proj; proj="$(make_repo)"

  run_init "$proj" >/dev/null 2>&1
  run_deinit "$proj" >/dev/null 2>&1

  # Second deinit must exit 0.
  local rc=0
  if ! run_deinit "$proj" >/dev/null 2>&1; then
    note "second deinit exited non-zero"; rc=1
  fi

  rm -rf "$proj"
  [ "$rc" -eq 0 ] && ok "$name" || bad "$name"
}

# ---------------------------------------------------------------------------
# Footgun 1: conditioning/install.sh role injection
# A crafted --role value containing Nickel syntax breaks out of the string
# literal passed to `nickel export`, potentially importing arbitrary files.
# Fix: validate $role against the known set BEFORE interpolation; reject with
# exit 2 for any unknown value.
# ---------------------------------------------------------------------------
case_role_injection_rejected() {
  local name="conditioning: injected --role value is rejected before Nickel interpolation"
  local rc=0

  local conditioning_sh="$plugin_root/conditioning/install.sh"
  if [ ! -f "$conditioning_sh" ]; then
    note "conditioning/install.sh not found at $plugin_root — skipping"; rc=1
    bad "$name"; return
  fi

  # A crafted role that breaks out of the Nickel string literal.
  local evil_role='x" (import "/etc/passwd") #'

  # The script must exit non-zero for an invalid role without reaching Nickel.
  local out
  out="$(PREDICATE_SRC="$plugin_root" bash "$conditioning_sh" \
          --role "$evil_role" --dry-run 2>&1)" && {
    note "conditioning/install.sh exited 0 for an invalid role (not rejected)"; rc=1
  }

  # The rejection message must be the role-validation error, NOT Nickel diagnostics.
  # Nickel diagnostics would include "std.record.get" or "imported here" — if those
  # appear, Nickel was reached (injection not blocked).  The error message echoing
  # the role value is expected and fine; we check for Nickel-specific markers.
  if printf '%s' "$out" | grep -qE 'std\.record\.get|imported here|nickel diagnostics'; then
    note "Nickel was reached and tried to import /etc/passwd (injection not blocked)"; rc=1
  fi
  # Conversely, the "unknown role" rejection must appear.
  if ! printf '%s' "$out" | grep -q 'unknown role'; then
    note "expected 'unknown role' rejection message not found in output"; rc=1
  fi

  # Also verify a VALID role still works (exit 0, no rejection).
  if ! PREDICATE_SRC="$plugin_root" bash "$conditioning_sh" \
        --role architect --dry-run >/dev/null 2>&1; then
    note "valid role 'architect' was incorrectly rejected"; rc=1
  fi

  [ "$rc" -eq 0 ] && ok "$name" || bad "$name"
}

# ---------------------------------------------------------------------------
# Footgun 2: hooks/install-hooks.sh --uninstall with a dangling hook symlink
# When the hook symlink target (or its parent directory) is missing, the old
# `realpath "$dst"` returns empty, so the comparison against $expected fails
# and the symlink is orphaned instead of removed.
# Fix: use `realpath -m "$dst"` which canonicalises without existence check.
#
# Test scenario: install hooks from a fake plugin, then remove the hook FILES
# (keeping the directory). On systems where realpath returns empty for a
# missing file (macOS/BSD), the bug fires. On GNU/Linux realpath succeeds when
# only the file is missing but the dir exists — so we additionally test by
# deleting the entire hooks directory (making the symlinks truly dangling) and
# re-creating it with only install-hooks.sh to verify the fix handles the
# case where the hooks directory itself was cleaned up.
# ---------------------------------------------------------------------------
case_uninstall_dangling_symlink_removed() {
  local name="uninstall: dangling hook symlink (hook files missing) is removed, not orphaned"
  local rc=0

  # Build a throwaway plugin with dummy hook files + install-hooks.sh.
  local tmp_plugin; tmp_plugin="$(mktemp -d)"
  local fake_hooks="$tmp_plugin/hooks"
  mkdir -p "$fake_hooks"
  cp "$plugin_root/hooks/install-hooks.sh" "$fake_hooks/"
  printf '#!/bin/sh\nexit 0\n' >"$fake_hooks/commit-msg";  chmod +x "$fake_hooks/commit-msg"
  printf '#!/bin/sh\nexit 0\n' >"$fake_hooks/pre-commit"; chmod +x "$fake_hooks/pre-commit"

  local proj; proj="$(make_repo)"
  ( cd "$proj" && bash "$fake_hooks/install-hooks.sh" ) >/dev/null 2>&1

  local common; common="$(git -C "$proj" rev-parse --git-common-dir 2>/dev/null)"
  case "$common" in /*) : ;; *) common="$proj/$common" ;; esac

  if [ ! -L "$common/hooks/commit-msg" ]; then
    note "install precondition: commit-msg symlink missing"; rc=1
    bad "$name"; rm -rf "$tmp_plugin" "$proj"; return
  fi

  # Sub-case A: hook FILES deleted, directory remains.
  # GNU realpath handles this (returns the path despite file missing);
  # BSD/macOS realpath does not. The realpath -m fix covers both.
  rm -f "$fake_hooks/commit-msg" "$fake_hooks/pre-commit"
  ( cd "$proj" && bash "$fake_hooks/install-hooks.sh" --uninstall ) >/dev/null 2>&1 || true

  for hook in commit-msg pre-commit; do
    if [ -L "$common/hooks/$hook" ]; then
      note "sub-case A: $hook symlink still present after uninstall (hook files deleted)"; rc=1
    fi
  done

  # Re-install for sub-case B (re-install from the same tmp_plugin).
  printf '#!/bin/sh\nexit 0\n' >"$fake_hooks/commit-msg";  chmod +x "$fake_hooks/commit-msg"
  printf '#!/bin/sh\nexit 0\n' >"$fake_hooks/pre-commit"; chmod +x "$fake_hooks/pre-commit"
  ( cd "$proj" && bash "$fake_hooks/install-hooks.sh" ) >/dev/null 2>&1

  # Sub-case B: entire hooks directory removed and re-created without hook files.
  # Symlinks become dangling (parent dir missing → GNU realpath also returns empty).
  # Save install-hooks.sh before deleting the dir.
  local saved_installer; saved_installer="$(mktemp)"
  cp "$fake_hooks/install-hooks.sh" "$saved_installer"
  rm -rf "$fake_hooks"
  # Recreate the directory with only install-hooks.sh (simulating a fresh checkout
  # that has install-hooks.sh but not the hook files — e.g., post-stash or
  # partial git-clean scenario).
  mkdir -p "$fake_hooks"
  cp "$saved_installer" "$fake_hooks/install-hooks.sh"
  rm -f "$saved_installer"

  # At this point the symlinks encode a relative path to $fake_hooks/commit-msg.
  # Since we just recreated $fake_hooks/ (empty of hook files), GNU realpath
  # will succeed on directory traversal. Use realpath -m path for the test assertion.
  ( cd "$proj" && bash "$fake_hooks/install-hooks.sh" --uninstall ) >/dev/null 2>&1 || true

  for hook in commit-msg pre-commit; do
    if [ -L "$common/hooks/$hook" ]; then
      note "sub-case B: $hook symlink still present after uninstall (hooks dir recreated empty)"; rc=1
    fi
  done

  rm -rf "$tmp_plugin" "$proj"
  [ "$rc" -eq 0 ] && ok "$name" || bad "$name"
}

# ---------------------------------------------------------------------------
# Footgun 3: bootstrap/install.sh init does not write .gitignore
# After init, .ledger/ is an untracked subrepo. A downstream `git add -A`
# hits the "embedded gitlink" error. Fix: init appends .ledger/ and .scratch/
# to the project's .gitignore (idempotent — no duplicate lines, no clobber).
# ---------------------------------------------------------------------------
case_init_gitignore_entries() {
  local name="init: .gitignore gets .ledger/ and .scratch/ entries (idempotent, non-clobbering)"
  local rc=0
  local proj; proj="$(make_repo)"
  local gitignore="$proj/.gitignore"

  # Pre-populate with user content so we can verify non-clobbering.
  printf '# existing ignore rules\n*.log\nbuild/\n' >"$gitignore"
  local original; original="$(cat "$gitignore")"

  run_init "$proj" >/dev/null 2>&1

  # Both entries must be present.
  if ! grep -qxF '.ledger/' "$gitignore"; then
    note ".ledger/ not present in .gitignore after init"; rc=1
  fi
  if ! grep -qxF '.scratch/' "$gitignore"; then
    note ".scratch/ not present in .gitignore after init"; rc=1
  fi
  # Original content must be preserved (non-clobbering).
  if ! grep -qxF '*.log' "$gitignore" 2>/dev/null; then
    note "original .gitignore content was clobbered"; rc=1
  fi

  # Second init must not duplicate entries (idempotent).
  run_init "$proj" >/dev/null 2>&1
  local ledger_count scratch_count
  ledger_count="$(grep -cxF '.ledger/' "$gitignore")"
  scratch_count="$(grep -cxF '.scratch/' "$gitignore")"
  if [ "$ledger_count" -ne 1 ]; then
    note ".ledger/ appears $ledger_count times after second init (want 1)"; rc=1
  fi
  if [ "$scratch_count" -ne 1 ]; then
    note ".scratch/ appears $scratch_count times after second init (want 1)"; rc=1
  fi

  # Also verify: git add -A no longer hits the embedded-gitlink error.
  git -C "$proj" config user.email "test@example.invalid"
  git -C "$proj" config user.name  "Fixture"
  git -C "$proj" config commit.gpgsign false
  printf 'hello\n' >"$proj/file.txt"
  if ! git -C "$proj" add -A 2>/dev/null; then
    note "git add -A failed after init (embedded-gitlink error not resolved)"; rc=1
  fi

  rm -rf "$proj"
  [ "$rc" -eq 0 ] && ok "$name" || bad "$name"
}

# ---------------------------------------------------------------------------
# Defect 1a: conditioning/install.sh --uninstall strips the conditioning block.
# Before the fix, conditioning/install.sh has no --uninstall flag → exits 2.
# ---------------------------------------------------------------------------
case_conditioning_sh_uninstall() {
  local name="conditioning/install.sh --uninstall: strips conditioning block from CLAUDE.md"
  local conditioning_sh="$plugin_root/conditioning/install.sh"
  if [ ! -f "$conditioning_sh" ]; then
    note "conditioning/install.sh not found at $plugin_root — skipping"; bad "$name"; return
  fi

  local home; home="$(make_home)"
  local claude_md="$home/.claude/CLAUDE.md"

  # Pre-populate with user content + a pre-written conditioning block (simulating
  # what conditioning/install.sh Tier 2 would have written on install).
  cat >"$claude_md" <<'EOF'
# My global config
1. Always address me by name.
# >>> predicate conditioning block >>>
# Generated conditioning for role: architect
# Managed by conditioning/install.sh — re-run to update.
This is the big inline conditioning prompt (215 lines in production).
# <<< predicate conditioning block <<<
EOF
  local original_first_line="# My global config"

  # Also seed a fake conditioning/generated/ to verify teardown removes it.
  local gen_dir="$plugin_root/conditioning/generated"
  local gen_existed=0
  [ -d "$gen_dir" ] && gen_existed=1
  mkdir -p "$gen_dir"
  printf 'fake generated prompt\n' >"$gen_dir/architect.md"

  local rc=0
  HOME="$home" PREDICATE_SRC="$plugin_root" \
    bash "$conditioning_sh" --uninstall >/dev/null 2>&1 || {
    note "conditioning/install.sh --uninstall exited non-zero"; rc=1
  }

  # Conditioning block must be gone.
  if grep -qxF '# >>> predicate conditioning block >>>' "$claude_md"; then
    note "conditioning block BEGIN marker still present after --uninstall"; rc=1
  fi
  if grep -qxF '# <<< predicate conditioning block <<<' "$claude_md"; then
    note "conditioning block END marker still present after --uninstall"; rc=1
  fi
  # User content outside the conditioning block must survive.
  if ! grep -qxF "$original_first_line" "$claude_md"; then
    note "user content outside conditioning block was lost"; rc=1
  fi
  # conditioning/generated/ must be removed (or already gone).
  if [ -d "$gen_dir" ]; then
    note "conditioning/generated/ still present after --uninstall"; rc=1
  fi

  # Restore gen_dir state (if it existed before this test, bring it back).
  # If it did not exist, leave it gone (clean slate).
  [ "$gen_existed" -eq 0 ] || mkdir -p "$gen_dir"

  # Idempotent: second --uninstall is a clean no-op (exit 0, no mutation).
  local before_second; before_second="$(cat "$claude_md")"
  HOME="$home" PREDICATE_SRC="$plugin_root" \
    bash "$conditioning_sh" --uninstall >/dev/null 2>&1 || {
    note "second --uninstall exited non-zero (not idempotent)"; rc=1
  }
  if [ "$(cat "$claude_md")" != "$before_second" ]; then
    note "second --uninstall mutated the file (not idempotent)"; rc=1
  fi

  rm -rf "$home"
  [ "$rc" -eq 0 ] && ok "$name" || bad "$name"
}

# ---------------------------------------------------------------------------
# Defect 1b: bootstrap phase_uninstall also strips the conditioning block.
# Before the fix, phase_uninstall only strips the managed block.
# ---------------------------------------------------------------------------
case_uninstall_strips_conditioning_block() {
  local name="uninstall: conditioning block stripped by bootstrap phase_uninstall"
  local home; home="$(make_home)"
  local claude_md="$home/.claude/CLAUDE.md"

  # Pre-populate with user content.
  cat >"$claude_md" <<'EOF'
# My global config
1. Always address me by name.
EOF

  # install writes the conditioning block (via nickel); @import managed block is
  # NOT written (output style is the single always-on surface).
  run_install "$home" >/dev/null 2>&1

  # Confirm the conditioning block exists post-install (precondition).
  local rc=0
  if ! grep -qxF '# >>> predicate conditioning block >>>' "$claude_md"; then
    note "conditioning block missing after install — was nickel not available or conditioning skipped?"; rc=1
    bad "$name"; rm -rf "$home"; return
  fi
  # Confirm the @import managed block was NOT written.
  if grep -qxF '# >>> predicate managed block >>>' "$claude_md"; then
    note "managed @import block found after install (must not be written)"; rc=1
  fi

  run_uninstall "$home" >/dev/null 2>&1

  # Conditioning block must be gone.
  if grep -qxF '# >>> predicate conditioning block >>>' "$claude_md"; then
    note "conditioning block still present after uninstall (orphaned)"; rc=1
  fi
  if grep -qxF '# <<< predicate conditioning block <<<' "$claude_md"; then
    note "conditioning block END marker still present after uninstall (orphaned)"; rc=1
  fi
  # @import managed block must remain absent.
  if grep -qxF '# >>> predicate managed block >>>' "$claude_md"; then
    note "managed @import block appeared after uninstall (should never exist)"; rc=1
  fi
  # User content must survive.
  if ! grep -qxF '# My global config' "$claude_md"; then
    note "user content outside blocks was lost during uninstall"; rc=1
  fi

  # Idempotent second run.
  local before_second; before_second="$(cat "$claude_md")"
  run_uninstall "$home" >/dev/null 2>&1
  if [ "$(cat "$claude_md")" != "$before_second" ]; then
    note "second uninstall mutated the file (not idempotent)"; rc=1
  fi

  rm -rf "$home"
  [ "$rc" -eq 0 ] && ok "$name" || bad "$name"
}

# ---------------------------------------------------------------------------
# Defect 2: bootstrap forces Tier 2 by passing --harness explicitly to
# conditioning, defeating auto-detect even when the CLI supports Tier 1.
# After the fix, bootstrap lets conditioning auto-detect; a Tier-1-capable
# claude results in conditioning/generated/architect.md being written.
# ---------------------------------------------------------------------------
case_bootstrap_allows_tier1() {
  local name="bootstrap: conditioning auto-detects Tier 1 when CLI supports --append-system-prompt"
  local conditioning_sh="$plugin_root/conditioning/install.sh"
  if [ ! -f "$conditioning_sh" ]; then
    note "conditioning/install.sh not found — skipping"; bad "$name"; return
  fi

  # Build a mock claude that advertises --append-system-prompt and handles the
  # plugin sub-commands bootstrap invokes (marketplace add, install, uninstall,
  # marketplace remove).
  local mock_bin; mock_bin="$(mktemp -d)"
  cat >"$mock_bin/claude" <<'EOF'
#!/bin/sh
case "$1" in
  --help) printf '  --append-system-prompt string\n'; exit 0 ;;
  plugin) exit 0 ;;
  *) exit 0 ;;
esac
EOF
  chmod +x "$mock_bin/claude"

  local home; home="$(make_home)"

  # Capture the state of conditioning/generated/ so we can restore it.
  local gen_dir="$plugin_root/conditioning/generated"
  local gen_existed=0
  [ -d "$gen_dir" ] && gen_existed=1

  local rc=0
  # Run bootstrap install with the mock claude on PATH; let it auto-detect harness.
  # Pass --harness claude-code so bootstrap skips the real 'claude plugin ...' check
  # (which we've mocked) and goes straight to inject_conditioning.
  PATH="$mock_bin:$PATH" HOME="$home" PREDICATE_PLUGIN_SRC="$plugin_root" \
    bash "$install_sh" install --harness claude-code >/dev/null 2>&1

  # After the fix, conditioning should have used Tier 1 (no forced --harness
  # passed from bootstrap), so the generated file must exist.
  if [ ! -f "$gen_dir/architect.md" ]; then
    note "conditioning/generated/architect.md not created — Tier 1 was not used"; rc=1
    note "(bootstrap likely forced --harness claude-code, bypassing Tier-1 auto-detect)"
  fi

  # And CLAUDE.md's conditioning block should contain an @import line (not inline prompt).
  local claude_md="$home/.claude/CLAUDE.md"
  if grep -qxF '# >>> predicate conditioning block >>>' "$claude_md"; then
    # Block present — verify it uses @import not inline.
    local block_content
    block_content="$(awk '/# >>> predicate conditioning block >>>/,/# <<< predicate conditioning block <<</' "$claude_md")"
    if ! printf '%s' "$block_content" | grep -qE '^@'; then
      note "conditioning block present but has no @import line (Tier 2 inline was used)"; rc=1
    fi
  fi

  # Cleanup: remove generated dir if it was not there before this test.
  if [ "$gen_existed" -eq 0 ]; then
    rm -rf "$gen_dir"
  fi

  rm -rf "$mock_bin" "$home"
  [ "$rc" -eq 0 ] && ok "$name" || bad "$name"
}

# ---------------------------------------------------------------------------
# run all cases
# ---------------------------------------------------------------------------
case_install_uninstall_preserves_user_content
case_uninstall_already_clean
case_uninstall_antigravity_symlink
case_deinit_removes_hooks_preserves_ledger
case_deinit_preserves_user_hook
case_deinit_preserves_foreign_symlink
case_deinit_idempotent
# footgun fixes
case_role_injection_rejected
case_uninstall_dangling_symlink_removed
case_init_gitignore_entries
# conditioning lifecycle defects
case_conditioning_sh_uninstall
case_uninstall_strips_conditioning_block
case_bootstrap_allows_tier1

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
