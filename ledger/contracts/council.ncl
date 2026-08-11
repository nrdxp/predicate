# council.ncl — the council's law as a Nickel contract (two layers), a first-class
# peer of dag.ncl / worker_ibc.ncl. EXTENDS THE ENTRY CORE (entry.ncl): the
# provenance and evidence vocabulary (Signer, CommitRef, Check, Witness) is
# defined once in the core and imported, never restated.
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
#                      machine-consensus tally so its own assent never moves that
#                      tally either way. Consensus and ratification stay two distinct
#                      gates because `consent_ok` runs BEFORE `class_ok` regardless of
#                      tally membership — the exclusion alone does not keep them apart.
# Both are encoded uniformly as `must_assent` on a DelegationRule and checked BEFORE
# the assent-class predicate, so each violation surfaces its own named reason.
#
# The decision reform (G-1/G-2): every decision carries its proposer (core Signer —
# who brought it), `at` (core CommitRef — the record-state it was decided against),
# and a SPECIES-AWARE grounding: a run check XOR an admitted witness, the core's
# corroborated/vouched cut applied at the decision grain. The bare grounding string
# died; "never empty" became "never speciesless". A decision MAY name a `subject` —
# the seat whose CONDUCT it is about (REQUIRED on 'bar: with no subject there is
# nothing to void) — and the subject's assent on its own judgement is void
# (self-assent), exactly as a barred seat's is. Chain order is a tested property:
# intrinsic-content defects (bar-without-subject, self-assent) surface before
# extrinsic state (no-barred) — a seat both subject and barred names the conduct
# conflict, the more informative defect.
let e = import "entry.ncl" in
{
  Seat = {
    id | String,
    role | e.NonEmptyString,
    domain | e.NonEmptyString,
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
    std.seq _sc (
      if !every_one then 'Error { message = "anti-incoherence: a decision_type lacks exactly one delegation rule" }
      else if !no_orphan then 'Error { message = "delegation rule references an undeclared decision_type" }
      else if !owners_ok then 'Error { message = "delegation owner is not a declared seat" }
      else if !quorum_ok then 'Error { message = "subset rule needs 0 < quorum <= |seats|" }
      else if !consent_seats_ok then 'Error { message = "anti-incoherence: a must_assent co-signer is not a declared seat" }
      else 'Ok value)),

  # The species-aware grounding (G-1). Shape: the prose why (`claim` — kept from
  # the old field so a stranger still reads the reason, not just the anchor) plus
  # exactly one species anchor from the core: a Check that RAN (the corroborated
  # cut — a named-but-unrun mechanism is a dispatchable question, not backing) or
  # an admitted Witness. Hand-rolled like the rest of this file's law, so each
  # defect surfaces its own token.
  GroundingShape = {
    claim | e.NonEmptyString,
    check | e.Check | optional,
    witness | e.Witness | optional,
  },
  Grounding = std.contract.custom (fun _label v =>
    if !std.is_record v then
      'Error { message = "grounding-speciesless: a grounding is a record naming its species (a run check or an admitted witness) — the bare string is gone" }
    else
      let shaped = v | GroundingShape in
      let has_check = std.record.has_field "check" shaped in
      let has_witness = std.record.has_field "witness" shaped in
      if has_check && has_witness then
        'Error { message = "grounding-species-ambiguous: both check and witness present — a grounding names exactly one species" }
      else if !has_check && !has_witness then
        'Error { message = "grounding-speciesless: neither check nor witness present — never speciesless" }
      else if has_check && !shaped.check.ran then
        'Error { message = "grounding-speciesless: a named-but-unrun check is not backing — run it or vouch it" }
      else 'Ok shaped),

  Decision = {
    id | String,
    type | String,
    proposer | e.Signer,                             # who brought the decision (G-1)
    at | e.CommitRef,                                # the record-state decided against (G-1)
    assent | Array String,                           # seat ids that assented
    barred | Array String | optional | default = [], # seats ruled-out for this IBC
    # the seat whose CONDUCT this decision is about (G-2). REQUIRED on 'bar —
    # enforced in the violation chain, where the defect gets its own token —
    # and absent on decisions not about a party. The GENERAL "is this target
    # the signer's own conduct" beyond an explicit subject is a review matter:
    # gating it here would fake decidability.
    subject | e.NonEmptyString | optional,
    verdict | e.NonEmptyString,
    grounding | Grounding,                           # Verification Dual: never speciesless
  },

  # DecisionLedger is a contract CONSTRUCTOR parameterized by the constitution, so each
  # decision is checked against the live delegation table.
  DecisionLedger = fun constitution =>
    std.contract.custom (fun _label value =>
      # normalize each decision THROUGH the Decision contract first: fills the `barred`
      # default and validates shape/species (proposer, at, grounding). Checks then run
      # on the normalized form.
      let decisions = std.array.map (fun d => d | Decision) value.decisions in
      let deleg = std.array.map (fun r => r | DelegationRule) constitution.delegation in
      let seats = std.array.map (fun s => s | Seat) constitution.seats in
      # the 'full machine-consensus set: standing seats MINUS the head AND MINUS the
      # conductor. The head is excluded so its own assent never counts toward, or
      # substitutes for, machine consensus — ratification is a SEPARATE requirement,
      # enforced via must_assent/consent_ok below, which runs before this tally
      # regardless of whether the head is a tally member. The conductor (composer)
      # CONDUCTS the vote — it is a member but not a voter, excluded so it cannot
      # self-certify the close it orchestrated. The tally is the independent JUDGING
      # seats alone.
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
        # guards ordered most-specific-first so each violation surfaces its OWN
        # reason. INTRINSIC-CONTENT defects come before any read of extrinsic
        # state (the delegation table, barring): bar-without-subject is the
        # structural precondition of judging self-assent on a bar (no subject,
        # nothing to void), and self-assent precedes no-barred because the
        # subject's void is intrinsic to the decision's own content while
        # barring is extrinsic — a seat both subject and barred surfaces the
        # conduct conflict, the more informative defect (tested property).
        if d.type == "bar" && !(std.record.has_field "subject" d) then
          "bar-without-subject: a 'bar rules on a named seat's conduct — no subject, nothing to void"
        else if std.record.has_field "subject" d && std.array.elem d.subject d.assent then
          "self-assent: seat '%{d.subject}' is this decision's subject and its assent is void — a party does not assent to a ruling on its own conduct"
        else if !(std.record.has_field d.type deleg_map) then
          "ungoverned: decision references a decision-type with no delegation rule"
        else
          let r = std.record.get d.type deleg_map in
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
