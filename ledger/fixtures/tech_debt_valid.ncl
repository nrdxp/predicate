# EXPECT: pass
# Positive control: validates the tech-debt seed instances against TechDebtStore.
# Exercises: non-empty string enforcement, Severity enum, multi-item store,
# id uniqueness (4 distinct ids should pass).
let c = import "../../skills/record/tech_debt.ncl" in
(import "tech_debt_seed.yaml") | c.TechDebtStore
