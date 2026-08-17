#!/usr/bin/env bash
# test_pretooluse_agent_shadow.sh — TDD for the PreToolUse shadow-mode hook
# (harness/pretooluse_agent_shadow.py, node/cond-hooks) and its registration
# in harness/hooks.json.
#
# The hook observes an Agent/Task dispatch's prompt against the composer
# persona's own dispatch rules (workspace/branch/base-commit/sanction/cited-
# sources, plus seat-continuity for a seat subagent_type) and logs what it
# WOULD have flagged — it must NEVER emit a permissionDecision and NEVER
# raise past its own top-level try/except. This suite pins that contract and
# every discriminating check beneath it. Every assertion below is proved
# capable of failing (a MUTATION section per invariant class), matching
# test_session_start.sh's own convention: a case where the real hook and a
# broken one produce the same verdict is green-by-construction and worthless.
#
# Coverage:
#   (a)/(a2)  a complete, well-formed dispatch: every discriminating check
#             true, seat_role false, seating_declared None, failed == [],
#             would_deny_if_enforced false — both via evaluate() directly
#             and through the full script's stdout ({} exactly).
#   (b)       an empty/malformed dispatch: every discriminating check false,
#             would_deny_if_enforced TRUE — yet the full script's stdout is
#             STILL exactly {} and exit is STILL 0. This is the load-bearing
#             property: shadow mode never denies even when it would.
#   (c)-(k)   crash safety: missing tool_input, empty stdin, invalid JSON,
#             a non-string prompt/description/subagent_type, a huge prompt,
#             a unicode prompt — every path exits 0 with stdout exactly {}.
#   (l)       discrimination: for each of the 5 non-seat checks, the complete
#             dispatch minus exactly that element flips exactly that check
#             to false and leaves every other check untouched.
#   (m)-(q)   seat-role detection: a seat subagent_type without a seating
#             declaration fails seating_declared; the same dispatch WITH a
#             seating declaration does not; a non-seat dispatch reports
#             seating_declared as None (never applied, never a false
#             failure); case-insensitive substring matching on the seat
#             marker set.
#   (r)-(u)   logging: one JSONL line per invocation, valid JSON, the
#             prompt/description head truncated to 150 chars regardless of
#             input size, a huge prompt's full text never reaching the log,
#             unicode surviving truncation and re-decoding cleanly.
#   (v)-(y2)  registration: hooks.json parses, declares PreToolUse alongside
#             SessionStart/SubagentStart, its matcher fires on "Task" and
#             "Agent" but not on "SendMessage" or any Task-family tool name
#             (TaskCreate/TaskUpdate/TaskGet/TaskList/TaskStop), and its
#             command references this hook script. The matcher "Task|Agent"
#             contains only letters and "|", which code.claude.com/docs/en/
#             hooks' own matcher-evaluation table places on the EXACT-STRING-
#             ALTERNATION path ("Only letters, digits, _, -, spaces, ,, and
#             \|" -> "Exact string ... separated by \| or , ... Edit|Write
#             ... match either tool exactly"), never the unanchored-regex
#             path a bare substring search would imply — confirmed by a live
#             fetch of that page (2026-08-17), independently of the prior
#             walk's own reading, which it could not reproduce live. (y2)
#             pins this: re.fullmatch is the correct model for this
#             matcher's exact-alternation semantics, not re.search.
#
#   MUTATION 1 -- the never-deny contract: both `print(json.dumps({}))`
#       sites are patched to emit a permissionDecision:"deny" whenever
#       would_deny is true; re-running the malformed dispatch (b) against
#       the mutant now DOES surface a permissionDecision, proving (b)/(d)
#       can catch an enforcing regression rather than passing by construction.
#   MUTATION 2 -- discrimination: ABS_PATH_RE is broadened to match
#       anywhere; the workspace_path-omitted dispatch from (l) now reports
#       workspace_path=true against the mutant, proving that case can fail.
#   MUTATION 3 -- seat detection: is_seat_dispatch is patched to always
#       return False; a seat dispatch from (m) now reports seat_role=false
#       against the mutant, proving that case can fail.
#   MUTATION 4 -- logging truncation: the `[:PROMPT_HEAD_CHARS]` slice on
#       prompt_head is removed; a huge-prompt run against the mutant now
#       writes the FULL prompt into the log, proving the truncation
#       assertion (t) can fail.
#   MUTATION 5 -- crash safety: the top-level `except Exception` is narrowed
#       to `except ValueError`; feeding the mutant a non-string prompt (which
#       raises TypeError inside evaluate()) now exits NONZERO, proving the
#       never-crashes assertion (h) can fail.
#   MUTATION 6 -- registration: a mutated copy of hooks.json widens the
#       PreToolUse matcher to "SendMessage"; the matcher-exclusion assertion
#       (y), re-run against the mutant, now reports a match, proving that
#       case can fail rather than passing regardless of matcher content.
#
# Usage: test_pretooluse_agent_shadow.sh
# Exit:  0 = all cases matched, 1 = a case mismatched, 2 = environment error.
set -u

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root="$(cd "$here/../.." && pwd)"
hook="$root/harness/pretooluse_agent_shadow.py"
hooks_json="$root/harness/hooks.json"

