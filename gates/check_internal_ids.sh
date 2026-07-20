#!/usr/bin/env bash
# Campaign-ID content gate (the file-content sibling of check_selfcontained.sh).
#
# check_selfcontained.sh keeps campaign-internal tokens (node IDs, finding IDs,
# layer tags) out of COMMIT MESSAGES; this gate keeps them out of shipped file
# content. A shipped repository artifact must read whole to a stranger holding
# only the repository — a doc line or code comment citing a node or finding ID
# references ephemeral planning state (.scratch/.ledger) that never ships.
# Field experience: this leak class recurred across independent nodes and
# review sweeps whenever the check stayed ad hoc, so it is a standing gate run
# at merge review and layer boundaries, not a thing a reviewer remembers.
#
# Two modes with deliberately different scan surfaces:
#
#   check_internal_ids.sh <git-range>            scan the lines the range ADDS
#   check_internal_ids.sh --files <f> [<f> ...]  scan the named files in full
#
# Range mode scans ADDED LINES ONLY. A change is accountable for the tokens it
# introduces, not for prior debt (or deliberate ID-shaped fixture inputs and
# pedagogy) elsewhere in a file it happens to touch — full-content scanning
# made the gate permanently red on high-traffic files, and an always-red gate
# trains every operator to ignore it, destroying its entire value. Full-file
# scanning remains the right surface for --files, whose use case is wholly-new
# content: forge prose drafts and single-file audits.
#
# The token grammar is intentionally broad (bare node/finding-shaped tokens);
# a legitimate collision (a severity label, a CPU cache tier) is narrowed
# per-project via INTERNAL_ID_PAT in .ledger/config.sh — the same override
# mechanism as, but a distinct grammar from, check_selfcontained.sh's
# commit-message pattern (file contents and commit messages leak different
# forms). Paths under .ledger/ and .scratch/ are exempt — they ARE the
# internal record. Exit: 0 clean, 1 leak(s) found, 2 usage error.
set -u

root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
# shellcheck source=/dev/null
[ -f "$root/.ledger/config.sh" ] && source "$root/.ledger/config.sh"
# Bare node/premise/finding/constraint tokens — the single-letter-plus-digits
# ID classes predicate campaigns actually use in DAGs, IBCs, and findings
# ledgers — plus the compound acceptance-criterion form observed in past
# campaign artifacts. Projects override via INTERNAL_ID_PAT.
: "${INTERNAL_ID_PAT:=\b[NPFC][1-9][0-9]*\b|\bAC-[A-Z]*[0-9]+\b}"
pat="$INTERNAL_ID_PAT"

# skip_path <file> — the internal-record trees are exempt by design.
skip_path() {
  case "$1" in
    .ledger/*|.scratch/*|*/.ledger/*|*/.scratch/*) return 0 ;;
  esac
  return 1
}

viol=0
case "${1:-}" in
  "")
    echo "check_internal_ids: need a git range or --files list" >&2
    exit 2
    ;;
  --files)
    shift
    [ "$#" -eq 0 ] && { echo "check_internal_ids: nothing to scan"; exit 0; }
    for f in "$@"; do
      skip_path "$f" && continue
      case "$f" in
        /*) abs="$f" ;;
        *)  abs="$root/$f" ;;
      esac
      if [ ! -f "$abs" ]; then
        echo "check_internal_ids: skipping missing file: $f" >&2
        continue
      fi
      # -I skips binaries; grep exits 1 on no match, which is the clean case.
      hits="$(grep -nHIE "$pat" -- "$abs" || true)"
      if [ -n "$hits" ]; then
        printf '%s\n' "$hits" | sed "s|^$root/||"
        viol=1
      fi
    done
    ;;
  *)
    range="$1"
    # Deleted files carry nothing forward; skip them (--diff-filter=d). For
    # each remaining file, extract the range's ADDED lines with their new-file
    # line numbers (awk walks the -U0 hunk headers), then match the grammar.
    # awk only extracts — the ERE (with \b) is matched by grep, which supports
    # it portably where awk's dynamic regex does not.
    while IFS= read -r f; do
      skip_path "$f" && continue
      added="$(git -C "$root" diff -U0 "$range" -- "$f" | awk '
        /^@@/  { split($0, a, "+"); split(a[2], b, /[ ,]/); n = b[1]; next }
        /^\+\+\+/ { next }
        /^\+/  { printf "%d:%s\n", n, substr($0, 2); n++ }
      ')"
      [ -n "$added" ] || continue
      hits="$(printf '%s\n' "$added" | grep -E "$pat" || true)"
      if [ -n "$hits" ]; then
        printf '%s\n' "$hits" | sed "s|^|$f:|"
        viol=1
      fi
    done < <(git -C "$root" diff --name-only --diff-filter=d "$range")
    ;;
esac

if [ "$viol" -ne 0 ]; then
  printf '%s\n' \
    '' \
    'INTERNAL-ID LEAK — this change adds a campaign-internal token to a' \
    'shipped file.' \
    '' \
    'Node/finding IDs name ephemeral planning artifacts (.scratch/.ledger) that' \
    'never ship; in a committed file they are dangling labels to every reader' \
    'outside the campaign. Rewrite the reference in repository terms (name the' \
    'file, the behavior, or the commit), or — for a legitimate collision — set' \
    'INTERNAL_ID_PAT in .ledger/config.sh to a narrower pattern and retry.'
  exit 1
fi
exit 0
