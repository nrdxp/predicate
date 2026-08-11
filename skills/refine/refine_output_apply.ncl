# Apply-contract for refine REPORT records authored as pure-data YAML.
#
# Usage (from the project root, with the shell.nix nickel on PATH):
#   nickel export <report>.yaml --apply-contract skills/refine/refine_output_apply.ncl
#
# refine_output.ncl is the law and stays unchanged: RefineReport (shape —
# vouch-shaped judgments and a signed postmortem) composed with RefineOutput
# (the convergence + unanimity gate). All enums are value-restricted
# tag-or-string, so no YAML→tag lifting is needed.
let c = import "refine_output.ncl" in
std.contract.all_of [c.RefineReport, c.RefineOutput]
