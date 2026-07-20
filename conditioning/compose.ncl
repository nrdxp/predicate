# conditioning/compose.ncl
#
# Generator: system_prompt(role) = core_text ++ join(modules) ++ role_delta(role)
# Contract:  HasCore — every generated string must contain core_text verbatim.
#            Export fails with a contract violation if core_text is absent.
#            HasModule / HasLens are sibling verbatim-substring contracts for
#            module and lens text. The nine reviewer fields below consume them:
#            all nine carry HasModule reviewer_module; the eight lensed reviewers
#            also carry HasLens <their delta> (see docs/conditioning-layer.md
#            §The injection-rule contracts).
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
#   echo '(import "compose.ncl").composer' \
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
  composer         = import "personas/composer.ncl",
  "core-worker"    = import "personas/core-worker.ncl",
  "refine-worker"  = import "personas/refine-worker.ncl",
  "doc-worker"     = import "personas/doc-worker.ncl",
  "form-worker"    = import "personas/form-worker.ncl",
  "spec-worker"    = import "personas/spec-worker.ncl",
  "boundary-worker" = import "personas/boundary-worker.ncl",
  "survey-worker"  = import "personas/survey-worker.ncl",
  "test-worker"    = import "personas/test-worker.ncl",
} in

# Module segments. The producer carries the action PROCEDURE (the writer's test
# loop and mandatory halts); compose pulls it per role — code-writers receive it,
# review-only roles do not (see the per-role wiring below). Each module composes
# *between* core and the role delta — core stays first.
let producer : String = import "modules/producer.ncl" in

# Dispatched-walk module: the station every DISPATCHED subagent carries — the
# unattended/auto-mode ground truth, the composer-as-only-human-channel rule
# (a relayed authorization IS human authorization), workspace confirmation,
# explicit exit-code capture, and dispatch-is-commit-authorization. EVERY role
# except the composer pulls it, first in its module list: the composer is the
# dispatcher and human-facing conductor, so the station would be false for it.
let dispatched : String = import "modules/dispatched.ncl" in

# Reviewer-class module: the read-only adversarial-reviewer spine. Reviewers are
# read-only — each composes [reviewer_module], NEVER [producer]; pulling producer
# into a reviewer would erase the decorrelation the class exists to provide.
let reviewer_module : String = import "modules/reviewer.ncl" in

# Reviewer deltas: the lens-free refuter plus the eight lens overlays. Each is a
# plain String delta; composed atop core ++ reviewer_module.
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

# Council-class module: the shared station every architect-tier SEAT carries (the
# pact, the deliberation protocol, the governance spine). Seats are NOT code-writers
# — each composes [council_module], NEVER [producer]; the seat's role-divergent lens
# is the delta layered atop it. Sibling of reviewer_module one tier up.
let council_module : String = import "modules/council.ncl" in

# Seat deltas: the three landed standing-council seats. Each is a plain String
# delta (the seat's lens); composed atop core ++ council_module.
let council : { _ : String } = {
  "architect-seat"       = import "personas/architect-seat.ncl",
  "lead-maintainer-seat" = import "personas/lead-maintainer-seat.ncl",
  "process-auditor-seat" = import "personas/process-auditor-seat.ncl",
  "hacker-seat"          = import "personas/hacker-seat.ncl",
} in

# Constitution render. The single-sourced project constitution
# (conditioning/constitution.ncl, a Nickel value conforming to council.ncl's
# `Constitution`) is RENDERED to prose here and folded into the composer's prompt as a
# segment — so the live conductor is conditioned with the very council law it conducts.
# The delegation rows are GENERATED from the value (decision_type -> owner ->
# required_assent), never hand-copied: editing the constitution re-renders the prompt.
# Native enum tags (`required_assent`) are displayed via std.to_string; `head` /
# `conductor` are optional, hence the has_field guards.
let constitution = import "constitution.ncl" in
let council_render =
  let render_seat = fun s =>
    let mark =
      if std.record.has_field "head" s && s.head then " [head — ratifier]"
      else if std.record.has_field "conductor" s && s.conductor then " [conductor — you]"
      else "" in
    "- %{s.id} (%{s.role})%{mark}" in
  let render_rule = fun r =>
    "- %{r.decision_type} → %{r.owner} → %{std.to_string r.required_assent}" in
  let seats = std.string.join "\n" (std.array.map render_seat constitution.seats) in
  let rules = std.string.join "\n" (std.array.map render_rule constitution.delegation) in
  m%"
## Predicate's Constitution — the council delegation table

You CONDUCT this council. Route every decision-type to its owner per the live law
below (decision_type → owner → required_assent); never invent a rule for a type it
does not list.

