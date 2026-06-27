# conditioning/compose.ncl
#
# Generator: system_prompt(role) = core_text ++ join(modules) ++ role_delta(role)
# Contract:  HasCore — every generated string must contain core_text verbatim.
#            Export fails with a contract violation if core_text is absent.
#            HasModule / HasLens are sibling verbatim-substring contracts for
#            module and lens text (no persona consumer at N1; see ARCHITECTURE.md §1).
#
# EXPORT INTERFACE
# ----------------
# Evaluates to a record keyed by role identifier.
# Each field value is a String guarded by HasCore.
#
# Extract one role's prompt as plain text:
#   nix run nixpkgs#nickel -- export --format text conditioning/compose.ncl
#   (produces the record; wrap in a one-liner to extract a field)
#
# Via a wrapper file:
#   echo '(import "compose.ncl").architect' \
#     | nix run nixpkgs#nickel -- export --format text
#
# VERIFIED NICKEL IDIOMS (1.14.0 — the project's pinned nickel)
# --------------------------------
#   String concat:  ++
#   Array concat:   @          (arrays use @; strings use ++)
#   String join:    std.string.join sep array  (sep between elements)
#   Import:         import "relative/path.ncl"
#   Contract:       std.contract.from_predicate (fun s => <Bool>)
#   Substring:      std.string.contains needle haystack  (needle first, haystack second)
#   Hyphenated key: "core-worker" = ...

let core_text : String = import "core.ncl" in

let personas : { _ : String } = {
  architect        = import "personas/architect.ncl",
  "core-worker"    = import "personas/core-worker.ncl",
  "refine-worker"  = import "personas/refine-worker.ncl",
  "doc-worker"     = import "personas/doc-worker.ncl",
  "form-worker"    = import "personas/form-worker.ncl",
  "spec-worker"    = import "personas/spec-worker.ncl",
  "boundary-worker" = import "personas/boundary-worker.ncl",
} in

# Module segment. EMPTY at N1: the producer module is N2's deliverable, and an
# empty list collapses the join so every render stays byte-identical to the
# prior two-segment form (core ++ "\n\n" ++ role_delta). When non-empty, each
# module composes *between* core and the role delta — core stays first.
let modules : Array String = [] in

# INJECTION-RULE CONTRACT (ARCHITECTURE.md §4)
# Checks that core_text appears as a verbatim contiguous substring of the
# generated prompt.  Export fails (non-zero exit, error printed) when the
# condition is false — no prompt is emitted.
# Verified: std.string.contains needle haystack -> Bool (needle first).
let HasCore : Dyn = std.contract.from_predicate
  (fun s => std.string.contains core_text (s | String))
in

# Siblings of HasCore for the module and lens slots. Same verbatim-substring
# rule, parameterized by the expected text (there will be many modules and
# lenses). No persona consumes these at N1 — HasModule's bite is proven by
# probe_no_module.ncl; HasLens is defined for downstream reviewer lenses (N12+).
let HasModule : String -> Dyn = fun module_text =>
  std.contract.from_predicate (fun s => std.string.contains module_text (s | String))
in
let HasLens : String -> Dyn = fun lens_text =>
  std.contract.from_predicate (fun s => std.string.contains lens_text (s | String))
in

# Three-segment composition: core ++ join(modules) ++ role_delta. Segments are
# joined with "\n\n"; with `modules` empty this reduces to exactly
# core_text ++ "\n\n" ++ role_delta. Core is always the first segment.
let compose : String -> String = fun role_delta =>
  std.string.join "\n\n" ([core_text] @ modules @ [role_delta])
in

# One field per role.  Every field is typed HasCore; export fails if core_text
# is absent from the composed string.
{
  architect        | HasCore = compose personas.architect,
  "core-worker"    | HasCore = compose personas."core-worker",
  "refine-worker"  | HasCore = compose personas."refine-worker",
  "doc-worker"     | HasCore = compose personas."doc-worker",
  "form-worker"    | HasCore = compose personas."form-worker",
  "spec-worker"    | HasCore = compose personas."spec-worker",
  "boundary-worker" | HasCore = compose personas."boundary-worker",
}
