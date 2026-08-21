# Red fixture — a proved claim naming a check nobody ran

`signer:: agent/composer` · `at:: abc1234`

The exists/ran cut (docs/entries.md "The two evidence species") is a
REPORTED distinction, not an admissibility judgment a string parser makes for
itself (ruling AI13): whether a `check::` companion's command produced a
stated result is the only thing this parser can verify — never whether the
command actually ran. The node below names a check and states no observed
result, so it is reported and still emitted, `check.ran: false`; judging
whether that is enough to close a `proved` claim is the type layer's job
(entry.ncl's CorroborationBacked), never this parser's.

`[B1] grade::proved` Sharing one container brings the suite to 2m40s.
`check:: time pytest tests/` `tags:: perf`

`[B2] grade::proved` A well-formed sibling, naming its observed result,
extracts beside it exactly the same way: an unrun check changes nothing
about whether either node appears, only the honesty of its `ran` value.
`check:: time pytest tests/` → 2m40s, 412 passed, 0 failed.
