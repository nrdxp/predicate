# EXPECT: fail
# Negative control for the HasModule sibling contract (see compose.ncl).
# HasModule guards a module segment exactly as HasCore guards the invariant
# core: a generated prompt that drops the module's verbatim text fails export,
# so a module-stripped prompt can never be delivered. This proves the rule
# bites — the mirror of probe_no_core.ncl for the module slot.
#
# Run:  nickel export --format text conditioning/probe_no_module.ncl
# → should fail; exit non-zero with "contract broken by a value".

# The inert N1 placeholder module text. Must match the MODULE_SENTINEL in
# test_conditioning.sh exactly so both controls exercise one marker. The real
# producer module is N2's deliverable; this carries no procedure.
let module_text : String = "Predicate module segment: N1 inert example" in

# Sibling of HasCore: a verbatim-substring contract, parameterized by the
# expected module text. Mirrors compose.ncl's HasModule constructor.
let HasModule : String -> Dyn = fun expected =>
  std.contract.from_predicate
    (fun s => std.string.contains expected (s | String))
in

# A prompt missing the module segment — module_text intentionally absent.
let module_stripped_prompt : String = m%"
## Composed prompt without the module segment

This stands in for a prompt that should carry a module between the core and the
role delta but does not. The HasModule contract must reject it.
"% in

{
  "no-module" | HasModule module_text = module_stripped_prompt,
}
