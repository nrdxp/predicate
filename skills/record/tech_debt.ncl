# Tech-debt record contract (skills/record/tech_debt.ncl).
#
# A tech-debt record is a first-class, machine-shaped entry for a known
# limitation or deferred decision. It ABSORBS the campaign's "accepted
# limitations / tail" — making them trackable and actionable rather than
# buried in prose flight-log entries.
#
# Instance format: YAML (validated via:
#   nickel export <file>.yaml --apply-contract skills/record/tech_debt_apply.ncl)
#
# `severity` mirrors findings.ncl's enum, using the same value-restricted
# tag-or-string pattern so a YAML string ("medium") and a Nickel tag ('medium)
# both satisfy the contract.
#
# `signpost` mirrors the signpost discipline from ambient.md §known-unknowns:
# the observable that would resolve or invalidate the debt.
{
  NonEmptyString = std.contract.from_predicate (fun v =>
    std.is_string v && std.string.length v > 0
  ),

  # Severity: value-restricted tag-or-string so both Nickel tags ('medium) and
  # YAML strings ("medium") satisfy the contract without modification.
  Severity = std.contract.from_predicate (fun v =>
    v == 'critical || v == "critical"
    || v == 'high    || v == "high"
    || v == 'medium  || v == "medium"
    || v == 'low     || v == "low"
  ),

  # One tech-debt record.
  TechDebt = {
    id           | NonEmptyString,  # unique within the store
    claim        | NonEmptyString,  # falsifiable statement of the debt
    location     | NonEmptyString,  # file:line, gate, component, or system area
    severity     | Severity,        # critical | high | medium | low
    why_deferred | NonEmptyString,  # reason this was not fixed when discovered
    signpost     | NonEmptyString,  # what would resolve or invalidate this debt
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
