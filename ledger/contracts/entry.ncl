# The ledger ENTRY contract — the machine-checkable shape of a typed-claim
# record. Named `Entry` (the paper's own term for a record's units) because
# dag.ncl already exports `Node` meaning a campaign DAG node; reusing the word
# would misread as DAG machinery to anyone outside this pass (ruling D-7).
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
#   - questions carry a discharge condition AND a named closer
#   - edges typed by consequence
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

  SignerKind = std.contract.custom (fun _label v =>
    if matches v 'human "human" || matches v 'agent "agent"
       || matches v 'source "source" || matches v 'derived "derived"
    then 'Ok v
    else 'Error { message = "SignerKind: expected human|agent|source|derived (tag or string)" }
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
  # name. The name/kind coherence rule is ENFORCED by SignerDesignates below
  # (ruling D-3) — in the draft it was a comment, which is not an evaluator.
  Signer = {
    kind | SignerKind,
    name | NonEmptyString | optional,
  },

  # --- Edges, typed by consequence ------------------------------------------
  #
  # Adopted from docket, which has the better split: the two kinds differ in
  # what happens when the target is deleted. `depends` — this entry breaks.
  # `because` — only its stated reason is orphaned. A single untyped reference
  # cannot express that difference, and the difference is the whole point.
  Ref = NonEmptyString,

  # Both edge arrays are declared `optional` with NO fallback value, and every
  # consumer guards through this one helper: materializing an empty array via
  # a field fallback would make YAML fixtures depend on contract application
  # order, and the predicates must also run bare over raw YAML-parsed data.
  edges_of | doc "an entry's inbound derivation edges: depends and because combined"
    = fun n =>
      (if std.record.has_field "depends" n then n.depends else [])
      @ (if std.record.has_field "because" n then n.because else []),

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
    # half; the closer half is missing everywhere today.
    discharge | NonEmptyString | optional,
    closer | NonEmptyString | optional,

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

  # A claim carries axis coordinates; a question does not (it asserts no
  # truth-value, so there is nothing for the axes to be conditions on).
  ClaimHasAxes = fun n =>
    (!(matches n.assertion 'claim "claim") || std.record.has_field "axes" n)
    && (!(matches n.assertion 'question "question")
        || !(std.record.has_field "axes" n)),

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
  # comment on Signer.name, which is not an evaluator). A non-derived signer
  # names its party; a derived signer carries no name AND at least one inbound
  # edge — the designation IS the edges. `kind` here is the Signer record's
  # field (human|agent|source|derived), never docket's `kind` axis and never
  # the assertion axis.
  SignerDesignates = fun n =>
    if matches n.signer.kind 'derived "derived"
    then
      !(std.record.has_field "name" n.signer)
      && std.array.length (edges_of n) > 0
    else std.record.has_field "name" n.signer,

  # The closed predicate set, lifted. Exactly these nine and no others.
  # std.contract.all_of reports the FIRST failing contract, but every red
  # fixture is single-violation by construction (proved by reversing this
  # list: all cases still pass), so order is currently irrelevant to
  # attribution — it is only a tie-break for future multi-violation
  # instances.
  lifted = [
    asContract "CorroborationBacked" CorroborationBacked,
    asContract "VouchBacked" VouchBacked,
    asContract "ProvenanceGate" ProvenanceGate,
    asContract "QuestionRoutable" QuestionRoutable,
    asContract "ResidualIsQuestion" ResidualIsQuestion,
    asContract "ClaimHasAxes" ClaimHasAxes,
    asContract "CertifiabilityFibered" CertifiabilityFibered,
    asContract "NonMonotoneNamesCure" NonMonotoneNamesCure,
    asContract "SignerDesignates" SignerDesignates,
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
  # Deliberately MINIMAL: per-entry shape conformance plus the two corpus
  # properties. The nine predicates are NOT applied here — a contract aborts
  # at the first violation, and batch violation-collection over a corpus is
  # exactly the future batch-validator's job (the design reason the
  # predicates are bare booleans). Both edge kinds must resolve within the
  # aggregate: the depends/because difference is what DELETION of the target
  # means for the record's evolution, not a license to author a reference
  # that never resolved at all.
  EntryStore = std.contract.custom (fun _label value =>
    let entries = value.entries in
    # Per-element Entry conformance, EAGER: `std.contract.apply` alone stays
    # lazy and a malformed entry slips through `nickel export`; the
    # `std.deep_seq (e | Entry)` annotation raises the violation here.
    let _entry_conformance =
      std.array.fold_left
        (fun acc en => std.deep_seq (en | Entry) acc)
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
    let all_edges_resolve =
      std.array.all
        (fun en =>
          std.array.all
            (fun r => std.record.has_field r id_set)
            (edges_of en))
        entries
    in
    # Force the per-element applications before the structural verdict so a
    # malformed entry fails the contract rather than being skipped lazily.
    std.seq _entry_conformance (
      if !unique_ids then 'Error { message = "EntryStore: duplicate entry id" }
      else if !all_edges_resolve then
        'Error { message = "EntryStore: dangling edge — a depends/because ref does not resolve to a declared entry id" }
      else 'Ok value
    )
  ),
}
