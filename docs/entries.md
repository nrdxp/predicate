# Entries — the typed-claim vocabulary

> New to predicate? Read [`predicate-architecture.md`](predicate-architecture.md)
> first — it defines the vocabulary (*walk*, *IBC*, *Nickel*, *deposit*,
> *.ledger*, the *Verification Dual*) this document uses.

Every entry in a predicate record carries its evidence — or visibly does not.
This document is the **single home** of the typed-claim vocabulary: what an
entry asserts, what backs it, who signed it, and who may write which record.
The machine half is [`ledger/contracts/entry.ncl`](../ledger/contracts/entry.ncl);
this is the prose half. Where a contract enforces a rule stated here, the
contract wins. For the one rule no contract enforces — the [pen law](#the-pen-law)
— **this document is canonical**: every other statement of it is either a marked
operative projection ([`conditioning/core.ncl`](../conditioning/core.ncl), the
one full copy, carried because conditioning is loaded into every walk while
documents must be chased) or a scoped consequence pointing back here.

## The product: backing × assertion

An entry's type is a **product of two dimensions**, never a flat list:

- **`assertion`** — whether a truth-value is carried: `claim` (asserts one) or
  `question` (asserts none).
- **`backing`** — the evidence state: `corroborated`, `vouched`, `unclosed`,
  or `residual`.

The second axis is named **`assertion`, never `kind`**. `kind` is already
taken twice in this codebase — a procedure step's `kind: leaf|invoke` and the
signer designation's `kind: human|agent|source|derived|unattributed` — and a
third meaning invites silent misreads wherever the fields meet in one YAML
file.

The cells of the product have display names. They are convenience vocabulary
for prose; the record itself always carries the two dimensions as fields:

|              | corroborated   | vouched  | unclosed    |
| :----------- | :------------- | :------- | :---------- |
| **claim**    | `proved`       | `cited`  | `synthesis` |
| **question** | `dispatchable` | `routed` | `frontier`  |

- `proved` — a claim closed by a re-runnable check that was run.
- `cited` — a claim closed by a named **admitted** witness.
- `synthesis` — a claim derived from other entries; unclosed, and required by
  the provenance gate to carry at least one inbound edge. A synthesis with no
  inbound edge is the structural definition of a hallucination: a claim that
  declines to state its own provenance.
- `dispatchable` — a question whose discharge is a check that exists and has
  not been run.
- `routed` — a question whose discharge requires an admitted witness; a
  machine cannot close it.
- `frontier` — a question with no discharge condition *yet*, none proven
  impossible. It exits by transition, never by fiat.

Refutation is an **edge, not a state** — a claim's backing is never complected
with its relation to another claim.

## The two evidence species

Exactly two species of evidence exist, and nothing between them:

- **Corroboration** — a re-runnable check that **was run**, anchored to the
  record state it ran against and carrying a signer. `proved` never means
  "I ran it"; it means an attributable run exists.
- **Vouch** — a named **admitted** witness standing behind a judgement, as an
  **event** anchored to the record state it testified against. A vouch without
  its anchor silently claims an endurance it cannot have.

The cut that matters most in practice is **exists versus ran**: a check that
exists but has not run is not backing — it is a `dispatchable` question. Naming
a mechanism and never executing it is the recurring field failure the `ran`
field exists to make visible
([`entry.ncl`](../ledger/contracts/entry.ncl) `Check`;
[`deposit.ncl`](../ledger/contracts/deposit.ncl) `CorroborationSpeciesRan`).

## Residual — open by theorem

`residual` is a **backing value that attaches only to questions**: discharge
provably does not exist at our observation power. Do not build a check for a
residual question; name the import it represents and keep it visible.

The restriction to questions is **derived, not stipulated**: the claim-side
cell table is exhaustive, and every inhabited cell names a cure — even an
undetermined claim is cured by naming an admitted signer, never left open. So
no *claim* is ever open by theorem, and `residual` is question-shaped by
consequence ([`entry.ncl`](../ledger/contracts/entry.ncl)
`ResidualIsQuestion`).

## Closure edges — answered, or retired into a survivor

A question leaves the open state along one of exactly two edges, and which one
it took stays in the record:

- **`discharges`** names the questions an entry **answers**. Only an entry that
  itself carries closed evidence may bear one. A `synthesis` claim is a
  proposal until something closes it, so letting it discharge would let an
  unratified answer retire the question that asked for ratification; and a
  question closing a question is a chain of things none of which is known
  ([`entry.ncl`](../ledger/contracts/entry.ncl) `DischargeBacked`). Whether the
  target really is a question is a corpus property, decided where reference
  resolution already lives.
- **`supersedes`** names entries an entry **retires unanswered** — a duplicate
  merged into the entry that will carry it. It asserts nothing about what it
  retires, which is exactly why it is a second edge rather than a second
  meaning for the first, and why it carries no backing condition at all.

Collapsing the two would lose which exit was taken: a discharged question was
answered, a superseded one never was.

Supersession's one condition is relational, and it is **termination**. Retiring
an entry means something only if the chain of retirements reaches an entry that
nothing supersedes — the survivor that carries the retired ones. A cycle names
no survivor, so every entry in it is retired into nothing, and the corpus check
refuses it ([`entry.ncl`](../ledger/contracts/entry.ncl)
`SupersessionTerminates`).

Neither closure edge is a derivation edge. `depends` and `because` say where an
entry came from; these say what it retires. So neither designates a `derived`
signer, and neither satisfies the provenance gate.

## Directives — closure by authority

A directive — a goal, non-goal, constraint, or acceptance criterion — carries
**no truth-value**, so it cannot close by evidence. It closes by **authority**:
a provenance signer naming the issuing party
([`worker_ibc.ncl`](../ledger/contracts/worker_ibc.ncl) `Directive`). Asking
for a directive's `backing`, `axes`, or `discharge` is a category error, and
the contract rejects those fields as extras rather than policing them with
enforcement code. A constraint additionally names its `evaluator` and a
criterion its `eval` — *how compliance is checked*, which is not backing; the
directive itself still closes by authority.

## The self-vouch policy

**A party is never an admitted witness to its own conduct.**

The consequence is **visibility, not illegality**: a self-vouched entry is
shape-valid, and the record shows the self-vouch. Admission is the consumer's
policy, never the shape's — building the admission rule into the contract
would make self-vouch detection return nothing, exactly when it is needed
most. A solo walk's corpus is largely self-vouched, therefore largely
unclosable, **and the record shows it** — that is a feature of the vocabulary,
not a defect of the walk.

## Unattributed — the migration mode

`SignerKind` carries a fifth mode, `unattributed`: no party is recoverable for
this record — it predates the signing regime. Designation stays total: every
entry says *how* its party is designated, and "not recoverably" is a fifth
answer, never an omission. Like `derived`, `unattributed` carries no `name`;
unlike `derived`, it carries no edge requirement — a migrated record has no
inbound-edge stand-in for a party it cannot name at all. A **named**
`unattributed` is a contradiction, and the shape rejects it
([`entry.ncl`](../ledger/contracts/entry.ncl) `SignerDesignates`).

The classification consequence, stated as doctrine: **no `backing` value
admits "unknown."** `corroborated` names a re-runnable check that ran;
`vouched` names an admitted witness — neither slot has room for a party the
record cannot name. An `unattributed`-signed claim therefore can never close
**on its recorded evidence**: not because closure was withheld, but because
the vocabulary has no cell for a witness that does not exist. Such claims
stay `unclosed`, permanently and **visibly**, the same way a `synthesis`
claim does. This is the
[self-vouch policy](#the-self-vouch-policy)'s logic at its limit: the record
shows what it cannot close rather than fabricating a witness to close it.

## The closer — a narrower designation

A question names the party who **can** close it. That closer is a
**designation record** — a `kind`, and an optional `name` — the same shape as
the signer over a deliberately different set of kinds:

|        | admitted kinds                                        | `name`                                          |
| :----- | :---------------------------------------------------- | :---------------------------------------------- |
| signer | `human`, `agent`, `source`, `derived`, `unattributed` | required except on `derived` and `unattributed` |
| closer | `human`, `agent`, `source`                             | always optional                                 |

The two modes the closer drops are the two that assert **no reachable party**.
`derived` designates by inbound edges, and an answer that does not exist yet
has none. `unattributed` asserts nothing is recoverable, which routes to
nobody. Reusing the signer's set would make an unroutable question
representable, so the closer's set is closed at three
([`entry.ncl`](../ledger/contracts/entry.ncl) `CloserKind`).

`name` is optional here in a way the signer's is not, because a closer is
**prospective routing, never accountability**: the party class is often known
where the individual is not. Accountability for a close rests on the claim that
closes it, and that claim's own signer is name-enforced — so a kind-only closer
costs the record nothing. The designation is machine-readable so that
escalation is a lookup rather than a string match: escalate exactly when the
closer's kind is `human`.

## Axes — an authoring obligation, not a shape law

A claim's three coordinates — `determined`, `certifiable`, `monotone` — make
its cure **derivable rather than authored**. Each inhabited cell of the axis
table names its own trust anchor and minimal cure, so recording the coordinates
is what turns "what would close this" from a judgement into a lookup.
Certifiability is **fibered on determination**: where determination fails there
is no record-only predicate for the coordinate to range over, so it is
**undefined, not false**, and it is omitted rather than guessed
([`entry.ncl`](../ledger/contracts/entry.ncl) `CertifiabilityFibered`). A
question carries no coordinates at all — it asserts no truth-value, so there is
nothing for the axes to be conditions on.

**Carrying them is an obligation of the authoring surface, never a universal
shape law.** A claim is not required to have axes, and a claim that lacks them
is reported as *unassessed* rather than rejected. The distinction follows the
[self-vouch policy](#the-self-vouch-policy)'s logic: a rule refusing axis-less
claims would not obtain the coordinates, it would condition every author to
fabricate them to pass — the rule manufacturing the exact defect it exists to
refuse. **Absence stays visible; it is never fabricated.** The obligation
survives wherever an author genuinely holds it: an IBC premise is assessed
ground by definition, so
[`worker_ibc.ncl`](../ledger/contracts/worker_ibc.ncl) requires axes on its own
surface rather than inheriting the requirement from here.

A **non-monotone** claim owes the cure for that failure — a freshness
mechanism or an accepted expiry — and the shape enforces the pairing
([`entry.ncl`](../ledger/contracts/entry.ncl) `NonMonotoneNamesCure`). Without
it, a claim true when written becomes a documented invariant that quietly
expires.

## Two cuts, never conflated

The discourse taxonomy above (backing × assertion) and the verification
ceiling's classification (*closed* / *gaps* / *imports*) are **different
cuts**. In the ceiling's sense, **`closed` demands both species** — a
corroborating run *and* an admitted vouch — so no cell of the taxonomy is by
itself "closed" in the ceiling's sense. Conflating the two cuts is the one
substantive error on record in this vocabulary's lineage. This warning lives
here and nowhere else: a warning in a second file is a second record that will
silently diverge.

## The pen law

The recorder is **one graph**. Every node is signed by the party whose
testimony it is, and there is **one writer per node-kind-and-namespace**:

- **Testimony** — a deposit, an independent assessment, a finding as witnessed
  — is **append-only**, signed by the witnessing walker (seat or worker), and
  committed by that walker directly into the
  [testimony namespace](#the-testimony-namespace).
- **Synthesis, decision, and narrative nodes** — integration, the decision
  ledger, the flight log, every promotion — are **composer-signed**.
- **Solo** — a walk with no composer — the walker signs everything, and the
  [self-vouch policy](#the-self-vouch-policy) then does honest work.
- **Scratch is the mirror, never the record.**

The wording is chosen to carry three consequences:

- **Append-only is a requirement, not a preference.** The record's guarantees
  survive only extension; a store any party can edit is a shrinkable snapshot
  and forfeits them. Git supplies the mechanism: commits give the entry
  sequence, `git log` corroborates ordering, and the never-rewrite rail keeps
  the snapshot extension-only.
- **The signer is constitutive of the evidence.** Integration written in the
  integrator's voice does not merely degrade attributed testimony — it can
  silently *upgrade* an inadmissible self-vouch into an admissible one, and
  naming the witness inside the payload does not cure it: a name in the prose
  is not a signer on the node. Signers must merge nowhere between witnessing
  and recording.
- **The criterion is zero *silent* trust, not zero trust.** No arrangement
  eliminates trust in the writers; witness-signing shrinks the trusted surface
  and names every member of it.

## The testimony namespace

```text
.ledger/deposits/<topic>/<signer>/
```

- **Topic-scoped** — one directory per deliberation or workstream.
- **Signer-scoped** — one directory per signing party, keyed by the signer
  **designation**, of which a seat id is one case: workers and solo walkers
  deposit testimony too.
- **Append-only** — by the commit rails; a deposit is amended by a new
  deposit, never by editing history.

A deposit committed here satisfies the deliberation protocol's
deposit-before-read ordering *durably*: the git history of the namespace is
the corroborating evidence that the independent assessment preceded the
deliberation.

## The prose grammar

Prose is the **source**; the data view is derived and regenerated, never
maintained — a data block inside a note is dual maintenance by construction.
The pipeline is three stages, and only the first is new code:
[`ledger/derive/extract_entries.py`](../ledger/derive/extract_entries.py)
extracts, the existing
[`entry_apply.ncl`](../ledger/contracts/entry_apply.ncl) validates, and
[`entries_query.ncl`](../ledger/contracts/entries_query.ncl) evaluates
queries over the validated export. A query result is `proved` only relative
to extractor fidelity, so the extractor carries golden-vector and mutation
suites of its own
([`test_entries_extract.sh`](../ledger/gate/test_entries_extract.sh)).

This section promotes the de facto convention the graded documents already
follow to the stated standard the extractor is correct against:

- **Header.** A graded document opens with `` `signer:: <kind>[/<name>]` ``
  and `` `at:: <commit>` `` spans (first occurrence of each governs). The
  signer designates every node in the document; the anchor dates every check
  and vouch. A document without both is **pre-standard**: its tokens are
  countable, but nothing in it is extractable, and the extractor reports the
  document rather than guessing.
- **Node.** A paragraph opening with `` `[ID] grade::<grade>` ``. The marker
  is unique within its document; the extracted entry id is namespaced
  `<file-stem>:<ID>`. `<grade>` is a cell display name from the table above
  (`proved`, `cited`, `synthesis`, `dispatchable`, `routed`, `frontier`,
  `residual`) or `directive`, which is out-of-vocabulary for entries and
  extracts to a separate list with its `provenance::`.
- **Companions.** Backticked `token:: value` spans inside the node's
  paragraph — the blank-line-delimited block opened by the node's own
  `` `[ID] grade::` `` marker, and nothing past its closing blank line. A
  companion that lands one paragraph late — a common slip in flowing prose,
  where the provenance trails the claim it belongs to by a blank line — is
  invisible to that paragraph and is reported as `orphaned-companion`, never
  silently dropped: the extractor does not widen the node to "until the next
  marker" and guess at attribution, because prose between two nodes is not
  reliably either node's. `check::` carries the corroborating command (the
  grade asserts the run; the header anchor dates it). `source::` names the
  witness; `source:: same` repeats the previous node's source. `derives-from::`
  carries provenance: bracketed refs become edges, while `[[wikilinks]]` and
  free prose are **external provenance** — preserved in the export but never
  emitted as edges, which the corpus contract would rightly reject as
  dangling. `discharge::` and `closer::` carry a
  question's two routable halves; `closer::` takes a
  [designation](#the-closer--a-narrower-designation) (`human/nrd`,
  `agent/architect-seat`, or a bare kind), and `machine` is accepted as the
  legacy corpus's word for an unnamed agent rather than a fourth kind.
  `conversion-path::` is a recognized annotation that stays in the statement.
  Any other token-shaped span is reported, never silently discarded.
- **References.** A bracketed ref inside `derives-from::`, `discharges::`, or
  `supersedes::` names an entry, and it comes in two forms. **Plain** —
  `[ID]` — resolves against the document that wrote it, and only ever against
  that document: it does not widen to the corpus when the local lookup misses,
  and it does not prefer a same-named entry next door. A reference whose scope
  depended on which documents an extraction happened to cover would not be
  worth authoring. **Qualified** — `[<file-stem>:<ID>]` — writes the target's
  full id, and is the author's explicit declaration that the target lives
  elsewhere in the corpus. The stem is a file stem and carries whatever the
  file name carries, dates included: a note filed as
  `2026-08-11-vocabulary.md` is reached as `[2026-08-11-vocabulary:R3]`, date
  and all — the ordinary case, since dated file names are how the record is
  kept in order. A qualified ref naming an id no document declares is
  **reported** rather than quietly filed as external provenance: a bracketed
  id asserts the target is *in* the record, so demoting it would read as a
  deliberate pointer out of the record instead of the mistake it is. The
  report drops that one ref and leaves the others in the same value standing,
  so a mistyped stem costs a claim one edge rather than its whole provenance.
- **Wikilinks.** `[[text]]` is external **always** — never a reference, even
  when the text reads exactly like a corpus id. A name outside the record that
  happens to collide with one inside it is nobody's declaration, and neither
  author can see the collision; resolving it would close a question with no
  one having declared the crossing, and would make what a link means depend on
  how wide the extraction was. Loud dangling beats silent capture. An author
  who means the corpus says so in the qualified form.
- **Closure edges.** `discharges::` and `supersedes::` write the two
  [closure edges](#closure-edges--answered-or-retired-into-a-survivor). Unlike
  `derives-from::` they take bracketed refs **only**: a closure edge onto
  something outside the corpus closes nothing queryable, so an unresolvable
  target — a wikilink, free prose, or a stem naming no document — is reported
  rather than preserved as external provenance, which would file it where
  derivation lives and quietly lose the closure. `discharge::` and
  `discharges::` are one letter apart, and the names are the vocabulary's
  own — a prospective condition and the retrospective edge that pays it. They
  are two distinct keys, so a typo lands on the wrong one loudly rather than
  quietly.
- **Question backings.** Extracted questions carry `backing: unclosed`
  (residual excepted), the entry fixtures' practice: `corroborated` and
  `vouched` demand delivered evidence (`CorroborationBacked`,
  `VouchBacked`), which a question by definition lacks. The prospective
  cell reading — what *would* close it — survives as the prose grade in the
  export's sidecar, which the queries consume.
- **Axes.** `axes::` takes one polarity token per coordinate, in any order —
  `` `axes:: +determined -certifiable +monotone` ``. The `certifiable`
  coordinate is **omitted** where determination fails, because it is undefined
  there rather than false and the grammar has to be able to say so. A value the
  polarity tokens cannot place is reported rather than half-recorded: a partial
  coordinate set reads as a deliberate omission and would be believed as one.
  A claim carrying no `axes::` at all extracts without them, and the query
  lists it as *unassessed* rather than presenting an empty cure report as a
  clean bill.
- **Freshness.** `freshness::` names, in prose, the mechanism that keeps a
  non-monotone claim true — the cure such a claim
  [owes](#axes--an-authoring-obligation-not-a-shape-law).
- **Counts.** A count stored in prose is a second record that goes stale.
  Ledger notes store **no** counts — the surface is computed from the
  claims. A boundary document that must publish its own census does so in
  one place, a `## 7` results section excluded from its own census scope
  (the `sed -n '1,/^## 7/p'` discipline), and the extractor's `--census`
  reproduces the published block byte-for-byte.
