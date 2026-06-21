# Positive-control fixture: a fully-filled context-map carrying two requirements
# and one live unknown, every item grounded with non-empty evidence, freshness,
# and signpost. Both the `kind` enum and the NonEmptyString fields pass, so
# `nickel export` MUST exit 0.
#
# This is the shipped positive control: synthetic, carrying no live project
# state, so downstream repos and CI can rely on it without pulling in a real
# walk's context-map.
let c = import "../contracts/context_map.ncl" in
{
  items = [
    {
      id = "R1",
      statement = "Every ledger contract must export 0 under the structure gate.",
      kind = 'requirement,
      grounding = "ledger/gate/ledger-validate.sh (structure subcommand).",
      last_validated = "2026-06-21",
      signpost = "ledger-validate structure returns non-zero on a contract.",
    },
    {
      id = "I1",
      statement = "A required evidence field empty => export fails loudly.",
      kind = 'invariant,
      grounding = "context_map_empty_grounding.ncl: rc != 0 on empty grounding.",
      last_validated = "2026-06-21",
      signpost = "the negative-control fixture begins to export rc 0.",
    },
    {
      id = "U1",
      statement = "Does the carrier need staleness checking on last_validated?",
      kind = 'unknown,
      grounding = "CONTRACT.md KNOWN-UNKNOWNS: per-surface projection deferred.",
      last_validated = "2026-06-21",
      signpost = "a walk carries a stale item undetected past a reconcile boundary.",
    },
  ]
} | c.ContextMap
