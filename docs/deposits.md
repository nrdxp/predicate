# Worker Deposits — YAML Schema

A **procedure deposit** is the artifact a walk writes to record that it completed
a procedure step.  The process gate validates it automatically on commit.

**You write data.  The contract checks it.  You never write Nickel.**

A deposit is **testimony**: signed by the walker that witnessed the work, and
written by that walker — the evidence vocabulary it speaks (the two species,
signers, witnesses) and the pen law naming who writes which record are defined
once in [`entries.md`](entries.md).

---

## What a deposit looks like

A deposit is a plain YAML file.  Here is a minimal boundary procedure deposit:

```yaml
workflow: boundary
steps:
  - id: track
    kind: leaf
    evidence:
      - claim: R/I/U tracker loaded from .ledger/context_map.ncl
        method: review
        location: .ledger/context_map.ncl
        signer: { kind: agent, name: boundary-walker }
        witness: { name: boundary-walker, at: "df35300" }
    cites:
      - .ledger/context_map.ncl
  - id: adversarial-review
    kind: invoke
    class: adversarial-review
    ref:
      target: ar-1
      role: sub-procedure-output
  - id: draft
    kind: leaf
    evidence:
      - claim: IBC candidate authored from templates/IBC.md
        method: lint
        location: .scratch/topic/campaign_ibc.ncl
        signer: { kind: agent, name: boundary-walker }
        check: { command: "nickel export .scratch/topic/campaign_ibc.ncl", ran: true, at: "df35300" }
    cites:
      - templates/IBC.md
      - .scratch/topic/campaign_ibc.ncl
  - id: attack
    kind: invoke
    class: adversarial-review
    ref:
      target: ar-2
      role: sub-procedure-output
  - id: revise
    kind: leaf
    evidence:
      - claim: S1-S7 objections resolved with evidence
        method: review
        location: .scratch/topic/campaign_ibc.ncl
        signer: { kind: agent, name: boundary-walker }
        witness: { name: boundary-walker, at: "df35300" }
    cites:
      - .scratch/topic/campaign_ibc.ncl
  - id: approve
    kind: leaf
    evidence:
      - claim: human approved IBC after zero-objection sweep
        method: manual
        location: .scratch/topic/campaign_ibc.ncl
        signer: { kind: human, name: nrd }
        witness: { name: nrd, at: "df35300" }
    cites:
      - .scratch/topic/campaign_ibc.ncl
```

---

## Top-level fields

| Field | Type | Description |
| :---- | :--- | :---------- |
| `workflow` | string | Identifies the procedure (e.g. `"boundary"`, `"refine"`). Prose; not checked against a registry. |
| `steps` | array of Step | The procedure steps, in order. |

---

## Step fields

Every step has an `id` and a `kind`.  `kind` determines which other fields are
required.

| Field | Type | Description |
| :---- | :--- | :---------- |
| `id` | string | The step identifier.  Must match one of the upstream-required ids for the contract to pass (footprint-presence check).  Must be unique within the deposit. |
| `kind` | `"leaf"` or `"invoke"` | Discriminates the step type (see below). |

### kind: leaf

A leaf step does local work.  It must carry `evidence` and `cites`; it must
NOT carry `class` or `ref`.

| Field | Type | Description |
| :---- | :--- | :---------- |
| `evidence` | array (non-empty) | One or more Evidence items (see below). |
| `cites` | array of strings | File paths that support this step's claims. |

### kind: invoke

An invoke step calls a registered sub-procedure.  It must carry `class` and
`ref`; it must NOT carry `evidence`.

| Field | Type | Description |
| :---- | :--- | :---------- |
| `class` | string | The registered sub-procedure class.  Must be one of: `"discovery"`, `"adversarial-review"`, `"prior-art"`. |
| `ref` | DepositRef | A typed pointer to the sub-procedure's output deposit. |

---

## Evidence item fields

Each item in `evidence` is a structured sub-claim.  Four fields are always
required; the fifth is the **species anchor** the item's method demands —
a `check` or a `witness`, never neither and never both.

