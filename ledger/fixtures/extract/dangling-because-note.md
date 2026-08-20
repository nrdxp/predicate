# Synthetic dangling-qualified-because fixture — a corpus-tagged ref that resolves nowhere

`signer:: agent/composer` · `at:: abc1234`

Binds `resolve_qualified`'s edge-kind branch: the tagged-vs-plain
distinction serving `because`'s corpus-tagged refs specifically. A
derives-from value names one qualified ref that resolves and one that
names a stem nothing this run declares. The one that resolves must survive,
tagged; the one that does not must be reported AND actually dropped from
`because` — not left behind looking like a valid corpus ref. Raw string
equality over a tagged `because` element cannot do that removal: the element
is a `{kind, name}` record, a record is never `==` a bracket-ref string, so a
comparison written before the tagged shape landed keeps the dangling record
in place while still reporting it as gone. Single-document by design — a
qualified ref naming its own document's stem is still QUALIFIED (the stem
was written down), so this needs no second document to exercise the branch.

## Claims

`[K1] grade::proved` The local anchor the surviving edge lands on.
`check:: true` → EXIT=0.

`[X1] grade::synthesis` One qualified corpus ref that resolves, one that
names a stem this run never declares. `derives-from::
[dangling-because-note:K1], [nowhere-stem:K9]`
