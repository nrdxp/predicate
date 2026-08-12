#!/usr/bin/env bash
# install-hooks.sh — wire the SessionStart surface hook into a project's
# .claude/settings.json directly, in one idempotent command.
#
# This is the DIRECT-install path (harness/settings_merge.py's own docstring
# explains why it exists): for a project consuming predicate as an enabled
# Claude Code PLUGIN, no installer is needed at all — harness/hooks.json +
# .claude-plugin/plugin.json's `"hooks"` field are auto-discovered once the
# plugin is enabled, verified against two shipped Claude Code plugins and an
# end-to-end run of the exact ${CLAUDE_PLUGIN_ROOT} command string. THIS
# installer is for projects that install predicate some other way (e.g. via
# bootstrap/install.sh, not the marketplace) and still want the hook.
#
# Idempotent and non-destructive: adds exactly one SessionStart hook entry
# naming THIS installation's harness/session_start.py by absolute path — a
# direct settings.json hook has no ${CLAUDE_PLUGIN_ROOT} — and never touches
# any other hook entry, event, or top-level settings.json key. Re-running is
# a no-op once installed; --uninstall removes only the entry this installer
# added.
#
# Usage:
#   harness/install-hooks.sh [--project <path>]              (install; cwd if omitted)
#   harness/install-hooks.sh [--project <path>] --uninstall   (remove only our entry)
# Exit:   0 = installed / already current / removed, non-zero = could not complete.
#
# NOT composed from bootstrap/install.sh yet — a separate, deliberate wiring
# decision, not an oversight.
set -euo pipefail

mode="install"
project="."
while [ $# -gt 0 ]; do
  case "$1" in
    --uninstall) mode="uninstall"; shift ;;
    --project)
      [ $# -ge 2 ] || { echo "install-hooks: --project requires a path argument" >&2; exit 2; }
      project="$2"; shift 2 ;;
    *) echo "install-hooks: unknown argument: $1" >&2; exit 2 ;;
  esac
done

command -v python3 >/dev/null 2>&1 || { echo "install-hooks: python3 not found on PATH" >&2; exit 2; }

# The hook SOURCE is predicate MACHINERY: resolve it from THIS installer's
# own real path, never from the project being installed into — the same
# pattern hooks/install-hooks.sh and ledger/gate/install-recorder-hook.sh
# already establish.
plugin="$(cd "$(dirname "$(realpath "${BASH_SOURCE[0]}")")/.." && pwd)"
hook_script="$plugin/harness/session_start.py"
merger="$plugin/harness/settings_merge.py"
for f in "$hook_script" "$merger"; do
  [ -f "$f" ] || { echo "install-hooks: missing source file: $f" >&2; exit 1; }
done

[ -d "$project" ] || { echo "install-hooks: project directory not found: $project" >&2; exit 1; }
project_dir="$(cd "$project" && pwd)"
settings_dir="$project_dir/.claude"
settings_file="$settings_dir/settings.json"

command_str="python3 \"$hook_script\""

mkdir -p "$settings_dir"
[ -f "$settings_file" ] || printf '{}\n' > "$settings_file"

before="$(cat "$settings_file")"
python3 "$merger" "$settings_file" "$command_str" "$mode"
after="$(cat "$settings_file")"

if [ "$mode" = "uninstall" ]; then
  if [ "$before" = "$after" ]; then
    echo "install-hooks: no SessionStart entry to remove (already clean)."
  else
    echo "install-hooks: removed the SessionStart entry from $settings_file."
  fi
else
  if [ "$before" = "$after" ]; then
    echo "install-hooks: SessionStart hook already current in $settings_file (no-op)."
  else
    echo "install-hooks: wired SessionStart hook into $settings_file -> $hook_script"
  fi
fi
