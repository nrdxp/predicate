# EXPECT: fail
# Negative-control fixture: the "map-intent" step is MISSING. The instance
# has establish-universe, blast-radius, outward-world, outward-environment —
# but omits map-intent.  DiscoveryComplete must hard-fail because its
# required-set ("map-intent" is one of the five) is not fully covered.
# `nickel export` MUST exit non-zero (baseline delta-E0 != 0).
let c = import "../contracts/discovery.ncl" in
{
  deposits = [
    {
      id = "eu-1",
      step = "establish-universe",
      modality = 'structural_map,
      evidence = [
        {
          claim = "git ls-files enumerated the repository",
          method = 'example_test,
          location = "ledger/contracts/",
        },
      ],
      cites = [],
      refs = [],
    },
    {
      id = "br-1",
      step = "blast-radius",
      modality = 'trace,
      evidence = [
        {
          claim = "no callers of the touched symbol outside fixtures",
          method = 'example_test,
          location = "ledger/fixtures/",
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
          claim = "trivial — no external references required",
          method = 'review,
          location = "primitives-spec.md §P-GROUND",
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
          claim = "surveyed arsenal: habitual tool sufficient",
          method = 'review,
          location = "CLAUDE.md §grepai",
        },
      ],
      cites = [],
      refs = [],
    },
    # map-intent is intentionally absent — this is the skip under test
  ],
} | c.DiscoveryStore | c.DiscoveryComplete
