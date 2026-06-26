#!/usr/bin/env bash
# Recorder-close gate — deterministic audit that a campaign's CLOSE retrospective
# was actually committed to the flight recorder, and that the retrospective
# contains a "Sufficiency Review" section per the Dual-CLOSE Invariant.
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
# Dual-CLOSE Invariant (docs/orchestration-protocol.md §CLOSE): CLOSE terminates
# only when BOTH (a) the full deterministic gate suite exits green AND (b) a
# decorrelated sufficiency review finds the machinery wired in and sufficient.
# The review verdict is adversarial-path (no machine can decide "is this gate
# sufficient?"); this gate closes the structural half: was the review RECORDED?
# A "## Sufficiency Review" section (reviewers + convergence + verdict) MUST
# appear in at least one file touched by the close commit. Absence → FAIL.
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
# Check 1: a commit whose SUBJECT begins `log: close <topic>` must exist.
# --grep matches against the whole message; anchoring with ^ and restricting the
# format to the subject keeps the match to the subject line. <topic> is escaped so
# regex metacharacters in a topic slug match literally.
# ---------------------------------------------------------------------------
topic_re="$(printf '%s' "$topic" | sed 's/[.[\*^$()+?{|]/\\&/g')"

close_hash=""
match=""

line="$(git -C "$recorder" log --all --grep="^log: close ${topic_re}" \
  --format='%H %s' 2>/dev/null | grep -m1 " log: close ${topic} " || true)"

# Allow the bare `log: close <topic>` subject (no trailing text) too, not only the
# `… retrospective` form, by re-checking without the trailing-space requirement
# when the strict match found nothing.
if [[ -z "$line" ]]; then
  line="$(git -C "$recorder" log --all --grep="^log: close ${topic_re}\$" \
    --format='%H %s' 2>/dev/null | head -n1 || true)"
fi

if [[ -n "$line" ]]; then
  close_hash="${line%% *}"
  match="${line#* }"
fi

if [[ -z "$match" ]]; then
  echo "FAIL  recorder-close: recorder has no 'log: close $topic' entry —" \
    "the CLOSE retrospective was not recorded" >&2
  echo "      Recorder: $recorder" >&2
  echo "      CLOSE must not complete without committing the durable narrative to the" >&2
  echo "      flight recorder (a 'log: close $topic …' commit). Record it, then re-run." >&2
  exit 1
fi

echo "      recorder-close: '$topic' has a CLOSE entry in the recorder"
echo "      $match"

# ---------------------------------------------------------------------------
# Check 2 (Dual-CLOSE Invariant): the retrospective MUST contain a
# "## Sufficiency Review" section with NON-EMPTY substantive content.
#
# The review verdict is adversarial-path — no machine can decide whether the
# gate machinery is sufficient. This gate closes the structural half: was the
# review RECORDED, and does the record carry content? We inspect every file
# touched by the close commit for a Markdown heading that begins "Sufficiency
# Review" (any level: #, ##, ###) followed by at least one non-blank,
# non-heading line before EOF or the next heading. A hollow heading (the
# section exists but has nothing beneath it) fails this floor — an
# orchestrator under execution momentum could write a bare heading and pass
# the old presence-only check; this closes that gap.
#
# Presence + a non-empty floor is the structural check; quality — genuine
# reviewers, real convergence, honest findings — is the adversarial
# reviewer's responsibility, not this gate's.
# ---------------------------------------------------------------------------
sufficiency_found=0
while IFS= read -r fname; do
  [[ -z "$fname" ]] && continue
  content="$(git -C "$recorder" show "${close_hash}:${fname}" 2>/dev/null || true)"

  # Quick filter: skip files that don't even have the heading.
  if ! printf '%s\n' "$content" | grep -qiE '^#+[[:space:]]+Sufficiency Review'; then
    continue
  fi

  # Heading is present — verify at least one non-blank, non-heading line
  # follows it before EOF or the next heading. awk reads the file in order:
  # entering the section on the matching heading, stopping at the next
  # heading (any level), and recording success when a non-blank line appears.
  if printf '%s\n' "$content" | awk '
    /^#+[[:space:]]/ {
      if (in_section) { exit }
      if (tolower($0) ~ /^#+[[:space:]]+sufficiency review/) { in_section = 1 }
      next
    }
    in_section && /[^[:space:]]/ { found = 1; exit }
    END { exit (found ? 0 : 1) }
  '; then
    sufficiency_found=1
    break
  fi
done < <(git -C "$recorder" show --name-only --format='' "$close_hash" 2>/dev/null)

if [[ "$sufficiency_found" -eq 0 ]]; then
  echo "FAIL  recorder-close: '$topic' close record has no non-empty 'Sufficiency Review' section —" >&2
  echo "      CLOSE requires a decorrelated adversarial review of machinery sufficiency" >&2
  echo "      (Dual-CLOSE Invariant, docs/orchestration-protocol.md §CLOSE), not only" >&2
  echo "      that gate checks pass. The retrospective must contain a '## Sufficiency" >&2
  echo "      Review' section with substantive content (at least one non-blank," >&2
  echo "      non-heading line beneath the heading). A hollow heading — section" >&2
  echo "      present but empty — does not satisfy the structural floor." >&2
  echo "      Add the review content and re-run." >&2
  exit 1
fi

echo "PASS  recorder-close: '$topic' retrospective includes a non-empty Sufficiency Review section"
exit 0
