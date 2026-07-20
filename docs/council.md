# Council — the standing council and how to convene it

> New to predicate? Read the Orientation in
> [`predicate-architecture.md`](predicate-architecture.md) first — it defines the
> vocabulary (*walk*, *IBC*, *Nickel*, *deposit*, *harness*, the *Verification
> Dual*) this document uses.

The **council** is predicate's standing operating model: a bound set of
role-divergent, architect-tier seats that share the work's full context and
correct one another, replacing the single un-decorrelated architect. It is the
Verification Dual's adversarial path turned on the architecture procedure itself.

This is a **reference** for a maintainer who must understand the council and
convene it. It describes the landed system and points at the authorities; it does
not restate them, and it is not the design rationale (the *why* lives in the
[`council` station](../conditioning/modules/council.ncl) and the
[`/council`](../skills/council/SKILL.md) skill).

## Authorities

Every claim below is grounded in one of these committed sources. When this doc and
a source disagree, the source wins.

| Concern | Authority |
| :--- | :--- |
| The law (seats, delegation, assent classes, guards) | [`ledger/contracts/council.ncl`](../ledger/contracts/council.ncl) |
| The canonical roster + delegation table (a project instance) | [`ledger/fixtures/council/constitution.yaml`](../ledger/fixtures/council/constitution.yaml) |
| The validation gate (shape-dispatch apply-contract) | [`ledger/contracts/council_apply.ncl`](../ledger/contracts/council_apply.ncl) |
| The merge-consent deterministic gate | [`ledger/gate/council_consent.sh`](../ledger/gate/council_consent.sh) |
| The seat's discipline (deliberation, governance, recording) | [`skills/council/SKILL.md`](../skills/council/SKILL.md) |
| The shared station prose (pact, governance rationale) | [`conditioning/modules/council.ncl`](../conditioning/modules/council.ncl) |
| The deposit primitive (data is YAML, the contract checks it) | [`deposits.md`](deposits.md) |

## The roster and seat lifecycles

The seats are declared in the project Constitution
([`constitution.yaml`](../ledger/fixtures/council/constitution.yaml) is the
canonical instance). Each seat is a substantive architect-tier persona — a lens
that covers a blind spot its peers do not — not a label. Lifecycles are **ongoing,
not one-shot**: a seat is convened whenever its domain is touched, for the whole
duration of the work.

| Seat (`id`) | Domain | Lens | Standing |
| :--- | :--- | :--- | :--- |
| Composer (`composer`) | execution structure / scheduling | [`composer.ncl`](../conditioning/personas/composer.ncl) | the moderator / driver — see below |
| Architect (`architect`) | boundary / goal / strategy | [`architect-seat.ncl`](../conditioning/personas/architect-seat.ncl) | plan → reconcile/judge → dag-amend → cohere |
| Lead-maintainer (`maintainer`) | merge | [`lead-maintainer-seat.ncl`](../conditioning/personas/lead-maintainer-seat.ncl) | the standing merge gate |
| Process-auditor (`auditor`) | process / residue | [`process-auditor-seat.ncl`](../conditioning/personas/process-auditor-seat.ncl) | audits the process and the composer |
| Head (`human`) | taste / release | the human | ratifier; convened sparingly |

The **composer** is not an ordinary seat. It is the live output-style persona — the
**moderator and driver** that convenes seats proportionally, sequences the
independent-first deliberation, runs the delegation table, and integrates each
deliberation into a recorded decision. As the hub it holds outsized power over who
is convened and what each seat sees, so it is **not barrable**: the process-auditor
checks the composer's moderation directly and escalates composer-misconduct
straight to the head (see [`SKILL.md`](../skills/council/SKILL.md), governance
spine).

