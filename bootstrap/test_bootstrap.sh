#!/usr/bin/env bash
# test_bootstrap.sh — executable evaluator for the install bootstrap.
#
# Runs install.sh against a throwaway fixture HOME and a throwaway fixture
# project, so the user's real global config is never touched. The load-bearing
# assertion is idempotency + non-clobbering of the global CLAUDE.md append
# (C14-1): run the bootstrap twice, assert the two @import lines appear exactly
# once and the pre-existing content is byte-preserved as a prefix.
#
# Usage:  bootstrap/test_bootstrap.sh
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

# A sandbox: an isolated HOME + a clean fixture project, both under a tmpdir we
# remove on exit. The bootstrap is told the sandbox HOME via $HOME, and the
# fixture project via its first argument (the project root).
make_sandbox() {
  local box; box="$(mktemp -d)"
  mkdir -p "$box/home/.claude" "$box/project"
  git -C "$box/project" init -q
  printf '%s' "$box"
}

# Run the bootstrap with HOME pointed at the sandbox; harness defaults to
# claude-code, the plugin source is this repo, and the .ledger remote is a
# throwaway URL so no real network/push can occur.
run_bootstrap() {
  local box="$1"; shift
  HOME="$box/home" \
  PREDICATE_PLUGIN_SRC="$plugin_root" \
  PREDICATE_LEDGER_REMOTE="git@example.invalid:fixture/ledger.git" \
    bash "$install_sh" --project "$box/project" --harness claude-code "$@"
}

# ---------------------------------------------------------------------------
# Case 1 — idempotent, non-clobbering, append-safe CLAUDE.md injection (C14-1)
# ---------------------------------------------------------------------------
case_idempotent_append() {
  local name="claude_md idempotent + append-safe + non-clobbering"
  local box; box="$(make_sandbox)"
  local claude_md="$box/home/.claude/CLAUDE.md"

  # Seed a realistic pre-existing global config the user already owns.
  cat >"$claude_md" <<'EOF'
# My global config

1. Always address me by name.
2. Never add co-author trailers.
EOF
  local original; original="$(cat "$claude_md")"

  run_bootstrap "$box" >/dev/null 2>&1
  local after_first; after_first="$(cat "$claude_md")"
  run_bootstrap "$box" >/dev/null 2>&1
  local after_second; after_second="$(cat "$claude_md")"

  local rc=0

  # Non-clobber + append-safe: the original bytes are an exact PREFIX of the
  # result (existing content untouched, additions only at the tail).
  if [ "${after_first:0:${#original}}" != "$original" ]; then
    note "original content is not a byte-prefix of the result (clobbered/reordered)"; rc=1
  fi

  # Idempotency: the second run changes nothing.
  if [ "$after_first" != "$after_second" ]; then
    note "second run mutated the file (not idempotent)"; rc=1
  fi

  # Each @import line appears exactly once after two runs.
  local n_rules n_ambient
  n_rules="$(grep -cF '/rules.md' "$claude_md")"
  n_ambient="$(grep -cF '/ambient.md' "$claude_md")"
  if [ "$n_rules" != "1" ]; then note "rules.md @import count = $n_rules (want 1)"; rc=1; fi
  if [ "$n_ambient" != "1" ]; then note "ambient.md @import count = $n_ambient (want 1)"; rc=1; fi

  # The appended lines are real @import directives pointing at the plugin.
  if ! grep -qE "^@.*/rules\.md$" "$claude_md"; then note "no @.../rules.md import line"; rc=1; fi
  if ! grep -qE "^@.*/ambient\.md$" "$claude_md"; then note "no @.../ambient.md import line"; rc=1; fi

  rm -rf "$box"
  [ "$rc" -eq 0 ] && ok "$name" || bad "$name"
}

# Append-safety against a file with NO trailing newline (a nasty real case:
# naive `>>` would glue the import onto the user's last line).
case_no_trailing_newline() {
  local name="claude_md append-safe when original lacks a trailing newline"
  local box; box="$(make_sandbox)"
  local claude_md="$box/home/.claude/CLAUDE.md"
  printf '# config\nlast line no newline' >"$claude_md"

  run_bootstrap "$box" >/dev/null 2>&1
  local rc=0
  if ! grep -qx 'last line no newline' "$claude_md"; then
    note "the original last line was corrupted by the append"; rc=1
  fi
  if ! grep -qE "^@.*/rules\.md$" "$claude_md"; then note "rules import missing"; rc=1; fi

  rm -rf "$box"
  [ "$rc" -eq 0 ] && ok "$name" || bad "$name"
}

# Fresh HOME with no CLAUDE.md at all: the bootstrap creates one with only the
# managed block (still idempotent on re-run).
case_fresh_home() {
  local name="claude_md created when absent, then idempotent"
  local box; box="$(make_sandbox)"
  local claude_md="$box/home/.claude/CLAUDE.md"
  rm -f "$claude_md"

  run_bootstrap "$box" >/dev/null 2>&1
  run_bootstrap "$box" >/dev/null 2>&1
  local rc=0
  [ -f "$claude_md" ] || { note "CLAUDE.md was not created"; rc=1; }
  local n; n="$(grep -cF '/rules.md' "$claude_md" 2>/dev/null || echo 0)"
  [ "$n" = "1" ] || { note "rules import count = $n (want 1)"; rc=1; }

  rm -rf "$box"
  [ "$rc" -eq 0 ] && ok "$name" || bad "$name"
}

