#!/usr/bin/env bash
# Campaign-ID content gate (the file-content sibling of check_selfcontained.sh).
#
# check_selfcontained.sh keeps campaign-internal tokens (node IDs, finding IDs,
# layer tags) out of COMMIT MESSAGES; this gate keeps them out of the FILES a
# change touches. A shipped repository artifact must read whole to a stranger
# holding only the repository — a doc line or code comment citing a node or
# finding ID references ephemeral planning state (.scratch/.ledger) that never
# ships. Field experience: this leak class recurred across independent nodes
# and review sweeps whenever the check stayed ad hoc, so it is a standing gate
# run at merge review and layer boundaries, not a thing a reviewer remembers.
#
# Usage:
#   check_internal_ids.sh <git-range>            scan files touched in range
#   check_internal_ids.sh --files <f> [<f> ...]  scan the named files
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

files=()
case "${1:-}" in
  "")
    echo "check_internal_ids: need a git range or --files list" >&2
    exit 2
    ;;
  --files)
    shift
    files=("$@")
    ;;
  *)
    range="$1"
    # Deleted files carry nothing forward; skip them (--diff-filter=d).
    while IFS= read -r f; do
      files+=("$f")
    done < <(git -C "$root" diff --name-only --diff-filter=d "$range")
    ;;
esac

[ "${#files[@]}" -eq 0 ] && { echo "check_internal_ids: nothing to scan"; exit 0; }

viol=0
for f in "${files[@]}"; do
  case "$f" in
    .ledger/*|.scratch/*|*/.ledger/*|*/.scratch/*) continue ;;
  esac
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

if [ "$viol" -ne 0 ]; then
  printf '%s\n' \
    '' \
    'INTERNAL-ID LEAK — a shipped file references a campaign-internal token.' \
    '' \
    'Node/finding IDs name ephemeral planning artifacts (.scratch/.ledger) that' \
    'never ship; in a committed file they are dangling labels to every reader' \
    'outside the campaign. Rewrite the reference in repository terms (name the' \
    'file, the behavior, or the commit), or — for a legitimate collision — set' \
    'INTERNAL_ID_PAT in .ledger/config.sh to a narrower pattern and retry.'
  exit 1
fi
exit 0
