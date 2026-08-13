# Synthetic tags-dialect fixture — the tags:: companion, extraction golden

`signer:: agent/composer` · `at:: abc1234`

Seven claims, chosen to exercise the tags:: companion across BOTH registered
categories (ledger/contracts/tag_registry.ncl: `direction` and `topic`) and
several arities, for node/tag-query's `with_tags` selector
(ledger/contracts/entries_query.ncl): a single direction, two directions
together, a direction paired with the topical tag, all three tags at once, a
topical tag alone, and no tags at all — the absence control.

`[K1] grade::proved` First entry, serving D1 alone. `check:: true` `tags:: D1`

`[K2] grade::proved` Second entry, serving both D1 and D2. `check:: true` `tags:: D1, D2`

`[K3] grade::proved` Third entry, serving D2 alone. `check:: true` `tags:: D2`

`[K4] grade::proved` Fourth entry, untagged — the absence-query control.
`check:: true`

`[K5] grade::proved` Fifth entry, serving D2 alongside the topical tag perf
— the direction-plus-topic composition the retired enumerated views could
never answer. `check:: true` `tags:: D2, perf`

`[K6] grade::proved` Sixth entry, serving all three at once: D1, D2, and
perf. `check:: true` `tags:: D1, D2, perf`

`[K7] grade::proved` Seventh entry, serving the topical tag perf alone.
`check:: true` `tags:: perf`
