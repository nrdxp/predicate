# The admissible tag vocabulary — the coining bar itself.
#
# ledger/log/2026-08-12-tagging-hypothesis.md [G8]: "the risk is not in the
# hypothesis but in shipping tags without their registry." An open tag
# vocabulary becomes a second unmaintained namespace, which is the failure
# already recorded for directions (.ledger/directions.md's own header: "This
# document is not that text and must never become a copy of it"). So a tag is
# never authored free-form on an entry — it is admitted here FIRST, by a
# deliberate edit to this file, and entry.ncl's `TagName` contract (the
# admission check) refuses anything this record does not declare.
#
# `category` distinguishes DIRECTION tags — whose value is a direction's own
# marker in .ledger/directions.md (D1, D2, D3) — from every other kind a
# future addition might register. entries_query.ncl's `by_direction` view
# reads this field to select the direction subset out of the general tag
# index, rather than pattern-matching the tag string: admission and
# classification stay two readings of ONE record instead of drifting into two.
#
# TODAY every registered tag is a direction — the only tag class this pass
# was asked to ship (composer dispatch: "do not tag any existing entry...
# ship the mechanism and the registry"). `by_tag` and `by_direction` therefore
# coincide extensionally until a non-direction tag is registered; that is the
# honest state of an empty-but-typed vocabulary, not a defect of either view
# — see the by_tag/by_direction doc comment in entries_query.ncl.
{
  D1 = { category = "direction" },
  D2 = { category = "direction" },
  D3 = { category = "direction" },
}
