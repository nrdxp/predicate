# Positive-control fixture: a valid Selection deposit for the "repo-search"
# class. `chosen = "semantic-search"` is a registered member; all Deposit
# base fields and Selection extension fields are present and non-empty.
#
# Verified with:
#   nickel export -I ledger/contracts ledger/fixtures/arsenal_selection_valid.ncl
#   → exit 0

let registry = import "../contracts/arsenal_registry.ncl" in
let deposit   = import "../contracts/deposit.ncl" in

{
  id            = "sel-repo-search-001",
  step          = "discovery-select",
  evidence      = [
    {
      claim    = "semantic-search is available via grepai in this environment",
      method   = 'example_test,
      location = "grepai search 'user authentication flow' --json --compact → rc=0",
    }
  ],
  cites         = ["ledger/contracts/arsenal_registry.ncl"],
  refs          = [
    {
      target = "disc-repo-search-001",
      role   = "discovery-footprint",
    }
  ],
  # Selection extension fields
  chosen        = "semantic-search",
  available     = ["ls-files", "keyword-grep", "regex-grep", "fuzzy-search", "semantic-search"],
  discovery_ref = {
    target = "disc-repo-search-001",
    role   = "discovery-footprint",
  },
  justification = "The goal requires finding code by intent rather than exact text; semantic-search (grepai) is the cheapest modality that binds the task — no structural-map or call-graph trace needed for a targeted lookup.",
}
| (registry.make_selection registry.Arsenal "repo-search")
