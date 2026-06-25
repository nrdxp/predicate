# Apply-contract shim for tech-debt YAML instances.
#
# Usage (from the project root, with nickel on PATH):
#   nickel export <file>.yaml --apply-contract skills/record/tech_debt_apply.ncl
#
# The instance file is pure-data YAML (no Nickel execution model) — validated
# externally by this shim. Self-binding and import-DoS are impossible by
# construction (YAML has no execution model).
#
# Imports resolve relative to THIS file's location (skills/record/), so
# tech_debt.ncl is found in the same directory without any -I flag.
(import "tech_debt.ncl").TechDebtStore
