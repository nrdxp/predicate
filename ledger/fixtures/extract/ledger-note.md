# Synthetic ledger-dialect fixture — every grammar feature, one document

`signer:: agent/composer` · `at:: abc1234`

This fixture is SYNTHETIC: it exercises the extractor's grammar, feature by
feature, so its expected extraction is exact by construction. The bare
`grade::` convention mentioned here is a census-only occurrence, not a token.

Every question carries both routing halves, the frontier and residual ones
included: QuestionRoutable admits no exception, so the grade records how a
question was reached, never whether it states a discharge condition. Every
unclosed claim likewise names at least one doc-local ref, because an external
ref is filed beside the derivation edges and satisfies the provenance gate on
its own account — never in place of one.

## Claims

`[K1] grade::proved` The battery passes.
`check:: bash ledger/gate/test_entry.sh` → EXIT=0, run at this seat.

`[K2] grade::cited` The maintainer consented at its gate.
`source:: lead-maintainer gate deposit`

`[K3] grade::cited` The consent covers the follow-on too. `source:: same`

`[K4] grade::cited` Five defects share one class.
`source:: [[log/2026-08-11-pass2-deposit-reform]]`, `[[log/2026-08-11-pass3-pen-law]]`

`[X1] grade::synthesis` Typing makes error checkable rather than preventing it.
`derives-from:: [K1], [K2]`

`[X2] grade::synthesis` The fix is isolation, not vigilance.
`derives-from:: [K2]` [[process-feedback/tc-concurrent-writer]]

`[X3] grade::synthesis` A multiline companion span survives line joining.
`derives-from:: [X1]` `conversion-path:: candidate for the boundary discipline
alongside the vacuity rule`

## Questions

`[Q1] grade::dispatchable` Does the pattern survive a narrative log?
`discharge:: write the next notes this way and count the cost` `closer:: machine`

`[R1] grade::routed` Ratify the bundle. `discharge:: the head's ruling`
`closer:: human/nrd`

`[Q2] grade::frontier` What level of scrutiny does each claim type garner?
`discharge:: classify the landed corpus and count` `closer:: machine`

`[Z1] grade::residual` Whether an agent upholds the rules is conduct outside
the record. `discharge:: nothing in the record can settle it`
`closer:: machine` `source:: [[log/2026-08-11-escalation]]`

## Directive

`[C1] grade::directive` The extractor is the head's call, not a scope decision.
`provenance:: the head's bar, lifted this session`

A fenced block must not extract and its marker is census-only:

```text
`[F9] grade::proved` not a node — inside a fence
```
