# Directions — the example register

`signer:: agent/composer` · `at:: 4f2a91c`

A direction is a standing intent. It never closes; what closes are the terminal
questions beneath it, and the fraction of those that have closed is the only
convergence number this system will report.

## W1 — a developer can verify their change before pushing

`[W1] grade::directive` **A developer can verify their change before pushing.**
Non-terminal by construction: there is no state of the world that finishes it.

`[W1-T1] grade::directive` **Does the suite run fast enough to be used?**
`discharge:: the suite completes under the stated threshold on a developer
laptop` `closer:: agent`

`[W1-T2] grade::directive` **Does it run the same way in CI as on a laptop?**
`discharge:: the same suite passes against the CI image without modification`
`closer:: agent`
