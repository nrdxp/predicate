#!/usr/bin/env bash
# test_harness_install.sh — TDD for the direct-settings SessionStart
# installer (harness/install-hooks.sh, harness/settings_merge.py).
#
# This installer is the DIRECT path (settings_merge.py's own docstring):
# for a project consuming predicate as an enabled Claude Code plugin, no
# installer is needed at all (harness/hooks.json + plugin.json's "hooks"
# field are auto-discovered). This suite covers the OTHER path — a project
# that wants the hook without going through the plugin marketplace.
#
# Coverage (two levels):
#
#   1. UNIT (settings_merge.py) — structural-value assertions against the
#      returned dict, never against serialized/rendered JSON text:
#      (a) install into an empty settings dict adds exactly one entry.
#      (b) install is idempotent — re-installing changes nothing.
#      (c) install preserves every other key, event, and hook entry
#          byte-for-byte (a Stop hook, an unrelated top-level key).
#      (d) uninstall removes only our entry, leaving everything else,
#          including an empty SessionStart list.
#      (e) uninstall on a settings dict with no SessionStart hooks at all
#          is a no-op, not an error.
#
#   2. CLI (install-hooks.sh) — against throwaway project directories:
#      (f) fresh install creates .claude/settings.json with our entry.
#      (g) re-running install is idempotent (file byte-identical).
#      (h) install onto a settings.json with pre-existing unrelated
#          content preserves it (checked via the CLI's own before/after,
#          not by re-deriving expectations from prose).
#      (i) uninstall removes only our entry.
#      (j) a malformed (invalid JSON) settings.json is refused loudly,
#          never silently overwritten — exit non-zero, file untouched.
#      (k) missing --project directory fails loudly.
#
#   MUTATION -- the "already our entry" match in settings_merge.py is
#      broken in a throwaway copy: re-installing must now duplicate the
#      entry, proving the idempotency assertion (b) can fail.
#
# Usage: test_harness_install.sh
# Exit:  0 = all cases matched, 1 = a case mismatched, 2 = environment error.
set -u

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root="$(cd "$here/../.." && pwd)"
installer="$root/harness/install-hooks.sh"
merger="$root/harness/settings_merge.py"

for f in "$installer" "$merger"; do
  [ -f "$f" ] || { echo "test_harness_install: ENVIRONMENT ERROR — missing $f" >&2; exit 2; }
done
command -v python3 >/dev/null 2>&1 || { echo "ENV: python3 not found on PATH" >&2; exit 2; }

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

fails=0
pass() { echo "PASS  $1"; }
fail() { echo "FAIL  $1"; fails=$((fails + 1)); }

# assert_py DESC PYTHON-BODY — imports settings_merge with sys.path set up.
assert_py() {
  local desc="$1" body="$2"
  python3 - <<PY
import sys
sys.path.insert(0, "$root/harness")
from settings_merge import install, uninstall, hook_entry
ok = False
reason = ""
$body
sys.exit(0 if ok else (print(reason, file=sys.stderr) or 1))
PY
  if [ $? -eq 0 ]; then pass "$desc"; else fail "$desc"; fi
}

# No embedded quotes — this string is interpolated straight into a Python
# heredoc below; the CLI-level cases separately exercise the real quoted
# `python3 "<path>"` command the installer actually generates.
CMD='python3-fake-session-start-py'

# ─── (a) fresh install ───────────────────────────────────────────────────────
assert_py "(a) install into an empty dict adds exactly one entry" '
result = install({}, "'"$CMD"'")
ss = result["hooks"]["SessionStart"]
ok = len(ss) == 1 and ss[0]["hooks"][0]["command"] == "'"$CMD"'"
reason = f"result={result}"
'

# ─── (b) idempotent ──────────────────────────────────────────────────────────
assert_py "(b) re-installing is idempotent" '
once = install({}, "'"$CMD"'")
twice = install(once, "'"$CMD"'")
ok = once == twice and len(twice["hooks"]["SessionStart"]) == 1
reason = f"once={once}\ntwice={twice}"
'

# ─── (c) preserves unrelated content ─────────────────────────────────────────
assert_py "(c) install preserves unrelated keys and hook entries" '
existing = {
    "model": "opus",
    "hooks": {"Stop": [{"matcher": "*", "hooks": [{"type": "command", "command": "echo hi"}]}]},
}
result = install(existing, "'"$CMD"'")
ok = (
    result["model"] == "opus"
    and result["hooks"]["Stop"] == existing["hooks"]["Stop"]
    and len(result["hooks"]["SessionStart"]) == 1
)
reason = f"result={result}"
'

# ─── (d) uninstall removes only our entry ───────────────────────────────────
assert_py "(d) uninstall removes only our entry, leaves the rest" '
existing = {
    "model": "opus",
    "hooks": {
        "Stop": [{"matcher": "*", "hooks": [{"type": "command", "command": "echo hi"}]}],
        "SessionStart": [{"matcher": "*", "hooks": [{"type": "command", "command": "other-tool-hook"}]}],
    },
}
installed = install(existing, "'"$CMD"'")
result = uninstall(installed, "'"$CMD"'")
ss = result["hooks"]["SessionStart"]
ok = (
    result["model"] == "opus"
    and result["hooks"]["Stop"] == existing["hooks"]["Stop"]
    and len(ss) == 1
    and ss[0]["hooks"][0]["command"] == "other-tool-hook"
)
reason = f"result={result}"
'

