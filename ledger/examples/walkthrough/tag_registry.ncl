# The worked example's own project-local registry, admitting exactly the
# two tags deposit.md uses. ledger/contracts/tag_registry.ncl ships EMPTY
# (.ledger/tech-debt/tag-registry-ships-predicate-vocabulary.yaml): the
# walkthrough is itself a corpus, so it needs its own vocabulary the same
# way any adopting project would, following the pattern
# ledger/fixtures/extract/tagreg-project/tag_registry.ncl and
# ledger/fixtures/topic_query/tagreg/tag_registry.ncl already establish.
#
# `refused/unadmitted-tag.md`'s `speedup` tag stays refused: its governing
# directory is `refused/`, which has no sibling registry of its own, so the
# per-path discovery in entries_integrity.sh (and the equivalent
# TOPIC_QUERY_LEDGER_ROOT-scoped discovery in topic_query.sh) never composes
# this file in for it.
{
  perf = { category = "topic" },
  gate-mechanism = { category = "topic" },
}
