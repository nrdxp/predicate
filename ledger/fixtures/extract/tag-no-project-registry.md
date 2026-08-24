# Fixture — a tag with no project-local registry present

`signer:: agent/composer` · `at:: abc1234`

Sits directly under fixtures/extract/, which carries no sibling
`tag_registry.ncl` — proves the plugin default (empty) admits no tag when a
consuming project supplies no registry of its own.

`[T3] grade::proved` A claim naming a tag with no project registry in scope.
`check:: true` `tags:: some-tag`
