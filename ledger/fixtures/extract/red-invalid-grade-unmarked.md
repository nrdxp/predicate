# Red fixture — an invalid-only document still reports its unmarked prose

`signer:: agent/composer` · `at:: abc1234`

`[G1] grade::self-evident` This document's only marker carries a grade
outside the vocabulary, so this node is reported and dropped. What this
fixture pins is what happens next: the flag recording that the document
grades its claims is set from the marker parse, before the grade word is
checked against the vocabulary — so a document whose one attempt at grading
fails still counts as attempting it, and the paragraph below stays under
the discipline rather than falling silent with it.

**A rejected grade does not un-grade the document around it.** This
paragraph asserts in the record's own assertive form and opens no marker,
so it is exactly the shape the unmarked-assertion report exists to catch —
and it must still be caught here, where the only marker in the document
failed its own vocabulary check. Reporting it is the placement the merge
gate ruled correct: silence here would let a document that attempts the
discipline and fails hide the loss across all its prose, and the exit code
cannot see that loss either way.
