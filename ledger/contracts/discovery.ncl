# Discovery sub-procedure contract (architecture.md §DISCOVERY).
#
# PURPOSE (two-purpose principle, primitives-spec.md §P-GROUND):
#   1. FORMAL GATE — did the walk deposit a footprint for every required step?
#      (omission → hard-fail; deposit must be non-empty + shaped)
#   2. REVIEWER SUBSTRATE — each deposit is a structured DiscoveryDeposit, not
#      a free-text blob; the machine checks modality+evidence; the reviewer
#      judges whether the search was adequate.
#
# STEP SET (required, pinned UPSTREAM — the F-REQ property):
#   establish-universe  internal / structure   — git ls-files enumeration
#   map-intent          internal / semantics   — intent-relevant loci
#   blast-radius        internal / coupling    — transitive impact set (loopable)
#   outward-world       external / domain      — prior art / refs / triviality
#   outward-environment external / arsenal     — approach-changing capability
#
# These five ids are the discriminating set. The walk supplies only deposits;
# it never authors the set that judges it.
#
# SEARCH-CALCULUS MODALITY ENUM (cost-ordered, cheapest-sufficient):
#   keyword < regex < fuzzy < semantic < structural_map < trace
#   'none reserved for outward-* steps (web/skill surveys — no search modality)
#
# FOOTPRINT-PRESENCE vs REQUIRED-SET:
#   - complete_for checks ≥1 deposit per required step-id (loops allowed).
#   - blast-radius may appear multiple times (tracing several symbols); ≥1 passes.
#
# COMPOSITION with deposit.ncl:
#   Each deposit in a DiscoveryInstance is a DiscoveryDeposit — a Deposit
#   (from deposit.ncl) merged with a `modality` field. The DepositStore gate
#   (from deposit.ncl) enforces id-uniqueness and referential integrity;
#   DiscoveryStore additionally enforces DiscoveryDeposit shape.
#
# VERIFICATION:
#   CONTRACT DEFINITIONS (this file): nix run nixpkgs#nickel -- typecheck
#   INSTANCES / FIXTURES:             nix run nixpkgs#nickel -- export -I <contracts-dir>
#
# RUNNER NOTE: `nickel` resolves via PATH or `nix run nixpkgs#nickel --`.
let { Deposit, DepositStore, NonEmptyString, .. } = import "deposit.ncl" in

{
  # ── Modality enum (search-calculus, cost-ordered) ───────────────────────────
  # The walk deposits which modality was chosen, making the search tier
  # structurally checkable. Adequacy (was it the right tier?) → review.
  # 'none is reserved for outward-* steps that use web/skill surveys rather
  # than a code-search tool.
  Modality = [|
    'keyword,        # rg -F / exact token — cheapest
    'regex,          # ripgrep pattern — cheap
    'fuzzy,          # fzf / approximate — cheap
    'semantic,       # grepai search — priciest, intent-only fallback
    'structural_map, # git ls-files / universe enumeration
    'trace,          # grepai trace callers/callees/graph — coupling
    'none,           # no code-search (web fetch, skill survey, etc.)
  |],

  # ── DiscoveryDeposit ─────────────────────────────────────────────────────────
  # A Deposit (from deposit.ncl — id, step, evidence, cites, refs) extended with
  # a `modality` field.  The `step` field SHOULD be one of the five required ids
  # (enforced at presence level by complete_for); individual step shape comes
  # from the base Deposit contract.
  DiscoveryDeposit = Deposit & {
    modality | Modality,
  },

  # ── DiscoveryStore ───────────────────────────────────────────────────────────
  # A standalone store contract for DiscoveryDeposit arrays. It replicates the
  # DepositStore invariants (id-uniqueness, ref integrity, Evidence shape,
  # DepositRef shape) using DiscoveryDeposit for per-element checks, so the
  # extra `modality` field is accepted rather than rejected by a strict Deposit
  # contract application.
  #
  # DepositStore is NOT composed here because its inner fold applies `d | Deposit`
  # (a strict record contract that rejects extra fields), which would reject the
  # `modality` field that every DiscoveryDeposit carries. Pattern: inline the
  # same invariants from deposit.ncl §DepositStore, substituting DiscoveryDeposit.
  DiscoveryStore = std.contract.custom (fun _label value =>
    let deposits = value.deposits in

    # (a) Per-deposit DiscoveryDeposit conformance (eager).
    # Checks id+step+evidence (NonEmptyString + non-empty array), cites, refs,
    # AND the modality field. Uses deep_seq to force eagerly (same pattern as
    # DepositStore's Deposit fold).
    let _deposit_conformance =
      std.array.fold_left
        (fun acc d => std.deep_seq (d | DiscoveryDeposit) acc)
        null
        deposits
    in

    # (b) Per-ref and per-evidence conformance inside each deposit (eager).
    let { Evidence, DepositRef, .. } = import "deposit.ncl" in
    let _nested_conformance =
      std.array.fold_left
        (fun acc d =>
          let _evs =
            std.array.fold_left
              (fun a2 ev => std.deep_seq (ev | Evidence) a2)
              acc
              d.evidence
          in
          std.array.fold_left
            (fun a3 r => std.deep_seq (r | DepositRef) a3)
            _evs
            d.refs)
        null
        deposits
    in

    let ids = std.array.map (fun d => d.id) deposits in

    # (c) Id uniqueness.
    let dedup =
      std.array.fold_left
        (fun acc x => if std.array.elem x acc then acc else acc @ [x])
        []
        ids
    in
    let unique_ids = std.array.length ids == std.array.length dedup in

    # (d) Referential integrity: every ref.target must be a declared deposit id.
    let all_refs_resolve =
      std.array.all
        (fun d =>
          std.array.all
            (fun r => std.array.elem r.target ids)
            d.refs)
        deposits
    in

    std.seq _deposit_conformance (
      std.seq _nested_conformance (
        if !unique_ids
        then 'Error { message = "duplicate discovery deposit id" }
        else if !all_refs_resolve
        then 'Error { message = "dangling DepositRef: ref.target does not resolve to a declared deposit id" }
        else 'Ok value
      )
    )
  ),

  # ── complete_for (F-REQ combinator) ─────────────────────────────────────────
  # Returns a contract that verifies every required step-id is covered by at
  # least one deposit.  Loops are allowed (a step may appear multiple times);
  # ≥1 deposit per id satisfies presence.
  #
  # Usage:
  #   value | DiscoveryStore | DiscoveryComplete
  #   (compose DiscoveryStore FIRST so referential integrity is already enforced)
  #
  # The required-set is pinned HERE — the walk supplies only the deposits array
  # and never touches the set that judges it.
  complete_for = fun required =>
    std.contract.from_predicate (fun value =>
      let step_ids = std.array.map (fun d => d.step) value.deposits in
      std.array.all
        (fun req => std.array.any (fun sid => sid == req) step_ids)
        required
    ),

  # ── DiscoveryComplete (exported gate) ───────────────────────────────────────
  # The canonical required-step set, pinned upstream and exported as a named
  # contract.  Any caller that composes this contract inherits the full five-step
  # set without being able to shrink it (the F-REQ invariant).
  #
  # Shrink-attack: removing any id from the required list below causes a
  # well-formed skip fixture (missing that step) to pass DiscoveryComplete —
  # which is why the set lives HERE, not in the instance.
  DiscoveryComplete = complete_for [
    "establish-universe",
    "map-intent",
    "blast-radius",
    "outward-world",
    "outward-environment",
  ],
}
