# EXPECT: pass
# Positive-control fixture: all five required discovery steps are present,
# blast-radius appears TWICE (a loop — tracing two call sites), and every
# deposit is a well-formed DiscoveryDeposit.  DiscoveryStore + DiscoveryComplete
# must both pass; `nickel export` MUST exit zero.
let c = import "../contracts/discovery.ncl" in
{
  deposits = [
    {
      id = "eu-1",
      step = "establish-universe",
      modality = 'structural_map,
      evidence = [
        {
          claim = "git ls-files enumerated 47 tracked files in the repository",
          method = 'example_test,
          location = "ledger/contracts/",
          signer = { kind = 'agent, name = "walker" }, check = { command = "ledger/contracts/", ran = true, at = "6afbc9d" },
        },
      ],
      cites = ["ledger/contracts/deposit.ncl", "ledger/contracts/dag.ncl"],
      refs = [],
    },
    {
      id = "mi-1",
      step = "map-intent",
      modality = 'semantic,
      evidence = [
        {
          claim = "grepai search found deposit-substrate loci in deposit.ncl and dag.ncl",
          method = 'example_test,
          location = "ledger/contracts/deposit.ncl:77",
          signer = { kind = 'agent, name = "walker" }, check = { command = "ledger/contracts/deposit.ncl:77", ran = true, at = "6afbc9d" },
        },
      ],
      cites = ["ledger/contracts/deposit.ncl"],
      refs = [{ target = "eu-1", role = "universe-bound" }],
    },
    {
      id = "br-1",
      step = "blast-radius",
      modality = 'trace,
      evidence = [
        {
          claim = "grepai trace callers of DepositStore: only fixtures reference it",
          method = 'example_test,
          location = "ledger/fixtures/deposit_dangling_ref.ncl:28",
          signer = { kind = 'agent, name = "walker" }, check = { command = "ledger/fixtures/deposit_dangling_ref.ncl:28", ran = true, at = "6afbc9d" },
        },
      ],
      cites = ["ledger/fixtures/deposit_dangling_ref.ncl"],
      refs = [{ target = "mi-1", role = "intent-map" }],
    },
    {
      id = "br-2",
      step = "blast-radius",
      modality = 'trace,
      evidence = [
        {
          claim = "grepai trace callers of Deposit record: used in DiscoveryDeposit merge",
          method = 'example_test,
          location = "ledger/contracts/discovery.ncl:50",
          signer = { kind = 'agent, name = "walker" }, check = { command = "ledger/contracts/discovery.ncl:50", ran = true, at = "6afbc9d" },
        },
      ],
      cites = ["ledger/contracts/discovery.ncl"],
      refs = [],
    },
    {
      id = "ow-1",
      step = "outward-world",
      modality = 'none,
      evidence = [
        {
          claim = "trivial composition pattern — no external references needed; modality none",
          method = 'review,
          location = "primitives-spec.md §P-GROUND",
          signer = { kind = 'agent, name = "walker" }, witness = { name = "walker", at = "6afbc9d" },
        },
      ],
      cites = [],
      refs = [],
    },
    {
      id = "oe-1",
      step = "outward-environment",
      modality = 'none,
      evidence = [
        {
          claim = "surveyed installed skills: grepai available; habitual tool sufficient",
          method = 'review,
          location = "CLAUDE.md §grepai",
          signer = { kind = 'agent, name = "walker" }, witness = { name = "walker", at = "6afbc9d" },
        },
      ],
      cites = [],
      refs = [],
    },
  ],
} | c.DiscoveryStore | c.DiscoveryComplete