[ -f "$hook" ] || { echo "test_pretooluse_agent_shadow: ENVIRONMENT ERROR — missing $hook" >&2; exit 2; }
[ -f "$hooks_json" ] || { echo "test_pretooluse_agent_shadow: ENVIRONMENT ERROR — missing $hooks_json" >&2; exit 2; }
command -v python3 >/dev/null 2>&1 || { echo "ENV: python3 not found on PATH" >&2; exit 2; }
command -v git >/dev/null 2>&1 || { echo "ENV: git not found on PATH" >&2; exit 2; }

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

fails=0
pass() { echo "PASS  $1"; }
fail() { echo "FAIL  $1${2:+ -- $2}"; fails=$((fails + 1)); }

nonzero_exits=0
# run_hook_file HOOK_PATH STDIN_FILE — invokes a hook script (real or mutant)
# with stdin read from a file (never a bash arg — huge/unicode payloads go
# through files, never shell quoting).
run_hook_file() {
  local hookpath="$1" stdin_file="$2"
  python3 "$hookpath" <"$stdin_file" >"$tmp/stdout.json" 2>"$tmp/stderr.txt"
  return $?
}

# run_hook STDIN_FILE — the real hook, tracking the never-nonzero invariant.
run_hook() {
  run_hook_file "$hook" "$1"
  local rc=$?
  [ "$rc" -ne 0 ] && nonzero_exits=$((nonzero_exits + 1))
  return "$rc"
}

make_git_repo() {
  local d; d="$(mktemp -d)"
  git -c user.name=t -c user.email=t@t -c commit.gpgsign=false -C "$d" init -q -b topic/hook-test
  printf '%s' "$d"
}

# assert_py DESC BODY — runs BODY with `ph` (the real hook module) already
# imported and a `build_prompt(omit=frozenset([...]))` helper in scope that
# assembles the fragment set below, minus the omitted keys. Must set `ok`
# (and may set `reason`).
assert_py() {
  local desc="$1" body="$2"
  python3 - <<PY
import sys
sys.path.insert(0, "$root/harness")
import pretooluse_agent_shadow as ph

FRAGMENTS = {
    "workspace": "WORKSPACE: /var/home/nrd/git/wt/cond-hooks",
    "branch": "branch node/cond-hooks",
    "base": "base commit 2b91739",
    "sanction": "SANCTION: you are authorized to commit, auto mode",
    "sources": "cited sources [S1]",
    "seating": "this is your first seating",
}
FRAGMENT_ORDER = ["workspace", "branch", "base", "sanction", "sources", "seating"]

def build_prompt(omit=frozenset()):
    return "\n".join(FRAGMENTS[k] for k in FRAGMENT_ORDER if k not in omit)

ok = False
reason = ""
$body
sys.exit(0 if ok else (print(reason, file=sys.stderr) or 1))
PY
  # On failure the subprocess already printed `reason` to this shell's own
  # stderr (via python's print(..., file=sys.stderr)) — nothing further to
  # capture here, matching test_session_start.sh's own assert_py idiom.
  if [ $? -eq 0 ]; then pass "$desc"; else fail "$desc"; fi
}

