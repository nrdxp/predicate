#!/usr/bin/env bash
# Bidirectional coherence-impact evaluator (the explicit per-landing RECONCILE
# step). RECONCILE judges a landing two ways at the boundary:
#
#   backward  does this landing break ALREADY-LANDED artifacts? (e.g. a cut
#             leaves a now-dangling reference in a surviving file)
#   forward   does this landing invalidate PENDING artifacts? (handled by the
#             premise-freshness pass; this gate covers what freshness cannot:
#             structural breakage across the whole tree)
#
# Routing follows the Verification Dual: re-run every machine-check that an
# evaluator exists for over the affected surface (the symbolic path); for any
# concern no evaluator covers, emit an explicit decorrelated-review DISPATCH
# directive (the adversarial path). The dispatch is deterministic even though
# the dispatched review returns a soft verdict — which is what keeps the
# PROTOCOL machine-executable. Catching breakage here, at the boundary, is the
# fix for drift that otherwise surfaces only at CLOSE.
#
# Machine-checks run (each only when its evaluator and inputs are present):
#   contract   nickel export of every ledger artifact still exits 0
#   orphans    no surviving file references a removed workflow as if live
#   links      markdown link syntax still resolves
#
# Tracking the adversarial path (T1.4 — the Dual's soft path is not open-looped).
# Concerns no machine-check can close emit a DISPATCH directive; left as bare
# stdout those reviews were UNTRACKED — nothing recorded whether the dispatched
# review ever happened or converged before the orchestrator ACCEPTed the landing,
# so the Dual's own escape hatch was unenforced. Now each DISPATCH is a TRACKED
# obligation: when `--dispatch-log <file>` is given, every dispatched concern is
# appended as a `pending` record (`<concern>\tpending`). The orchestrator MUST
# resolve each to `converged`/`diverged` (mirroring reconcile_log.ncl's "accept
# names an evaluator, not a claim") before merge; a `pending` row gates ACCEPT.
# The script's own exit code stays the MACHINE-surface verdict (0 = all machine-
# checks passed) — the adversarial obligations are tracked out-of-band in the
# log, not folded into this exit code — so a clean machine surface with reviews
# still pending is honestly reported, not silently passed.
#
# Usage:
#   coherence_impact.sh <repo-root> [--removed <workflow> ...] [--dispatch-log <file>]
# Output: per-check PASS/FAIL, a DISPATCH line per uncovered concern, a tracked
#         count of pending adversarial reviews, verdict.
# Exit:   0 = all machine-checks passed (any adversarial-review dispatches are
#         recorded as PENDING obligations and gate ACCEPT until resolved), 1 = a
#         machine-check failed (breakage caught at the boundary), 2 = usage /
#         environment error.
set -u

root="${1:-}"
if [ -z "$root" ] || [ ! -d "$root" ]; then
  echo "usage: coherence_impact.sh <repo-root> [--removed <workflow> ...]" >&2
  exit 2
fi
shift
removed=()
dispatch_log=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    --removed) shift; removed+=("$1") ;;
    --dispatch-log) shift; dispatch_log="$1" ;;
    *) echo "coherence_impact: unknown arg: $1" >&2; exit 2 ;;
  esac
  shift || true
done

# $plugin = where predicate's MACHINERY lives, resolved from THIS script's own
# real path (this file is <plugin>/ledger/gate/coherence_impact.sh, so $plugin
# is two dirs up). The sibling gates this evaluator INVOKES — ledger-validate.sh,
# check_orphans.sh, check_docs.py — are located relative to $plugin, never to the
# $root it SCANS. In the self-host case ($plugin == $root) both coincide.
plugin="$(cd "$(dirname "$(realpath "${BASH_SOURCE[0]}")")/../.." && pwd)"

fails=0
gate="$plugin/ledger/gate"
gates="$plugin/gates"

# Adversarial-path tracking (T1.4). Every dispatched decorrelated review is a
# PENDING obligation, not a fire-and-forget echo: collect them, and when a
# --dispatch-log is given, append each as a `<concern>\tpending` record the
# orchestrator must resolve before ACCEPT. dispatch <concern> <human-message>.
pending_dispatches=0
# Truncate any stale log so a re-run records THIS landing's obligations, not a
# prior round's. Created only if a path was given (env error -> exit 2).
if [ -n "$dispatch_log" ]; then
  : > "$dispatch_log" || { echo "coherence_impact: cannot write dispatch-log: $dispatch_log" >&2; exit 2; }
fi
dispatch() { # concern-id  human-readable-message
  local concern="$1" msg="$2"
  echo "DISPATCH  $msg -> decorrelated review (tracked: PENDING)"
  pending_dispatches=$((pending_dispatches + 1))
  [ -n "$dispatch_log" ] && printf '%s\tpending\n' "$concern" >> "$dispatch_log"
}

