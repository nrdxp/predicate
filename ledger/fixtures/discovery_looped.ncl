# EXPECT: pass
# Positive-control fixture: blast-radius appears THREE times (a walk that traced
# three separate symbols in iteration). All five required steps are present;
# the loop is correctly accepted because complete_for requires ≥1 footprint
# per step — not exactly-1. `nickel export` MUST exit zero.
let c = import "../contracts/discovery.ncl" in
{
  deposits = [
    {
      id = "eu-1",
      step = "establish-universe",
      modality = 'structural_map,
      evidence = [
        {
          claim = "git ls-files listed all tracked files in ledger/contracts/",
          method = 'example_test,
          location = "ledger/contracts/",
          signer = { kind = 'agent, name = "walker" }, check = { command = "ledger/contracts/", ran = true, at = "6afbc9d" },
        },
      ],
      cites = [],
      refs = [],
    },
    {
      id = "mi-1",
      step = "map-intent",
      modality = 'keyword,
      evidence = [
        {
          claim = "rg -F 'DepositStore' found three call sites in fixtures",
          method = 'example_test,
          location = "ledger/fixtures/deposit_dangling_ref.ncl:28",
          signer = { kind = 'agent, name = "walker" }, check = { command = "ledger/fixtures/deposit_dangling_ref.ncl:28", ran = true, at = "6afbc9d" },
        },
      ],
      cites = [],
      refs = [{ target = "eu-1", role = "universe-bound" }],
    },
    {
      id = "br-1",
      step = "blast-radius",
      modality = 'trace,
      evidence = [
        {
          claim = "trace callers of DepositStore: deposit_dangling_ref.ncl only",
          method = 'example_test,
          location = "ledger/fixtures/deposit_dangling_ref.ncl",
          signer = { kind = 'agent, name = "walker" }, check = { command = "ledger/fixtures/deposit_dangling_ref.ncl", ran = true, at = "6afbc9d" },
        },
      ],
      cites = [],
      refs = [],
    },
    {
      id = "br-2",
      step = "blast-radius",
      modality = 'trace,
      evidence = [
        {
          claim = "trace callers of Deposit: discovery.ncl uses it in merge",
          method = 'example_test,
          location = "ledger/contracts/discovery.ncl",
          signer = { kind = 'agent, name = "walker" }, check = { command = "ledger/contracts/discovery.ncl", ran = true, at = "6afbc9d" },
        },
      ],
      cites = [],
      refs = [],
    },
    {
      id = "br-3",
      step = "blast-radius",
      modality = 'semantic,
      evidence = [
        {
          claim = "grepai search for deposit-substrate pattern: no additional callers",
          method = 'example_test,
          location = "ledger/contracts/deposit.ncl",
          signer = { kind = 'agent, name = "walker" }, check = { command = "ledger/contracts/deposit.ncl", ran = true, at = "6afbc9d" },
        },
      ],
      cites = [],
      refs = [],
    },
    {
      id = "ow-1",
      step = "outward-world",
      modality = 'none,
      evidence = [
        {
          claim = "trivial sub-procedure contract — no non-trivial algorithm; none needed",
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
          claim = "arsenal surveyed: grepai and nickel available; habitual tools sufficient",
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
