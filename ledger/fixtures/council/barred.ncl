# EXPECT: fail
# Case 5: a barred seat appears in `assent`. The no-barred predicate voids the
# ruled-out seat's vote and rejects the decision (export exit != 0).
let c = import "../../contracts/council.ncl" in
let con = (import "./constitution.ncl") | c.Constitution in
{ decisions = [ { id = "B1", type = "merge", assent = ["maintainer"], barred = ["maintainer"], verdict = "x", grounding = "a ruled-out seat still voted" } ] } | (c.DecisionLedger con)