# ─── (a)/(a2) a complete dispatch: every check true except seat fields ─────
assert_py "(a) a complete dispatch: all 5 checks true, seat_role false, seating_declared None" '
prompt = build_prompt()
result = ph.evaluate(prompt, "general-purpose")
c = result["checks"]
ok = (
    c["workspace_path"] and c["branch"] and c["base_commit"]
    and c["sanction"] and c["cited_sources"]
    and c["seat_role"] is False
    and c["seating_declared"] is None
    and result["failed"] == []
    and result["would_deny"] is False
)
reason = f"result={result}"
'

stdin_a="$tmp/stdin_a.json"
python3 - "$stdin_a" <<'PY'
import json, sys
FRAGMENTS = {
    "workspace": "WORKSPACE: /var/home/nrd/git/wt/cond-hooks",
    "branch": "branch node/cond-hooks",
    "base": "base commit 2b91739",
    "sanction": "SANCTION: you are authorized to commit, auto mode",
    "sources": "cited sources [S1]",
    "seating": "this is your first seating",
}
prompt = "\n".join(FRAGMENTS[k] for k in ["workspace", "branch", "base", "sanction", "sources"])
payload = {
    "tool_name": "Task",
    "tool_input": {"prompt": prompt, "subagent_type": "general-purpose", "description": "test dispatch"},
    "session_id": "sess-a",
    "cwd": sys.argv[1] if len(sys.argv) > 1 else ".",
}
with open(sys.argv[1], "w") as f:
    json.dump(payload, f)
PY
run_hook "$stdin_a"
rc_a=$?
if [ "$rc_a" -eq 0 ] && [ "$(cat "$tmp/stdout.json")" = "{}" ]; then
  pass "(a2) full script emits bare {} and exit 0 for a well-formed dispatch"
else
  fail "(a2) full script emits bare {} and exit 0 for a well-formed dispatch" "rc=$rc_a stdout=$(cat "$tmp/stdout.json")"
fi

# ─── (b) empty/malformed dispatch: would_deny true, output STILL {} ────────
assert_py "(b) an empty dispatch: every check false, would_deny_if_enforced true" '
result = ph.evaluate("", "")
c = result["checks"]
ok = (
    c["workspace_path"] is False and c["branch"] is False and c["base_commit"] is False
    and c["sanction"] is False and c["cited_sources"] is False
    and c["seat_role"] is False and c["seating_declared"] is None
    and sorted(result["failed"]) == ["base_commit", "branch", "cited_sources", "sanction", "workspace_path"]
    and result["would_deny"] is True
)
reason = f"result={result}"
'

stdin_b="$tmp/stdin_b.json"
printf '{"tool_name": "Task", "tool_input": {"prompt": "", "subagent_type": "", "description": ""}}' > "$stdin_b"
run_hook "$stdin_b"
rc_b=$?
if [ "$rc_b" -eq 0 ] && [ "$(cat "$tmp/stdout.json")" = "{}" ] && ! grep -q "permissionDecision" "$tmp/stdout.json"; then
  pass "(d) THE LOAD-BEARING PROPERTY: a maximally-malformed dispatch (would_deny=true) still emits bare {} and exit 0"
else
  fail "(d) THE LOAD-BEARING PROPERTY: a maximally-malformed dispatch still emits bare {} and exit 0" "rc=$rc_b stdout=$(cat "$tmp/stdout.json")"
fi

# ─── (c)-(k) crash safety ───────────────────────────────────────────────────

stdin_c="$tmp/stdin_c.json"
printf '{"tool_name": "Task"}' > "$stdin_c"
run_hook "$stdin_c"
if [ $? -eq 0 ] && [ "$(cat "$tmp/stdout.json")" = "{}" ]; then
  pass "(c) missing tool_input entirely — exit 0, bare {}"
else
  fail "(c) missing tool_input entirely — exit 0, bare {}"
fi

stdin_empty="$tmp/stdin_empty.json"
: > "$stdin_empty"
run_hook "$stdin_empty"
if [ $? -eq 0 ] && [ "$(cat "$tmp/stdout.json")" = "{}" ]; then
  pass "(f) empty stdin — exit 0, bare {}"
