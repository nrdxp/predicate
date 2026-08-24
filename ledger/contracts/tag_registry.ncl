# The admissible tag vocabulary this PLUGIN ships — deliberately EMPTY.
#
# .ledger/tech-debt/tag-registry-ships-predicate-vocabulary.yaml: this file
# used to carry D1-D3 (predicate's OWN direction markers, pointing at
# predicate's own .ledger/directions.md) plus six topic tags coined for
# predicate's own development, and every project adopting this plugin
# inherited them. That is a category error for the direction markers
# specifically — a direction marker's value is its own corpus's own
# directions.md entry, so it is per-corpus BY DEFINITION, never plugin
# machinery — and an unjustified universal for the topics: nothing about
# "conditioning", "failure-class", "gate-mechanism", "perf",
# "record-integrity", or "verification-dual" generalizes to a project that
# is not predicate's own development.
#
# No admitted default ships here for the same reason applied the other
# direction: no member of an open vocabulary is universal enough to bind
# every adopting project, so binding none is the honest baseline rather
# than an arbitrary pick. A consuming project declares its own vocabulary at
# <ledger-root>/tag_registry.ncl (mirroring `.ledger/config.sh`'s own "if
# present" precedent) — ledger/contracts/entry.ncl's own comment on
# `tag_registry` explains the composition mechanism, and
# ledger/gate/entries_integrity.sh is where it is wired. A project that
# declares no registry of its own gets NO admitted tags: the safe baseline,
# not a silent inheritance of some other project's vocabulary.
#
# Predicate's OWN registry — the D1-D3 + six topics this file used to carry
# — moved to `.ledger/tag_registry.ncl`, unchanged in content or in the
# reasoning that admitted each entry.
{}
