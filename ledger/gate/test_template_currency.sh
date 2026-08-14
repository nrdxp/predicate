#!/usr/bin/env bash
# ledger/gate/test_template_currency.sh
#
# Acceptance suite for node 4a (template currency). ledger/contracts/worker_ibc.ncl
# was upgraded to the GRADED IBC shape (premises as closed claim entries with
# axes; unknowns as routable question entries; goal/non-goals/constraints/
# acceptance as provenance-carrying Directives). Three teaching artifacts still
# condition an author toward the superseded flat shape: templates/IBC.md,
# skills/boundary/SKILL.md's premise/unknown prose, and
# conditioning/personas/boundary-worker.ncl (the live /boundary system prompt).
#
# THE PROPERTY THIS SUITE CHECKS (architect ruling,
# .ledger/deposits/composer-falsifiability/architect-seat/ruling-invocation-axis.md
# [B12]/[B13]): a teaching artifact's own example MUST validate against the
# contract it teaches. This is a CURRENCY check — does the clause's content
# still agree with the law it describes — not a PRESENCE check (does the text
# survive composition) and not an ADHERENCE check (does a conditioned walk take
# the branch). No generator is introduced: a generator is a third artifact that
# can itself drift from the contract, adding a party to a sync problem that
# already has two. Cases 1-3 apply the strongest available evaluator (Nickel,
# the symbolic path) to a literal, extractable example; cases 4-6 fall back to
# textual presence — declared explicitly as the WEAKEST tier in the S4
# hierarchy (linter-equivalent), because no deterministic evaluator exists for
# free-text prose semantics. Presence is a NECESSARY, not sufficient, proxy:
# see .ledger/log/2026-08-12-we-tested-prose.md for the failure mode this
# tier invites, and the architect's own [B14] check (identical technique,
# graded `proved`) for precedent that this is the strongest tier available
# here.
#
# CASE 1's EXTRACTION CONVENTION (this suite's own design choice, since no
# extraction tooling exists yet — [T13]/[Y3]/[Y4] confirm none does): the
# template's example floor MUST be embedded as a single fenced code block
# opened with a bare ```yaml line and closed with a bare ``` line. Extraction
# is a literal substring pull (awk), never a semantic transform — this is the
# "template's example CAN BE that fixture" reading of [B12], not a generator.
# An implementer is free to propose a different convention, but must then
# amend this suite's `extract_example` function to match, in the same commit.
#
# THE TRUE RED BASELINE (verified independently a third time by this walk,
# corroborating .ledger/log/2026-08-14-the-specimen-was-run.md [Y1] and
# .ledger/deposits/composer-falsifiability/architect-seat/ruling-invocation-axis.md
# [B15] — two prior walks that did not read each other, now a third): a
# minimal full Worker record with one premise in the template's literal
# shape ({id, statement, check, verified}) fails EXIT=1 with "extra field
# `verified`"; drop `verified` and rename `check` to `check_cmd` (the
# template's own field label after "Check:") and it fails EXIT=1 with "extra
# field `check_cmd`"; strip to {id, statement} alone and it fails EXIT=1 with
# "missing definition for `backing`" at entry.ncl:364. An earlier
# characterization ("fails on missing assertion/backing/signer") is WRONG on
# the first failure and wrong on two of its three named fields — do not
# revive it.
#
# Usage: test_template_currency.sh
# Exit:  0 = every case matched, 1 = a case mismatched, 2 = environment error.
set -u
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root="$(cd "$here/../.." && pwd)"
template="$root/templates/IBC.md"
skill="$root/skills/boundary/SKILL.md"
persona="$root/conditioning/personas/boundary-worker.ncl"
apply="$root/ledger/contracts/worker_ibc_apply.ncl"

command -v nickel >/dev/null 2>&1 || { echo "ENV: nickel not found on PATH"; exit 2; }
[ -f "$template" ] || { echo "ENV: template missing: $template"; exit 2; }
[ -f "$skill" ] || { echo "ENV: skill missing: $skill"; exit 2; }
[ -f "$persona" ] || { echo "ENV: persona missing: $persona"; exit 2; }
[ -f "$apply" ] || { echo "ENV: apply-file missing: $apply"; exit 2; }

fails=0
pass() { echo "PASS  $1"; }
fail() { echo "FAIL  $1"; shift; printf '%s\n' "$@" | sed 's/^/      /'; fails=$((fails + 1)); }

# Extracts the FIRST ```yaml ... ``` fenced block in templates/IBC.md. A
# literal substring pull, never a semantic transform (see header). Empty
# output when no such fence exists — the current, defect state.
extract_example() {
  awk '/^```yaml$/{f=1;next} /^```$/{if (f) exit; next} f' "$template"
}

