# Synthetic tags-dialect fixture — the tags:: companion, extraction golden

`signer:: agent/composer` · `at:: abc1234`

Four claims, chosen to separate the four query views: one entry tags a single
direction, one tags two (the co-occurrence case), one tags the other
direction alone, and one carries no tags at all — the absence control.

`[K1] grade::proved` First entry, serving D1 alone. `check:: true` `tags:: D1`

`[K2] grade::proved` Second entry, serving both D1 and D2 — the
co-occurrence case. `check:: true` `tags:: D1, D2`

`[K3] grade::proved` Third entry, serving D2 alone. `check:: true` `tags:: D2`

`[K4] grade::proved` Fourth entry, untagged — the absence-query control.
`check:: true`