# ---------------------------------------------------------------------------
# Case 2 — .ledger subrepo init with a configured remote and NO push (C14-3)
# ---------------------------------------------------------------------------
case_ledger_init_no_push() {
  local name="ledger init: subrepo + configured remote, no push"
  local box; box="$(make_sandbox)"

  run_bootstrap "$box" >/dev/null 2>&1
  local rc=0
  local ledger="$box/project/.ledger"
  if ! git -C "$ledger" rev-parse --git-dir >/dev/null 2>&1; then
    note ".ledger is not a git repo"; rc=1
  fi
  local remote; remote="$(git -C "$ledger" config --get remote.origin.url 2>/dev/null || true)"
  if [ "$remote" != "git@example.invalid:fixture/ledger.git" ]; then
    note "remote = '$remote' (want the configured URL)"; rc=1
  fi
  # No push must have happened: the configured remote is unreachable, so a push
  # attempt would have errored; more directly, install.sh must contain no
  # `git push`. Assert statically against the script.
  if grep -qE 'git[^#]*push' "$install_sh"; then
    note "install.sh contains a git push (forbidden)"; rc=1
  fi

  rm -rf "$box"
  [ "$rc" -eq 0 ] && ok "$name" || bad "$name"
}

# ---------------------------------------------------------------------------
# Case 3 — end to end: all four steps, install-hooks composed by path
# ---------------------------------------------------------------------------
case_end_to_end() {
  local name="end-to-end: plugin registered + hooks + ledger + imports"
  local box; box="$(make_sandbox)"

  run_bootstrap "$box" >/dev/null 2>&1
  local rc=0

  # 1. plugin registered: the claude-code harness dir holds the plugin manifest.
  if [ ! -f "$box/home/.claude/plugins/predicate/plugin.json" ]; then
    note "plugin not registered into the claude-code plugins dir"; rc=1
  fi
  # 2. hooks installed via the COMPOSED install-hooks.sh (effective in project).
  local common; common="$(git -C "$box/project" rev-parse --git-common-dir 2>/dev/null)"
  case "$common" in /*) : ;; *) common="$box/project/$common" ;; esac
  if [ ! -e "$common/hooks/commit-msg" ]; then
    note "commit-msg hook not installed by the composed install-hooks step"; rc=1
  fi
  # 3. ledger present.
  git -C "$box/project/.ledger" rev-parse --git-dir >/dev/null 2>&1 || { note ".ledger missing"; rc=1; }
  # 4. imports appended.
  grep -qE "^@.*/rules\.md$" "$box/home/.claude/CLAUDE.md" || { note "rules import missing"; rc=1; }

  rm -rf "$box"
  [ "$rc" -eq 0 ] && ok "$name" || bad "$name"
}

# install-hooks.sh must be composed, never modified: the bootstrap references it
# by path. (The campaign's name-only diff check is the architect's job; here we
# assert the script invokes it by path and does not inline its body.)
case_hooks_composed_by_path() {
  local name="install-hooks.sh composed by path, not inlined"
  local rc=0
  if ! grep -qF 'install-hooks.sh' "$install_sh"; then
    note "install.sh does not reference install-hooks.sh"; rc=1
  fi
  # Inlining would re-create the symlink loop here; the source-of-truth string
  # 'Worktree-correct' lives only in hooks/install-hooks.sh.
  if grep -qF 'Worktree-correct' "$install_sh"; then
    note "install.sh appears to inline install-hooks.sh body"; rc=1
  fi
  [ "$rc" -eq 0 ] && ok "$name" || bad "$name"
}

# The bootstrap emits a documented .ledger/config.sh.example (a commented
# override template, NOT an active config) that is itself valid bash.
case_config_example_emitted() {
  local name="ledger config.sh.example emitted + valid bash, no active config.sh"
  local box; box="$(make_sandbox)"

  run_bootstrap "$box" >/dev/null 2>&1
  local rc=0
  local example="$box/project/.ledger/config.sh.example"
  if [ ! -f "$example" ]; then
    note ".ledger/config.sh.example was not emitted"; rc=1
  else
    if ! bash -n "$example" 2>/dev/null; then note "config.sh.example is not valid bash"; rc=1; fi
    # The template must document the externalized override surface (P3's vars).
    for var in SELFCONTAINED_PAT ORPHAN_TARGETS ORPHAN_EXCLUDE SKILLS_DIR REMOVED; do
      grep -qF "$var" "$example" || { note "config.sh.example omits $var"; rc=1; }
    done
  fi
  # It is an EXAMPLE, not an active config: an active config.sh must NOT be
  # written (the optional-with-fallback design is preserved).
  if [ -f "$box/project/.ledger/config.sh" ]; then
    note "an active .ledger/config.sh was written (must stay opt-in)"; rc=1
  fi

  rm -rf "$box"
  [ "$rc" -eq 0 ] && ok "$name" || bad "$name"
}

case_idempotent_append
case_no_trailing_newline
case_fresh_home
case_ledger_init_no_push
case_config_example_emitted
case_end_to_end
case_hooks_composed_by_path

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
