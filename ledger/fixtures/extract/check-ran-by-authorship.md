# Fixture — `ran` follows authorship, not punctuation

`signer:: agent/composer` · `at:: abc1234`

The exists/ran cut (docs/entries.md "The two evidence species") is real, but
no parser-observable mark decides it: a check companion carries no glyph
that proves a command executed, and the head's ruling corrects an earlier
pass that tried to infer a run from an arrow — authorship of the companion
IS the attestation. A signer who writes a check into a signed record is
vouching they ran it, so a claim's `ran` field is true whenever the
companion is present, whether or not it also states an observed result.

`[B1] grade::proved` Sharing one container brings the suite to 2m40s.
`check:: time pytest tests/` `tags:: perf`

`[B2] grade::proved` A well-formed sibling stating its observed result
extracts exactly the same way: stating a result changes nothing about `ran`,
only the reader's own confidence when deciding whether to re-verify.
`check:: time pytest tests/` → 2m40s, 412 passed, 0 failed.
