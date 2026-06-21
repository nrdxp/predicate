# EXPECT: fail
# Negative-control fixture (baseline delta-E0 != 0): item R1 carries an empty
# `grounding`. An ungrounded requirement is the silent omission this carrier
# exists to kill, so the ContextMap contract MUST make `nickel export` exit
# non-zero. This is the fail-loud proof: a missing required evidence field makes
# export fail, unforgeably.
let c = import "../contracts/context_map.ncl" in
{
  items = [
    {
      id = "R1",
      statement = "All ledger contracts must export under the structure gate.",
      kind = 'requirement,
      grounding = "",
      last_validated = "2026-06-21",
      signpost = "ledger-validate structure returns non-zero on any contract.",
    },
  ]
} | c.ContextMap
