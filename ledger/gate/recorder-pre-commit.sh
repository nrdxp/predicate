#!/usr/bin/env bash
# recorder-pre-commit.sh — the .ledger subrepo's OWN commit-time gate.
#
# .ledger/ is a fully separate git repository (ledger/README.md: "its OWN
# sub-repository, never part of the project repo") and is gitignored from the
# project tree. That means the project's hooks/pre-commit — which validates
# staged *.ncl artifacts against their Nickel contracts (tier 3, LEDGER
# STRUCTURE) — never sees a commit made INSIDE .ledger: it only fires on
# commits to the project repo. Every record class ships a Nickel contract
# (skills/record/tech_debt.ncl, skills/record/process_feedback.ncl), but until
# this hook existed nothing ever invoked those contracts at commit time — a
# record missing a required field could land in .ledger cleanly, and only a
# hand-run `nickel export --apply-contract` would catch it.
#
# Installed as a symlink at <ledger>/.git/hooks/pre-commit by
# ledger/gate/install-recorder-hook.sh (composed from bootstrap/install.sh
# init, never inlined — the same COMPOSED-not-inlined principle
# hooks/install-hooks.sh already follows for the project's own hooks).
#
# Routing — THREE classes, by staged path prefix:
#   tech-debt/*.yaml          -> skills/record/tech_debt_apply.ncl   (per-record)
#   process-feedback/*.yaml   -> skills/record/process_feedback_apply.ncl (per-record)
#   log/*.md                  -> whole-corpus validation (see below)
#
# A deposits/testimony namespace is named in doctrine that is drafted and
# awaiting the head's ratification (see
# .ledger/tech-debt/gate-paths-predate-namespace.yaml) — routing a gate
# against a path that can still change would repeat that exact recorded
# mistake, so it is deliberately NOT wired here. A staged file outside the
# three live namespaces (state/, config.sh[.example], ...) is not a
# record this gate knows about and is skipped.
#
# log/ cannot be validated per-record like the other two classes: entry ids
# are document-qualified and refs cross namespaces (a log/ entry can
# reference directions.md; a tech-debt discharge can name a log/ entry), so
# validating a staged file — or even the whole log/ directory — in
# isolation produces spurious dangling-edge findings for refs that resolve
# fine against the full corpus. The only sound scope is the WHOLE .ledger
# corpus, so a staged log/*.md file instead runs
# ledger/gate/entries_integrity.sh (extract + apply-contract, already built
# and tested for exactly this) over the entire recorder root — reused
# rather than re-implemented, per ledger/README.md's own bar: "a runner
# must never re-implement an invariant".
#
# nickel MUST be on PATH to validate a staged record; python3 MUST be on
# PATH to validate a staged log/ entry (entries_integrity.sh's own
# extractor). If either tool is absent while its class is staged, the gate
# fails LOUDLY (exit 2) rather than silently passing — "a gate that no-ops
# when its tool is missing" is a defect class this repository has hit
# repeatedly (see ledger/README.md's portability note and td-import-dos). A
# commit that stages neither a record nor a log/ entry incurs zero
# overhead: neither tool is ever invoked and their absence never blocks
# unrelated state commits.
#
# --- The unattributed-designation ceiling ----------------------------------
#
# `SignerKind` (ledger/contracts/entry.ncl) admits `unattributed` — no party
# is recoverable, stated for a record that predates a recorder's signing
# regime. The architect's ruling on that addition was explicit: the abuse
# guard is POLICY, not shape — no regime-boundary metadata belongs on the
# Signer contract itself, because a flag excusing the signer field would make
# designation-totality conditional again. So the guard lives here, at the
# commit gate, as a plain count: whenever a tech-debt/ or process-feedback/
# record is staged, count every record across BOTH namespaces (not just what
# is staged — the ceiling bounds the recorder's whole history) that
# designates `unattributed`, and block if it exceeds UNATTRIBUTED_CEILING.
#
# The default here is 0: a fresh recorder adopts signing from its first
# record, so by default NO record may claim "predates the signing regime".
# `unattributed` only has inhabitants where a recorder did a real one-time
# legacy migration, and that is a PER-RECORDER fact — never a plugin-wide
# one, since this script is shared machinery symlinked into every consuming
# project's .ledger/. A recorder that has done that migration grandfathers
# its frozen count via UNATTRIBUTED_CEILING in its own .ledger/config.sh
# (see config.sh.example), the established override surface for exactly
# this class of per-recorder policy constant (SELFCONTAINED_PAT,
# ORPHAN_TARGETS, ...). The ceiling may only be LOWERED from there, never
# raised — falling is legitimate (a record gets superseded), and a rising
# ceiling converts the guard into a rubber stamp for the next agent who
# reaches for `unattributed` rather than naming a real signer.
#
# Exit: 0 = every staged record validated against its contract, the
#           unattributed count is at or under the ceiling, and (if a log/
#           entry was staged) the whole corpus validates — or nothing in
#           any of the three classes was staged — true no-op
#       1 = a staged record failed its contract, the unattributed ceiling
#           was exceeded, or the whole-corpus validation failed
#       2 = a record is staged but nickel is not on PATH, a log/ entry is
#           staged but nickel or python3 is not on PATH (or
#           entries_integrity.sh's own environment checks fail), or an
#           existing record file could not be read while counting
set -u

