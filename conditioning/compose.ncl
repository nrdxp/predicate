# conditioning/compose.ncl
#
# Generator: system_prompt(role) = core_text ++ "\n\n" ++ persona(role)
# Contract:  HasCore — every generated string must contain core_text verbatim.
#            Export fails with a contract violation if core_text is absent.
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

# INJECTION-RULE CONTRACT (ARCHITECTURE.md §4)
# Checks that core_text appears as a verbatim contiguous substring of the
# generated prompt.  Export fails (non-zero exit, error printed) when the
# condition is false — no prompt is emitted.
# Verified: std.string.contains needle haystack -> Bool (needle first).
let HasCore : Dyn = std.contract.from_predicate
  (fun s => std.string.contains core_text (s | String))
in

# One field per role.  Every field is typed HasCore; export fails if core_text
# is absent from the composed string.
{
  architect        | HasCore = core_text ++ "\n\n" ++ personas.architect,
  "core-worker"    | HasCore = core_text ++ "\n\n" ++ personas."core-worker",
  "refine-worker"  | HasCore = core_text ++ "\n\n" ++ personas."refine-worker",
  "doc-worker"     | HasCore = core_text ++ "\n\n" ++ personas."doc-worker",
  "form-worker"    | HasCore = core_text ++ "\n\n" ++ personas."form-worker",
  "spec-worker"    | HasCore = core_text ++ "\n\n" ++ personas."spec-worker",
  "boundary-worker" | HasCore = core_text ++ "\n\n" ++ personas."boundary-worker",
}
