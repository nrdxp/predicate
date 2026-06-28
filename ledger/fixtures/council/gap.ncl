# EXPECT: fail
# Case 2: a gapped constitution — `release` is a decision-type with no delegation
# rule. The anti-incoherence invariant rejects it (export exit != 0): you cannot
# convene under a law that leaves a decision-type unassigned.
let c = import "../../contracts/council.ncl" in
let con = import "./constitution.ncl" in
{ seats = con.seats, decision_types = con.decision_types @ ["release"], delegation = con.delegation } | c.Constitution