# --- Case 1 (load-bearing): the template's own example validates ----------
# THE PROPERTY: a teaching artifact's own example MUST validate against the
# contract it teaches ([B12]). Currently there is no ```yaml fence in the
# template at all ([B14]: zero occurrences of "yaml" in the file), so
# extraction yields empty content and the Nickel export fails on an empty
# record rather than on any field-shape mismatch — a different failure than
# the S1-3 cascade below, and the one this case actually gates.
tmp_example="$(mktemp)"
trap 'rm -f "$tmp_example"' EXIT
extract_example > "$tmp_example"
out="$(nickel export "$tmp_example" --apply-contract "$apply" 2>&1)"; rc=$?
if [ "$rc" -eq 0 ]; then
  pass "case 1: template's extracted example floor validates (rc=0)"
else
  fail "case 1: template's extracted example floor validates" \
    "got rc=$rc, want rc=0 (no \`\`\`yaml fence found in templates/IBC.md yet)" \
    "$out"
fi

# --- Case 2: the template names the artifact class it teaches -------------
# An IBC premise is authored as a graded markdown document PLUS a YAML floor,
# and the floor is what worker_ibc.ncl actually validates ([Z11]/[B14]). A
# template silent on all four of these tokens teaches only the prose half.
vocab_count="$(grep -icE 'yaml|worker_ibc|floor|nickel' "$template")"
if [ "$vocab_count" -gt 0 ]; then
  pass "case 2: template names its artifact class (yaml|worker_ibc|floor|nickel hits=$vocab_count)"
else
  fail "case 2: template names its artifact class" \
    "grep -icE 'yaml|worker_ibc|floor|nickel' templates/IBC.md -> $vocab_count, want > 0"
fi

# --- Case 3: the template no longer instructs the rejected flat fields ----
# templates/IBC.md's Premises section format block currently reads:
#   **[premise-id]**: [Falsifiable statement]
#   - **Check**: [exact command, file:line, or document section]
#   - **Verified**: [date/commit + evidence, or UNVERIFIED]
# `verified` is the exact extra field the contract rejects first (case 1's
# header baseline); `**Check**:` names the pre-graded free-text pair
# worker_ibc.ncl's own comment says it superseded.
old_field_hits="$(grep -noE '\*\*Check\*\*|\*\*Verified\*\*' "$template")"
if [ -z "$old_field_hits" ]; then
  pass "case 3: template's premises format no longer instructs Check/Verified"
else
  fail "case 3: template's premises format no longer instructs Check/Verified" \
    "found:" "$old_field_hits"
fi

# --- Case 4: SKILL.md names the premise-side companions --------------------
# S1 (FALSIFIABILITY) is the skill's normative authority over the premises
# section; it must name at least the claim-entry companions a premise now
# carries (backing, signer, axes) rather than only the pre-graded
# "falsifiable + name the check" framing.
skill_premise_hits="$(grep -cwE 'backing|signer|axes' "$skill")"
if [ "$skill_premise_hits" -gt 0 ]; then
  pass "case 4: SKILL.md names premise companions (backing|signer|axes hits=$skill_premise_hits)"
else
  fail "case 4: SKILL.md names premise companions" \
    "grep -cwE 'backing|signer|axes' skills/boundary/SKILL.md -> $skill_premise_hits, want > 0"
fi

# --- Case 5: SKILL.md names the question-side companions -------------------
# The `unknowns` field is a routable question entry (discharge + closer);
# S3's RESOLVED/DELEGATED/RESERVED partition never introduces either term.
skill_question_hits="$(grep -cwE 'discharge|closer' "$skill")"
if [ "$skill_question_hits" -gt 0 ]; then
  pass "case 5: SKILL.md names question companions (discharge|closer hits=$skill_question_hits)"
else
  fail "case 5: SKILL.md names question companions" \
    "grep -cwE 'discharge|closer' skills/boundary/SKILL.md -> $skill_question_hits, want > 0"
fi

# --- Case 6: the live /boundary system prompt names the closed-record ------
# --- companions -------------------------------------------------------------
# conditioning/personas/boundary-worker.ncl is rendered as the system prompt
# for every /boundary walk ([T3]) — it conditions the author before any
# document is read, which makes this the higher-stakes instance of the same
# defect as cases 4-5.
persona_hits="$(grep -cwE 'backing|signer|axes|discharge|closer' "$persona")"
if [ "$persona_hits" -gt 0 ]; then
  pass "case 6: boundary-worker.ncl names the closed-record companions (hits=$persona_hits)"
else
  fail "case 6: boundary-worker.ncl names the closed-record companions" \
    "grep -cwE 'backing|signer|axes|discharge|closer' conditioning/personas/boundary-worker.ncl -> $persona_hits, want > 0"
fi

if [ "$fails" -ne 0 ]; then
  echo "FAIL: $fails template-currency case(s) failed"; exit 1
fi
echo "PASS: all template-currency cases passed"
exit 0
