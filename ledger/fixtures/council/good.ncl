# EXPECT: pass
# Case 1: a complete constitution + a valid ledger. Exports clean (exit 0).
# D1 is a routine owner-only `dispatch` — proof that proportional/standing convening
# is lawful: you need NOT convene everyone for routine forward motion.
let c = import "../../contracts/council.ncl" in
let con = (import "./constitution.ncl") | c.Constitution in
{
  constitution = con,
  ledger = {
    decisions = [
      { id = "D1", type = "dispatch", assent = ["composer"], verdict = "dispatched N1", grounding = "routine forward motion; the owner alone suffices (proportional convening)" },
      { id = "D2", type = "reconcile-accept", assent = ["architect"], verdict = "accepted", grounding = "landed diff matches the IBC surface; architect reconciles" },
      { id = "D3", type = "merge", assent = ["maintainer"], verdict = "merge", grounding = "maintainer affirmatively accepts the maintenance burden" },
      { id = "D4", type = "dag-amendment", assent = ["architect", "human"], verdict = "amended", grounding = "node added mid-flight; the head ratifies the scope change" },
      { id = "D5", type = "classification", assent = ["architect", "maintainer"], verdict = "procedure->module", grounding = "governing rule applied; quorum of 2 concur" },
      { id = "D6", type = "close", assent = ["architect", "composer", "maintainer", "auditor", "human"], verdict = "closed", grounding = "dual-CLOSE green + sufficiency; full council assents" },
    ],
  } | (c.DecisionLedger con),
}
