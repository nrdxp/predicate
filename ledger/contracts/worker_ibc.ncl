# Worker-IBC contract. A worker IBC is the boundary a single worker walk
# executes under. It renders the S1-S7 sufficiency shape of templates/IBC.md:
# metadata (including the S7 single discipline), the singular goal, non-goals,
# premises (S1), decision rights (S3), constraints (S4), context map (S5),
# acceptance criteria, and the amendment partition (S6).
#
# EXTENDS THE ENTRY CORE (entry.ncl). The boundary is claim-bearing three ways,
# and each gets the core's shape rather than a private vocabulary:
#
#   - PREMISES are claim entries: the old free-text check/verified pair is the
#     core Check (command, ran, at) plus the entry's backing machinery. A
#     premise must be CLOSED (check or witness) — an unclosed premise is an
#     assumption, and generating under unvalidated assumptions is the exact
#     failure a boundary exists to prevent.
#   - UNKNOWNS enter as question entries: discharge condition AND named closer
#     (the core's QuestionRoutable), first-class instead of buried in prose.
#   - NORMATIVE CONTENT (goal, non-goals, constraints, criteria) are
#     DIRECTIVES (ruling E-1): a directive does not carry a truth-value, so it
#     closes by AUTHORITY — a provenance Signer naming the issuing party —
#     never by evidence. The record is CLOSED: `backing`, `axes`, `discharge`
#     on a directive are category errors, rejected as extra fields with no
#     enforcement code (record contracts without `..` are closed by default).
#
# Intrinsic gate (boundary sufficiency): there MUST be at least one acceptance
# criterion (without a definition of done the walk is unbounded). The old
# empty-goal branch is SUBSUMED: goal is a Directive and its statement is
# NonEmptyString, so the empty goal is a shape red — a second check here would
# be a dead enforcement path no mutation could expose.
#
# The `discipline` enum is imported from `discipline.ncl` — the single
# canonical definition shared with `dag.ncl` (T1.1).
let disciplines = import "discipline.ncl" in
let e = import "entry.ncl" in
{
  # ── The Directive record (ruling E-1) — defined ONCE, here, in the boundary
  # layer; context_map.ncl imports it for its R/I/C rows. ─────────────────────
  Directive = {
    id | e.NonEmptyString,
    statement | e.NonEmptyString,
    provenance | e.Signer,        # the issuing authority
    depends | Array e.Ref | optional,
    because | Array e.Ref | optional,
  },

  # A directive's provenance designates its authority the way an entry's
  # signer designates its party (the core's SignerDesignates, restated over
  # `provenance` because the field names differ): non-derived names the
  # party; derived carries no name and at least one inbound edge.
  DirectiveDesignates = fun d =>
    if e.matches d.provenance.kind 'derived "derived"
    then
      !(std.record.has_field "name" d.provenance)
      && std.array.length (e.edges_of d) > 0
    else std.record.has_field "name" d.provenance,

  DirectiveChecked = std.contract.all_of [
    Directive,
    e.asContract "DirectiveDesignates" DirectiveDesignates,
  ],

  # Directive specializations: a constraint carries its evaluator, a criterion
  # its eval — HOW compliance is checked, which is not backing (the directive
  # itself still closes by authority). Record merge extends the closed base;
  # the merged records stay closed.
  Constraint = Directive & { evaluator | e.NonEmptyString },
  ConstraintChecked = std.contract.all_of [
    Constraint,
    e.asContract "DirectiveDesignates" DirectiveDesignates,
  ],

  Criterion = Directive & { eval | e.NonEmptyString },
  CriterionChecked = std.contract.all_of [
    Criterion,
    e.asContract "DirectiveDesignates" DirectiveDesignates,
  ],

  # ── Premises and unknowns as core entries ───────────────────────────────────
  # A premise asserts a truth-value about the world the walk stands on.
  PremiseIsClaim = fun n => e.matches n.assertion 'claim "claim",

  # A premise must be closed by one of the two species — an unclosed premise
  # (even a legitimately-derived synthesis) is an assumption the dispatch
  # would be built on.
  PremiseClosed = fun n =>
    std.record.has_field "check" n || std.record.has_field "witness" n,

  PremiseChecked = std.contract.all_of (
    [e.Entry]
    @ e.lifted
    @ [
      e.asContract "PremiseIsClaim" PremiseIsClaim,
      e.asContract "PremiseClosed" PremiseClosed,
    ]
  ),

  # An unknown filed as anything but a question dodges QuestionRoutable (the
  # discharge + closer requirement) — mis-filing is the evasion this blocks.
  UnknownIsQuestion = fun n => e.matches n.assertion 'question "question",

  UnknownChecked = std.contract.all_of (
    [e.Entry]
    @ e.lifted
    @ [e.asContract "UnknownIsQuestion" UnknownIsQuestion]
  ),

  # ── The IBC record ──────────────────────────────────────────────────────────
  Worker = {
    id | e.NonEmptyString,
    tier | e.NonEmptyString,      # architect | worker + model class
    discipline | disciplines.Discipline,   # S7: exactly ONE control loop (shared enum)
    depends | Array e.Ref | optional,      # upstream IBC ids: deleted -> this IBC breaks
    because | Array e.Ref | optional,      # upstream ids that only motivate
    goal | DirectiveChecked,      # S0: the singular objective
    non_goals | Array DirectiveChecked,    # forbidden regions
    premises | Array PremiseChecked,       # S1: claim entries, closed
    unknowns | Array UnknownChecked | optional,   # question entries, routable
    delegated | Array String,     # S3: the walker's calls
    reserved | Array String,      # S3: halt predicates (the human's calls)
    constraints | Array ConstraintChecked, # S4
    context_map | Array String,   # S5: pointers / verbatim excerpts
    acceptance | Array CriterionChecked,   # definition of done
    load_bearing | Array String,  # S6: amendment returns to the human
    plastic | Array String,       # S6: walker may revise with logged justification
  },

  # The sufficiency gate, composed AFTER `Worker` (like DagNoConflict after Dag):
  #   value | Worker | WorkerIBC
  WorkerIBC = std.contract.custom (fun _label value =>
    if std.array.length value.acceptance == 0
    then 'Error { message = "worker IBC has no acceptance criteria (unbounded walk)" }
    else 'Ok value
  ),
}
