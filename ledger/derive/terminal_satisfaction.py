#!/usr/bin/env python3
"""Terminal-target selection, shared by the D3 satisfaction-integrity gates.

`ledger/gate/self_vouch.py` (D3-T8: is a terminal target satisfied on the
testimony of its own author?) and `ledger/gate/terminal_freshness.py`
(D3-T10: does a terminal target's satisfying claim carry the coordinate that
makes a lapsed corroboration visible?) both start from the identical two
questions -- what is a terminal target, and which claim satisfies one --
before diverging on what each then checks about the claim it finds. Deriving
that selection twice is exactly the drift D3 exists to catch, so it lives
here once and both gates import it rather than re-deriving it.

WHAT COUNTS AS A TERMINAL TARGET
----------------------------------
A `directive` node under document stem `directions` whose marker has the
`<DIRECTION>-<TAG>` shape -- `ledger/derive/convergence.py`'s own
TERMINAL_SHAPE regex, passed in by the caller and matched against here rather
than copied, so no consumer of this module drifts from what "terminal" means
for the corpus at large.

WHAT SATISFIES ONE
--------------------
An entry naming the target in its own `discharges` edge, with
`assertion: claim` and `backing: corroborated` (ruling-terminal-composition
[TC1]). `discharging_claims` returns every claim naming a target regardless
of backing -- a caller may need the unsatisfying remainder for its own
visibility reporting (self_vouch.py does); `is_satisfying` is the one-line
predicate that narrows to the satisfying subset. A target with no
discharging claim at all is UNMET, not a violation of anything either gate
checks -- `ledger/derive/convergence.py` already reports the unmet fraction,
and neither gate importing this module should double-count that gap under a
different name.
"""

from __future__ import annotations


def terminal_targets(directives: list, convergence_mod) -> tuple[dict, list]:
    """Directive nodes under document stem 'directions' whose marker has the
    <DIRECTION>-<TAG> shape. Reuses convergence.py's own TERMINAL_SHAPE regex
    (single source of truth for what "terminal" means) rather than a second
    copy of the pattern that could silently diverge from it.

    Returns (targets, malformed): `targets` maps target id -> its directive
    node; `malformed` lists ids whose marker looks terminal but is joined
    with the wrong separator (convergence.py's own malformed-marker case) --
    reported for visibility, never treated as a target."""
    targets: dict[str, dict] = {}
    malformed: list[str] = []
    for directive in directives:
        doc, _, marker = directive["id"].rpartition(":")
        if doc != "directions":
            continue
        shape = convergence_mod.TERMINAL_SHAPE.match(marker)
        if not shape:
            continue  # a direction node itself (D1/D2/D3), or an
            # out-of-shape marker like DX4 -- neither is a terminal target
        _head, sep, _tag = shape.groups()
        if sep == "-":
            targets[directive["id"]] = directive
        else:
            malformed.append(directive["id"])
    return targets, malformed


def discharging_claims(entries: list, target_id: str) -> list[dict]:
    """Every entry naming target_id in its own `discharges` edge, regardless
    of backing -- callers decide what they need from the unsatisfying
    remainder; `is_satisfying` narrows to what actually closed the target."""
    return [e for e in entries if target_id in (e.get("discharges") or [])]


def is_satisfying(entry: dict) -> bool:
    return entry.get("assertion") == "claim" and entry.get("backing") == "corroborated"