The **lead-maintainer** holds the merge gate: every merge into the working branch
is its affirmative call, and green deterministic gates are necessary but never
sufficient — see the law below. The **process-auditor** reads the durable record
(decision ledger + per-seat deposits) directly and cannot be convened or suppressed
by the composer, which is what keeps the only check on the hub independent. The
**head** is the human — a standing seat with ultimate authority (taste-fork
arbiter, ratifier of structural changes, final on release) convened sparingly.

**Guests** (mathematician, type theorist, research/prior-art expert, an OSS-maintainer
foil) are summoned per decision — Tier-economy at the council layer — and carry
`standing: guest` rather than `standing` in the Constitution.

## The law

The law is two Nickel layers in
[`council.ncl`](../ledger/contracts/council.ncl), parallel to the static-contract ⊥
data-instance split used elsewhere:

- **Constitution** (static, per-project) — the seats, the decision types, and the
  delegation table. The canonical instance is
  [`constitution.yaml`](../ledger/fixtures/council/constitution.yaml).
- **DecisionLedger** (dynamic) — a contract *constructor* parameterized by the
  Constitution, validating each decision against the live delegation table.

The law is **intrinsic**: a single command is the gate, with no roundtrip a
headless orchestrator could skip.

```bash
nickel export <instance>.yaml --apply-contract ledger/contracts/council_apply.ncl
```

The apply-contract shape-dispatches: a value carrying `seats` is checked as a
Constitution; otherwise it is a decision ledger, threaded with the canonical
Constitution. Exit 0 iff the instance is lawful.

### Decision taxonomy and ownership

Each decision type maps to exactly one owner and one required-assent class. This is
the canonical [`constitution.yaml`](../ledger/fixtures/council/constitution.yaml)
delegation table; a project may declare its own.

| Decision type | Owner | Required assent | Named guard |
| :--- | :--- | :--- | :--- |
| `boundary-design` | architect | `'single` | — |
| `dag-structure` | composer | `'single` | — |
| `dag-amendment` | architect | `'single` | head-ratification |
| `reconcile-accept` | maintainer | `'single` | — |
| `dispatch` | composer | `'single` | — |
| `convene` | composer | `'single` | — |
| `lifecycle` | composer | `'single` | — |
| `classification` | architect | `'subset` (quorum 2) | — |
| `merge` | maintainer | `'single` | merge-consent |
| `taste-fork` | human | `'human` | — |
| `residue` | auditor | `'single` | — |
| `bar` | human | `'human` | — |
| `close` | architect | `'full` | head-ratification |

### Assent classes

A decision records the seat ids that assented in its `assent` array. The class its
delegation rule names decides what that array must contain
([`council.ncl`](../ledger/contracts/council.ncl), the `class_ok` predicate):

- **`'single`** — the owner's id is present. Routine forward-motion; proportional
  convening, so you need not convene everyone.
- **`'subset`** — at least `quorum` seats assent (judgment, e.g. `classification`
  needs a quorum of 2).
- **`'full`** — every **machine-consensus** seat assents. That set is the standing
  seats *minus the head* — in the canonical Constitution: architect, composer,
  maintainer, and auditor.
- **`'human`** — the id `"human"` (the head) is present.

### The named guards

Two guards are encoded as mandatory co-signers (`must_assent`) and checked **before**
the class predicate, so a later reclassification cannot silently drop a required
signature, and each violation surfaces its own reason:

- **`merge-consent`** — a `merge` decision must carry the maintainer's recorded
  assent (`"maintainer"`), regardless of class. The deterministic
  [`council_consent.sh`](../ledger/gate/council_consent.sh) gate reduces to this
  guard (it exports through the apply-contract and reads the exit code), enforcing
  that green gates alone never land a node.
- **`head-ratification`** — a `dag-amendment` or `close` decision must carry the
  head (`"human"`). For `close`, this sits **atop** full machine consensus: the head
  is a standing seat but the *ratifier*, excluded from the `'full` tally so
  consensus and ratification stay two distinct gates, both required to close.

### The intrinsic gates

The export also rejects, with a named reason:

