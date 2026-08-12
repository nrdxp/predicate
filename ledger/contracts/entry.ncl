# The ledger ENTRY contract — the machine-checkable shape of a typed-claim
# record. Named `Entry` (the paper's own term for a record's units) because
# dag.ncl already exports `Node` meaning a campaign DAG node; reusing the word
# would misread as DAG machinery to anyone outside this pass (ruling D-7).
#
# This file is the MACHINE half of the vocabulary; the prose half — the
# backing × assertion product, the two evidence species, the self-vouch
# policy, and the pen law — is docs/entries.md, the single home every other
# statement references.
#
# Scope discipline: this contract's ONLY job is to make a ledger record
# machine-checkable for well-formedness against the formalism. It deliberately
# does NOT link claims to code — no markers, no evaluator runners, no register.
# That is docket's job, and docket is optional: the ledger's value (keeping
# agents coherent and honest about what they actually know) stands alone.
#
# What it enforces is exactly the formalism's shape:
#   - the assertion axis: an entry asserts a truth-value, or asks something
#   - the two evidence species, and nothing between them
#   - a recoverable signer on every entry, ENFORCED (ruling D-3)
#   - the provenance gate, scoped to claims (ruling D-2)
#   - questions carry a discharge condition AND a designated closer
#   - questions carry NO axis coordinates — but a claim is not required to
#     carry them: assessment is an authoring obligation borne by the
#     surfaces whose authors hold it (worker_ibc premises), never a
#     universal shape law, and an unassessed claim is REPORTED, not refused
#   - edges typed by consequence, derivation and closure alike
#
# The predicates run at BOTH granularities — a lone entry and a corpus — so
# the choice of granularity is a scope for the law, never a loophole in it.
#
# Two hard-won idioms govern every definition below; both were proved by run
# before this file was written (the boundary's spike-first rule):
#
#   1. Dual comparison (ruling D-8). YAML carries strings, Nickel enums are
#      tags, and `==` between them is silently FALSE — so a bare
#      `n.backing != 'corroborated` against YAML data is unconditionally true
#      and the predicate short-circuits to PASS, enforcing nothing. Every enum
#      comparison in a predicate body therefore goes through the single
#      `matches` helper. Normalizing inside the enum contracts instead would
#      not help: the predicates are deliberately exposed as bare booleans so a
#      batch validator can collect EVERY violation over raw YAML-parsed data,
#      and contract-time normalization never reaches them.
#
#   2. The named lift (ruling D-9). A bare `fun n => bool` is not a valid
#      contract in nickel 1.14, and `std.contract.from_predicate` fails
#      anonymously — no way to satisfy the right-reason discipline (every red
#      names its violated predicate). Each predicate stays a bare boolean
#      function (the batch-validation design stands) and gains its contract
#      form through ONE generic lift, `asContract`, which carries the name
#      into the error message.
{
  # Shared dual-comparison helper (ruling D-8): true iff v is the enum tag OR
  # the string form YAML carries. The ONLY sanctioned way to compare an enum
  # field inside a predicate body.
  matches = fun v tag str => v == tag || v == str,

  # The generic lift (ruling D-9): a bare boolean predicate becomes a named
  # contract whose failure message carries the predicate's own token.
  asContract = fun name pred =>
    std.contract.custom (fun _label value =>
      if pred value then 'Ok value else 'Error { message = "%{name} violated" }
    ),

  NonEmptyString = std.contract.custom (fun _label v =>
    if std.is_string v && std.string.length v > 0
    then 'Ok v
    else 'Error { message = "NonEmptyString: expected a non-empty string" }
  ),

  # A git commit in the ledger subrepo. The record IS the git history, so a
  # record-state reference is a commit — no separate versioning invented.
  CommitRef = std.contract.custom (fun _label v =>
    if std.is_string v && std.string.is_match "^[0-9a-f]{7,40}$" v
    then 'Ok v
    else 'Error { message = "CommitRef: expected a 7-40 char lowercase hex commit hash" }
  ),

  # --- Enums (value-restricted tag-or-string, ruling D-6) -------------------
  #
  # YAML instances carry strings, not Nickel tags; a bare [| 'x, .. |] enum
  # rejects every YAML entry on arrival, and std.enum.TagOrString accepts ANY
  # string and loses the value restriction. These accept exactly the allowed
  # set in either form — the discipline.ncl / EvidenceMethod idiom, written as
  # named customs so a shape red carries its own token.

  # `SignerKind`'s dimension is designation-MODE, not "who": `derived` is
  # already a mode where the name is structurally absent and the designation
  # lives in the edges. `unattributed` is the mode "no designation is
  # recoverable — this record predates the signing regime", stated rather
  # than omitted. Designation stays total: every entry says HOW its party is
  # designated, including "not recoverably" (docs/entries.md carries the
  # classification consequence — no closure Backing can admit "unknown").
  SignerKind = std.contract.custom (fun _label v =>
    if matches v 'human "human" || matches v 'agent "agent"
       || matches v 'source "source" || matches v 'derived "derived"
       || matches v 'unattributed "unattributed"
    then 'Ok v
    else 'Error { message = "SignerKind: expected human|agent|source|derived|unattributed (tag or string)" }
  ),

  # `CloserKind` is deliberately NOT `SignerKind`, though both range over
  # designation modes: a closer is the party who COULD close, so the modes
  # that assert no reachable party are incoherent for it. `derived` designates
  # by inbound edges — an entry that does not exist yet has none — and
  # `unattributed` asserts nothing is recoverable, which routes to nobody.
  # Reusing the signer's enum would admit both and make an unroutable question
  # representable, so the closed set here is exactly human|agent|source.
  CloserKind = std.contract.custom (fun _label v =>
    if matches v 'human "human" || matches v 'agent "agent"
       || matches v 'source "source"
    then 'Ok v
    else 'Error { message = "CloserKind: expected human|agent|source (tag or string)" }
  ),

  # backing: the evidence species, per the formalism. `corroborated` is a
  # re-runnable check that HAS BEEN RUN — a named-but-unrun check is not
  # backing, it is a dispatchable question. `vouched` is a named admitted
  # witness. `unclosed` is neither. `residual` is open by theorem.
  Backing = std.contract.custom (fun _label v =>
    if matches v 'corroborated "corroborated" || matches v 'vouched "vouched"
       || matches v 'unclosed "unclosed" || matches v 'residual "residual"
    then 'Ok v
    else 'Error { message = "Backing: expected corroborated|vouched|unclosed|residual (tag or string)" }
  ),

  # assertion: whether a truth-value is carried. The source's name for this
  # axis is `assertion`, NOT `kind` — docket's `kind` is a different axis
  # (requirement/invariant/constraint) and the two must not collide.
  Assertion = std.contract.custom (fun _label v =>
    if matches v 'claim "claim" || matches v 'question "question"
    then 'Ok v
    else 'Error { message = "Assertion: expected claim|question (tag or string)" }
  ),

  # --- Signer ---------------------------------------------------------------
  #
  # Who asserted this. NOT an identity system and not forgery-resistant: "who
  # authored this" is a claim about what happened outside the record, so it is
  # undetermined and admits no check at any power. Naming the party IS the
  # terminal move — what the formalism prescribes where determination fails.
  #
  # `derived` is the synthesis case: the designation IS the inbound edges, so
  # a derived entry's provenance is read off `depends`/`because` rather than a
  # name. `unattributed` is the migration case: no party is recoverable at
  # all, and no edges stand in for one either — the record says so, rather
  # than fabricating a witness or omitting the field. The name/kind coherence
  # rule is ENFORCED by SignerDesignates below (ruling D-3) — in the draft it
  # was a comment, which is not an evaluator.
  Signer = {
    kind | SignerKind,
    name | NonEmptyString | optional,
  },

  # --- Closer ---------------------------------------------------------------
  #
  # Who CAN close a question — the same designation shape as Signer, over a
  # narrower set of modes (CloserKind above). It is PROSPECTIVE ROUTING
  # METADATA, never accountability: the party class is often known where the
  # individual is not, so `name` is optional here in a way `Signer`'s is not
  # (SignerDesignates enforces the signer's; nothing enforces a closer's,
  # deliberately). Accountability for a close rests on the CLAIM that closes
  # it, whose own signer is strictly name-enforced, so a kind-only closer
  # costs the record nothing. Machine-readable so escalation is a lookup
  # rather than a string match: escalate iff `closer.kind` is human.
  Closer = {
    kind | CloserKind,
    name | NonEmptyString | optional,
  },

  # --- Edges, typed by consequence ------------------------------------------
  #
  # Adopted from docket, which has the better split: the two kinds differ in
  # what happens when the target is deleted. `depends` — this entry breaks.
  # `because` — only its stated reason is orphaned. A single untyped reference
  # cannot express that difference, and the difference is the whole point.
  #
  # `discharges` and `supersedes` are the CLOSURE edges, and they run the
  # other way: a derivation edge says where an entry came from, a closure edge
  # says what it retires. They stay distinct from derivation because their
  # consequences differ again — a discharged question was ANSWERED, a
  # superseded one was merged into a survivor and never answered at all, and
  # collapsing the two exits would lose which happened. Neither is a
  # derivation edge, so neither designates a `derived` signer and neither
  # satisfies the provenance gate: `edges_of` stays derivation-only.
  Ref = NonEmptyString,

  # Every edge array is declared `optional` with NO fallback value, and every
  # consumer guards through this one helper: materializing an empty array via
  # a field fallback would make YAML fixtures depend on contract application
  # order, and the predicates must also run bare over raw YAML-parsed data.
  refs_of | doc "the refs under an entry's optional array field; [] when absent"
    = fun name n => if std.record.has_field name n then n."%{name}" else [],

  edges_of | doc "an entry's inbound derivation edges: depends and because combined"
    = fun n => refs_of "depends" n @ refs_of "because" n,

  # --- Check: a corroboration -----------------------------------------------
  #
  # `ran` is the field the existing contracts are missing everywhere: they
  # name a mechanism and cannot say whether it was executed. `at` anchors the
  # run to the record state, so staleness is decidable rather than a
  # judgement. When `ran` is false, `at` records the state the check was
  # AUTHORED against — still required, because a check with no anchor cannot
  # be judged fresh or stale at any later point (delegated decision, pass 1).
  Check = {
    command | NonEmptyString,
    ran | Bool,
    at | CommitRef,
  },

  # --- Witness: a vouch -----------------------------------------------------
  #
  # Testimony is an EVENT, not a status. `at` is what makes a review
  # snapshot-sound in the model's sense — it certifies the artifact as it
  # stood when read. A vouch without it silently claims an endurance it
  # cannot have, and staleness against a changed target becomes undetectable.
  Witness = {
    name | NonEmptyString,
    at | CommitRef,
  },

  # --- The three axes -------------------------------------------------------
  #
  # From the paper's cell table: three binary axes, eight nominal cells, six
  # inhabited, two EMPTY BY THEOREM. Each inhabited cell names its own trust
  # anchor and minimal cure, so recording a claim's coordinates makes its cure
  # DERIVABLE rather than authored — which is the point of carrying them.
  #
  # Certifiability is FIBERED on determination: where determination fails
  # there is no record-only predicate for the coordinate to range over, so it
  # is UNDEFINED — not false. Rows 7 and 8 are exactly the error of positing
  # certifiability anyway, and CertifiabilityFibered refutes them. Encoding
  # certifiability as a plain Bool would make those two unrepresentable states
  # representable, so it is optional and its presence is constrained below.
  #
  # No coordinate carries a fallback value (ruling D-1): a coordinate the
  # author did not assert is a silently wrong classification, not a benign
  # omission.
  Axes = {
    determined | Bool,
    certifiable | Bool | optional,
    monotone | Bool,
  },

  # The cure, read straight off the cell table — the SINGLE normative source
  # of that mapping (ruling D-5). Not a judgement, a lookup: T1 =
  # determination failure, T2 = certifiability failure, T3 = monotonicity
  # failure; labels compose. The draft's "ill-formed" guard branch is removed:
  # a determined claim missing its certifiability coordinate is
  # CertifiabilityFibered's violation, and a lookup over validated input
  # carries no validation of its own.
  cure_for | doc "minimal cure for a claim's axis coordinates, per the cell table"
    = fun a =>
      if !a.determined then
        (if a.monotone
         then "T1: witness of history — an admitted signer or attestor"
         else "T1+T3: an admitted signer, plus a freshness mechanism")
      else if a.certifiable && a.monotone then
        "none — verify"
      else if a.certifiable && !a.monotone then
        "T3: a liveness holder (witness quorum or gossip), or restriction to \"as of t\", or an accepted expiry"
      else if a.monotone then
        "T2: a voucher — an admitted judgement; or restriction to a decidable subclass"
      else
        "T2+T3: a voucher, plus a freshness mechanism",

  # --- The entry ------------------------------------------------------------
  Entry = {
    id | NonEmptyString,
    statement | NonEmptyString,
    assertion | Assertion,
    backing | Backing,
    signer | Signer,

    check | Check | optional,
    witness | Witness | optional,

    # Required on questions: the condition that would close it, and the party
    # who can. `signpost` in the existing tech-debt contract is the condition
    # half. The two halves are named for their tense and read as a pair:
    # `discharge` is prospective prose, `discharges` below is the
    # retrospective edge that pays it.
    discharge | NonEmptyString | optional,
    closer | Closer | optional,

    # Required on claims, absent on questions: a question asserts no
    # truth-value, so it has no axis coordinates to carry.
    axes | Axes | optional,

    # Required when a claim is non-monotone: the cell table's cure for a T3
    # failure is a freshness mechanism or an accepted expiry. Naming it is
    # what stops a non-monotone claim being promoted into documentation as a
    # standing invariant that quietly expires.
    freshness | NonEmptyString | optional,

    depends | Array Ref | optional,
    because | Array Ref | optional,

    # The closure edges. `discharges` names questions this entry ANSWERS —
    # gated by DischargeBacked below and target-typed by EntryStore, so a
    # close is only ever claimed by something that carries evidence.
    # `supersedes` names entries this one retires unanswered, and carries no
    # backing condition: merging a duplicate question asserts nothing about
    # the question, which is exactly why it is a second edge and not a second
    # meaning for the first. Its one condition is relational and lands in
    # EntryStore — the retirement chain must reach a survivor.
    discharges | Array Ref | optional,
    supersedes | Array Ref | optional,
  },

  # --- The constraints that make it worth having ----------------------------
  #
  # Bare boolean predicates rather than contracts, so a batch validator can
  # collect EVERY violation in a corpus (a contract application aborts at the
  # first, which under-reports). Their contract forms are derived through
  # `asContract` in the `lifted` list below — one logic definition per rule.
  #
  # The self-vouch admission rule the draft carried is gone (ruling D-4):
  # admission is the consumer's policy, never the shape's. A self-vouched
  # claim is SHAPE-VALID and the record shows it — which is what makes
  # self-vouch detection queryable at all.

  # A corroborated claim must name a check that WAS RUN. This is the single
  # distinction absent from every existing predicate contract.
  CorroborationBacked = fun n =>
    !(matches n.backing 'corroborated "corroborated")
    || (std.record.has_field "check" n && n.check.ran),

  # A vouched claim must name its witness and the state it testified against.
  VouchBacked = fun n =>
    !(matches n.backing 'vouched "vouched")
    || std.record.has_field "witness" n,

  # MISCLOSURE MADE UNREPRESENTABLE. A `discharges` edge asserts that this
  # entry ANSWERS the question it names, so only an entry that itself carries
  # closed evidence may bear one. Two ways to violate it, and both are real
  # failure modes of the record this contract exists to stop: a `synthesis`
  # claim (unclosed) is a PROPOSAL until something closes it, so letting it
  # discharge would let an unratified answer retire the question that asked
  # for ratification; and a `question` asserts no truth-value at all, so a
  # question closing a question is a chain of things none of which is known.
  # `residual` needs no clause — ResidualIsQuestion already forces it onto the
  # question side, where this predicate refuses it. The rule is about the
  # DISCHARGER's own backing; whether the target is really a question is a
  # corpus property, decided by EntryStore where resolution already lives.
  DischargeBacked = fun n =>
    std.array.length (refs_of "discharges" n) == 0
    || (matches n.assertion 'claim "claim"
        && (matches n.backing 'corroborated "corroborated"
            || matches n.backing 'vouched "vouched")),

  # THE PROVENANCE GATE — the structural definition of a hallucination. An
  # unbacked CLAIM with no inbound edge is not vaguely unsupported: it is a
  # claim that declines to state where it came from, the one thing every
  # other designation supplies. Scoped to claims (ruling D-2): a question
  # asserts nothing, so a frontier question is legitimately edge-free at
  # birth — the draft's unscoped gate made `frontier` unrecordable.
  ProvenanceGate = fun n =>
    !(matches n.assertion 'claim "claim")
    || !(matches n.backing 'unclosed "unclosed")
    || std.array.length (edges_of n) > 0,

  # A question carries BOTH halves or it is not routable.
  QuestionRoutable = fun n =>
    !(matches n.assertion 'question "question")
    || (std.record.has_field "discharge" n && std.record.has_field "closer" n),

  # `residual` means open by theorem. DERIVED, not stipulated: the cell table
  # is exhaustive over claims, and every one of its six inhabited cells names
  # a cure — rows 5 and 6 (undetermined) are cured by an admitted signer, not
  # left open. The two empty cells are not claims lacking cures; they are
  # incoherent coordinate combinations refuted by the determination gate. So
  # NO CLAIM IS EVER OPEN BY THEOREM, and `residual` is question-shaped by
  # consequence.
  ResidualIsQuestion = fun n =>
    !(matches n.backing 'residual "residual")
    || matches n.assertion 'question "question",

  # A question carries NO axis coordinates: it asserts no truth-value, so
  # there is nothing for the axes to be conditions on. That category error is
  # the whole of this predicate.
  #
  # The converse half — every claim carries axes — was removed when the
  # predicate went live on the corpus path, as a DISCREPANCY RESOLUTION
  # between two ratified artifacts rather than a weakening. Expressibility is
  # not the reason: the dialect has an `axes::` companion the extractor
  # parses, so a claim CAN arrive assessed. Whether one MUST is the separate
  # question, and the answer is no. A gate refusing axis-less claims would
  # not obtain the coordinates; it would condition every future walk to
  # fabricate them to pass — the law manufacturing the exact defect this
  # contract exists to refuse. So absence is REPORTED instead:
  # entries_query.ncl's `unpaid_cures` view is BUILT to read it and list
  # those claims as `unassessed` rather than presenting an empty cure report
  # as a clean bill. `unassessed` follows `unclosed`: absence is made
  # VISIBLE, never forbidden.
  #
  # The half that died was an AUTHORING OBLIGATION, not a universal shape
  # law, and it survives where the author carries that obligation — an IBC
  # premise is assessed ground by definition, so worker_ibc.ncl requires axes
  # on its own surface rather than inheriting the requirement from here.
  #
  # Presence is all this leaves unstated: axes that ARE carried stay governed
  # by CertifiabilityFibered and NonMonotoneNamesCure, so no conditional
  # clause belongs here restating them.
  ClaimHasAxes = fun n =>
    !(matches n.assertion 'question "question")
    || !(std.record.has_field "axes" n),

  # Certifiability is fibered on determination — undefined where determination
  # fails, required where it holds. This is what makes cell-table rows 7 and 8
  # unrepresentable rather than merely unpopulated.
  CertifiabilityFibered = fun n =>
    !(std.record.has_field "axes" n)
    || (if n.axes.determined
        then std.record.has_field "certifiable" n.axes
        else !(std.record.has_field "certifiable" n.axes)),

  # A non-monotone claim must name its T3 cure. This is the promotion gate's
  # content: without it, a claim true when written becomes a documented
  # invariant that expires silently.
  NonMonotoneNamesCure = fun n =>
    !(std.record.has_field "axes" n)
    || n.axes.monotone
    || std.record.has_field "freshness" n,

  # Signer designation, ENFORCED (ruling D-3; the draft carried this as a
  # comment on Signer.name, which is not an evaluator). A non-derived,
  # non-unattributed signer names its party; a derived signer carries no name
  # AND at least one inbound edge — the designation IS the edges.
  # `unattributed` carries no name either, but requires NO edges: that
  # requirement is `derived`'s alone, and a migrated record predating the
  # signing regime has no inbound-edge stand-in for the party it cannot name.
  # A NAMED `unattributed` is a contradiction — the mode asserts nothing is
  # recoverable, so a name present is the entry lying about its own kind.
  # `kind` here is the Signer record's field
  # (human|agent|source|derived|unattributed), never docket's `kind` axis and
  # never the assertion axis.
  SignerDesignates = fun n =>
    if matches n.signer.kind 'derived "derived"
    then
      !(std.record.has_field "name" n.signer)
      && std.array.length (edges_of n) > 0
    else if matches n.signer.kind 'unattributed "unattributed"
    then !(std.record.has_field "name" n.signer)
    else std.record.has_field "name" n.signer,

  # `proved` never means "I ran it" — it means a run happened AND is
  # attributable. An `unattributed` signer's `ran: true` is testimony about a
  # run from a party the record cannot name: indistinguishable from an
  # asserted-ran, so it cannot ground CorroborationBacked's promise, and
  # equally cannot ground VouchBacked's admitted witness — a vouch is
  # testimony too, and an unattributed party cannot be the one testifying.
  # The exists/ran cut this whole reform holds collapses without an
  # attributable runner. Unattributed evidence — vouch or recorded check — is
  # therefore INADMISSIBLE; the only honest backing for an unattributed
  # signer is `unclosed`. This is party-independent of CorroborationBacked
  # and VouchBacked (which never inspect `signer.kind`), so it is its own
  # predicate rather than a clause folded into either. Closure stays
  # reachable prospectively — a party-independent re-run today enters as
  # freshly SIGNED evidence — docs/entries.md narrows accordingly
  # ("can never close on its recorded evidence").
  UnattributedUnclosed = fun n =>
    !(matches n.signer.kind 'unattributed "unattributed")
    || matches n.backing 'unclosed "unclosed",

  # The closed predicate set, lifted. Exactly these eleven and no others.
  # std.contract.all_of reports the FIRST failing contract, but every red
  # fixture is single-violation by construction (proved by reversing this
  # list: all cases still pass), so order is currently irrelevant to
  # attribution — it is only a tie-break for future multi-violation
  # instances.
  lifted = [
    asContract "CorroborationBacked" CorroborationBacked,
    asContract "VouchBacked" VouchBacked,
    asContract "DischargeBacked" DischargeBacked,
    asContract "ProvenanceGate" ProvenanceGate,
    asContract "QuestionRoutable" QuestionRoutable,
    asContract "ResidualIsQuestion" ResidualIsQuestion,
    asContract "ClaimHasAxes" ClaimHasAxes,
    asContract "CertifiabilityFibered" CertifiabilityFibered,
    asContract "NonMonotoneNamesCure" NonMonotoneNamesCure,
    asContract "SignerDesignates" SignerDesignates,
    asContract "UnattributedUnclosed" UnattributedUnclosed,
  ],

  # --- EntryStore: corpus-level integrity -----------------------------------
  #
  # Intrinsic gate over an aggregate `{ entries = [...] }` instance —
  # id-uniqueness and edge-resolution are corpus properties no single-entry
  # contract can decide. Chosen over a validator-level bash check because the
  # contract is the law and a runner must never re-implement an invariant
  # (the council harness's own rule); mirrors DepositStore / dag.ncl,
  # including the record-as-set idiom for O(1) membership.
  #
  # Per-entry conformance here is the FULL law — shape plus the eleven lifted
  # predicates — not shape alone. A predicate must be live on every validation
  # path whose consumers read the property it guards, and the corpus is the
  # only shape a real record takes: a predicate that fires only on a lone
  # entry is a predicate that never fires. `DischargeBacked` is the case that
  # proved it — misclosure was declared unrepresentable while the live path
  # never evaluated it.
  #
  # Fail-fast is the right disposition for a GATE: it needs soundness, and
  # aborting at the first violation is sound. Batch violation-COLLECTION
  # remains a future reporter's job, and it stays cheap to build because the
  # predicates are bare booleans it can fold over the same corpus — one logic
  # definition serving refusal and reporting alike.
  #
  # Every edge kind must resolve within the aggregate: the depends/because
  # difference is what DELETION of the target means for the record's
  # evolution, not a license to author a reference that never resolved at all.
  #
  # The closure edges add the conditions no per-entry contract can decide:
  # `discharges` is claim -> QUESTION by type, and the target's assertion is
  # only readable once the corpus is in hand. Target-typing therefore lands
  # here, beside resolution, rather than growing the per-entry closed set —
  # DischargeBacked already carries the half that IS per-entry (the
  # discharger's own backing). `supersedes` types nothing — any entry may be
  # retired unanswered by a survivor — but it must TERMINATE, which is a
  # property of the relation rather than of any entry in it.
  EntryStore = std.contract.custom (fun _label value =>
    let entries = value.entries in
    # Per-element conformance, EAGER: `std.contract.apply` alone stays lazy
    # and a violating entry slips through `nickel export`; the `std.deep_seq`
    # annotation raises it here. Shape FIRST, then the lifted predicates, so a
    # malformed entry fails on its field contract before any predicate reads
    # it — the same composition entry_apply.ncl gives a lone entry, because
    # the two granularities must refuse the same defects.
    let _entry_conformance =
      std.array.fold_left
        (fun acc en =>
          std.deep_seq (en | std.contract.all_of ([Entry] @ lifted)) acc)
        null
        entries
    in
    let ids = std.array.map (fun en => en.id) entries in
    # id set (record) — O(1) membership; cardinality decides id-uniqueness.
    let id_set =
      std.array.fold_left
        (fun acc id =>
          if std.record.has_field id acc then acc
          else std.record.insert id true acc)
        {}
        ids
    in
    let unique_ids =
      std.array.length ids == std.array.length (std.record.fields id_set)
    in
    # resolves NAME: every entry's refs under that optional array field land
    # on a declared id. One helper for all three kinds — the kinds differ in
    # what they MEAN, never in whether they must resolve.
    let resolves = fun name =>
      std.array.all
        (fun en =>
          std.array.all
            (fun r => std.record.has_field r id_set)
            (refs_of name en))
        entries
    in
    let all_edges_resolve =
      std.array.all
        (fun en =>
          std.array.all
            (fun r => std.record.has_field r id_set)
            (edges_of en))
        entries
    in
    # question set (record) — the same O(1) idiom as id_set, so discharges
    # target-typing is a membership test rather than a scan per edge.
    let question_set =
      std.array.fold_left
        (fun acc en =>
          if matches en.assertion 'question "question"
             && !(std.record.has_field en.id acc)
          then std.record.insert en.id true acc
          else acc)
        {}
        entries
    in
    let discharges_target_questions =
      std.array.all
        (fun en =>
          std.array.all
            (fun r => std.record.has_field r question_set)
            (refs_of "discharges" en))
        entries
    in
    # SupersessionTerminates. Resolution was the only condition the corpus
    # placed on a supersession edge, and resolution does not bound the walk: a
    # resolved cycle retires every entry it touches and delivers no survivor.
    # Openness is DERIVED from the closure edges, so each entry in the cycle
    # counts as closed and silently leaves the work lists while remaining, by
    # the record's own account, unanswered. The property is that the relation
    # BOTTOMS OUT — never that it is short; a chain of any depth is well
    # formed exactly when its walk ends in an entry nothing supersedes.
    #
    # Kahn reduction over a record-set of settled ids (the dag.ncl idiom):
    # each round settles every entry whose supersedes targets are all settled;
    # an acyclic relation settles everything within as many rounds as there
    # are entries carrying an edge, and a cycle leaves its members forever
    # unsettled. Entries with no supersedes edge ARE the relation's floors, so
    # they are pre-settled and the reduction pays only for the minority that
    # supersede something. Acyclicity and bottoming-out are one condition over
    # a finite corpus, so this is one check rather than two.
    let bottoms =
      std.array.fold_left
        (fun acc en =>
          if std.array.length (refs_of "supersedes" en) == 0
             && !(std.record.has_field en.id acc)
          then std.record.insert en.id true acc
          else acc)
        {}
        entries
    in
    let risers =
      std.array.filter
        (fun en => std.array.length (refs_of "supersedes" en) > 0)
        entries
    in
    let settle_round = fun settled =>
      std.array.fold_left
        (fun acc en =>
          if std.record.has_field en.id acc then acc
          else if std.array.all
                    (fun r => std.record.has_field r acc)
                    (refs_of "supersedes" en)
          then std.record.insert en.id true acc
          else acc)
        settled
        risers
    in
    let final_settled =
      std.array.fold_left
        (fun acc _i => settle_round acc)
        bottoms
        (std.array.generate (fun i => i) (std.array.length risers))
    in
    let supersession_terminates =
      std.array.length (std.record.fields final_settled)
        == std.array.length (std.record.fields id_set)
    in
    # Force the per-element applications before the structural verdict so a
    # malformed entry fails the contract rather than being skipped lazily.
    std.seq _entry_conformance (
      if !unique_ids then 'Error { message = "EntryStore: duplicate entry id" }
      else if !all_edges_resolve then
        'Error { message = "EntryStore: dangling edge — a depends/because ref does not resolve to a declared entry id" }
      else if !(resolves "discharges") then
        'Error { message = "EntryStore: dangling discharges — a closure edge does not resolve to a declared entry id" }
      else if !(resolves "supersedes") then
        'Error { message = "EntryStore: dangling supersedes — a supersession edge does not resolve to a declared entry id" }
      else if !discharges_target_questions then
        'Error { message = "EntryStore: discharges target is not a question — a claim answers questions, nothing else" }
      else if !supersession_terminates then
        'Error { message = "EntryStore: SupersessionTerminates — the supersedes relation cycles, so the entries it retires name no surviving entry to carry them" }
      else 'Ok value
    )
  ),
}
