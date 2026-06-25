# EXPECT: fail
# Negative control: duplicate id in TechDebtStore must make nickel export exit
# non-zero. Baseline delta-E0 != 0 — if this passes, the id-uniqueness gate
# has regressed.
let c = import "../../skills/record/tech_debt.ncl" in
{
  items = [
    {
      id = "td-x",
      claim = "First claim",
      location = "file.sh:10",
      severity = "low",
      why_deferred = "Deferred for now",
      signpost = "Fix when Y",
    },
    {
      id = "td-x",
      claim = "Duplicate id — store must reject this",
      location = "file.sh:20",
      severity = "medium",
      why_deferred = "Also deferred",
      signpost = "Fix when Z",
    },
  ]
} | c.TechDebtStore
