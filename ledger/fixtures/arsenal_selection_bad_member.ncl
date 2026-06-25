# EXPECT: fail
#
# Negative-control fixture: `chosen = "hallucinated-tool"` is NOT a registered
# member of class "repo-search". The membership gate (I-A2) must reject this.
#
# Verified with:
#   nickel export -I ledger/contracts ledger/fixtures/arsenal_selection_bad_member.ncl
#   → exit non-zero (contract broken: chosen not a registered member)

let registry = import "../contracts/arsenal_registry.ncl" in
let deposit   = import "../contracts/deposit.ncl" in

{
  id            = "sel-repo-search-bad-001",
  step          = "discovery-select",
  evidence      = [
    {
      claim    = "hallucinated-tool was discovered in this environment",
      method   = 'manual,
      location = "this claim is fabricated — testing the membership gate",
    }
  ],
  cites         = [],
  refs          = [],
  # Selection extension fields
  chosen        = "hallucinated-tool",   # NOT in class "repo-search" → must fail
  available     = ["hallucinated-tool"],
  discovery_ref = {
    target = "disc-bad-001",
    role   = "discovery-footprint",
  },
  justification = "Intentionally invalid: chosen is not a registry member.",
}
| (registry.make_selection registry.Arsenal "repo-search")