# Load project config if present; a downstream repo can override LINK_TARGETS
# (bash array) to match its own authoritative surface layout.
# Absent config → predicate defaults (mirrors check_orphans' ORPHAN_TARGETS list so
# that both gates apply the same frozen-history exclusion without duplicating it).
# shellcheck source=/dev/null
[ -f "$root/.ledger/config.sh" ] && source "$root/.ledger/config.sh"
# Default: same authoritative surfaces as check_orphans.sh ORPHAN_TARGETS.
# docs/plans/, docs/chronicle.md, and .scratch/.ledger working trees are
# intentionally omitted — they record frozen history, not live doctrine.
if [ -z "${LINK_TARGETS+set}" ]; then
  LINK_TARGETS=(skills templates ambient.md README.md AGENTS.md rules.md docs/authoring.md docs/getting-started.md)
fi

# --- contract: every ledger artifact still satisfies its Nickel contract -----
if [ -x "$gate/ledger-validate.sh" ] && [ -d "$root/ledger" ]; then
  artifacts=$(find "$root/ledger/fixtures" "$root/ledger/contracts" \
    -name '*.ncl' 2>/dev/null | sort)
  contract_fail=0
  for a in $artifacts; do
    # contracts/ are schema libraries (imported, not exported standalone); skip.
    case "$a" in */contracts/*) continue ;; esac
    # fixtures/ contains both positive-control and negative-control instances.
    # Negative-control files declare "non-zero" in their header comments
    # (they intentionally fail export to prove the contract bites). Skip them;
    # only positive-control fixtures must export cleanly.
    grep -q "non-zero" "$a" && continue
    "$gate/ledger-validate.sh" structure "$a" >/dev/null 2>&1 \
      || { echo "FAIL  contract: $a no longer exports"; contract_fail=1; }
  done
  if [ "$contract_fail" -eq 0 ]; then
    echo "PASS  contract: every ledger fixture still exports"
  else
    fails=$((fails + 1))
  fi
else
  dispatch "contract" "contract: no ledger gate present"
fi

# --- orphans: no surviving file references a removed workflow as if live -----
if [ "${#removed[@]}" -gt 0 ]; then
  if [ -x "$gates/check_orphans.sh" ]; then
    if "$gates/check_orphans.sh" "$root" "${removed[@]}" >/dev/null 2>&1; then
      echo "PASS  orphans: no live reference to a removed workflow"
    else
      echo "FAIL  orphans: a surviving file references a removed workflow"
      fails=$((fails + 1))
    fi
  else
    dispatch "orphans" "orphans: no orphan gate present"
  fi
fi

# --- links: markdown link syntax still resolves ------------------------------
# The link gate ships with the doc-audit skill (its script survived the skill's
# merge into documentation); fall back to a gates/ copy if one is promoted.
# Scans LINK_TARGETS only (authoritative surfaces), matching the exclusion used
# by check_orphans.sh — frozen history (docs/plans/, docs/chronicle.md, and
# the .scratch/.ledger working trees) is naturally excluded by not being listed.
link_gate=""
for cand in "$gates/check_docs.py" "$plugin/skills/doc-audit/scripts/check_docs.py"; do
  [ -f "$cand" ] && { link_gate="$cand"; break; }
done
if [ -n "$link_gate" ]; then
  link_fail=0
  for t in "${LINK_TARGETS[@]}"; do
    [ -e "$root/$t" ] || continue
    python3 "$link_gate" "$root/$t" >/dev/null 2>&1 || link_fail=1
  done
  if [ "$link_fail" -eq 0 ]; then
    echo "PASS  links: markdown link syntax resolves"
  else
    echo "FAIL  links: a markdown link no longer resolves"
    fails=$((fails + 1))
  fi
else
  # Link integrity has an evaluator in principle but none is wired here; the
  # adversarial path covers it explicitly rather than silently skipping.
  dispatch "links" "links: no link gate present"
fi

# Concerns with no deterministic evaluator at all (semantic coherence: does the
# landing's MEANING still cohere with the system's doctrine?) always route to
# the adversarial path — they are why CLOSE had a decorrelated sweep.
dispatch "semantic-coherence" "semantic-coherence: no evaluator can exist"

if [ "$fails" -ne 0 ]; then
  echo "INCOHERENT: $fails machine-check(s) failed — breakage caught at the boundary"
  exit 1
fi
# Machine surface is clean. Report the adversarial obligations HONESTLY: ACCEPT
# is gated on the pending decorrelated reviews converging, tracked in the
# dispatch-log when one was supplied (else the count is the standing signal).
if [ -n "$dispatch_log" ]; then
  echo "COHERENT (machine surface): all evaluators passed; $pending_dispatches adversarial review(s) PENDING in $dispatch_log — ACCEPT gated until each is resolved (converged/diverged)"
else
  echo "COHERENT (machine surface): all evaluators passed; $pending_dispatches adversarial review(s) PENDING — ACCEPT gated until each converges (pass --dispatch-log to track them)"
fi
exit 0
