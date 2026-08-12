# Cross-document ids — the closing document

`signer:: agent/composer` · `at:: 3f1c9a2`

This fixture is SYNTHETIC. It pairs with xdoc-open.md and is extracted with
it as one corpus: two documents together are the smallest record on which a
reference either does or does not cross a document boundary.

A qualified reference — a bracketed id carrying its document stem — is an
explicit authorial declaration that the target lives in the corpus rather
than in this document. A plain bracketed id keeps its old meaning and is
resolved against this document alone. Both readings are exercised here on
the same marker name, so a resolution rule that confuses the two cannot
pass: the plain edge below and the question it must not reach are spelled
identically apart from the stem.

## Claims

`[K1] grade::proved` A closure edge reaching a question in the other
document. `check:: true` `axes:: +determined +certifiable +monotone`
`discharges:: [xdoc-open:R1]`

`[K2] grade::proved` A plain closure edge answering the local question, not
the same-named one next door. `check:: true`
`axes:: +determined +certifiable +monotone` `discharges:: [Q1]`

`[X1] grade::synthesis` A derivation edge reaching across the boundary
beside a local one, so both branches of one value are read.
`derives-from:: [K2], [xdoc-open:K1]`

## Questions

`[Q1] grade::dispatchable` The local question the plain reference answers.
`discharge:: run the local check` `closer:: machine`

`[R9] grade::routed` The collating question retiring a constituent that
lives in the other document. `discharge:: the head rules the collation`
`closer:: human/nrd` `supersedes:: [xdoc-open:Q2]`
