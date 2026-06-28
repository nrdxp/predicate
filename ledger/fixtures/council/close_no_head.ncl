# EXPECT: fail
# Case 7: a `close` with full MACHINE consensus (all four machine seats assent) but
# WITHOUT the head (human). The 'full machine-consensus gate is satisfied, yet the
# head never ratified — close requires BOTH gates, and the head-ratification guard
# (must_assent = ["human"]) rejects it (export exit != 0). This isolates the two
# terminal gates: consensus alone does not close; the head ratifies on top.
let c = import "../../contracts/council.ncl" in
let con = (import "./constitution.ncl") | c.Constitution in
{ decisions = [ { id = "C1", type = "close", assent = ["architect", "composer", "maintainer", "auditor"], verdict = "closed without ratification", grounding = "machine council reached consensus but the head never ratified" } ] } | (c.DecisionLedger con)
