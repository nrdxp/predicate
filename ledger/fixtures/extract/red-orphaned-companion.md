# Red fixture — a companion one paragraph late must be reported, not dropped

`signer:: agent/composer` · `at:: abc1234`

## The defect this reproduces

`[K1] grade::proved` A well-formed sibling, so the orphan below does not
mask a total extraction failure. `check:: true` → EXIT=0.

`[X1] grade::synthesis` A claim whose provenance trails into the next
paragraph instead of staying inside this node's own paragraph.

`derives-from:: [K1]` completes the claim above, one blank line too late —
exactly the shape a careful author writes without noticing.
