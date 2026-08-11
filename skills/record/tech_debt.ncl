# Tech-debt record contract (skills/record/tech_debt.ncl).
#
# A tech-debt record is a first-class, machine-shaped entry for a known
# limitation or deferred decision. It ABSORBS the campaign's "accepted
# limitations / tail" — making them trackable and actionable rather than
# buried in prose flight-log entries.
#
# EXTENDS THE ENTRY CORE (ledger/contracts/entry.ncl): a debt is a claim, so
# it carries a signer (who recorded it) and an `at` anchor (the record state
# it was found against — without one, a debt whose surrounding code has moved
# is undetectably stale). The old `signpost` is the core's `discharge`: the
# condition that would resolve or invalidate the debt. The category fields
# (severity, why_deferred, location) are the record's own and stay.
#
# Instance format: YAML (validated via:
#   nickel export <file>.yaml --apply-contract skills/record/tech_debt_apply.ncl)
let e = import "../../ledger/contracts/entry.ncl" in
{
  # Severity: value-restricted tag-or-string (ruling D-6) through the core's
  # `matches`, named so a shape red carries its own token.
  Severity = std.contract.custom (fun _label v =>
    if e.matches v 'critical "critical" || e.matches v 'high "high"
       || e.matches v 'medium "medium" || e.matches v 'low "low"
    then 'Ok v
    else 'Error { message = "Severity: expected critical|high|medium|low (tag or string)" }
  ),

  # One tech-debt record.
  TechDebt = {
    id           | e.NonEmptyString,  # unique within the store
    claim        | e.NonEmptyString,  # falsifiable statement of the debt
    location     | e.NonEmptyString,  # file:line, gate, component, or system area
    severity     | Severity,          # critical | high | medium | low
    why_deferred | e.NonEmptyString,  # reason this was not fixed when discovered
    discharge    | e.NonEmptyString,  # what would resolve or invalidate this debt
    signer       | e.Signer,          # who recorded the debt
    at           | e.CommitRef,       # the record state it was found against
  },

  # Store contract: validates an array of records with id uniqueness enforced.
  # Usage: { items = [...] } | TechDebtStore
  TechDebtStore = std.contract.custom (fun _label value =>
    let items = value.items in
    let ids = std.array.map (fun d => d.id) items in
    let dedup =
      std.array.fold_left
        (fun acc x => if std.array.elem x acc then acc else acc @ [x])
        []
        ids
    in
    let _conformance =
      std.array.fold_left
        (fun acc d => std.deep_seq (d | TechDebt) acc)
        null
        items
    in
    std.seq _conformance (
      if std.array.length ids != std.array.length dedup
      then 'Error { message = "duplicate tech-debt id" }
      else 'Ok value
    )
  ),
}
