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
record cannot name. An `unattributed`-signed claim therefore can never close:
not because closure was withheld, but because the vocabulary has no cell for a
witness that does not exist. Such claims stay `unclosed`, permanently and
**visibly**, the same way a `synthesis` claim does. This is the
[self-vouch policy](#the-self-vouch-policy)'s logic at its limit: the record
shows what it cannot close rather than fabricating a witness to close it.

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
