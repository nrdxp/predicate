# A headerless document — SYNTHETIC

Deliberately carries no `signer::`/`at::` header, so extract_entries.py
reports this document as `pre-standard-doc` and the whole extraction run
exits 3 (findings present) rather than 0 — the fixture this directory
exists to provide: a corpus where one document is incomplete and the
others still parse cleanly.
