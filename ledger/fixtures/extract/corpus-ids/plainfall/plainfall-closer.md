# A plain reference does not fall through to the corpus

`signer:: agent/composer` · `at:: 3f1c9a2`

This fixture is SYNTHETIC and is extracted with plainfall-open.md. It pins
the resolution rule's one remaining escape: a plain bracketed id matching
nothing in its own document, while a document next door carries exactly that
marker.

A resolver falling back to the corpus when the local lookup missed would
make plain references document-scoped-until-they-are-not, and the scope of a
reference would then depend on whatever else the record happened to contain.
Plain stays local unconditionally, so this edge stays unresolved — and
unresolved is not silent: it is namespaced to this document, and the corpus
contract refuses it as a dangling closure edge.

## Claims

`[K1] grade::proved` A plain closure edge matching nothing here.
`check:: true` `axes:: +determined +certifiable +monotone`
`discharges:: [Z9]`
