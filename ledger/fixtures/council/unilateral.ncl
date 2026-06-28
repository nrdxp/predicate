# EXPECT: fail
# Case 3: a unilateral decision — `close` is a terminal 'full type, yet only the
# architect assented. The anti-unilateral predicate rejects it (export exit != 0).
let c = import "../../contracts/council.ncl" in
let con = (import "./constitution.ncl") | c.Constitution in
{ decisions = [ { id = "U1", type = "close", assent = ["architect"], verdict = "rammed through", grounding = "skipped the room" } ] } | (c.DecisionLedger con)
