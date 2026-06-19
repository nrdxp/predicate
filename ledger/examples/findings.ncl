# Clean example: a findings ledger where every resolved finding names the
# evaluator that closed it. Exports 0.
#
# Open and planned findings may leave evaluator "" (not yet grounded); a
# mitigated or accepted-risk finding must name its gate.
let c = import "../contracts/findings.ncl" in
{
  findings = [
    {
      id = "F1",
      severity = 'high,
      statement = "DAG topology was prose-only; no machine check for cycles.",
      evidence = "no contract under ledger/ before this campaign",
      status = 'mitigated,
      evaluator = "nix run nixpkgs#nickel -- export examples/dag.ncl",
    },
    {
      id = "F2",
      severity = 'medium,
      statement = "Findings could be marked resolved without a closing gate.",
      evidence = "campaign grammar FINDINGS had no evaluator field",
      status = 'mitigated,
      evaluator = "nix run nixpkgs#nickel -- export fixtures/findings_empty_evaluator.ncl (must fail)",
    },
    {
      id = "F3",
      severity = 'low,
      statement = "Prose lenses lack grammars; cannot be machine-gated yet.",
      evidence = "skills/documentation/SKILL.md has no parser",
      status = 'accepted_risk,
      evaluator = "decorrelated adversarial review (no deterministic gate exists)",
    },
    {
      id = "F4",
      severity = 'medium,
      statement = "Reconcile log freshness is not yet enforced at dispatch.",
      evidence = "gate wiring is a downstream node",
      status = 'planned,
      evaluator = "",
    },
  ]
} | c.Findings
