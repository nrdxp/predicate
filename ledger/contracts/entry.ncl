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

  # --- Tags -------------------------------------------------------------------
  #
  # The admissible tag vocabulary lives in its OWN file, never inline here:
  # `entry.ncl` is the law, `tag_registry.ncl` is the data the law consults —
  # the same split the corpus/law pair already keeps everywhere else in this
  # file. Exposed as a field (the `matches`/`cure_for` idiom) so a consumer
  # that already imports `entry.ncl` — `entries_query.ncl` among them — reads
  # the registry off `law.tag_registry` rather than importing it a second way.
  tag_registry | doc "the admissible tag vocabulary (ledger/contracts/tag_registry.ncl); the coining bar's data half"
    = import "tag_registry.ncl",

  # A tag NAMES a member of the registry above — closed-set membership, not an
  # open string. This is the coining bar's enforcement half
  # (ledger/log/2026-08-12-tagging-hypothesis.md [G8]): an entry naming a tag
  # the registry does not declare is REFUSED, never merely reported, because
  # the whole point of a registry is that admission is a deliberate edit to
  # it — never a side effect of writing an entry.
  #
  # Enforced at the SHAPE tier — beside `SignerKind` and `Backing`, which are
  # also closed-set membership over a fixed record field — rather than as a
  # twelfth lifted predicate: admission reads no OTHER entry, so it carries
  # none of the corpus-relative content that earns a predicate a seat in
  # `lifted` (`DischargeBacked`, `ProvenanceGate`, ... all consult the corpus
  # around the entry; this does not).
  TagName = std.contract.custom (fun _label v =>
    if std.is_string v && std.record.has_field v tag_registry
    then 'Ok v
    else 'Error { message = "TagName: `%{v}` is not in the admissible tag registry (ledger/contracts/tag_registry.ncl)" }
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
  # collapsing the two exits would lose which happened. `discharges` never
  # designates a `derived` signer and never satisfies the provenance gate — an
  # answer is not where its own writer came from. `supersedes` DOES satisfy
  # the gate (ruling-provenance-gate fix (i)): a retraction tethered to the
  # record only by naming what it retires is not the hallucination the gate
  # exists to catch, so `ProvenanceGate` consults it beside `provenance_of` at
  # its own call site — the one clause that reads it, deliberately, since
  # neither `SignerDesignates`' derived arm nor `DirectiveDesignates` has any
  # reason to.
  #
  # PROVENANCE IS TAGGED ON `because` ALONE (ruling-provenance-representation
  # [SR4]): `depends`, `discharges` and `supersedes` stay plain corpus ids —
  # the record's own deletion semantics decide it. `depends` means THIS ENTRY
  # BREAKS if the target is deleted, so an antecedent outside the corpus has
  # no deletion event to break on; only `derives-from::` can name what the
  # graph cannot contain, and only `because` carries it.
  Ref = NonEmptyString,

  # The tagged ref's discriminator: a stated antecedent is either IN the
  # corpus (walkable, subject to id resolution) or OUTSIDE it (a repository
  # document, a doctrine, a pre-standard deposit, ...) — the two partition
  # exhaustively and exclusively, so the type is DERIVABLE rather than
  # enumerated. The six antecedent kinds an earlier discriminator listed were
  # OBSERVED in one corpus, not derived, and an enum over them would be an
  # open variant set — worse than the sidecar it replaces (ruling-provenance-
  # representation [SR5]).
  RefKind = std.contract.custom (fun _label v =>
    if matches v 'corpus "corpus" || matches v 'external "external"
    then 'Ok v
    else 'Error { message = "RefKind: expected corpus|external (tag or string)" }
  ),

  # A RECORD, not a payloaded Nickel variant: `nickel export --format json` on
  # a payloaded variant like `'corpus "abc"` fails at 1.14.0, and the corpus
  # round-trips through JSON the extractor writes (ruling-provenance-
  # representation [SR6]). `Signer` and `Closer` already answer the same
  # shape of question — a designation mode from a closed set, plus a payload
  # the type does not enumerate — so this matches them rather than inventing
  # a third idiom for the same job ([SR7]).
  ProvenanceRef = {
    kind | RefKind,
    name | NonEmptyString,
  },

  # Every edge array is declared `optional` with NO fallback value, and every
  # consumer guards through this one helper: materializing an empty array via
  # a field fallback would make YAML fixtures depend on contract application
  # order, and the predicates must also run bare over raw YAML-parsed data.
  refs_of | doc "the refs under an entry's optional array field; [] when absent"
    = fun name n => if std.record.has_field name n then n."%{name}" else [],

  # `edges_of` is REMOVED, not aliased (ruling-provenance-representation
  # [SR8]): it conflated two questions three consumers each asked wrongly —
  # "does this entry state where it came from", answered with "does it have a
  # WALKABLE corpus edge". Two helpers now, named for the two meanings.
  #
  # `provenance_of` — every stated antecedent, corpus or external — feeds
  # `ProvenanceGate`, `SignerDesignates`' derived branch, and
  # `DirectiveDesignates` (worker_ibc.ncl). Mixed-shape by construction
  # (`depends` yields plain strings, `because` yields tagged records): every
  # caller only ever asks its LENGTH, never its elements, so the mix costs
  # nothing.
  provenance_of | doc "every antecedent an entry states, corpus or external"
    = fun n => refs_of "depends" n @ refs_of "because" n,

  # `corpus_edges_of` — the WALKABLE subset, plain corpus-id strings only —
  # feeds `chain_floor`, `unbacked` and `EntryStore`'s edge resolution.
  # `because` contributes only its `'corpus`-tagged names; an `'external` ref
  # names nothing the corpus's id set could ever resolve.
  corpus_edges_of | doc "an entry's WALKABLE derivation edges: depends and because's corpus-tagged refs"
    = fun n =>
      refs_of "depends" n
      @ (refs_of "because" n
         |> std.array.filter (fun r => matches r.kind 'corpus "corpus")
         |> std.array.map (fun r => r.name)),

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
    because | Array ProvenanceRef | optional,

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

    # Self-classification, orthogonal to backing/assertion (never a third
    # reading of either axis): a member of the registry above, per entry, any
    # number of times. Direction membership is not a separate field — a
    # direction's tag IS its marker in .ledger/directions.md (D1, D2, D3), so
    # "this entry serves D1" is `tags: [D1]` like any other tag, and
    # entries_query.ncl's `by_direction` view is the general `by_tag` index
    # read through the registry's `category` field, not a second mechanism.
    tags | Array TagName | optional,
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

  # Shared by both converse clauses below: is this entry's declared backing
  # one of the two CLOSED species (corroborated or vouched)? The forward
  # clauses already pin which companion each closed backing requires; the
  # converse's only job is to ask whether a companion present without one of
  # these two backings is a claim understating its own closure.
  backing_closed = fun n =>
    matches n.backing 'corroborated "corroborated" || matches n.backing 'vouched "vouched",

  # A corroborated claim must name a check that WAS RUN (forward), and a
  # CLAIM naming a ran check must declare itself closed (converse — ruling
  # ruling-backing-cure.md [CU2], ruling-converse-phrasing.md [BC2]/[BC3]).
  # The converse is scoped to claims and ORs into the forward clause, never
  # replaces it: a corroborated claim whose check was never run must keep
  # failing, and a QUESTION's ran check testifies to a finding's existence,
  # not its discharge, so it stays exempt (residual entries carrying a ran
  # check are legitimate).
  CorroborationBacked = fun n =>
    (!(matches n.backing 'corroborated "corroborated")
     || (std.record.has_field "check" n && n.check.ran))
    && (!(matches n.assertion 'claim "claim")
        || !(std.record.has_field "check" n)
        || !n.check.ran
        || backing_closed n),

  # A vouched claim must name its witness and the state it testified against
  # (forward), and a CLAIM naming a witness must declare itself closed
  # (converse, same ruling, same claim scoping — a question's witness
  # testifies to its existence, not its discharge).
  VouchBacked = fun n =>
    (!(matches n.backing 'vouched "vouched")
     || std.record.has_field "witness" n)
    && (!(matches n.assertion 'claim "claim")
        || !(std.record.has_field "witness" n)
        || backing_closed n),

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
  # unbacked CLAIM with no stated antecedent is not vaguely unsupported: it is
  # a claim that declines to state where it came from, the one thing every
  # other designation supplies. Scoped to claims (ruling D-2): a question
  # asserts nothing, so a frontier question is legitimately edge-free at
  # birth — the draft's unscoped gate made `frontier` unrecordable. Reads
  # `provenance_of` (corpus or external, ruling-provenance-representation) so
  # an externally-cited synthesis tethers the record exactly as a corpus-cited
  # one does; the `supersedes` clause beside it is fix (i)'s own widening — a
  # retraction naming what it retires is not the hallucination this gate
  # exists to catch, and no other predicate has a reason to read that edge.
  ProvenanceGate = fun n =>
    !(matches n.assertion 'claim "claim")
    || !(matches n.backing 'unclosed "unclosed")
    || std.array.length (provenance_of n) > 0
    || std.array.length (refs_of "supersedes" n) > 0,

  # A question carries BOTH halves or it is not routable — EXCEPT `residual`,
  # which is exempt by the same theorem that puts it on the question side at
  # all (ResidualIsQuestion): discharge PROVABLY does not exist at our
  # observation power. Routing demands a `closer` — a party who COULD close
  # the question — and forcing one onto a residual entry would make every
  # author name a closer who by definition never can, the identical category
  # error `Closer`'s own kind set already refuses for `derived` and
  # `unattributed` signers (no reachable party to designate). Docs/entries.md
  # states the same call directly: "Do not build a check for a residual
  # question; name the import it represents and keep it visible" — a
  # `discharge`/`closer` pair IS that check-in-waiting, and residual has none
  # to wait for. This EXEMPTS, it does not FORBID: an entry may still carry
  # both (the routed-question shape stays valid data), so nothing already
  # authored that way is made invalid — only the requirement to author it
  # that way is lifted.
  QuestionRoutable = fun n =>
    !(matches n.assertion 'question "question")
    || matches n.backing 'residual "residual"
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
      && std.array.length (provenance_of n) > 0
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
  # DIRECTIVES ENTER THE RESOLVABLE ID SPACE (ruling-terminal-composition
  # [TC5]). A `directive` closes by authority, not evidence, so the extractor
  # routes it to its own top-level `directives` list, out of `entries`
  # entirely — and a correct `depends`/`because`/`discharges` ref naming one
  # was failing resolution before target-typing was ever consulted, because
  # `id_set` only ever counted `entries`. `resolvable_id_set` widens the space
  # every edge resolves against to entries-or-directives; `id_set` itself
  # stays entries-only, because id-UNIQUENESS is a property of what this
  # aggregate declares, not of what it may cite.
  #
  # The closure edges add the conditions no per-entry contract can decide:
  # `discharges` is claim -> QUESTION-OR-DIRECTIVE by type ([TC5]/[TC6] — a
  # directive states what should be and is open until met, the same relation
  # `discharges` already names for a question, not a second one), and the
  # target's assertion is only readable once the corpus is in hand.
  # Target-typing therefore lands here, beside resolution, rather than growing
  # the per-entry closed set — DischargeBacked already carries the half that
  # IS per-entry (the discharger's own backing, untouched by this widening).
  # `supersedes` types nothing — any entry may be retired unanswered by a
  # survivor — but it must TERMINATE, which is a property of the relation
  # rather than of any entry in it.
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
    # ENTRIES ONLY: uniqueness is a property of what this aggregate declares.
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
    # `directives` is optional (the same refs_of-guarded idiom used
    # throughout): a lone-entry corpus fixture predating this widening, or one
    # that simply cites none, carries no such field.
    let directives =
      if std.record.has_field "directives" value then value.directives else []
    in
    let directive_ids = std.array.map (fun d => d.id) directives in
    # The resolvable space: entries' own ids plus every directive id, folded
    # onto a COPY of id_set so uniqueness (above) never sees the union.
    let resolvable_id_set =
      std.array.fold_left
        (fun acc id =>
          if std.record.has_field id acc then acc
          else std.record.insert id true acc)
        id_set
        directive_ids
    in
    # resolves NAME: every entry's refs under that optional array field land
    # on a declared id — entry or directive. One helper for all three kinds —
    # the kinds differ in what they MEAN, never in whether they must resolve.
    let resolves = fun name =>
      std.array.all
        (fun en =>
          std.array.all
            (fun r => std.record.has_field r resolvable_id_set)
            (refs_of name en))
        entries
    in
    let all_edges_resolve =
      std.array.all
        (fun en =>
          std.array.all
            (fun r => std.record.has_field r resolvable_id_set)
            (corpus_edges_of en))
        entries
    in
    # question-or-directive set (record) — the same O(1) idiom as id_set, so
    # discharges target-typing is a membership test rather than a scan per
    # edge. Built from `entries`' questions UNION `directives`' ids: a target
    # naming nothing at all — neither a declared question nor a declared
    # directive — still fails membership here exactly as it always did.
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
    let question_or_directive_set =
      std.array.fold_left
        (fun acc id =>
          if std.record.has_field id acc then acc
          else std.record.insert id true acc)
        question_set
        directive_ids
    in
    let discharges_target_questions =
      std.array.all
        (fun en =>
          std.array.all
            (fun r => std.record.has_field r question_or_directive_set)
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
        'Error { message = "EntryStore: dangling edge — a depends/because ref does not resolve to a declared entry or directive id" }
      else if !(resolves "discharges") then
        'Error { message = "EntryStore: dangling discharges — a closure edge does not resolve to a declared entry or directive id" }
      else if !(resolves "supersedes") then
        'Error { message = "EntryStore: dangling supersedes — a supersession edge does not resolve to a declared entry or directive id" }
      else if !discharges_target_questions then
        'Error { message = "EntryStore: discharges target is not a question or directive — a claim answers questions or directives, nothing else" }
      else if !supersession_terminates then
        'Error { message = "EntryStore: SupersessionTerminates — the supersedes relation cycles, so the entries it retires name no surviving entry to carry them" }
      else 'Ok value
    )
  ),
}
