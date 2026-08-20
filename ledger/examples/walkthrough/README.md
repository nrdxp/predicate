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

Every paragraph says what kind of thing it is. There are two questions to ask
about any statement: **is it a claim or a question**, and **what stands behind
it**. Those are tracked separately, which is why "I ran the test" and "someone
told me" never collapse into the same state.

| in `deposit.md` | what it is |
| :--- | :--- |
| `[W3]`, `[W4]` `proved` | a claim closed by a check that was actually run |
| `[W5]` `cited` | a claim closed by a named person — go ask them, do not re-litigate |
| `[W6]` `synthesis` | reasoning built on other entries; it names which ones |
| `[W7]` `dispatchable` | a question whose check exists and simply has not been run |
| `[W8]` `routed` | a question no command can answer; it names the person who can |
| `[W9]` `frontier` | nobody knows yet and there is no check to write, so it carries a signpost |
| `[W10]` `residual` | answerable by nothing that still exists; naming it stops a future walk trying |
| `[W1]`, `[W2]` `directive` | a goal or a constraint — true because someone with the authority said so |

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
