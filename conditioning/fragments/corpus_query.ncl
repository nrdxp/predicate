# conditioning/fragments/corpus_query.ncl
#
# FRAGMENT, not a class station: the typed-corpus query recipe, single-sourced
# and interpolated (%{import ...}) into the two carriers that teach it —
# conditioning/personas/composer.ncl and conditioning/modules/council.ncl — so
# the two copies cannot drift: the duplication sweep compares core against
# delta and cannot see two deltas that never co-render in one prompt. Never
# listed in a compose.ncl module list; fragments/ holds interpolation targets
# only. Lines carry a two-space indent because
# both interpolation sites sit inside indented list context.
# Export: `nickel export --format text conditioning/modules/corpus_query.ncl`

m%"extract the typed corpus from ONE record namespace
  (`python3 ledger/derive/extract_entries.py <dir> -o <export>.json`, with
  `<dir>` scoped to the namespace you are reading, e.g.
  `.ledger/deposits/<topic>` — the query stops at the FIRST backing-contract
  violation among extracted entries, so a whole-corpus `.ledger` run fails
  while any entry anywhere in the record is mis-backed), then query it
  (`nickel export <export>.json --apply-contract
  ledger/contracts/entries_query.ncl`) for `awaiting_human` (only the head
  can clear it), `runnable_now` (a check exists and has not been run),
  `unbacked` (rests on nothing), and `chain_floor` (where support actually
  bottoms out)"%
