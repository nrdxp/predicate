# templates/project-gates/ — Predicate's Own Project-Local Gates

This directory holds predicate's own project-local gates: checks that enforce
predicate-internal invariants and are installed into **predicate's own**
`.ledger/gates/` on a self-hosting init (`bootstrap/install.sh init` run
against the predicate checkout itself).

## Self-host only — NOT auto-installed in consumer projects

These gates are predicate-specific. They check invariants that are only
meaningful inside the predicate repository (e.g., the skill-contract colocation
decision). Installing them in a downstream project would **false-fire**: a
consumer project is entitled to have a `state_machine.ncl` or
`boundary_procedure.ncl` in its own `ledger/contracts/` without triggering
predicate's colocation alarm.

The install logic enforces this split:

| Init target | Gates installed |
| :--- | :--- |
| Predicate itself (`project == plugin_src`) | Contents of `templates/project-gates/` → `.ledger/gates/` |
| Any consumer project | **None** — consumer writes its own `.ledger/gates/` |

## For consumer projects — opt-in examples

If you want to add project-local gates to your own repository, the mechanism
is the same `.ledger/gates/` directory. Write an executable script there; the
runner (`ledger/gate/project-gates.sh`) discovers and runs every executable in
that directory at every pre-commit gate.

You may copy any gate from this directory as a **starting point**, adapting it
to your project's own invariants. The interface is:

```bash
#!/usr/bin/env bash
# $1 = absolute path to your project root
root="${1:?usage: $0 <project-root>}"
# ... check your invariant; exit 0 = pass, exit 1 = fail
```

See [`ledger/gate/README.md`](../../ledger/gate/README.md#project-local-gates)
for the full interface contract and usage notes.

## Currently shipped

| Gate | File | Enforces |
| :--- | :--- | :--- |
| Skill-contract colocation | `10-skill-contract-colocation.sh` | The five skill-owned contracts (`boundary_procedure`, `refine_procedure`, `refine_output`, `state_machine`, `tracker_freshness`) must not reappear in `ledger/contracts/`; fails on re-centralization. |
