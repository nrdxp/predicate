# Red fixture — a grade value outside the vocabulary must be reported

`signer:: agent/composer` · `at:: abc1234`

`[K1] grade::bogus` This node's grade is not in the vocabulary; silently
skipping it would make the export confidently incomplete.

`[K2] grade::proved` A well-formed sibling still extracts.
`check:: true` → EXIT=0.
