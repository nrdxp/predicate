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
# Routing — TWO classes only, by staged path prefix:
#   tech-debt/*.yaml          -> skills/record/tech_debt_apply.ncl
#   process-feedback/*.yaml   -> skills/record/process_feedback_apply.ncl
#
# A deposits/testimony namespace is named in doctrine that is drafted and
# awaiting the head's ratification (see
# .ledger/tech-debt/gate-paths-predate-namespace.yaml) — routing a gate
# against a path that can still change would repeat that exact recorded
# mistake, so it is deliberately NOT wired here. A staged file outside the
# two live namespaces (log/, state/, config.sh[.example], ...) is not a
# record this gate knows about and is skipped.
#
# nickel MUST be on PATH to validate a staged record. If a record is staged
# and nickel is absent, the gate fails LOUDLY (exit 2) rather than silently
# passing — "a gate that no-ops when its tool is missing" is a defect class
# this repository has hit repeatedly (see ledger/README.md's portability
# note and td-import-dos). A commit that stages NO record incurs zero
# overhead: nickel is never invoked and its absence never blocks unrelated
# flight-log or state commits.
#
# Exit: 0 = every staged record validated against its contract (or none
#           staged — true no-op)
#       1 = a staged record failed its contract
#       2 = a record is staged but nickel is not on PATH
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

# Route each staged path to its class contract; anything outside the two
# record namespaces is not this gate's concern.
records=()
contracts=()
for f in "${staged[@]}"; do
  case "$f" in
    tech-debt/*.yaml)
      records+=("$f"); contracts+=("$plugin/skills/record/tech_debt_apply.ncl") ;;
    process-feedback/*.yaml)
      records+=("$f"); contracts+=("$plugin/skills/record/process_feedback_apply.ncl") ;;
  esac
done

# Nothing to validate — true no-op, nickel never invoked.
[ "${#records[@]}" -eq 0 ] && exit 0

if ! command -v nickel >/dev/null 2>&1; then
  echo "recorder-pre-commit: 'nickel' not on PATH — cannot validate staged record(s):" >&2
  printf '  %s\n' "${records[@]}" >&2
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

if [ "$rc" -ne 0 ]; then
  echo "recorder-pre-commit: staged record gate failed — commit blocked." >&2
fi
exit "$rc"