# ─── (e) uninstall no-op on absent hooks ────────────────────────────────────
assert_py "(e) uninstall with no SessionStart hooks at all is a no-op" '
existing = {"model": "opus"}
result = uninstall(existing, "'"$CMD"'")
ok = result == existing
reason = f"result={result}"
'

# ─── CLI level ────────────────────────────────────────────────────────────────
run_cli() { # project_dir [--uninstall]
  bash "$installer" --project "$1" ${2-} >"$tmp/cli_out.txt" 2>"$tmp/cli_err.txt"
}

proj="$(mktemp -d)"
run_cli "$proj"
rc=$?
if [ "$rc" -eq 0 ] && [ -f "$proj/.claude/settings.json" ] && grep -q "session_start.py" "$proj/.claude/settings.json"; then
  pass "(f) fresh install creates .claude/settings.json with our entry"
else
  fail "(f) rc=$rc, file exists=$([ -f "$proj/.claude/settings.json" ] && echo yes || echo no)"
fi

before="$(cat "$proj/.claude/settings.json" 2>/dev/null)"
run_cli "$proj"
after="$(cat "$proj/.claude/settings.json" 2>/dev/null)"
if [ "$before" = "$after" ]; then
  pass "(g) re-running install is idempotent (file byte-identical)"
else
  fail "(g) file changed on re-install"
fi
rm -rf "$proj"

proj="$(mktemp -d)"
mkdir -p "$proj/.claude"
cat > "$proj/.claude/settings.json" <<'EOF'
{"model": "opus", "hooks": {"Stop": [{"matcher": "*", "hooks": [{"type": "command", "command": "echo hi"}]}]}}
EOF
run_cli "$proj"
if python3 -c "
import json
d = json.load(open('$proj/.claude/settings.json'))
assert d.get('model') == 'opus'
assert d['hooks']['Stop'][0]['hooks'][0]['command'] == 'echo hi'
assert len(d['hooks']['SessionStart']) == 1
" 2>"$tmp/py_err.txt"; then
  pass "(h) install onto pre-existing content preserves it"
else
  fail "(h) $(cat "$tmp/py_err.txt")"
fi

run_cli "$proj" --uninstall
if python3 -c "
import json
d = json.load(open('$proj/.claude/settings.json'))
assert d.get('model') == 'opus'
assert d['hooks']['Stop'][0]['hooks'][0]['command'] == 'echo hi'
assert d['hooks']['SessionStart'] == []
" 2>"$tmp/py_err.txt"; then
  pass "(i) uninstall removes only our entry"
else
  fail "(i) $(cat "$tmp/py_err.txt")"
fi
rm -rf "$proj"

proj="$(mktemp -d)"
mkdir -p "$proj/.claude"
printf 'not-valid-json{{{' > "$proj/.claude/settings.json"
before="$(cat "$proj/.claude/settings.json")"
run_cli "$proj"
rc=$?
after="$(cat "$proj/.claude/settings.json")"
if [ "$rc" -ne 0 ] && [ "$before" = "$after" ]; then
  pass "(j) malformed settings.json is refused loudly, file untouched"
else
  fail "(j) rc=$rc, file changed=$([ "$before" = "$after" ] && echo no || echo yes)"
fi
rm -rf "$proj"

bash "$installer" --project "$tmp/does-not-exist-$$" >"$tmp/cli_out.txt" 2>"$tmp/cli_err.txt"
rc=$?
if [ "$rc" -ne 0 ]; then
  pass "(k) missing --project directory fails loudly"
else
  fail "(k) missing project directory did not fail (rc=$rc)"
fi

# ─── MUTATION: prove case (b) can fail ──────────────────────────────────────
mutant="$tmp/mutant_settings_merge.py"
sed 's/def _is_our_entry(entry: Any, command: str) -> bool:/def _is_our_entry(entry, command):\n    return False\n\ndef _is_our_entry_orig(entry: Any, command: str) -> bool:/' "$merger" > "$mutant"
python3 - "$mutant" <<'PY'
import sys, importlib.util
mutant_path = sys.argv[1]
spec = importlib.util.spec_from_file_location("mutant_sm", mutant_path)
mutant_sm = importlib.util.module_from_spec(spec)
sys.modules["mutant_sm"] = mutant_sm
spec.loader.exec_module(mutant_sm)
once = mutant_sm.install({}, "cmd")
twice = mutant_sm.install(once, "cmd")
# The mutant's broken match never recognizes an existing entry as "ours",
# so a second install duplicates it — the real installer never does this.
sys.exit(0 if len(twice["hooks"]["SessionStart"]) == 2 else 1)
PY
mutant_duplicates=$?
if [ "$mutant_duplicates" -eq 0 ]; then
  pass "(mutation) breaking entry-matching makes re-install duplicate the hook"
else
  fail "(mutation) mutant still stayed idempotent — assertion (b) cannot discriminate this defect"
fi

# ─── Results ─────────────────────────────────────────────────────────────────
if [ "$fails" -ne 0 ]; then
  echo "FAIL: $fails harness-install case(s) mismatched"
  exit 1
fi
echo "PASS: all harness-install cases matched"
exit 0
