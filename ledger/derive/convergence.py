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

Exit codes: 0 always on a readable corpus. This measures; it does not gate.
"""

import json
import sys


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
    """Terminal questions keyed by direction.

    A terminal question's marker is `<DIRECTION>-<TAG>`, so the direction is
    read off the id rather than carried in a second field that could disagree
    with it.

    Directives arrive in their own top-level list rather than among the
    entries -- the extractor routes them there because a directive closes by
    authority rather than by evidence.
    """
    directions, terminals = {}, {}
    for entry in entries:
        marker = entry["id"].split(":")[-1]
        if entry.get("assertion") == "question" and "-" in marker:
            head = marker.split("-", 1)[0]
            terminals.setdefault(head, []).append(entry)
    for directive in directives:
        doc, _, marker = directive["id"].rpartition(":")
        if doc == "directions":
            directions[marker] = directive
    return directions, terminals


def measure(corpus):
    entries = corpus["entries"]
    closed = discharged_ids(entries)
    directions, terminals = group_by_direction(entries, corpus.get("directives", []))
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
    return report


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


def main(argv):
    if len(argv) < 2:
        print(__doc__.strip(), file=sys.stderr)
        return 0
    corpus = load(argv[1])
    per_direction = measure(corpus)
    overall = corpus_wide(corpus)

    if "--json" in argv:
        json.dump(
            {"corpus": overall, "directions": per_direction},
            sys.stdout,
            indent=2,
        )
        print()
        return 0

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
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
