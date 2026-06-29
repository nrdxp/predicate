# council.ncl — the council's law as a Nickel contract (two layers), a first-class
# peer of dag.ncl / worker_ibc.ncl.
#
#   Constitution           (static, per-project): seats + decision_types + delegation.
#   DecisionLedger(const)   (dynamic, per-campaign): decisions validated vs the
#                           constitution.
#
# Why intrinsic: like dag.ncl, every law below is an INTRINSIC contract, so the
# single command `nickel export <fixture>` IS the gate — a gapped/unilateral/
# ungrounded/barred/no-consent/un-ratified law makes the export exit non-zero, with
# no JSON-roundtrip step a headless orchestrator could skip.
#
# Anti-incoherence invariant (stated once): every decision_type has EXACTLY ONE
# delegation rule, every owner / must_assent co-signer is a declared seat, and every
# subset quorum is in 0 < q <= |seats|. You cannot convene under an under-specified
# law: a gap fails the export rather than deadlocking at the first deliberation.
#
# Two explicit named guards beyond the assent-class check make defeater-resistance
# structural (a later reclassification cannot silently drop a required co-signer):
#   merge-consent      a 'merge decision MUST carry the maintainer's recorded assent.
#   head-ratification  a 'dag-amendment OR 'close decision MUST carry the head (human)
#                      in assent — for 'close, ATOP full machine consensus. The head
#                      is a standing seat but the ratifier, excluded from the 'full
#                      machine-consensus tally so consensus and ratification stay two
#                      distinct gates, both required to close.
# Both are encoded uniformly as `must_assent` on a DelegationRule and checked BEFORE
# the assent-class predicate, so each violation surfaces its own named reason.
{
  NonEmptyString = std.contract.from_predicate (fun v =>
    std.is_string v && std.string.length v > 0),

  Seat = {
    id | String,
    role | NonEmptyString,
    domain | NonEmptyString,
    standing | [| 'standing, 'guest |],
    # the head (human) is a standing seat but the RATIFIER, not a machine-council
    # member: excluded from the 'full machine-consensus tally and instead required
    # atop it via must_assent on the terminal decision-types.
    head | Bool | optional | default = false,
    # the conductor (composer) is a standing council MEMBER but the moderator/hub: it
    # CONDUCTS the consensus rather than voting in it. Excluded from the 'full tally so
    # the seat that orchestrates the vote cannot self-certify its own conducted close —
    # the same un-decorrelation the council exists to prevent.
    conductor | Bool | optional | default = false,
  },

  DelegationRule = {
    decision_type | String,
    owner | String,                                  # a seat id
    required_assent | [| 'single, 'subset, 'full, 'human |],
    quorum | Number | optional | default = 0,        # used iff required_assent == 'subset
    # seats that MUST appear in `assent` regardless of the assent class — the
    # explicit named guards (merge-consent, head-ratification). Default none.
    must_assent | Array String | optional | default = [],
  },

  # The constitution: the anti-incoherence invariants are enforced intrinsically, so a
  # gapped or ambiguous law fails the export rather than deadlocking at runtime.
  Constitution = std.contract.custom (fun _label value =>
    let seats = value.seats in
    let dtypes = value.decision_types in
    # normalize rules THROUGH DelegationRule first: fills `quorum`/`must_assent`
    # defaults and validates shape, so the checks below read total fields.
    let deleg = std.array.map (fun r => r | DelegationRule) value.delegation in
    let _sc = std.array.fold_left (fun acc s => std.deep_seq (s | Seat) acc) null seats in
    let _rc = std.array.fold_left (fun acc r => std.deep_seq r acc) null deleg in
    let seat_ids = std.array.map (fun s => s.id) seats in
    let n = std.array.length seats in
    let rules_for = fun dt => std.array.filter (fun r => r.decision_type == dt) deleg in
    let every_one = std.array.all (fun dt => std.array.length (rules_for dt) == 1) dtypes in
    let no_orphan = std.array.all (fun r => std.array.elem r.decision_type dtypes) deleg in
    let owners_ok = std.array.all (fun r => std.array.elem r.owner seat_ids) deleg in
    let quorum_ok = std.array.all (fun r =>
      if r.required_assent == 'subset then r.quorum > 0 && r.quorum <= n else true) deleg in
    let consent_seats_ok = std.array.all (fun r =>
      std.array.all (fun sid => std.array.elem sid seat_ids) r.must_assent) deleg in
    std.seq _sc (std.seq _rc (
      if !every_one then 'Error { message = "anti-incoherence: a decision_type lacks exactly one delegation rule" }
      else if !no_orphan then 'Error { message = "delegation rule references an undeclared decision_type" }
      else if !owners_ok then 'Error { message = "delegation owner is not a declared seat" }
      else if !quorum_ok then 'Error { message = "subset rule needs 0 < quorum <= |seats|" }
      else if !consent_seats_ok then 'Error { message = "anti-incoherence: a must_assent co-signer is not a declared seat" }
      else 'Ok value))),

  Decision = {
    id | String,
    type | String,
    assent | Array String,                           # seat ids that assented
    barred | Array String | optional | default = [], # seats ruled-out for this IBC
    verdict | NonEmptyString,
    grounding | NonEmptyString,                       # Verification Dual: never empty
  },

  # DecisionLedger is a contract CONSTRUCTOR parameterized by the constitution, so each
  # decision is checked against the live delegation table.
  DecisionLedger = fun constitution =>
    std.contract.custom (fun _label value =>
      # normalize each decision THROUGH the Decision contract first: fills the `barred`
      # default and validates shape/NonEmptyString. Checks then run on the normalized form.
      let decisions = std.array.map (fun d => d | Decision) value.decisions in
      let deleg = std.array.map (fun r => r | DelegationRule) constitution.delegation in
      let seats = std.array.map (fun s => s | Seat) constitution.seats in
      # the 'full machine-consensus set: standing seats MINUS the head AND MINUS the
      # conductor. The head ratifies terminal decisions on top of consensus (via
      # must_assent), so it is never in the tally. The conductor (composer) CONDUCTS the
      # vote — it is a member but not a voter, excluded so it cannot self-certify the
      # close it orchestrated. The tally is the independent JUDGING seats alone.
      let machine_ids = std.array.map (fun s => s.id)
        (std.array.filter (fun s => s.standing == 'standing && !s.head && !s.conductor) seats) in
      let deleg_map = std.array.fold_left
        (fun acc r => std.record.insert r.decision_type r acc) {} deleg in
      let _dc = std.array.fold_left (fun acc d => std.deep_seq d acc) null decisions in
      # the assent-class predicate: routine forward-motion needs only the owner
      # ('single) — proportional/standing convening; broader classes only for
      # judgment ('subset), terminal ('full), or head-reserved ('human) types.
      let class_ok = fun d r =>
        if r.required_assent == 'single then std.array.elem r.owner d.assent
        else if r.required_assent == 'subset then std.array.length d.assent >= r.quorum
        else if r.required_assent == 'full then
          std.array.all (fun sid => std.array.elem sid d.assent) machine_ids
        else std.array.elem "human" d.assent in
      let no_barred = fun d => std.array.all (fun sid => !(std.array.elem sid d.assent)) d.barred in
      # the explicit named guards: every must_assent seat must be present REGARDLESS of
      # the assent class, so a later reclassification of `merge`/`dag-amendment` cannot
      # silently drop the maintainer's consent or the head's ratification.
      let consent_ok = fun d r =>
        std.array.all (fun sid => std.array.elem sid d.assent) r.must_assent in
      let consent_reason = fun r =>                    # name the specific guard violated
        if std.array.elem "maintainer" r.must_assent then
          "merge-consent: a 'merge decision must carry the maintainer's recorded assent"
        else if std.array.elem "human" r.must_assent then
          "head-ratification: this decision requires the head (human) in assent"
        else "mandatory co-signer absent from assent" in
      let violation = fun d =>                        # "" iff the decision is lawful
        if !(std.record.has_field d.type deleg_map) then
          "ungoverned: decision references a decision-type with no delegation rule"
        else
          let r = std.record.get d.type deleg_map in
          # guards ordered most-specific-first so each violation surfaces its OWN reason.
          if !(no_barred d) then "no-barred: a barred seat appears in assent"
          else if !(consent_ok d r) then consent_reason r
          else if !(class_ok d r) then
            "anti-unilateral: decision lacks the assent its delegation rule requires"
          else "" in
      let first = std.array.fold_left
        (fun acc d => if acc != "" then acc else violation d) "" decisions in
      std.seq _dc (
        if first != "" then 'Error { message = first } else 'Ok value)),
}