else
  fail "(f) empty stdin — exit 0, bare {}"
fi

stdin_badjson="$tmp/stdin_badjson.json"
printf 'not-json-at-all{{{' > "$stdin_badjson"
run_hook "$stdin_badjson"
if [ $? -eq 0 ] && [ "$(cat "$tmp/stdout.json")" = "{}" ]; then
  pass "(g) invalid JSON on stdin — exit 0, bare {}"
else
  fail "(g) invalid JSON on stdin — exit 0, bare {}"
fi

stdin_nonstr="$tmp/stdin_nonstr.json"
printf '{"tool_name": "Task", "tool_input": {"prompt": 12345, "subagent_type": "general-purpose"}}' > "$stdin_nonstr"
run_hook "$stdin_nonstr"
if [ $? -eq 0 ] && [ "$(cat "$tmp/stdout.json")" = "{}" ] && grep -q "internal error" "$tmp/stderr.txt"; then
  pass "(h) a non-string prompt (int) — exit 0, bare {}, stderr names the internal error"
else
  fail "(h) a non-string prompt (int) — exit 0, bare {}, stderr names the internal error" "stderr=$(cat "$tmp/stderr.txt")"
fi

stdin_nonstr2="$tmp/stdin_nonstr2.json"
printf '{"tool_name": "Task", "tool_input": {"prompt": "hello", "subagent_type": ["a", "list"], "description": {"not": "a string"}}}' > "$stdin_nonstr2"
run_hook "$stdin_nonstr2"
if [ $? -eq 0 ] && [ "$(cat "$tmp/stdout.json")" = "{}" ]; then
  pass "(i) non-string subagent_type/description — exit 0, bare {}"
else
  fail "(i) non-string subagent_type/description — exit 0, bare {}"
fi

stdin_huge="$tmp/stdin_huge.json"
python3 - "$stdin_huge" <<'PY'
import json, sys
payload = {
    "tool_name": "Task",
    "tool_input": {"prompt": "X" * 500000, "subagent_type": "general-purpose", "description": "huge"},
    "session_id": "sess-huge",
}
with open(sys.argv[1], "w") as f:
    json.dump(payload, f)
PY
run_hook "$stdin_huge"
if [ $? -eq 0 ] && [ "$(cat "$tmp/stdout.json")" = "{}" ]; then
  pass "(j) a 500,000-char prompt — exit 0, bare {}"
else
  fail "(j) a 500,000-char prompt — exit 0, bare {}"
fi

stdin_unicode="$tmp/stdin_unicode.json"
python3 - "$stdin_unicode" <<'PY'
import json, sys
payload = {
    "tool_name": "Task",
    "tool_input": {"prompt": "调度 🚀 ünïcödé WORKSPACE: /a/b/c branch tip", "subagent_type": "general-purpose", "description": "unicode dispatch"},
    "session_id": "sess-uni",
}
with open(sys.argv[1], "w") as f:
    json.dump(payload, f, ensure_ascii=False)
PY
run_hook "$stdin_unicode"
if [ $? -eq 0 ] && [ "$(cat "$tmp/stdout.json")" = "{}" ]; then
  pass "(k) a unicode prompt — exit 0, bare {}"
else
  fail "(k) a unicode prompt — exit 0, bare {}"
fi

# ─── (l) discrimination: each check flips independently on element removal ─
for key in workspace branch base sanction sources; do
  case "$key" in
    workspace) checkname="workspace_path" ;;
    branch)    checkname="branch" ;;
    base)      checkname="base_commit" ;;
    sanction)  checkname="sanction" ;;
    sources)   checkname="cited_sources" ;;
  esac
  assert_py "(l) omitting '$key' flips ONLY '$checkname' to false" "
prompt = build_prompt(omit=frozenset(['$key']))
result = ph.evaluate(prompt, 'general-purpose')
c = result['checks']
others_untouched = all(
    c[name] for name in ('workspace_path', 'branch', 'base_commit', 'sanction', 'cited_sources')
    if name != '$checkname'
)
ok = (c['$checkname'] is False) and others_untouched
reason = f'result={result}'
"
done

