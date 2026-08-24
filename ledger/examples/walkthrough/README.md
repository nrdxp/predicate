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
python3 ledger/derive/extract_entries.py ledger/examples/walkthrough/deposit.md ledger/examples/walkthrough/directions.md -o /tmp/wt.json
```

→ 11 entries, 5 directives, 0 findings. (Point the extractor at the whole
`ledger/examples/walkthrough` directory instead and it also sweeps up this
README and `refused/` — both hold graded-looking prose deliberately, so the
corpus proper is these two files.)

Ask what is open, what is backed by nothing, and what only a person can settle:

```
nickel export /tmp/wt.json --apply-contract ledger/contracts/entries_query_apply.ncl
```

→ `awaiting_human` holds one question, `runnable_now` one, `unbacked` one.
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

The names are meant literally, which is easier to see with the example beside
them:

- **`proved`** — someone ran something and it came out that way. `[W4]` is a
  timing, taken by running the suite.
- **`cited`** — you can cite a person for it. `[W5]` is what a colleague said
  about a decision made two years ago; the record names her so a later reader
  goes and asks rather than re-litigating it.
- **`synthesis`** — put together out of other entries. `[W6]` is an argument
  resting on `[W4]` and `[W5]`, and it says so; nothing new was observed.
- **`dispatchable`** — ready to be handed off. `[W7]`'s check already exists
  and nobody has run it yet, so it can go straight into a queue as work.
- **`routed`** — it has an address. `[W8]` asks whether 2m40s is fast enough,
  which no command answers, so it names the person who decides.
- **`frontier`** — the edge of what is understood. Nobody knows why `[W9]`
  happens and there is no check to write yet, so it carries a signpost —
  where the next person should look — instead of a task nobody can do.

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
python3 ledger/derive/extract_entries.py ledger/examples/walkthrough/refused/unadmitted-tag.md -o /tmp/bad.json
nickel export /tmp/bad.json --apply-contract ledger/contracts/entries_query_apply.ncl
```

→ ``TagName: `speedup` is not in the admissible tag registry``, exit 1. A tag
is admitted by a deliberate edit to the registry, never as a side effect of
someone writing one down.

`refused/dangling-reference.md` points a `derives-from::` edge at an id no
document in the corpus declares:

```
python3 ledger/derive/extract_entries.py ledger/examples/walkthrough/refused/dangling-reference.md -o /tmp/bad2.json
```

→ `` `[deposit:W99]` is a qualified reference to an id the corpus does not
declare; the edge is dropped``, exit 3. The extractor reports it and drops
the edge rather than silently keeping a link to nothing — a derivation tool
never omits what it cannot place; it says so and moves on.
