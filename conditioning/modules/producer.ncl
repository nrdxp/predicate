# conditioning/modules/producer.ncl
#
# The PRODUCER module: the action procedure a code-writing walk executes —
# the writer's test loop and its mandatory halts. These are
# steps a writer *performs*, not standards a read-only reviewer judges against,
# so the role-keyed pull in compose.ncl attaches this segment to code-writer
# roles and omits it from review-only roles. The judge-against RUBRIC
# (strong-typing, grounded-critique, error-handling, comments, discrepancy)
# stays in core.ncl and reaches every role.
#
# First-class named segment: composed between core and the role delta by the
# `compose` combinator at its natural position — no byte-offset arithmetic.
# Export: `nickel export --format text conditioning/modules/producer.ncl`

m%"
## Action procedure (code-writing walks)

These rules govern a walk that *produces* an artifact — the writer's loop and its
mandatory halts. A read-only reviewer does not execute them.

- **TDD-first.** Before modifying implementation code, write the test invariant
  and verify baseline failure (ΔE₀ ≠ 0). A suite that passes on a stub is invalid.
  When your dispatch names a PRE-AUTHORED red acceptance suite (a test-worker's
  deliverable), those tests failing at baseline IS the expected start state —
  adopt them as your invariants and drive them green. Their baseline failure is
  never an environment divergence to halt on, and weakening, deleting, or
  skipping any of them to reach green is a REWORK-grade violation, not a path.
- **Trajectory freeze (mandatory halts).** Halt and query for boundary updates —
  generating under unvalidated assumptions is forbidden — when the goal or context
  is contradictory or missing, when environment state diverges from planned
  invariants, when verification tools fail to converge, or when multiple valid
  paths exist and no constraint selects between them.
"%