# ─── (m)-(q) seat-role detection ────────────────────────────────────────────
assert_py "(m) a seat dispatch missing its seating declaration fails seating_declared" '
prompt = build_prompt(omit=frozenset(["seating"]))
result = ph.evaluate(prompt, "predicate-architect-seat")
c = result["checks"]
ok = c["seat_role"] is True and c["seating_declared"] is False and "seating_declared" in result["failed"]
reason = f"result={result}"
'

assert_py "(n) the same seat dispatch WITH a seating declaration does not fail seating_declared" '
prompt = build_prompt()
result = ph.evaluate(prompt, "predicate-architect-seat")
c = result["checks"]
ok = c["seat_role"] is True and c["seating_declared"] is True and "seating_declared" not in result["failed"]
reason = f"result={result}"
'

assert_py "(o) a non-seat dispatch missing seating text reports seating_declared=None, never a failure" '
prompt = build_prompt(omit=frozenset(["seating"]))
result = ph.evaluate(prompt, "general-purpose")
c = result["checks"]
ok = c["seat_role"] is False and c["seating_declared"] is None and "seating_declared" not in result["failed"]
reason = f"result={result}"
'

assert_py "(p) seat-marker matching is case-insensitive and substring-based" '
ok = (
    ph.is_seat_dispatch("PREDICATE-ARCHITECT-SEAT-REVIEWER") is True
    and ph.is_seat_dispatch("predicate-hacker-seat") is True
    and ph.is_seat_dispatch("general-purpose") is False
    and ph.is_seat_dispatch("") is False
)
reason = "is_seat_dispatch mismatched for one of the fixtures above"
'

# ─── (r)-(u) logging ─────────────────────────────────────────────────────────
log_proj="$(make_git_repo)"
stdin_log1="$tmp/stdin_log1.json"
python3 - "$stdin_log1" "$log_proj" <<'PY'
import json, sys
payload = {
    "tool_name": "Task",
    "tool_input": {"prompt": "WORKSPACE: /a/b branch tip sanction cited [S1]", "subagent_type": "general-purpose", "description": "first"},
    "session_id": "sess-log-1",
    "cwd": sys.argv[2],
}
with open(sys.argv[1], "w") as f:
    json.dump(payload, f)
PY
run_hook_file "$hook" "$stdin_log1"
rc1=$?
stdin_log2="$tmp/stdin_log2.json"
python3 - "$stdin_log2" "$log_proj" <<'PY'
import json, sys
payload = {
    "tool_name": "Agent",
    "tool_input": {"prompt": "second dispatch", "subagent_type": "predicate-hacker-seat", "description": "second"},
    "session_id": "sess-log-2",
    "cwd": sys.argv[2],
}
with open(sys.argv[1], "w") as f:
    json.dump(payload, f)
PY
run_hook_file "$hook" "$stdin_log2"
rc2=$?
logfile="$log_proj/.ledger/state/agent-dispatch-shadow.jsonl"
nlines="$( [ -f "$logfile" ] && wc -l < "$logfile" || echo 0 )"
if [ "$rc1" -eq 0 ] && [ "$rc2" -eq 0 ] && [ -f "$logfile" ] && [ "$(echo "$nlines" | tr -d ' ')" = "2" ]; then
  pass "(r) two invocations append exactly two JSONL lines"
else
  fail "(r) two invocations append exactly two JSONL lines" "rc1=$rc1 rc2=$rc2 nlines=$nlines file_exists=$([ -f "$logfile" ] && echo yes || echo no)"
fi

if [ -f "$logfile" ] && python3 - "$logfile" <<'PY'
import json, sys
path = sys.argv[1]
with open(path) as f:
    lines = [l for l in f.read().splitlines() if l.strip()]
ok = True
for line in lines:
    rec = json.loads(line)  # raises if invalid JSON
    required = {"ts", "tool_name", "subagent_type", "description", "prompt_head", "checks", "failed", "would_deny_if_enforced", "session_id"}
    ok = ok and required.issubset(rec.keys())
sys.exit(0 if ok and len(lines) == 2 else 1)
PY
then
  pass "(s) every logged line is valid JSON carrying the full required key set"
else
  fail "(s) every logged line is valid JSON carrying the full required key set"
fi
rm -rf "$log_proj"

