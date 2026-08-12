# Wikilinks stay external — the closing document

`signer:: agent/composer` · `at:: 3f1c9a2`

This fixture is SYNTHETIC and reproduces, in miniature, the two closure
attempts the live record exports as broken edges. Both are written as
wikilinks, and both must stay broken and LOUD.

The first aims at text reading exactly like an id in the other document of
this corpus. Resolving it would be silent capture: a wikilink's text is an
external name, and an external name colliding with a corpus id would flip a
question from open to closed with nobody having declared the crossing.
Whether it resolved would additionally depend on which documents the
extraction happened to cover, which is not a property an authored record may
have. The declaration a crossing needs is the qualified bracketed form, so
the repair here is authorial — and until it is made, the edge is reported.

The second aims at a note outside the corpus entirely. Nothing can resolve
it, and it must not be filed as derivation provenance either: that would put
a lost closure where support is recorded and quietly lose it.

## Claims

`[K1] grade::proved` The wikilink whose text collides with a corpus id.
`check:: true` `axes:: +determined +certifiable +monotone`
`discharges:: [[wikicap-open:R1]]`

`[K2] grade::proved` The wikilink naming a note outside the corpus.
`check:: true` `axes:: +determined +certifiable +monotone`
`discharges:: [[process-feedback/nowhere-note]]`
