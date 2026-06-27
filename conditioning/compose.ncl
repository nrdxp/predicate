# conditioning/compose.ncl
#
# Generator: system_prompt(role) = core_text ++ join(modules) ++ role_delta(role)
# Contract:  HasCore — every generated string must contain core_text verbatim.
#            Export fails with a contract violation if core_text is absent.
#            HasModule / HasLens are sibling verbatim-substring contracts for
#            module and lens text. The nine reviewer fields below consume them:
#            all nine carry HasModule reviewer_module; the eight lensed reviewers
#            also carry HasLens <their delta> (see ARCHITECTURE.md §1).
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

# Module segments. The producer carries the action PROCEDURE (the writer's test
# loop and mandatory halts); compose pulls it per role — code-writers receive it,
# review-only roles do not (see the per-role wiring below). Each module composes
# *between* core and the role delta — core stays first.
let producer : String = import "modules/producer.ncl" in

# Reviewer-class module: the read-only adversarial-reviewer spine. Reviewers are
# read-only — each composes [reviewer_module], NEVER [producer]; pulling producer
# into a reviewer would erase the decorrelation the class exists to provide.
let reviewer_module : String = import "modules/reviewer.ncl" in

# Reviewer deltas: the lens-free refuter plus the eight lens overlays. Each is a
# plain String delta (N3/N4 bodies); composed atop core ++ reviewer_module.
let reviewers : { _ : String } = {
  "refuter-reviewer"    = import "personas/refuter-reviewer.ncl",
  "hickey-reviewer"     = import "personas/hickey-reviewer.ncl",
  "lowy-reviewer"       = import "personas/lowy-reviewer.ncl",
  "api-reviewer"        = import "personas/api-reviewer.ncl",
  "security-reviewer"   = import "personas/security-reviewer.ncl",
  "git-review-reviewer" = import "personas/git-review-reviewer.ncl",
  "ai-slop-reviewer"    = import "personas/ai-slop-reviewer.ncl",
  "prior-art-reviewer"  = import "personas/prior-art-reviewer.ncl",
  "vestigial-reviewer"  = import "personas/vestigial-reviewer.ncl",
} in

# INJECTION-RULE CONTRACT (ARCHITECTURE.md §4)
# Checks that core_text appears as a verbatim contiguous substring of the
# generated prompt.  Export fails (non-zero exit, error printed) when the
# condition is false — no prompt is emitted.
# Verified: std.string.contains needle haystack -> Bool (needle first).
let HasCore : Dyn = std.contract.from_predicate
  (fun s => std.string.contains core_text (s | String))
in

# Siblings of HasCore for the module and lens slots. Same verbatim-substring
# rule, parameterized by the expected text. The reviewer fields below consume
# both: every reviewer carries HasModule reviewer_module, and the eight lensed
# reviewers additionally carry HasLens over their lens delta (the lens-free
# refuter carries only HasModule).
let HasModule : String -> Dyn = fun module_text =>
  std.contract.from_predicate (fun s => std.string.contains module_text (s | String))
in
let HasLens : String -> Dyn = fun lens_text =>
  std.contract.from_predicate (fun s => std.string.contains lens_text (s | String))
in

# Three-segment composition: core ++ join(role_modules) ++ role_delta. Segments
# are joined with "\n\n"; with `role_modules` empty this reduces to exactly
# core_text ++ "\n\n" ++ role_delta. Core is always the first segment. The module
# list is a per-role argument so each role pulls only the modules it needs.
let compose : Array String -> String -> String = fun role_modules role_delta =>
  std.string.join "\n\n" ([core_text] @ role_modules @ [role_delta])
in

# One field per role.  Every field is typed HasCore; export fails if core_text
# is absent from the composed string. The five code-writers pull [producer]; the
# two review-only roles (doc, boundary) pull [] — they shed the action procedure.
{
  architect        | HasCore = compose [producer] personas.architect,
  "core-worker"    | HasCore = compose [producer] personas."core-worker",
  "refine-worker"  | HasCore = compose [producer] personas."refine-worker",
  "doc-worker"     | HasCore = compose [] personas."doc-worker",
  "form-worker"    | HasCore = compose [producer] personas."form-worker",
  "spec-worker"    | HasCore = compose [producer] personas."spec-worker",
  "boundary-worker" | HasCore = compose [] personas."boundary-worker",

  # Reviewer fields: core ++ reviewer_module ++ lens-delta. Each is HasCore +
  # HasModule reviewer_module; the eight lenses also carry HasLens <their delta>.
  # The lens-free refuter has NO HasLens. None pulls [producer] — read-only.
  "refuter-reviewer"    | HasCore | HasModule reviewer_module
    = compose [reviewer_module] reviewers."refuter-reviewer",
  "hickey-reviewer"     | HasCore | HasModule reviewer_module | HasLens reviewers."hickey-reviewer"
    = compose [reviewer_module] reviewers."hickey-reviewer",
  "lowy-reviewer"       | HasCore | HasModule reviewer_module | HasLens reviewers."lowy-reviewer"
    = compose [reviewer_module] reviewers."lowy-reviewer",
  "api-reviewer"        | HasCore | HasModule reviewer_module | HasLens reviewers."api-reviewer"
    = compose [reviewer_module] reviewers."api-reviewer",
  "security-reviewer"   | HasCore | HasModule reviewer_module | HasLens reviewers."security-reviewer"
    = compose [reviewer_module] reviewers."security-reviewer",
  "git-review-reviewer" | HasCore | HasModule reviewer_module | HasLens reviewers."git-review-reviewer"
    = compose [reviewer_module] reviewers."git-review-reviewer",
  "ai-slop-reviewer"    | HasCore | HasModule reviewer_module | HasLens reviewers."ai-slop-reviewer"
    = compose [reviewer_module] reviewers."ai-slop-reviewer",
  "prior-art-reviewer"  | HasCore | HasModule reviewer_module | HasLens reviewers."prior-art-reviewer"
    = compose [reviewer_module] reviewers."prior-art-reviewer",
  "vestigial-reviewer"  | HasCore | HasModule reviewer_module | HasLens reviewers."vestigial-reviewer"
    = compose [reviewer_module] reviewers."vestigial-reviewer",
}
