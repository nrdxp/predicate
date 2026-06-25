# Apply-contract for campaign DAGs authored as YAML instances.
#
# Usage (from the project root, with the shell.nix nickel on PATH):
#   nickel export <dag>.yaml --apply-contract ledger/contracts/dag_apply.ncl
#
# This composes Dag ∘ DagNoConflict in one --apply-contract pass so the single
# command is the portable gate — no intermediate JSON step that a headless
# orchestrator could skip. Equivalent to what the NCL DAG instances express
# inline (`({ nodes = [...] } | c.Dag) | c.DagNoConflict`), but as an external
# contract applied to a pure-data YAML file.
#
# Imports resolve relative to THIS file's location, so dag.ncl and its transitive
# imports (discipline.ncl, authorized.ncl) all sit in the same directory and are
# found without any -I flag needed.
let c = import "dag.ncl" in
std.contract.all_of [c.Dag, c.DagNoConflict]
