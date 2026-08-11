# EXPECT: pass
#
# Self-contained fixture (native Nickel, not YAML+apply): the shipped
# constitution (ledger/fixtures/council/constitution.yaml, threaded by
# council_fixture_apply.ncl / council_apply.ncl for every OTHER fixture in
# this suite) has exactly one 'full decision type (`close`), and `close`
# always carries `must_assent: [human]`. Under that one constitution, whether
# `machine_ids` (council.ncl:156-157) excludes the head via `!s.head`, or
# excludes non-standing seats via `s.standing == 'standing`, changes NO
# fixture's verdict: the head's ratification is separately mandatory either
# way (via must_assent/consent_ok), and the shipped constitution seats no
# guest at all. Both filters are therefore CONSTITUTION-INERT under the
# YAML+apply harness — no delete-goes-red/green fixture expressible there can
# exercise them, because that harness can only thread the one canonical
# constitution.
#
# This fixture threads council.ncl's DecisionLedger CONSTRUCTOR directly with
# a bespoke constitution built for exactly this purpose: a 'full type
# (`ratify`) that carries NO must_assent, a head seat, and a guest seat. The
# tally of three non-head, non-guest standing seats (architect, maintainer,
# auditor) is complete without either the head or the guest, so this decision
# is LAWFUL (export clean, rc 0) under the real law.
#
# Mutation record (verified in a copy of council.ncl, never the installed
# file — see the item's dispatch report for the exact commands):
#   - unmutated council.ncl:                                        EXIT=0
#   - `!s.head` deleted from the machine_ids filter (line 157):      EXIT=1
#     (head joins the tally, is absent from this decision's assent,
#     class_ok fails -> "anti-unilateral")
#   - `s.standing == 'standing &&` deleted from the same filter:     EXIT=1
#     (guest-x joins the tally, is absent from this decision's assent,
#     class_ok fails -> "anti-unilateral")
# Both mutants flip this SAME green fixture to a violation, which is what
# makes the exclusion observable — proving it is live law, not dead law.
let c = import "../../contracts/council.ncl" in
let constitution = {
  seats = [
    { id = "architect", role = "boundary lens", domain = "boundary", standing = 'standing },
    { id = "maintainer", role = "merge gate", domain = "merge", standing = 'standing },
    { id = "auditor", role = "process + residue", domain = "process", standing = 'standing },
    { id = "human", role = "head / ultimate arbiter", domain = "taste", standing = 'standing, head = true },
    { id = "guest-x", role = "summoned domain lens", domain = "guest", standing = 'guest },
  ],
  decision_types = ["ratify"],
  delegation = [
    # deliberately NO must_assent — this is the case where head-ratification
    # cannot paper over the tally exclusion, unlike `close` in the shipped law.
    { decision_type = "ratify", owner = "architect", required_assent = 'full },
  ],
} in
{
  decisions = [
    {
      id = "R1",
      type = "ratify",
      proposer = { kind = 'agent, name = "architect" },
      at = "deadbeef",
      assent = ["architect", "maintainer", "auditor"],
      verdict = "ratified",
      grounding = {
        claim = "full machine consensus reached: the three non-head, non-guest standing seats all assented",
        witness = { name = "architect", at = "deadbeef" },
      },
    },
  ],
} | c.DecisionLedger constitution
