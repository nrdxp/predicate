# Red fixture — duplicate markers are the contract's red, not the extractor's

`signer:: agent/composer` · `at:: abc1234`

`[K1] grade::proved` The first bearer of the marker.
`check:: true` → EXIT=0.

`[K1] grade::proved` The second bearer of the same marker; the extractor
emits both and EntryStore's id-uniqueness red catches the collision — the
contract is the law, and the extractor never re-implements an invariant.
`check:: true` → EXIT=0.
