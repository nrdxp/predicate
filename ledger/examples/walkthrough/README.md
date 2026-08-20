# A worked example of the record

Everything here is a real, runnable corpus. Nothing in it is illustrative
pseudo-data: the commands below are the actual commands, and the outputs shown
are what they actually print.

The scenario is small on purpose. An agent was asked to cut a 14-minute test
suite down to something a developer would run before pushing. What follows is
what it wrote down while doing that.

## Start here

- **`deposit.md`** — the agent's own record of the work. One paragraph per
  claim or question. This is the file to read first; the rest exists to be run
  against it.
- **`directions.md`** — a standing intent and the questions that would show it
  advancing. Directions never close; the questions under them do.
- **`refused/`** — documents that are wrong on purpose, to show what the
  record declines to accept.

## Run it

Extract the prose into structured entries:

```
python3 ledger/derive/extract_entries.py ledger/examples/walkthrough -o /tmp/wt.json
```

→ 11 entries, 5 directives, 0 findings.

Ask what is open, what is backed by nothing, and what only a person can settle:

```
nickel export /tmp/wt.json --apply-contract ledger/contracts/entries_query.ncl
```

→ `awaiting_human` holds two questions, `runnable_now` one, `unbacked` one.
Nothing was marked open or closed by hand — it is computed from the links
between entries.

Ask how far the work has got:

```
python3 ledger/derive/convergence.py /tmp/wt.json
```

```
CORPUS: 1/5 questions discharged (20.0%)

W1: 1/2 (50%)
    open  directions:W1-T1  [directive]
```

The half that is still open is open because a person has not answered a
question, not because an agent has not finished a task. That distinction is
most of the point.

## What the shapes mean

Every paragraph says what kind of thing it is. Two questions get asked
about any statement, and they are asked separately: **is it a claim or a
question**, and **what stands behind it**. Three answers
to the second — a check that was run, a person who vouched, or nothing yet.
Two times three is the whole vocabulary:

|              | a check that ran | a person vouched | nothing yet |
| :----------- | :--------------- | :--------------- | :---------- |
| **claim**    | `proved` `[W3]` `[W4]` | `cited` `[W5]` | `synthesis` `[W6]` |
| **question** | `dispatchable` `[W7]` | `routed` `[W8]` | `frontier` `[W9]` |

Read across the top row: `[W4]` was measured, `[W5]` is what a colleague said,
`[W6]` is reasoning built on both. Down the second: `[W7]`'s check exists and
nobody has run it, `[W8]` needs a person because no command answers it, `[W9]`
is not yet understood well enough to have a check at all — so it carries a
signpost saying where to look.

Those six are the whole of it. Everything about how well something is known
lands in exactly one of them, and there is a proof that no seventh is needed.

Two more markers appear in `deposit.md` and neither adds a seventh state:

- `[W10]` `residual` — a question answerable by nothing that still exists. This
  is a fourth answer to "what stands behind it", and it attaches only to
  questions. That restriction is not a rule someone chose: because every claim
  in the table above has a cure, no *claim* can ever be permanently open, so
  this can only ever be question-shaped.
- `[W1]`, `[W2]` `directive` — a goal and a constraint. These are not in the
  table because they are not true or false at all. A goal does not become more
  established when evidence arrives; it holds because someone with the standing
  to set it said so. Asking what backs a directive is a category error.

`[W13]` closes `[W7]` by naming it. That is the only way a question closes: a
separate entry with real backing points at it. There is no status field to
maintain, and therefore none to forget.

## Two claims that have nothing to do with the task

`[W11]` and `[W12]` are about a stale CI cache key and an unpinned dependency.
The agent noticed them while doing something else. They are in the record
because the record holds every claim the machine makes, not only the ones
serving the task it was given — an agent that notices something true and drops
it for being off-topic has thrown away the most expensive thing it produced.

## What it refuses

`refused/unadmitted-tag.md` uses a tag nobody registered:

```
nickel export /tmp/bad.json --apply-contract ledger/contracts/entries_query.ncl
```

→ ``TagName: `speedup` is not in the admissible tag registry``, exit 1. A tag
is admitted by a deliberate edit to the registry, never as a side effect of
someone writing one down.