- **anti-incoherence** — every decision type has exactly one delegation rule, every
  owner and co-signer is a declared seat, and every subset quorum is in range. A
  gapped law fails the export rather than deadlocking at the first deliberation.
- **ungoverned** — a decision referencing a type with no delegation rule fails; you
  cannot route it.
- **no-barred** — a barred seat appearing in `assent` fails. Barring rules a rash
  seat out of one decision: the auditor proposes it (grounded), the head ratifies it
  (`bar` is a `'human` type), it scopes to that one IBC, and it auto-lifts when the
  IBC resolves.
- **anti-unilateral** — a decision lacking the assent its rule requires fails; the
  move is invalid.

## The deposit and decision flow

The council's decorrelation is **role-based, not context-based** — every seat
hydrates the same record — so the order of acts is the guard: **independent first,
deliberate second**.

1. **Deposit before reading.** Each seat writes its independent, role-based
   assessment and commits its durable form **before** opening any sibling's
   deposit. Reading a peer first collapses decorrelation (and is a barring trigger).
2. **Deposit as data.** A deposit is a [`deposit.ncl`](../ledger/contracts/deposit.ncl)-conformant
   **YAML instance** committed to a `.ledger` home the moment it is made — never
   Nickel. You write the data; the externally-applied contract checks it (see
   [`deposits.md`](deposits.md)). Durability is required because the auditor reads
   these deposits directly to check the hub.
3. **Integrate into a recorded decision.** Once every seat has deposited, the
   composer relays correction and integrates the deliberation into a **decision
   ledger** entry — a YAML `DecisionLedger` instance in `.ledger/state/`, validated
   on each write by [`council.ncl`](../ledger/contracts/council.ncl). Assent without
   non-empty `grounding` fails the export; there is no bare "yes."
4. **The auditor reads the durable record.** Process and residue audits run against
   the committed decision ledger and deposits, never through the composer.

The council is **standing, not campaign-only**: the composer convenes
proportionally — a one-liner may convene only the lead-maintainer at merge plus the
architect for a coherence check, while a multi-workstream effort convenes the full
council. Under this protocol `.scratch/<topic>/` is the live **mirror** the seats
work from; the `.ledger` deposits and decision ledger are the **system of record**;
the retrospective at CLOSE merely **consolidates** the durable trail, which can then
be discarded with nothing lost.

## How to convene

Convening a council means binding seats to the [`/council`](../skills/council/SKILL.md)
skill — the law a seat operates under (deliberation protocol, the pact, the
governance spine, and how to record assent and findings). The shared station prose
each seat carries is the [`council` module](../conditioning/modules/council.ncl);
each seat's lens is its persona in [`conditioning/personas/`](../conditioning/personas/).

The protocol in brief:

1. **Configure the project.** Declare the Constitution (seats + delegation table)
   for the project; the canonical
   [`constitution.yaml`](../ledger/fixtures/council/constitution.yaml) is the
   reference shape. It must validate before convening — an under-specified law is a
   dispatch failure.
2. **Convene proportionally.** The composer summons the seats the task warrants and
   sequences the independent-first deliberation.
3. **Route by the table.** Act on each decision only with the assent its delegation
   rule requires; never invent a rule for an unlisted type — halt instead.
4. **Record durably.** Deposits and the decision ledger are YAML instances gated by
   `nickel export`.

### A minimal convened ledger

[`ledger/fixtures/council/good.yaml`](../ledger/fixtures/council/good.yaml) is a
worked decision ledger: a routine owner-only `dispatch` (D1), a consented `merge`
(D3, carrying `maintainer`), a head-ratified `dag-amendment` (D4, carrying `human`),
and a terminal `close` (D6, full machine consensus plus the head). Validate it the
way every council record is gated:

```bash
nickel export ledger/fixtures/council/good.yaml \
  --apply-contract ledger/contracts/council_apply.ncl
```

A clean export (exit 0) is the proof the ledger is lawful under the Constitution.
