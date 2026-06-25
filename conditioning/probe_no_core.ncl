# EXPECT: fail
# Negative control: a persona stripped of the invariant-core. The HasCore
# injection-rule contract MUST reject it — proof the rule bites (a generated
# prompt without the core verbatim fails export, so it can never be delivered).
# probe_no_core.ncl — PROOF ARTIFACT for the injection-rule contract.
#
# This file simulates a tampered persona that drops the invariant-core.
# The HasCore contract is applied to a persona-only string (no core_text).
# Expected: nickel export fails with "contract broken by a value", exit 1.
#
# Run:  nix run nixpkgs#nickel -- export conditioning/probe_no_core.ncl
# → should fail; exit non-zero.

let core_text : String = import "core.ncl" in

let HasCore : Dyn = std.contract.from_predicate
  (fun s => std.string.contains core_text (s | String))
in

# A persona-only string — core_text intentionally absent.
let tampered_persona : String = m%"
## Tampered role

This persona has been stripped of the invariant-core.
It contains only the persona delta — no core law.
"% in

{
  "bad-role" | HasCore = tampered_persona,
}