| Field | Type | Required | Description |
| :---- | :--- | :------- | :---------- |
| `claim` | string (non-empty) | always | The falsifiable assertion this evidence supports. |
| `method` | string | always | The evaluator tier (see below); determines the species. |
| `location` | string (non-empty) | always | Where to look to reproduce or refute the claim: a file path, `file:line`, command, URL, or commit hash. |
| `signer` | Signer | always | Who asserts this item (see below). |
| `check` | Check anchor | corroboration-species methods | The mechanism run: `{ command, ran, at }`. `ran` must be `true` — a named-but-unrun mechanism is a dispatchable question, not evidence. |
| `witness` | Witness anchor | vouch-species methods | The admitted judgement: `{ name, at }`. `at` anchors the testimony to the record state it certified. |

Both anchors accept an optional `dirty: true` marker, meaning the check or
review ran against `at` **plus uncommitted changes** — absent means the tree
matched `at` exactly.

### Method and species

The `method` value ranks the evaluator (weakest escalates to human review) and
fixes which anchor the item must carry:

| Value | Species | Required anchor | Meaning |
| :---- | :------ | :-------------- | :------ |
| `proof` | corroboration | `check` (with `ran: true`) | Formal proof |
| `type_check` | corroboration | `check` (with `ran: true`) | Type-system verification |
| `property_test` | corroboration | `check` (with `ran: true`) | Property or fuzz test |
| `example_test` | corroboration | `check` (with `ran: true`) | Example-based unit test |
| `lint` | corroboration | `check` (with `ran: true`) | Static analysis or linter |
| `review` | vouch | `witness` | Decorrelated adversarial review |
| `manual` | vouch | `witness` | Human spot-check (weakest; requires explicit escalation) |

The two species are the ledger's evidence vocabulary — a re-runnable check
that **was run**, or a named admitted witness — defined once in
[`entries.md`](entries.md).

### Signer

The `signer` names who asserts the item, in the core's designation modes:

| Field | Type | Description |
| :---- | :--- | :---------- |
| `kind` | string | One of `human`, `agent`, `source`, `derived`, `unattributed`. |
| `name` | string (non-empty) | The party's name.  Required for `human`/`agent`/`source`; absent for `derived` and `unattributed`. |

---

## DepositRef fields

A `ref` field on an invoke step points to the sub-procedure's output deposit:

| Field | Type | Description |
| :---- | :--- | :---------- |
| `target` | string | The `id` of the referenced deposit. |
| `role` | string (non-empty) | Why the reference exists (e.g. `"sub-procedure-output"`). |

---

## How the gate validates your deposit

When you have an active walk registered (`process-gate.sh register`), the
pre-commit hook:

1. Reads the two-line active-walk pointer: contract class (line 1) and deposit
   path (line 2).
2. If the declared deposit path is staged, runs:
   ```
   nickel export <deposit>.yaml --apply-contract ledger/contracts/<class>_apply.ncl
   ```
3. The contract checks footprint-presence (all required step ids present),
   id uniqueness, step grammar (leaf XOR invoke), evidence shape — including
   the signer and the species anchor each method demands — and invoke class
   membership.
4. If validation fails, the commit is blocked with a diagnostic.

The contract is applied **externally** — the deposit carries no Nickel logic.
This means:

- **A YAML deposit cannot self-bind** (A-B1): there is no way to embed a
  weakened contract or skip validation from inside the file.
- **A YAML deposit cannot import code**: YAML has no execution model, so
  import-DoS attacks are structurally impossible.
- **A bare `steps: []` dodge is caught**: the contract is applied outside the
  deposit regardless of its content.

---

## Required step ids by contract class

### boundary

`track`, `adversarial-review` (CoreSteps), `draft`, `attack`, `revise`,
`approve`.

### refine

`track`, `adversarial-review` (CoreSteps), `absorb`, `clarify`, `audit`,
`iterate`, `sweep`, `review`, `report`, `halt`.

---

## Walk lifecycle

```bash
# 1. Register at walk startup — writes the active-walk pointer and installs a
#    teardown trap in your shell.
eval "$(bash ledger/gate/process-gate.sh register boundary .scratch/topic/deposit.yaml)"

# 2. Author your YAML deposit at the declared path.
# 3. Stage it and commit — the hook validates it.

# 4. At close, deregister explicitly and remove the trap.
bash ledger/gate/process-gate.sh deregister
trap - EXIT HUP INT TERM
```

See `ledger/gate/process-gate.sh` for the full register/deregister API.

---

## Canonical examples

- `ledger/fixtures/process_gate_honest.yaml` — boundary, all 6 steps present.
  Gate exits 0.
- `ledger/fixtures/process_gate_skip.yaml` — boundary, "attack" omitted.
  Gate exits 1.