# huge prompt: prompt_head/description truncated, full prompt never logged
log_proj2="$(make_git_repo)"
stdin_log_huge="$tmp/stdin_log_huge.json"
python3 - "$stdin_log_huge" "$log_proj2" <<'PY'
import json, sys
payload = {
    "tool_name": "Task",
    "tool_input": {"prompt": "Y" * 500000, "subagent_type": "general-purpose", "description": "Z" * 500000},
    "session_id": "sess-huge-log",
    "cwd": sys.argv[2],
}
with open(sys.argv[1], "w") as f:
    json.dump(payload, f)
PY
run_hook_file "$hook" "$stdin_log_huge"
logfile2="$log_proj2/.ledger/state/agent-dispatch-shadow.jsonl"
if [ -f "$logfile2" ] && python3 - "$logfile2" <<'PY'
import json, sys
rec = json.loads(open(sys.argv[1]).read().strip())
ok = (
    len(rec["prompt_head"]) <= 150
    and len(rec["description"]) <= 150
    and "Y" * 151 not in rec["prompt_head"]
    and rec["prompt_head"] == "Y" * 150
)
sys.exit(0 if ok else 1)
PY
then
  pass "(t) a 500,000-char prompt/description is truncated to 150 chars in the log, never logged in full"
else
  fail "(t) a 500,000-char prompt/description is truncated to 150 chars in the log, never logged in full"
fi
rm -rf "$log_proj2"

# unicode: log line valid JSON, decodes cleanly, head carries the unicode text
log_proj3="$(make_git_repo)"
stdin_log_uni="$tmp/stdin_log_uni.json"
python3 - "$stdin_log_uni" "$log_proj3" <<'PY'
import json, sys
payload = {
    "tool_name": "Task",
    "tool_input": {"prompt": "调度 🚀 ünïcödé dispatch", "subagent_type": "general-purpose", "description": "unicode"},
    "session_id": "sess-uni-log",
    "cwd": sys.argv[2],
}
with open(sys.argv[1], "w") as f:
    json.dump(payload, f, ensure_ascii=False)
PY
run_hook_file "$hook" "$stdin_log_uni"
logfile3="$log_proj3/.ledger/state/agent-dispatch-shadow.jsonl"
if [ -f "$logfile3" ] && python3 - "$logfile3" <<'PY'
import json, sys
rec = json.loads(open(sys.argv[1], encoding="utf-8").read().strip())
ok = "调度" in rec["prompt_head"] and "🚀" in rec["prompt_head"]
sys.exit(0 if ok else 1)
PY
then
  pass "(u) a unicode prompt round-trips through the log without corruption"
else
  fail "(u) a unicode prompt round-trips through the log without corruption"
fi
rm -rf "$log_proj3"

# ─── (v)-(y) registration ───────────────────────────────────────────────────
assert_py "(v) harness/hooks.json is valid JSON declaring SessionStart, SubagentStart, and PreToolUse" '
import json
data = json.load(open("'"$hooks_json"'"))
hooks = data.get("hooks", {})
ok = "SessionStart" in hooks and "SubagentStart" in hooks and "PreToolUse" in hooks
reason = f"hooks keys={list(hooks.keys())}"
'

assert_py "(w) the PreToolUse entry command references pretooluse_agent_shadow.py" '
import json
data = json.load(open("'"$hooks_json"'"))
entries = data["hooks"]["PreToolUse"]
cmds = [h["command"] for e in entries for h in e.get("hooks", [])]
ok = any("pretooluse_agent_shadow.py" in c for c in cmds)
reason = f"cmds={cmds}"
'

assert_py "(x) the PreToolUse matcher fires on Task and Agent" '
import json, re
data = json.load(open("'"$hooks_json"'"))
matcher = data["hooks"]["PreToolUse"][0]["matcher"]
ok = re.fullmatch(matcher, "Task") is not None and re.fullmatch(matcher, "Agent") is not None
reason = f"matcher={matcher!r}"
'

assert_py "(y) the PreToolUse matcher does NOT fire on SendMessage" '
import json, re
data = json.load(open("'"$hooks_json"'"))
matcher = data["hooks"]["PreToolUse"][0]["matcher"]
ok = re.fullmatch(matcher, "SendMessage") is None and re.search(matcher, "SendMessage") is None
reason = f"matcher={matcher!r}"
'

