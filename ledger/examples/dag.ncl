# Clean example: the predicate-cohesion campaign DAG.
#
# `nix run nixpkgs#nickel -- export examples/dag.ncl` exits 0 iff the graph is a
# valid, conflict-free DAG: it exits non-zero on a cycle, a dangling edge, a
# duplicate id, or an undeclared concurrent-surface conflict.
#
# Sequencing is foundation-first: the topology, rules rewrite, Nickel substrate,
# and gates land before any consolidation cut. Consolidation nodes that touch the
# shared narrative surface (README.md, rules.md) carry `serialize = true` so the
# conflict gate accepts them — run one at a time even though the topology leaves
# them mutually unordered.
#
# Each node also carries human-facing fields (title, rationale) ignored by the
# contract but read by an orchestrator.
let c = import "../contracts/dag.ncl" in
(
  (
    {
      nodes = [
        {
          id = "P1",
          title = "Topology migration + durability gap",
          depends_on = [],
          file_surface = [".scratch/", ".agent/workflows", ".gitignore", ".sketches/"],
          discipline = 'core,
          mitigates = ["AC5", "C9", "P7-topology"],
          rationale = "Move state under .scratch/{work,worktrees,sketches}; remove dangling .agent/workflows; configure + push a .sketches remote. Foundation: cuts launch from settled topology.",
        },
        {
          id = "P2",
          title = "rules.md rewrite — Verification Dual + Cutting Imperative",
          depends_on = [],
          file_surface = ["rules.md", "skills/constitution/SKILL.md"],
          discipline = 'core,
          mitigates = ["AC1"],
          rationale = "Encode the Verification Dual as a Prime Invariant; add the Cutting Imperative. The ambient layer that later cuts relocate INTO must exist first.",
        },
        {
          id = "P3",
          title = "Nickel ledger contracts + example instances",
          depends_on = [],
          file_surface = ["ledger/"],
          discipline = 'core,
          mitigates = ["AC2", "C1", "C2", "C10"],
          rationale = "Author Nickel contracts for campaign IBC, DAG, worker IBC, findings, reconcile log; one clean example each; cycle/dangling/conflict fixtures. Foundation substrate.",
        },
        {
          id = "P4",
          title = "Gate wiring — ledger validate at commit + dispatch",
          depends_on = ["P3"],
          file_surface = ["skills/commit-hygiene/scripts/", "ledger/gate/"],
          discipline = 'core,
          mitigates = ["AC3", "C2", "C3"],
          rationale = "One portable command validates a ledger artifact at the commit gate and at dispatch; enforce 'not in the IBC -> not authorized'. Needs P3's contracts.",
        },
        {
          id = "P5",
          title = "Scale-invariant gate set + demonstration",
          depends_on = ["P4"],
          file_surface = ["ledger/gate/", "skills/core/SKILL.md", "skills/refine/SKILL.md"],
          discipline = 'core,
          mitigates = ["AC6", "C7"],
          rationale = "Prove the gate set a /core task runs is a superset of a campaign node's; weave refinement into /core. Needs the gate from P4.",
        },
        {
          id = "P6",
          title = "Relocate ambient principles into the ambient layer",
          depends_on = ["P2"],
          file_surface = ["ambient/"],
          discipline = 'refine,
          mitigates = ["AC4", "F-planning", "F-continue", "F-predicate", "F-engineering", "F-sketch-principle", "F-dialectic-principle"],
          rationale = "Move the load-bearing essences into ambient docs created by P2. Pure additive relocation — no deletion here, so it precedes every cut. Disjoint surface.",
        },
        {
          id = "P7",
          title = "Cut orphans — plan-review, personalization",
          depends_on = ["P2", "P6"],
          file_surface = ["skills/plan-review/", "skills/personalization/"],
          discipline = 'refine,
          mitigates = ["AC4", "F-plan-review", "F-personalization"],
          rationale = "Zero inbound refs -> cheapest clearance. plan-review essence subsumed by RECONCILE+CLOSE; personalization is one ambient naming rule. Disjoint surfaces.",
        },
        {
          id = "P8",
          title = "Cut plan + charter (rewrite README/templates first)",
          depends_on = ["P2", "P6"],
          file_surface = ["skills/plan/", "skills/charter/", "templates/PLAN.md", "templates/CHARTER.md", "README.md", "docs/"],
          discipline = 'refine,
          mitigates = ["AC4", "F-plan", "F-charter"],
          rationale = "campaign emits its own plan/framing; rewrite README invocations + templates + docs refs, THEN delete. Touches README.md + docs (shared) -> serialize.",
          serialize = true,
        },
        {
          id = "P9",
          title = "Demote sketch/dialectic/continue/predicate skills",
          depends_on = ["P1", "P2", "P6"],
          file_surface = ["skills/sketch/", "skills/dialectic/", "skills/continue/", "skills/predicate/", "README.md", "rules.md", "docs/"],
          discipline = 'refine,
          mitigates = ["AC4", "F-sketch-skill", "F-dialectic-skill", "F-continue", "F-predicate"],
          rationale = "Remove the four workflow shells whose principles P6 already relocated. PRESERVE the .sketches/ substrate. Rewrite rules.md + README refs first. Touches README.md + rules.md + docs (shared) -> serialize.",
          serialize = true,
        },
        {
          id = "P10",
          title = "Fold doc-audit prose rules into documentation",
          depends_on = ["P2", "P6"],
          file_surface = ["skills/doc-audit/SKILL.md", "skills/documentation/SKILL.md"],
          discipline = 'refine,
          mitigates = ["AC4", "F-doc-audit"],
          rationale = "Merge link/header/lint prose rules into documentation; KEEP the doc-audit check script (the evaluator invokes it). Disjoint surface; concurrent with P7.",
        },
        {
          id = "P11",
          title = "CLOSE — full verification surface + cumulative sweep",
          depends_on = ["P5", "P7", "P8", "P9", "P10"],
          file_surface = [],
          discipline = 'refine,
          mitigates = ["AC8"],
          rationale = "All gates green, link checks clean, final decorrelated sweep over the cumulative diff for cross-node integration drift. Empty file surface (verification only).",
        },
      ]
    } | c.Dag
  ) | c.DagNoConflict
)
