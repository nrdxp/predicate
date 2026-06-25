# Positive-control fixture for a hydrated context-map: items that were
# populated from a project's AGENTS.md hierarchy (the P-TRACK / I14 architecture)
# rather than from scratch. The `hydration_source` field records the AGENTS.md
# path:section the item was hydrated from; its value is non-empty (as required).
#
# This fixture feeds tracker_fresh.sh: the gate reads `last_validated` and
# `hydration_source` to decide whether the persistent AGENTS.md anchor is stale.
# `nickel export` MUST exit 0 — every required field is non-empty and the
# `hydration_source` string is non-empty.
let c = import "../contracts/context_map.ncl" in
{
  items = [
    {
      id = "R1",
      statement = "The orient workflow authors a per-construct R/I/U section in AGENTS.md.",
      kind = 'requirement,
      grounding = "skills/orient/SKILL.md §AGENTS.md as R/I/U Hierarchy.",
      last_validated = "2026-06-25",
      signpost = "orient produces AGENTS.md without a Requirements section for some construct.",
      hydration_source = "AGENTS.md#requirements",
    },
    {
      id = "I1",
      statement = "Every live tracker item carries a non-empty last_validated date.",
      kind = 'invariant,
      grounding = "ledger/contracts/context_map.ncl: NonEmptyString on last_validated.",
      last_validated = "2026-06-25",
      signpost = "context_map export passes with an empty last_validated string.",
      hydration_source = "AGENTS.md#invariants",
    },
    {
      id = "U1",
      statement = "Does reorientation need a separate gate trigger beyond tracker_fresh?",
      kind = 'unknown,
      grounding = "primitives-spec.md §P-TRACK: reorientation-on-staleness described.",
      last_validated = "2026-06-25",
      signpost = "a walk carries a stale AGENTS.md-sourced item without triggering reorientation.",
      hydration_source = "AGENTS.md#unknowns",
    },
  ]
} | c.ContextMap