# $plugin = predicate's own machinery, resolved from THIS script's own real
# path — the installed hook is a SYMLINK from <ledger>/.git/hooks/pre-commit
# back here, so realpath is required to land in the real plugin tree rather
# than the ledger being gated. Two levels up: ledger/gate/ -> ledger/ -> plugin root.
plugin="$(cd "$(dirname "$(realpath "${BASH_SOURCE[0]}")")/../.." && pwd)"
# $root = the recorder repo being gated (a .ledger subrepo). Git runs
# commit-time hooks with cwd at the working tree root, so this resolves
# correctly with no explicit argument.
root="$(git rev-parse --show-toplevel)"

# Staged files (added/copied/modified), repo-root-relative to $root — the
# same coordinate space `git diff --cached --name-only` always emits.
mapfile -t staged < <(git diff --cached --name-only --diff-filter=ACMR)

# Route each staged path to its class; anything outside the three record
# namespaces is not this gate's concern.
records=()
contracts=()
log_staged=()
for f in "${staged[@]}"; do
  case "$f" in
    tech-debt/*.yaml)
      records+=("$f"); contracts+=("$plugin/skills/record/tech_debt_apply.ncl") ;;
    process-feedback/*.yaml)
      records+=("$f"); contracts+=("$plugin/skills/record/process_feedback_apply.ncl") ;;
    log/*.md)
      log_staged+=("$f") ;;
  esac
done

# Nothing to validate — true no-op, neither tool ever invoked.
[ "${#records[@]}" -eq 0 ] && [ "${#log_staged[@]}" -eq 0 ] && exit 0

if ! command -v nickel >/dev/null 2>&1; then
  echo "recorder-pre-commit: 'nickel' not on PATH — cannot validate staged record(s):" >&2
  printf '  %s\n' "${records[@]}" "${log_staged[@]}" >&2
  echo "  Enter the project shell (nix-shell / nix develop) to get nickel 1.14.0, then retry." >&2
  echo "  (A gate that cannot run its check is not a gate that passes — commit blocked.)" >&2
  exit 2
fi

rc=0
for i in "${!records[@]}"; do
  f="${records[$i]}"
  contract="${contracts[$i]}"
  out="$(nickel export "$root/$f" --apply-contract "$contract" 2>&1)"
  status=$?
  if [ "$status" -ne 0 ]; then
    echo "recorder-pre-commit: RECORD FAILED its contract: $f" >&2
    echo "  contract: $(basename "$contract")" >&2
    printf '%s\n' "$out" | sed 's/^/  /' >&2
    rc=1
  fi
done

# --- Whole-corpus validation (log/) -----------------------------------------
#
# See the header comment for why this cannot be scoped to the staged
# file(s) or to log/ alone: refs are document-qualified and cross
# namespaces, so only the whole .ledger corpus is a sound validation scope.
# entries_integrity.sh already does exactly this (extract + apply-contract,
# tested at ledger/gate/test_entries_integrity.sh) — invoked here rather
# than re-implemented.
if [ "${#log_staged[@]}" -gt 0 ]; then
  out="$("$plugin/ledger/gate/entries_integrity.sh" "$root" 2>&1)"
  status=$?
  if [ "$status" -eq 2 ]; then
    echo "recorder-pre-commit: whole-corpus record validation could not run:" >&2
    printf '%s\n' "$out" | sed 's/^/  /' >&2
    exit 2
  elif [ "$status" -ne 0 ]; then
    echo "recorder-pre-commit: WHOLE-CORPUS RECORD VALIDATION FAILED (staged: ${log_staged[*]}):" >&2
    printf '%s\n' "$out" | sed 's/^/  /' >&2
    rc=1
  fi
fi

# Per-recorder override surface (config.sh.example documents this and every
# other overridable constant). Absent config.sh, the conservative default (0)
# applies — see the header comment for why 0, not some inherited number.
UNATTRIBUTED_CEILING="${UNATTRIBUTED_CEILING:-0}"
[ -f "$root/config.sh" ] && . "$root/config.sh"

# Sums SignerKind == 'unattributed' across every tracked record file in BOTH
# namespaces, not just what this commit stages — the ceiling bounds the
# recorder's whole history. Reads from disk ($root/...), the same
# working-tree-trusts-index simplification the per-record loop above already
# makes. nickel's JSON export pretty-prints one field per line, so a plain
# line-count of `"kind": "unattributed"` is exact — that literal string is
# only ever a SignerKind value (ledger/contracts/entry.ncl); a
# process-feedback record's own top-level `kind` field draws from a disjoint
# vocabulary (improvement, miss, ...) and cannot collide.
count_unattributed() {
  local total=0 f out status
  shopt -s nullglob
  for f in "$root"/tech-debt/*.yaml "$root"/process-feedback/*.yaml; do
    out="$(nickel export "$f" --format json 2>&1)"
    status=$?
    if [ "$status" -ne 0 ]; then
      echo "recorder-pre-commit: could not read $f while counting unattributed designations:" >&2
      printf '%s\n' "$out" | sed 's/^/  /' >&2
      shopt -u nullglob
      return 2
    fi
    total=$(( total + $(printf '%s\n' "$out" | grep -c '"kind": "unattributed"') ))
  done
  shopt -u nullglob
  printf '%d' "$total"
}

# Only runs when a record file is staged (mirrors the true-no-op above): a
# commit that never touches tech-debt/ or process-feedback/ cannot have
# changed the count since the last commit, which already passed this gate.
if [ "${#records[@]}" -gt 0 ]; then
  unattributed_count="$(count_unattributed)"
  count_status=$?
  if [ "$count_status" -ne 0 ]; then
    rc=1
  elif [ "$unattributed_count" -gt "$UNATTRIBUTED_CEILING" ]; then
    echo "recorder-pre-commit: unattributed-designation ceiling exceeded ($unattributed_count > $UNATTRIBUTED_CEILING) — commit blocked." >&2
    echo "  'unattributed' designates a record predating this recorder's signing regime." >&2
    echo "  The ceiling is frozen at the count fixed by that one-time migration and may" >&2
    echo "  only fall (as records are superseded), never grow. A new record claiming" >&2
    echo "  'unattributed' is not a migration — name its real signer instead" >&2
    echo "  (human|agent|source|derived)." >&2
    rc=1
  fi
fi

if [ "$rc" -ne 0 ]; then
  echo "recorder-pre-commit: staged record gate failed — commit blocked." >&2
  # A refused COMMIT does not refuse the STAGING that preceded it: `git add`
  # already succeeded, so the index stays dirty after this hook exits
  # non-zero. Left alone, that is a trap — a later unrelated `git add` (or
  # `git commit -a`) sweeps the still-staged file into an unrelated commit
  # under a message describing only the other change
  # (.ledger/process-feedback/pc-blocked-commit-leaves-index.yaml recorded
  # this happening for real). Unstage exactly what THIS run examined and
  # refused — restoring the index to what it found — never anything else
  # already staged. `git reset` only moves the index pointer; the working
  # tree (the author's edits) is untouched, so nothing is lost, only
  # unstaged for re-add once the underlying issue is fixed.
  if [ "${#records[@]}" -gt 0 ] || [ "${#log_staged[@]}" -gt 0 ]; then
    if git -C "$root" reset -q -- "${records[@]}" "${log_staged[@]}" 2>/dev/null; then
      echo "recorder-pre-commit: unstaged the refused file(s) — fix and re-add." >&2
    fi
  fi
fi
exit "$rc"
