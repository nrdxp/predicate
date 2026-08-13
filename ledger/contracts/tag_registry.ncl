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
# marker in .ledger/directions.md (D1, D2, D3) — from TOPIC tags, admission's
# other class. entries_query.ncl's `with_tags` selector never reads this
# field at all (it intersects on tag NAME alone, direction and topic in one
# namespace by design); `category` stays recorded here purely as
# classification metadata for a reader browsing the registry itself.
#
# `perf` is the first registered topic tag (node/tag-query,
# ledger/log/2026-08-12-tagging-hypothesis.md's own composer dispatch: "do
# not tag any existing entry... ship the mechanism and the registry" no
# longer bounds the registry to directions alone — a composed query spanning
# a direction and a topic needed a real second class to prove against, not a
# hypothetical one). Nothing in the corpus carries it yet; an admitted,
# idle tag is the registry's honest starting state for a class, the same as
# it was for D1–D3 before this pass.
{
  D1 = { category = "direction" },
  D2 = { category = "direction" },
  D3 = { category = "direction" },
  awaiting-head = { category = "topic" },
  failure-class = { category = "topic" },
  gate-mechanism = { category = "topic" },
  perf = { category = "topic" },
  record-integrity = { category = "topic" },
  unbacked = { category = "topic" },
}
