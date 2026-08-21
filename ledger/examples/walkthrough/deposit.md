# Making the test suite fast enough to run on every commit

`signer:: agent/core-worker` · `at:: 4f2a91c`

An agent was asked to cut a 14-minute test suite down to something a developer
would actually run before pushing. This is what it wrote into the record while
doing that. Everything below is one paragraph per claim or question, and the
first backticked span says what kind of thing it is.

## What the work was for

`[W1] grade::directive` **The suite runs in under three minutes on a developer
laptop.** A directive states what should be; it closes because someone with the
authority to set it said so, never because evidence arrived.
`tags:: perf`

`[W2] grade::directive` **No test may be deleted or skipped to reach the
target.** The obvious way to make a suite fast is to make it test less. Stating
the constraint is what makes that failure visible rather than clever.
`tags:: perf`

## What it found out

`[W3] grade::proved` **The suite spends 9 of its 14 minutes starting Postgres
containers, once per test file.** Measured, not estimated.
`check:: pytest --durations=0 tests/ | head -40` → 31 files, 9m12s in fixture
setup. `tags:: perf`

`[W4] grade::proved` **Sharing one container across the suite brings it to
2m40s, with every test still passing.**
`check:: time pytest tests/` → 2m40s, 412 passed, 0 failed. `tags:: perf`

`[W5] grade::cited` **The team already rejected a shared container once, in
2024, because tests leaked state into each other.** This is not something the
agent measured — it is something a person told it, and the record names who, so
a later reader can go ask that person rather than re-litigating it.
`source:: human/priya` `tags:: perf`

`[W6] grade::synthesis` **The 2024 objection is addressed, because the leak it
describes came from shared sequences, and each test now runs in its own
transaction that is rolled back.** Nothing was run to establish this; it is
reasoning built on the two claims below it, and it says so. A synthesis that
named no source would be a claim with no parentage — which is the shape of a
made-up fact. `derives-from:: [W4] [W5]` `tags:: perf`

## What it did not settle

`[W7] grade::dispatchable` **Does the suite still pass under the container
runtime the CI image uses, rather than the one on the laptop?** The check
exists and simply has not been run yet — that is the whole difference between
this and `[W4]`. `discharge:: run the suite against the CI image`
`closer:: agent` `tags:: perf`

`[W8] grade::routed` **Is a 2m40s suite fast enough to make pre-push runs a
team norm, or does it need to be under a minute?** No command answers this. It
needs a named person, so it says so rather than sitting in a work queue nothing
can clear. `discharge:: the team states the threshold` `closer:: human/priya`
`tags:: perf`

`[W9] grade::frontier` **Why does the container take 400ms longer to become
ready on ARM laptops?** Nobody knows yet and there is no check to write, so it
carries a signpost instead — what a future walk should look at.
`discharge:: none yet; signpost: compare the readiness probe's syscall trace
between architectures` `closer:: agent` `tags:: perf`

`[W10] grade::residual` **Would this refactor have changed the outcome of the
flaky failures seen before the test database was rebuilt in March?** The
evidence no longer exists — those runs were not recorded and the database is
gone. This is not an open task. It is a question demonstrably beyond what can
now be observed, and naming it stops a future walk from trying.
`discharge:: provably none — those runs were never recorded and the database
they ran against is gone` `closer:: human/priya` `tags:: perf`

## Things it noticed that were none of its business

The two claims below have nothing to do with making tests fast. They are here
because the record holds every claim the machine makes, not only the ones that
serve the task it was given. An agent that notices something true and drops it
because it was off-topic has thrown away the most expensive thing it produced.

`[W11] grade::proved` **The CI cache key omits the lockfile hash, so every
build restores a stale dependency cache and then discards it.**
`check:: grep -n 'key:' .github/workflows/ci.yml` → line 34, keyed on branch
name only. `tags:: gate-mechanism`

`[W12] grade::dispatchable` **Is the `requests` dependency pinned anywhere?**
Noticed while reading the lockfile; not chased, because chasing it was not the
task. `discharge:: grep the dependency manifests for a version constraint`
`closer:: agent` `tags:: gate-mechanism`

## Closing one of the questions

`[W13] grade::proved` **The suite passes against the CI image's container
runtime, unchanged.** `check:: docker run --rm ci-image:latest pytest tests/`
→ 412 passed, 0 failed. `discharges:: [W7] [directions:W1-T2]`
`tags:: perf`
