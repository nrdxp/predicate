#!/usr/bin/env python3
"""Convergence: the satisfaction rate over each direction's terminal targets.

A direction is non-terminal by construction, so it is never "done". What is
measurable is the fraction of its terminal targets that have been satisfied.

A terminal target is a PAIR of nodes, not one (architect ruling,
ruling-terminal-composition [TC1]): the TARGET states what should be and
closes by authority, never by evidence; the SATISFACTION is a separate claim,
made only once the target is met, carrying its own check and graded `proved`
(backing `corroborated`). Convergence is the fraction of a direction's
targets for which a corroborated satisfaction-claim exists -- not the
fraction merely named in some entry's `discharges` edge, which is a weaker
claim a stale or unproven entry could also make.

TWO SHAPES, ONE MEASURE, DURING THE TRANSITION
------------------------------------------------
The register converts direction by direction, tag by tag, never all at once,
so a single corpus can carry both shapes of terminal target at the same time:

  * QUESTION-shaped (legacy): an `entries` node, `assertion: question`,
    marker `<DIRECTION>-<TAG>`. This is how every terminal item was written
    before the ruling. Openness here predates the pair vocabulary -- it is
    closed by ANY entry naming it in `discharges` or `supersedes`, regardless
    of that entry's own backing -- and changing that reading now would
    silently rewrite the meaning of every terminal item already landed under
    it. So this shape keeps its original rule.

  * DIRECTIVE-shaped (the ruling's converted form): a `directives` node under
    document stem `directions`, marker `<DIRECTION>-<TAG>`, grade `directive`.
    A directive is not an assertion of fact and cannot self-report progress,
    so it is satisfied only by a SEPARATE claim: an entry with
    `assertion: claim`, `backing: corroborated`, naming the target in its own
    `discharges`. `supersedes` does not count here -- it retires an item, it
    does not assert the item was met.

Reading only the directive shape would report every direction UNDEFINED (zero
denominator) against a corpus the conversion has not reached yet -- the
silent-wrong-answer direction the ruling exists to close, not open. So both
shapes are read and folded into one denominator per direction; a target's
shape decides which satisfaction rule applies to IT, never which directions
get measured at all.

Openness/satisfaction is DERIVED, not authored: there is no status field to
maintain and none to fall stale.

A direction with no terminal targets has an UNDEFINED rate, not a zero one --
reporting 0/0 as zero would read as "no progress" when it means "no denominator
has been drafted", and those demand opposite responses.

Usage:
    extract_entries.py <record> > corpus.json
    convergence.py corpus.json [--json]

Exit codes:
    0  clean measurement, no findings.
    2  usage or environment error (missing argument, unreadable corpus).
    3  one or more findings (a marker shaped like a terminal target that
       does not parse, or no direction register found) -- the report is
       still emitted; the findings are what need attention.
"""

import json
import re
import sys

# A terminal target's marker names its direction with a hyphen:
# `<DIRECTION>-<TAG>` (e.g. `D1-T5`). This matches anything shaped like that
# compound form -- a direction-like prefix (letters then digits) followed by
# ONE separator -- regardless of which separator was actually used, so a
# wrong separator is caught as a malformed terminal target rather than
# silently read as an ordinary, non-terminal one. Applies identically to
# question-shaped entry ids and directive-shaped directive ids -- the shape
# rule does not depend on which register a marker was written into.
TERMINAL_SHAPE = re.compile(r"^([A-Za-z]+\d+)([-_])(.+)$")


def load(path):
    with open(path, encoding="utf8") as fh:
        return json.load(fh)


def discharged_ids(entries):
    """Ids named by any entry's closure edges -- the LEGACY openness rule for
    question-shaped terminal targets, backing-independent. A question and its
    discharging entry were always an implicit two-node pair; this reads it
    exactly as every terminal item landed under this shape already expects."""
    closed = set()
    for entry in entries:
        for kind in ("discharges", "supersedes"):
            for target in entry.get(kind) or []:
                closed.add(target)
    return closed


def corroborated_targets(entries):
    """Ids discharged by a CORROBORATED claim -- the satisfaction half of the
    explicit terminal pair a directive-shaped target composes with
    (ruling-terminal-composition [TC1]/[TC5]/[TC6]). Narrower than
    `discharged_ids` on purpose: an uncorroborated claim (backing vouched,
    unclosed, or residual) naming the target in `discharges` does not count
    -- that is the whole point of the ruling -- and `supersedes` is excluded
    entirely, because retiring a target is not asserting it was met."""
    satisfied = set()
    for entry in entries:
        if entry.get("assertion") != "claim" or entry.get("backing") != "corroborated":
            continue
        for target in entry.get("discharges") or []:
            satisfied.add(target)
    return satisfied


