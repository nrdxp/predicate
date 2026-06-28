# EXPECT: fail
# Case 4: a `merge` decision whose assent lacks the maintainer. The explicit
# merge-consent guard rejects it (export exit != 0) — green gates are necessary but
# never sufficient; the merge requires the maintainer's recorded affirmative assent.
let c = import "../../contracts/council.ncl" in
let con = (import "./constitution.ncl") | c.Constitution in
{ decisions = [ { id = "M1", type = "merge", assent = ["composer"], verdict = "merged", grounding = "slipped past the maintainer" } ] } | (c.DecisionLedger con)