Seats:
%{seats}

Delegation:
%{rules}
"% in

# INJECTION-RULE CONTRACT (docs/conditioning-layer.md §The injection-rule contracts)
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
# is absent from the composed string. EVERY dispatched role (all but the
# composer) pulls [dispatched] first — the unattended-walk station — and
# carries HasModule dispatched so its omission fails the export. The four
# code-writer workers additionally pull [producer]; the review-only roles
# (doc, boundary, survey) pull no producer. The composer pulls neither — it is
# the dispatcher and the human-facing conductor, not a dispatched walk.
{
  composer         | HasCore = compose [council_render] personas.composer,
  "core-worker"    | HasCore | HasModule dispatched
    = compose [dispatched, producer] personas."core-worker",
  "refine-worker"  | HasCore | HasModule dispatched
    = compose [dispatched, producer] personas."refine-worker",
  "doc-worker"     | HasCore | HasModule dispatched
    = compose [dispatched] personas."doc-worker",
  "form-worker"    | HasCore | HasModule dispatched
    = compose [dispatched, producer] personas."form-worker",
  "spec-worker"    | HasCore | HasModule dispatched
    = compose [dispatched, producer] personas."spec-worker",
  "test-worker"    | HasCore | HasModule dispatched
    = compose [dispatched, producer] personas."test-worker",
  "boundary-worker" | HasCore | HasModule dispatched
    = compose [dispatched] personas."boundary-worker",
  "survey-worker"  | HasCore | HasModule dispatched
    = compose [dispatched] personas."survey-worker",

  # Reviewer fields: core ++ dispatched ++ reviewer_module ++ lens-delta. Each
  # is HasCore + HasModule dispatched + HasModule reviewer_module; the eight
  # lenses also carry HasLens <their delta>. The lens-free refuter has NO
  # HasLens. None pulls [producer] — read-only.
  "refuter-reviewer"    | HasCore | HasModule dispatched | HasModule reviewer_module
    = compose [dispatched, reviewer_module] reviewers."refuter-reviewer",
  "hickey-reviewer"     | HasCore | HasModule dispatched | HasModule reviewer_module | HasLens reviewers."hickey-reviewer"
    = compose [dispatched, reviewer_module] reviewers."hickey-reviewer",
  "lowy-reviewer"       | HasCore | HasModule dispatched | HasModule reviewer_module | HasLens reviewers."lowy-reviewer"
    = compose [dispatched, reviewer_module] reviewers."lowy-reviewer",
  "api-reviewer"        | HasCore | HasModule dispatched | HasModule reviewer_module | HasLens reviewers."api-reviewer"
    = compose [dispatched, reviewer_module] reviewers."api-reviewer",
  "security-reviewer"   | HasCore | HasModule dispatched | HasModule reviewer_module | HasLens reviewers."security-reviewer"
    = compose [dispatched, reviewer_module] reviewers."security-reviewer",
  "git-review-reviewer" | HasCore | HasModule dispatched | HasModule reviewer_module | HasLens reviewers."git-review-reviewer"
    = compose [dispatched, reviewer_module] reviewers."git-review-reviewer",
  "ai-slop-reviewer"    | HasCore | HasModule dispatched | HasModule reviewer_module | HasLens reviewers."ai-slop-reviewer"
    = compose [dispatched, reviewer_module] reviewers."ai-slop-reviewer",
  "prior-art-reviewer"  | HasCore | HasModule dispatched | HasModule reviewer_module | HasLens reviewers."prior-art-reviewer"
    = compose [dispatched, reviewer_module] reviewers."prior-art-reviewer",
  "vestigial-reviewer"  | HasCore | HasModule dispatched | HasModule reviewer_module | HasLens reviewers."vestigial-reviewer"
    = compose [dispatched, reviewer_module] reviewers."vestigial-reviewer",

  # Council-seat fields: core ++ dispatched ++ council_module ++ seat-delta.
  # Each is HasCore + HasModule dispatched + HasModule council_module; the seat
  # lens decorrelates them by ROLE. None pulls [producer] — seats reason about
  # the architecture, they do not write code.
  "architect-seat"       | HasCore | HasModule dispatched | HasModule council_module
    = compose [dispatched, council_module] council."architect-seat",
  "lead-maintainer-seat" | HasCore | HasModule dispatched | HasModule council_module
    = compose [dispatched, council_module] council."lead-maintainer-seat",
  "process-auditor-seat" | HasCore | HasModule dispatched | HasModule council_module
    = compose [dispatched, council_module] council."process-auditor-seat",
  "hacker-seat"          | HasCore | HasModule dispatched | HasModule council_module
    = compose [dispatched, council_module] council."hacker-seat",
}