def _terminal_groups(items, findings, kind_label):
    """Bucket items whose marker is TERMINAL_SHAPE-matched, keyed by
    direction head. Shared between question-shaped entries and
    directive-shaped directives -- the shape rule and the malformed-separator
    finding are identical in both registers; only the source collection and
    the label in the finding's prose differ."""
    grouped = {}
    for item in items:
        marker = item["id"].split(":")[-1]
        shape = TERMINAL_SHAPE.match(marker)
        if not shape:
            continue
        head, sep, _tag = shape.groups()
        if sep == "-":
            grouped.setdefault(head, []).append(item)
        else:
            findings.append(
                {
                    "kind": "malformed-marker",
                    "id": item["id"],
                    "reason": (
                        f"marker '{marker}' looks like a terminal {kind_label} "
                        f"for {head} but is joined with '{sep}', not '-' -- "
                        "excluded from every direction's count rather than "
                        "guessed at"
                    ),
                }
            )
    return grouped


def group_by_direction(entries, directives):
    """Direction registers, plus their terminal targets split by shape.

    Only directives whose document stem is literally "directions" are
    directions in this tool's sense: other directive-graded nodes elsewhere
    in the corpus (goals, constraints, acceptance criteria) are not
    per-direction terminal registers. Within that stem, a directive whose
    marker is TERMINAL_SHAPE'd is one of a direction's converted targets, not
    the direction node itself.
    """
    findings = []

    questions = [e for e in entries if e.get("assertion") == "question"]
    question_terminals = _terminal_groups(questions, findings, "question")

    directions = {}
    target_directives = []
    for directive in directives:
        doc, _, marker = directive["id"].rpartition(":")
        if doc != "directions":
            continue
        if TERMINAL_SHAPE.match(marker):
            target_directives.append(directive)
        else:
            directions[marker] = directive
    directive_terminals = _terminal_groups(target_directives, findings, "directive")

    if not directions:
        findings.append(
            {
                "kind": "no-directions",
                "reason": (
                    "no directive found with document stem 'directions' -- "
                    "check the register's filename and that it carries "
                    "grade::directive nodes"
                ),
            }
        )
    return directions, question_terminals, directive_terminals, findings


def measure(corpus):
    entries = corpus["entries"]
    closed = discharged_ids(entries)
    satisfied = corroborated_targets(entries)
    directions, question_terminals, directive_terminals, findings = group_by_direction(
        entries, corpus.get("directives", [])
    )
    grades = corpus.get("grades", {})

    report = []
    for name in sorted(directions):
        questions = question_terminals.get(name, [])
        targets = directive_terminals.get(name, [])
        total = len(questions) + len(targets)
        done = sum(1 for q in questions if q["id"] in closed) + sum(
            1 for t in targets if t["id"] in satisfied
        )
        report.append(
            {
                "direction": name,
                "statement": directions[name]["statement"][:90],
                "total": total,
                "discharged": done,
                # None, never 0.0 -- an undrafted denominator is not stalled work
                "rate": (done / total) if total else None,
                "open": [
                    {"id": q["id"], "grade": grades.get(q["id"], "?")}
                    for q in questions
                    if q["id"] not in closed
                ]
                + [
                    {"id": t["id"], "grade": grades.get(t["id"], "?")}
                    for t in targets
                    if t["id"] not in satisfied
                ],
            }
        )
    return report, findings


def corpus_wide(corpus):
    entries = corpus["entries"]
    closed = discharged_ids(entries)
    questions = [e for e in entries if e.get("assertion") == "question"]
    done = [q for q in questions if q["id"] in closed]
    return {
        "questions": len(questions),
        "discharged": len(done),
        "rate": (len(done) / len(questions)) if questions else None,
    }


def usage():
    print("usage: convergence.py <corpus.json> [--json]", file=sys.stderr)


def main(argv):
    if len(argv) < 2:
        print("convergence: missing corpus argument", file=sys.stderr)
        usage()
        return 2

    try:
        corpus = load(argv[1])
    except (OSError, json.JSONDecodeError) as err:
        print(f"convergence: cannot read corpus {argv[1]!r}: {err}", file=sys.stderr)
        return 2

    per_direction, findings = measure(corpus)
    overall = corpus_wide(corpus)

    if "--json" in argv:
        json.dump(
            {"corpus": overall, "directions": per_direction, "findings": findings},
            sys.stdout,
            indent=2,
        )
        print()
    else:
        rate = overall["rate"]
        shown = f"{rate:.1%}" if rate is not None else "undefined"
        print(
            f"CORPUS: {overall['discharged']}/{overall['questions']} "
            f"questions discharged ({shown})"
        )
        print()
        for row in per_direction:
            if row["rate"] is None:
                head = f"{row['direction']}: UNDEFINED (no terminal targets drafted)"
            else:
                head = (
                    f"{row['direction']}: {row['discharged']}/{row['total']} "
                    f"({row['rate']:.0%})"
                )
            print(head)
            for item in row["open"]:
                print(f"    open  {item['id']}  [{item['grade']}]")
            print()

    for finding in findings:
        print(f"convergence: {finding['kind']}: {finding['reason']}", file=sys.stderr)

    return 3 if findings else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
