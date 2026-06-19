# Dangling-edge fixture: A depends on undeclared "ZZZ". Referential integrity is
# intrinsic; `nickel export` MUST exit non-zero (baseline delta-E0 != 0).
let c = import "../contracts/dag.ncl" in
{
  nodes = [
    { id = "A", depends_on = ["ZZZ"], file_surface = ["a/"], discipline = 'core, mitigates = [] },
  ]
} | c.Dag