# code.claude.com/docs/en/hooks (fetched live 2026-08-17): a matcher
# containing only letters, digits, _, -, spaces, "," and "|" is evaluated as
# an EXACT string, or a list of exact strings split on "|"/",", never an
# unanchored substring search — "Edit|Write... match either tool exactly".
# "Task|Agent" is such a matcher (letters and "|" only), so re.fullmatch
# against each alternative is the correct model of the harness's own
# evaluation, not re.search. Five Task-family tools this environment exposes
# (TaskCreate/TaskUpdate/TaskGet/TaskList/TaskStop) would spuriously match
# under a substring reading; under the docs-verified exact-alternation
# reading none of them do — this is the property that reading rules out.
assert_py "(y2) the PreToolUse matcher does NOT fire on any Task-family tool (TaskCreate/TaskUpdate/TaskGet/TaskList/TaskStop)" '
import json, re
data = json.load(open("'"$hooks_json"'"))
matcher = data["hooks"]["PreToolUse"][0]["matcher"]
task_family = ["TaskCreate", "TaskUpdate", "TaskGet", "TaskList", "TaskStop"]
ok = all(re.fullmatch(matcher, name) is None for name in task_family)
reason = f"matcher={matcher!r} matches={[n for n in task_family if re.fullmatch(matcher, n)]}"
'

# ─── (h-all) never a non-zero exit, across every fixture above ─────────────
if [ "$nonzero_exits" -eq 0 ]; then
  pass "(h-all) every full-script invocation across the fixture set exits 0"
else
  fail "(h-all) $nonzero_exits invocation(s) exited non-zero — a PreToolUse hook must never block a dispatch"
fi

# ─── MUTATION 1: prove the never-deny contract can fail ────────────────────
mutant1="$tmp/mutant1_shadow.py"
sed 's/print(json.dumps({}))/print(json.dumps({"hookSpecificOutput": {"permissionDecision": "deny"}} if result["would_deny"] else {}))/' "$hook" > "$mutant1"
run_hook_file "$mutant1" "$stdin_b"
if grep -q "permissionDecision" "$tmp/stdout.json"; then
  pass "(mutation 1) an enforcing regression on the malformed dispatch now surfaces a permissionDecision — (d) can catch this"
else
  fail "(mutation 1) mutant still emits bare {} — assertion (d) cannot discriminate an enforcing regression" "stdout=$(cat "$tmp/stdout.json")"
fi

# ─── MUTATION 2: prove discrimination (l) can fail ──────────────────────────
mutant2="$tmp/mutant2_shadow.py"
sed 's|^ABS_PATH_RE = .*$|ABS_PATH_RE = re.compile(r".*")|' "$hook" > "$mutant2"
python3 - "$mutant2" <<'PY'
import sys, importlib.util
spec = importlib.util.spec_from_file_location("mutant2_shadow", sys.argv[1])
m = importlib.util.module_from_spec(spec)
sys.modules["mutant2_shadow"] = m
spec.loader.exec_module(m)
prompt = "\n".join([
    "branch node/cond-hooks",
    "base commit 2b91739",
    "SANCTION: you are authorized to commit, auto mode",
    "cited sources [S1]",
])  # workspace fragment omitted, same as case (l)'s workspace variant
result = m.evaluate(prompt, "general-purpose")
sys.exit(0 if result["checks"]["workspace_path"] is True else 1)
PY
if [ $? -eq 0 ]; then
  pass "(mutation 2) a broadened ABS_PATH_RE reports workspace_path=true with no path present — case (l) can discriminate this"
else
  fail "(mutation 2) mutant still reports workspace_path=false — case (l) cannot discriminate this defect"
fi

