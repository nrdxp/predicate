#!/usr/bin/env python3
"""Convergence: the discharge rate over each direction's terminal questions.

A direction is non-terminal by construction, so it is never "done". What is
measurable is the fraction of its terminal questions that have been discharged.

Openness is DERIVED, not authored: a question is open iff no entry in the corpus
names it in `discharges` or `supersedes`. There is no status field to maintain
and none to fall stale.

A direction with no terminal questions has an UNDEFINED rate, not a zero one --
reporting 0/0 as zero would read as "no progress" when it means "no denominator
has been drafted", and those demand opposite responses.

Usage:
    extract_entries.py <record> > corpus.json
    convergence.py corpus.json [--json]

Exit codes:
    0  clean measurement, no findings.
    2  usage or environment error (missing argument, unreadable corpus).
    3  one or more findings (a marker shaped like a terminal question that
       does not parse, or no direction register found) -- the report is
       still emitted; the findings are what need attention.
"""

import json
import re
import sys

# A terminal question's marker names its direction with a hyphen:
# `<DIRECTION>-<TAG>` (e.g. `D1-T5`). This matches anything shaped like that
# compound form -- a direction-like prefix (letters then digits) followed by
# ONE separator -- regardless of which separator was actually used, so a
# wrong separator is caught as a malformed terminal question rather than
# silently read as an ordinary, non-terminal one.
TERMINAL_SHAPE = re.compile(r"^([A-Za-z]+\d+)([-_])(.+)$")


def load(path):
    with open(path, encoding="utf8") as fh:
        return json.load(fh)


def discharged_ids(entries):
    """Ids named by any entry's closure edges. Openness is the complement."""
    closed = set()
    for entry in entries:
        for kind in ("discharges", "supersedes"):
            for target in entry.get(kind) or []:
                closed.add(target)
    return closed


def group_by_direction(entries, directives):
    """Terminal questions keyed by direction, plus any that failed to parse.

    Directives arrive in their own top-level list rather than among the
    entries -- the extractor routes them there because a directive closes by
    authority rather than by evidence. Only directives whose document stem is
    literally "directions" are directions in this tool's sense: other
    directive-graded nodes elsewhere in the corpus (goals, constraints,
    acceptance criteria) are not per-direction terminal-question registers.

    A marker shaped like `<DIRECTION>-<TAG>` groups under DIRECTION. A marker
    shaped the same way but joined by the wrong separator (`D1_T5` rather than
    `D1-T5`) still names a direction it is TERMINAL_SHAPE-matched against, but
    it is not grouped there: silently leaving it out of every direction's
    denominator would understate its question count and inflate the reported
    rate with nothing to notice by, so it is reported as a finding instead of
    dropped. A marker with no such shape at all (a general, non-directional
    question) is not terminal-shaped and is skipped without comment -- that is
    not a parse failure, it is a question this tool was never asked about.
    """
    directions, terminals, findings = {}, {}, []
    for entry in entries:
        if entry.get("assertion") != "question":
            continue
        marker = entry["id"].split(":")[-1]
        shape = TERMINAL_SHAPE.match(marker)
        if not shape:
            continue
        head, sep, _tag = shape.groups()
        if sep == "-":
            terminals.setdefault(head, []).append(entry)
        else:
            findings.append(
                {
                    "kind": "malformed-marker",
                    "id": entry["id"],
                    "reason": (
                        f"marker '{marker}' looks like a terminal question for "
                        f"{head} but is joined with '{sep}', not '-' -- excluded "
                        "from every direction's count rather than guessed at"
                    ),
                }
            )
    for directive in directives:
        doc, _, marker = directive["id"].rpartition(":")
        if doc == "directions":
            directions[marker] = directive
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
    return directions, terminals, findings


def measure(corpus):
    entries = corpus["entries"]
    closed = discharged_ids(entries)
    directions, terminals, findings = group_by_direction(
        entries, corpus.get("directives", [])
    )
    grades = corpus.get("grades", {})

    report = []
    for name in sorted(directions):
        questions = terminals.get(name, [])
        done = [q for q in questions if q["id"] in closed]
        report.append(
            {
                "direction": name,
                "statement": directions[name]["statement"][:90],
                "total": len(questions),
                "discharged": len(done),
                # None, never 0.0 -- an undrafted denominator is not stalled work
                "rate": (len(done) / len(questions)) if questions else None,
                "open": [
                    {"id": q["id"], "grade": grades.get(q["id"], "?")}
                    for q in questions
                    if q["id"] not in closed
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
                head = f"{row['direction']}: UNDEFINED (no terminal questions drafted)"
            else:
                head = (
                    f"{row['direction']}: {row['discharged']}/{row['total']} "
                    f"({row['rate']:.0%})"
                )
            print(head)
            for question in row["open"]:
                print(f"    open  {question['id']}  [{question['grade']}]")
            print()

    for finding in findings:
        print(f"convergence: {finding['kind']}: {finding['reason']}", file=sys.stderr)

    return 3 if findings else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
