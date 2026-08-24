# Test fixture: a minimal project-local registry, admitting exactly the one
# tag entry.md uses. Proves ledger/gate/topic_query.sh composes a
# project-local registry the same way ledger/gate/entries_integrity.sh does
# (.ledger/tech-debt/tag-registry-ships-predicate-vocabulary.yaml). Not
# predicate's real vocabulary — see .ledger/tag_registry.ncl for that.
{
  topic-query-tag = { category = "topic" },
}
