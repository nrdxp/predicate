# A properly-headered document with one open entry — SYNTHETIC

`signer:: agent/test` · `at:: 0000000`

Pairs with `bad.md` in this same directory, which carries NO header at all
and so triggers extract_entries.py's `pre-standard-doc` finding (exit 3).
This file's own entry must still be extracted and reach the open surface —
a finding against ONE document in a corpus reports that document as
incomplete; it does not void the documents that parsed cleanly.

`[G1] grade::frontier` An open question in the one document of this corpus
that actually carries a header.
`discharge:: whatever eventually answers this` `closer:: agent/test`
