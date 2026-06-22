#!/usr/bin/env bash
# Recorder-close gate — deterministic audit that a campaign's CLOSE retrospective
# was actually committed to the flight recorder.
#
# This gate exists because the durable narrative of a campaign is supposed to land
# in the flight recorder (the .ledger subrepo, on the recorder's branch) at CLOSE,
# as a commit subject-tagged `log: close <topic> …`. That discipline had no machine
# check: an orchestrator under execution momentum can drop it, and nothing catches
# it — only the human did. The Verification Dual's "externalize the check" principle
# says a discipline an agent can rationalize away must be closed by a machine check
# it does not control. A CLOSE that ran without recording the retrospective is
# indistinguishable by its OUTPUT from one that recorded it; it is distinguishable
# by the recorder's HISTORY. This gate reads that history — the sibling of
# adherence_audit.sh, which audits isolation from the integration branch's history.
#
# Usage:
#   recorder_close_check.sh <topic> [recorder-dir]
#
#   <topic>        the campaign topic whose CLOSE retrospective must be recorded.
#   recorder-dir   the flight-recorder git repo to read (default: the MAIN tree's
#                  .ledger). A worktree has no .ledger of its own — it lives only
#                  in the main tree — so the default resolves the main tree via the
#                  COMMON git dir's parent, the same way hooks/pre-commit does.
#
# It PASSES (rc 0) iff the recorder's git history contains a commit whose subject
# matches `^log: close <topic>` (the convention the sketch close discipline writes).
# It FAILS (rc 1) with a diagnostic if no such close entry exists.
# Usage error (rc 2) if <topic> is empty or the recorder dir is not a git repo.
#
# Exit codes: 0 (PASS) / 1 (FAIL — close retrospective absent) / 2 (usage error)

set -uo pipefail

# ---------------------------------------------------------------------------
# Arguments
# ---------------------------------------------------------------------------
topic="${1:-}"

if [[ -z "$topic" ]]; then
  echo "usage: recorder_close_check.sh <topic> [recorder-dir]" >&2
  echo "recorder_close_check: <topic> is empty — cannot check for a CLOSE entry without it" >&2
  exit 2
fi

# Default the recorder to the MAIN tree's .ledger. The main tree is the parent of
# the common git dir (a linked worktree's common dir points at the main repo's
# .git), matching hooks/pre-commit's resolution; in the self-host case it is the
# work tree's own .ledger. If $2 is given, it overrides this entirely.
recorder="${2:-}"
if [[ -z "$recorder" ]]; then
  main_tree="$(cd "$(dirname "$(git rev-parse --git-common-dir)")" 2>/dev/null && pwd || true)"
  if [[ -z "$main_tree" ]]; then
    echo "recorder_close_check: cannot locate the main tree (not in a git repo?)" >&2
    echo "      Pass the recorder dir explicitly: recorder_close_check.sh <topic> <recorder-dir>" >&2
    exit 2
  fi
  recorder="$main_tree/.ledger"
fi

# The recorder must be a git repo — the gate reads its history.
if ! git -C "$recorder" rev-parse --git-dir >/dev/null 2>&1; then
  echo "recorder_close_check: recorder dir is not a git repo: $recorder" >&2
  exit 2
fi

# ---------------------------------------------------------------------------
# The check: a commit whose SUBJECT begins `log: close <topic>` must exist.
# --grep matches against the whole message; anchoring with ^ and restricting the
# format to the subject keeps the match to the subject line. <topic> is escaped so
# regex metacharacters in a topic slug match literally.
# ---------------------------------------------------------------------------
topic_re="$(printf '%s' "$topic" | sed 's/[.[\*^$()+?{|]/\\&/g')"

match="$(git -C "$recorder" log --all --grep="^log: close ${topic_re}" \
  --format='%s' 2>/dev/null | grep -m1 "^log: close ${topic} " || true)"

# Allow the bare `log: close <topic>` subject (no trailing text) too, not only the
# `… retrospective` form, by re-checking without the trailing-space requirement
# when the strict match found nothing.
if [[ -z "$match" ]]; then
  match="$(git -C "$recorder" log --all --grep="^log: close ${topic_re}\$" \
    --format='%s' 2>/dev/null | head -n1 || true)"
fi

if [[ -n "$match" ]]; then
  echo "PASS  recorder-close: '$topic' has a CLOSE retrospective in the recorder"
  echo "      $match"
  exit 0
fi

echo "FAIL  recorder-close: recorder has no 'log: close $topic' entry —" \
  "the CLOSE retrospective was not recorded" >&2
echo "      Recorder: $recorder" >&2
echo "      CLOSE must not complete without committing the durable narrative to the" >&2
echo "      flight recorder (a 'log: close $topic …' commit). Record it, then re-run." >&2
exit 1