# ─── MUTATION 3: prove seat detection (m) can fail ──────────────────────────
mutant3="$tmp/mutant3_shadow.py"
sed 's/^    return any(marker in low for marker in SEAT_ROLE_MARKERS)$/    return False/' "$hook" > "$mutant3"
python3 - "$mutant3" <<'PY'
import sys, importlib.util
spec = importlib.util.spec_from_file_location("mutant3_shadow", sys.argv[1])
m = importlib.util.module_from_spec(spec)
sys.modules["mutant3_shadow"] = m
spec.loader.exec_module(m)
result = m.evaluate("branch base commit 2b91739 SANCTION authorized auto mode cited sources [S1]", "predicate-architect-seat")
sys.exit(0 if result["checks"]["seat_role"] is False else 1)
PY
if [ $? -eq 0 ]; then
  pass "(mutation 3) a disabled is_seat_dispatch reports seat_role=false for a real seat dispatch — case (m) can discriminate this"
else
  fail "(mutation 3) mutant still detects the seat — case (m) cannot discriminate this defect"
fi

# ─── MUTATION 4: prove logging truncation (t) can fail ──────────────────────
mutant4="$tmp/mutant4_shadow.py"
sed 's/"prompt_head": prompt\[:PROMPT_HEAD_CHARS\],/"prompt_head": prompt,/' "$hook" > "$mutant4"
chmod +x "$mutant4"
log_proj4="$(make_git_repo)"
stdin_mut4="$tmp/stdin_mut4.json"
python3 - "$stdin_mut4" "$log_proj4" <<'PY'
import json, sys
payload = {
    "tool_name": "Task",
    "tool_input": {"prompt": "Q" * 500000, "subagent_type": "general-purpose", "description": "mutant4"},
    "session_id": "sess-mut4",
    "cwd": sys.argv[2],
}
with open(sys.argv[1], "w") as f:
    json.dump(payload, f)
PY
run_hook_file "$mutant4" "$stdin_mut4"
logfile4="$log_proj4/.ledger/state/agent-dispatch-shadow.jsonl"
if [ -f "$logfile4" ] && python3 - "$logfile4" <<'PY'
import json, sys
rec = json.loads(open(sys.argv[1]).read().strip())
sys.exit(0 if len(rec["prompt_head"]) > 150 else 1)
PY
then
  pass "(mutation 4) removing the truncation slice logs the full 500,000-char prompt — case (t) can discriminate this"
else
  fail "(mutation 4) mutant still truncates — case (t) cannot discriminate this defect"
fi
rm -rf "$log_proj4"

# ─── MUTATION 5: prove crash safety (h) can fail ────────────────────────────
mutant5="$tmp/mutant5_shadow.py"
sed 's/except Exception as exc:  # last-resort: this hook must never block a dispatch/except ValueError as exc:  # mutated -- narrowed on purpose/' "$hook" > "$mutant5"
run_hook_file "$mutant5" "$stdin_nonstr"
if [ $? -ne 0 ]; then
  pass "(mutation 5) narrowing the outer except lets a non-string prompt's TypeError escape uncaught — case (h) can discriminate this"
else
  fail "(mutation 5) mutant still exits 0 on a non-string prompt — case (h) cannot discriminate this defect"
fi

# ─── MUTATION 6: prove registration matcher exclusion (y) can fail ─────────
mutant_hooks="$tmp/mutant_hooks.json"
python3 - "$hooks_json" "$mutant_hooks" <<'PY'
import json, sys
data = json.load(open(sys.argv[1]))
data["hooks"]["PreToolUse"][0]["matcher"] = "SendMessage"
json.dump(data, open(sys.argv[2], "w"))
PY
python3 - "$mutant_hooks" <<'PY'
import json, re, sys
data = json.load(open(sys.argv[1]))
matcher = data["hooks"]["PreToolUse"][0]["matcher"]
sys.exit(0 if re.fullmatch(matcher, "SendMessage") is not None else 1)
PY
if [ $? -eq 0 ]; then
  pass "(mutation 6) a widened matcher now fires on SendMessage — case (y) can discriminate this"
else
  fail "(mutation 6) mutant matcher still excludes SendMessage — case (y) cannot discriminate this defect"
fi

# ─── Results ─────────────────────────────────────────────────────────────────
if [ "$fails" -ne 0 ]; then
  echo "FAIL: $fails pretooluse-agent-shadow case(s) mismatched"
  exit 1
fi
echo "PASS: all pretooluse-agent-shadow cases matched"
exit 0
