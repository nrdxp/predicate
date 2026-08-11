# Positive-control fixture: a fully-filled context-map carrying two directive
# rows (a requirement and an invariant, each with provenance, grounding,
# freshness, anchor, and defeater) and one live unknown expressed as a full
# question entry (discharge + closer). `nickel export` MUST exit 0.
#
# This is the shipped positive control: synthetic, carrying no live project
# state, so downstream repos and CI can rely on it without pulling in a real
# walk's context-map.
let c = import "../contracts/context_map.ncl" in
{
  items = [
    {
      id = "R1",
      kind = 'requirement,
      statement = "Every ledger contract must export 0 under the structure gate.",
      provenance = { kind = 'human, name = "nrd" },
      grounding = "ledger/gate/ledger-validate.sh (structure subcommand).",
      last_validated = "2026-08-10",
      at = "6afbc9d",
      signpost = "ledger-validate structure returns non-zero on a contract.",
    },
    {
      id = "I1",
      kind = 'invariant,
      statement = "A required evidence field empty => export fails loudly.",
      provenance = { kind = 'agent, name = "architect-seat" },
      grounding = "context_map_empty_grounding.ncl: rc != 0 on empty grounding.",
      last_validated = "2026-08-10",
      at = "6afbc9d",
      signpost = "the negative-control fixture begins to export rc 0.",
    },
    {
      id = "U1",
      kind = 'unknown,
      statement = "Does the carrier need staleness checking on last_validated?",
      assertion = 'question,
      backing = 'unclosed,
      signer = { kind = 'agent, name = "walk" },
      discharge = "tracker_fresh.sh flags a stale hydrated item in the field",
      closer = { kind = 'human, name = "nrd" },
      grounding = "raised during the P-TRACK design review.",
      last_validated = "2026-08-10",
      at = "6afbc9d",
    },
  ]
} | c.ContextMap
