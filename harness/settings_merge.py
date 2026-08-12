#!/usr/bin/env python3
"""settings_merge.py — idempotent, non-destructive SessionStart hook entry
merge into a Claude Code `settings.json` (the "direct" format: unwrapped
events at the top level — the hook-development skill's "Settings Format
(Direct)", distinct from a plugin's wrapped `hooks/hooks.json`).

This exists for projects that install predicate WITHOUT going through the
plugin marketplace mechanism. Where the plugin path applies (harness/
hooks.json + plugin.json's `"hooks"` field), no installer is needed at all
— the manifest is auto-discovered once the plugin is enabled, verified
against two shipped Claude Code plugins and an end-to-end run of the exact
`${CLAUDE_PLUGIN_ROOT}` command string (see harness/hooks.json). A direct
settings.json hook has no `${CLAUDE_PLUGIN_ROOT}` — nothing populates it
outside plugin-loading — so the installed command names this installation's
`session_start.py` by absolute, real path instead.

Pure functions (`install`/`uninstall`) take and return a plain dict — never
mutate the input, never touch any hook entry, event, or top-level key that
is not this installation's own SessionStart entry — so tests assert on the
returned structure directly. `main()` is the thin read-JSON / call / write-
JSON CLI wrapper `harness/install-hooks.sh` shells out to.
"""

from __future__ import annotations

import copy
import json
import sys
from typing import Any, Dict


def hook_entry(command: str) -> Dict[str, Any]:
    return {
        "matcher": "*",
        "hooks": [{"type": "command", "command": command, "timeout": 10}],
    }


def _is_our_entry(entry: Any, command: str) -> bool:
    if not isinstance(entry, dict):
        return False
    hooks = entry.get("hooks")
    if not isinstance(hooks, list):
        return False
    return any(
        isinstance(h, dict) and h.get("type") == "command" and h.get("command") == command
        for h in hooks
    )


def install(settings: Dict[str, Any], command: str) -> Dict[str, Any]:
    """A NEW settings dict with our SessionStart entry present exactly
    once. Idempotent: re-installing when our entry is already present
    changes nothing. Every other key, event, and hook entry is preserved
    byte-for-byte (deepcopy, then the one targeted append)."""
    out = copy.deepcopy(settings)
    hooks = out.setdefault("hooks", {})
    session_start = hooks.setdefault("SessionStart", [])
    if not any(_is_our_entry(e, command) for e in session_start):
        session_start.append(hook_entry(command))
    return out


def uninstall(settings: Dict[str, Any], command: str) -> Dict[str, Any]:
    """A NEW settings dict with ONLY our SessionStart entry removed. Every
    other hook entry, event, and top-level key is untouched — including an
    empty SessionStart list or hooks object left behind by the removal;
    tidying a container the user or another tool created is reaching past
    our own entry, not this function's job."""
    out = copy.deepcopy(settings)
    hooks = out.get("hooks")
    if not isinstance(hooks, dict):
        return out
    session_start = hooks.get("SessionStart")
    if not isinstance(session_start, list):
        return out
    hooks["SessionStart"] = [e for e in session_start if not _is_our_entry(e, command)]
    return out


def main(argv) -> int:
    if len(argv) != 3:
        sys.stderr.write(
            "usage: settings_merge.py <settings.json path> <hook-command> <install|uninstall>\n"
        )
        return 2
    path, command, mode = argv
    fn = {"install": install, "uninstall": uninstall}.get(mode)
    if fn is None:
        sys.stderr.write(f"settings_merge: unknown mode: {mode!r} (want install|uninstall)\n")
        return 2

    try:
        with open(path, "r", encoding="utf-8") as f:
            raw = f.read()
    except OSError as exc:
        sys.stderr.write(f"settings_merge: cannot read {path}: {exc}\n")
        return 1
    try:
        settings = json.loads(raw) if raw.strip() else {}
    except json.JSONDecodeError as exc:
        # A malformed settings.json is a real problem, not a degrade-and-
        # continue case: this is a one-time setup action a human or
        # bootstrap script runs, never an advisory hook — silently
        # overwriting or skipping past invalid JSON risks discarding
        # config a human wrote on purpose. Fail loudly instead.
        sys.stderr.write(f"settings_merge: {path} is not valid JSON, refusing to modify it: {exc}\n")
        return 1
    if not isinstance(settings, dict):
        sys.stderr.write(f"settings_merge: {path} does not contain a JSON object at the top level\n")
        return 1

    result = fn(settings, command)

    try:
        with open(path, "w", encoding="utf-8") as f:
            json.dump(result, f, indent=2)
            f.write("\n")
    except OSError as exc:
        sys.stderr.write(f"settings_merge: cannot write {path}: {exc}\n")
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
