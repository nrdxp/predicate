# Test fixture: a minimal project-local registry, admitting exactly the one
# tag admitted.md uses. Proves ledger/gate/entries_integrity.sh composes a
# project-local registry that admits a tag the plugin's own (empty) default
# does not (.ledger/tech-debt/tag-registry-ships-predicate-vocabulary.yaml).
# Not predicate's real vocabulary — see .ledger/tag_registry.ncl for that.
{
  project-topic = { category = "topic" },
}
