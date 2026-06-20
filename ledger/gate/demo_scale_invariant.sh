#!/usr/bin/env bash
# Demonstration: a direct /core task passes the same gates as a DAG node.
#
# The companion to gate-set.sh. Where that proves the superset relation over the
# gate-set *data*, this runs the gates and shows the transcripts coincide — the
# property is re-run, not claimed. The boundary gate a node passes (rules.md §3)
# and the boundary gate a /core task passes are the *same command set*; a /core
# task is a degenerate one-node DAG, so the only difference between the two paths
# is which DAG authorizes the change, never which gates fire.
#
# Method:
#   1. Build a degenerate one-node DAG — the /core task's DAG — in a temp file.
#   2. Stage one authorized change under a surface both DAGs cover.
#   3. Run the identical commit-gate sequence (commit-msg hygiene, ledger
#      structure, ledger authority) under the campaign DAG and under the
#      one-node DAG, recording each gate's identifier and exit code.
#   4. Assert the two transcripts are byte-identical.
#
# Run from the repo root. Exit 0 iff the node transcript and the /core
# transcript match (the gates a /core task passes == the gates a node passes);
# exit 1 if they diverge.
set -euo pipefail

root="$(git rev-parse --show-toplevel)"
cd "$root"
here="ledger/gate"
gate="$here/ledger-validate.sh"
hygiene="skills/commit-hygiene/scripts/check_commit_msg.py"
campaign_dag="ledger/fixtures/dag_valid.ncl"

# A representative, hygienic commit message — both paths validate the same one,
# since message hygiene is DAG-independent but part of every boundary transcript.
msg="test(ledger): demonstrate scale-invariant gate set

Both a direct task and a campaign node pass this identical gate, so the
boundary transcript is the same at both scales."

work="$(mktemp -d)"
onenode="$work/onenode.ncl"
node_log="$work/node.transcript"
core_log="$work/core.transcript"

cleanup() {
  git restore --staged "$staged" 2>/dev/null \
    || git reset -q HEAD "$staged" 2>/dev/null || true
  rm -f "$staged"
  rmdir "$(dirname "$staged")" 2>/dev/null || true
  rm -rf "$work"
}

# Degenerate one-node DAG: the /core task as a campaign of one. Its file_surface
# covers the same staged change the campaign DAG covers, so authority passes on
# both paths. The contracts import resolves against an absolute path so the temp
# file is location-independent.
contracts_abs="$(cd ledger/contracts && pwd)"
cat >"$onenode" <<NCL
let c = import "$contracts_abs/dag.ncl" in
(
  (
    {
      nodes = [
        {
          id = "T1",
          depends_on = [],
          file_surface = ["ledger/gate/"],
          discipline = 'core,
          mitigates = [],
        },
      ]
    } | c.Dag
  ) | c.DagNoConflict
)
NCL

# One authorized staged change, under a surface both DAGs cover (ledger/gate/).
staged="ledger/gate/.demo_scale_invariant_$$_$RANDOM"
echo "scale-invariance demonstration fixture" >"$staged"
git add "$staged"
trap cleanup EXIT

# Record one gate's identifier and pass/fail (not its stdout — only the gate
# id and outcome are the transcript, so the two paths are comparable). The
# identifiers match the tokens in gate-sets/node.txt.
record() {
  local logfile="$1" id="$2" rc="$3"
  if [[ "$rc" -eq 0 ]]; then
    echo "$id PASS" >>"$logfile"
  else
    echo "$id FAIL" >>"$logfile"
  fi
}

# Run the boundary gate transcript for one DAG. Identical command sequence for
# both the node path and the /core path — only $dag differs.
run_transcript() {
  local dag="$1" logfile="$2"
  : >"$logfile"

  local rc=0
  python3 "$hygiene" --message "$msg" >/dev/null 2>&1 || rc=$?
  record "$logfile" commit-msg-hygiene "$rc"

  rc=0
  "$gate" structure "$dag" >/dev/null 2>&1 || rc=$?
  record "$logfile" ledger-structure "$rc"

  rc=0
  "$gate" authorize "$dag" >/dev/null 2>&1 || rc=$?
  record "$logfile" ledger-authority "$rc"
}

run_transcript "$campaign_dag" "$node_log"
run_transcript "$onenode"      "$core_log"

echo "--- node (campaign DAG) gate transcript ---"
cat "$node_log"
echo "--- /core (one-node DAG) gate transcript ---"
cat "$core_log"

if diff -u "$node_log" "$core_log" >/dev/null; then
  echo "DEMO PASS: /core task passes the same gates as a campaign node."
  exit 0
fi
echo "DEMO FAIL: gate transcripts diverge (see diff below):" >&2
diff -u "$node_log" "$core_log" >&2 || true
exit 1
