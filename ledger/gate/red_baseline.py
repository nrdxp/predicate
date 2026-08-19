#!/usr/bin/env python3
"""Red-baseline gate (directions:D3-T9, second half): for a landed node
branch, does the COMMITTED HISTORY show a `test:` commit preceding the
implementation commit(s) it verifies -- not merely a claim that a worker
verified the evaluator red before implementing?

THE DEFECT THIS CLOSES
------------------------
D3-T9 asks two things at once: were acceptance evaluators verified failing
before the implementation that satisfies them, AND is that recorded in the
history. Measured across this campaign's landed nodes
(.ledger/log/2026-08-13-t9-measured.md [T1]-[T7]): the practice held --
worker after worker reported a red baseline, several demonstrated it by
mutation -- but the history mostly does not preserve it. A red baseline
verified in a worker's own shell and reported in prose leaves nothing a
later reader can check; from the outside a diligent campaign and a careless
one are indistinguishable. The cure named there [T6]-[T7] is a
commit-boundary convention: land the evaluator as its own commit, before the
implementation commit that satisfies it, so the ordering is checkable from
the ref alone. This gate is that check.

PATH SCOPE: PROSE IS EXEMPT (AI7)
----------------------------------
D3-T9's ordering requirement presupposes an evaluator able to distinguish
CORRECT behavior from incorrect. For prose the only available evaluator is a
presence check -- did the text land at all -- and a presence check's red
state means the text is ABSENT, which proves nothing about whether the text
is RIGHT. Ordering a presence check before the prose it checks is ceremony,
not verification (.ledger/state/decisions-architect-intake.yaml, AI7).

So this gate scopes to CODE paths: a commit that touches no code path never
enters the impl/test ordering at all, regardless of its Conventional-Commit
type. `is_prose_path()` names PROSE narrowly and defaults everything else to
CODE -- the conservative direction, matching the AMBIGUOUS posture above
(never assume the flattering reading for an unclassified path):

  * everything under `docs/` or `conditioning/` (AI7's named case: Nickel
    prompt-composition sources and their e2e install script are verified
    only by sentinel presence-checks and materialized-file presence-checks,
    never by a test that discriminates correct logic from incorrect logic);
  * any `*.md` file anywhere in the repository -- the same reasoning
    generalized: a doc-audit link/anchor check is a presence check too, no
    less than a conditioning sentinel grep, so a markdown file carries the
    same ceiling regardless of which directory holds it.

A MIXED commit -- touching both a prose path and a code path -- is scoped as
CODE: prose sharing a commit with code does not launder the code out of
D3-T9's requirement. A merge commit is always kept in scope (it is already
never impl/test signal per Commit.ctype, so scoping changes nothing about
its verdict, and dropping it would break the parent-chain bookkeeping
--sweep relies on).

WHAT COUNTS AS EVIDENCE, AND WHAT IT CANNOT SEE
--------------------------------------------------
The only signal available from committed history without deeper static
analysis is the Conventional-Commit type prefix: a `test:` (or scoped
`test(x):`) commit reads as an evaluator; `feat:`/`fix:` (with or without a
scope) reads as implementation. This is a WEAK, GAMEABLE signal:

  * a `test:` commit that does not actually add a failing evaluator (a
    mislabeled commit) passes this gate while adding nothing D3-T9 cares
    about -- this gate cannot see inside a commit's diff to confirm the
    test in it ever failed;
  * an implementation folded into the SAME commit as its evaluator (the
    "bundle the evaluator into the implementation commit" pattern this
    campaign's own measurement names as the majority case) reads as a bare
    `feat:`/`fix:` with no preceding `test:` -- correctly FAIL by this
    gate's own rule, even though a red baseline may genuinely have been run
    and simply never split into its own commit;
  * a merge commit (2+ parents) is never itself evaluator or implementation
    signal -- it is a structural landmark whose parents' own commits are
    already walked individually, so it is classified as neither and never
    blocks or satisfies the ordering;
  * a commit whose subject carries no parseable Conventional-Commit type at
    all (a bare `git merge` default message, a `Revert "..."` auto-message)
    is UNPARSEABLE -- if it falls before the first implementation commit and
    no earlier `test:` commit has already satisfied the ordering, this gate
    reports AMBIGUOUS rather than guessing either way: it genuinely cannot
    rule out that an unparseable commit is (or is not) the missing
    evaluator. An ambiguous case silently counted as a pass is the
    flattering direction, and this project has been burned by exactly that
    shape of error before -- so it is never folded into PASS.

This gate proves ORDER, never CONTENT: it cannot confirm a `test:` commit's
suite actually failed before the paired implementation landed, only that a
commit typed `test:` precedes one typed `feat:`/`fix:` in the branch's own
history. That is the ceiling of what a commit-subject heuristic can certify,
stated here rather than left implicit.

USAGE
-----
Single node, mirroring trial_merge.sh's CLI shape:
  red_baseline.py <branch-ref> [--against <base-ref>] [--repo <path>]

Sweep every first-parent merge commit in a revision range (one node per
merge, base = merge-base(parent1, parent2), tip = parent2) -- the same unit
directions:D3-T9's own measurement note describes: "for each merge on
master, the commit subjects between the merge base and the branch tip, read
in order":
  red_baseline.py --sweep <base-ref>..<tip-ref> [--repo <path>]

Exit codes (single-node mode):
  0  PASS -- a test: commit precedes the first implementation commit, or
             there is no implementation commit in range at all
  1  FAIL -- an implementation commit exists with no preceding test: commit
  2  usage or environment error (bad ref, git failure)
  3  AMBIGUOUS -- an unparseable commit precedes the first implementation
             commit and no test: commit already satisfies the ordering;
             this gate declines to guess its type

Exit codes (--sweep mode): 0 iff every node PASSes (SKIPs, reported, do not
block); 1 if any node FAILs; 3 if no node FAILs but at least one is
AMBIGUOUS; 2 on usage/environment error.
"""

from __future__ import annotations

import argparse
import re
import subprocess
import sys
from dataclasses import dataclass, field

IMPL_TYPES = {"feat", "fix"}
TEST_TYPES = {"test"}
# AI7 (.ledger/state/decisions-architect-intake.yaml): a path is PROSE --
# exempt from D3-T9's ordering requirement, since its only evaluator is a
# presence check -- when it sits under one of these roots, or is markdown
# anywhere. Everything else defaults to CODE.
PROSE_ROOTS = ("docs/", "conditioning/")
# Conventional-Commit header: type, optional (scope), optional breaking `!`,
# then `: `. Anchored at the start -- a subject that merely CONTAINS a colon
# further in (e.g. a default `Revert "type(scope): subject"` message) does
# not match, and that is deliberate: this gate reads the commit's OWN
# declared type, never sniffs one out of quoted prose.
TYPE_RE = re.compile(r"^([a-zA-Z][a-zA-Z0-9_-]*)(\([^)]*\))?!?:\s")


class EnvError(Exception):
    """A usage or environment problem -- never a finding about the history."""


@dataclass
class Commit:
    sha: str
    subject: str
    n_parents: int

    @property
    def ctype(self) -> str | None:
        # A merge commit (2+ parents) is a structural landmark, never
        # itself evaluator or implementation signal -- its own parents'
        # commits are already walked and classified individually.
        if self.n_parents >= 2:
            return "merge"
        m = TYPE_RE.match(self.subject)
        return m.group(1).lower() if m else None

    @property
    def unparsed(self) -> bool:
        return self.n_parents < 2 and TYPE_RE.match(self.subject) is None

    def label(self) -> str:
        return f"{self.sha[:9]} ({self.subject!r})"


@dataclass
class Verdict:
    status: str  # "PASS" | "FAIL" | "AMBIGUOUS" | "SKIP"
    reason: str
    commits: list = field(default_factory=list)


def is_prose_path(path: str) -> bool:
    """PROSE (exempt from D3-T9's ordering) iff under docs/ or conditioning/,
    or markdown anywhere -- see the module docstring's PATH SCOPE section.
    Everything else is CODE, the conservative default."""
    return path.startswith(PROSE_ROOTS) or path.endswith(".md")


def run_git(repo: str, *args: str) -> str:
    proc = subprocess.run(["git", "-C", repo, *args], capture_output=True, text=True)
    if proc.returncode != 0:
        raise EnvError(f"git {' '.join(args)} failed: {proc.stderr.strip()}")
    return proc.stdout


def resolve(repo: str, ref: str) -> str:
    try:
        return run_git(repo, "rev-parse", "--verify", f"{ref}^{{commit}}").strip()
    except EnvError as err:
        raise EnvError(f"cannot resolve ref {ref!r}: {err}") from err


def commits_between(repo: str, base_sha: str, tip_sha: str) -> list:
    """Every commit reachable from tip_sha but not base_sha, oldest first --
    the full ancestry (not --first-parent), so a nested sub-merge's own
    commits are walked individually rather than collapsed into one line."""
    if base_sha == tip_sha:
        return []
    out = run_git(
        repo, "log", "--reverse", "--format=%H\x01%P\x01%s", f"{base_sha}..{tip_sha}"
    )
    commits = []
    for line in out.splitlines():
        if not line:
            continue
        sha, parents, subject = line.split("\x01", 2)
        n_parents = len(parents.split()) if parents.strip() else 0
        commits.append(Commit(sha=sha, subject=subject, n_parents=n_parents))
    return commits


def commit_paths(repo: str, sha: str) -> set:
    """Changed file paths for a single (non-merge) commit. `--root` makes a
    parentless commit diff against the empty tree instead of returning
    nothing; it is a no-op for every other commit, so it is always safe to
    pass."""
    out = run_git(repo, "diff-tree", "--no-commit-id", "--name-only", "-r", "--root", sha)
    return {line for line in out.splitlines() if line}


def touches_code(repo: str, c: "Commit") -> bool:
    """A merge is never itself impl/test signal (Commit.ctype), so its path
    set is irrelevant -- always in scope. A non-merge is in scope iff at
    least one changed path is CODE (a mixed commit counts: prose does not
    launder code out of the ordering requirement)."""
    if c.n_parents >= 2:
        return True
    return any(not is_prose_path(p) for p in commit_paths(repo, c.sha))


def scope_to_code(repo: str, commits: list) -> list:
    """AI7 path scope: drop every commit that touches no code path -- it can
    never be impl or test signal, so it never enters the ordering. Order is
    preserved; indices into the returned list are what classify() reasons
    over."""
    return [c for c in commits if touches_code(repo, c)]


def classify(commits: list) -> Verdict:
    """AC1-4 stated directly:
      1. a test: commit before an implementation commit -> PASS
      2/3. an implementation commit with no preceding test: commit -> FAIL,
           naming it (distinguishing "evaluator exists but late" from "no
           evaluator at all" in the reason, both FAIL)
      4. no implementation commit in range at all -> PASS, not a violation
    plus AMBIGUOUS: an unparseable commit precedes the first implementation
    commit and no test: commit already closes the ordering -- reported
    rather than guessed either way.
    """
    impl_idx = [i for i, c in enumerate(commits) if c.ctype in IMPL_TYPES]
    if not impl_idx:
        return Verdict("PASS", "no implementation commit in range -- nothing to order", commits)

    first_impl = impl_idx[0]
    f = commits[first_impl]

    test_idx = [i for i, c in enumerate(commits) if c.ctype in TEST_TYPES]
    preceding_tests = [i for i in test_idx if i < first_impl]
    if preceding_tests:
        t = commits[preceding_tests[-1]]
        return Verdict("PASS", f"{t.label()} precedes {f.label()}", commits)

    unparsed_idx = [i for i, c in enumerate(commits) if c.unparsed]
    preceding_unparsed = [i for i in unparsed_idx if i < first_impl]
    if preceding_unparsed:
        u = commits[preceding_unparsed[0]]
        return Verdict(
            "AMBIGUOUS",
            f"{u.label()} precedes {f.label()} but carries no Conventional-Commit "
            "type -- cannot rule out that it is the missing evaluator",
            commits,
        )

    if test_idx:
        t = commits[test_idx[0]]
        return Verdict(
            "FAIL",
            f"{f.label()} has no preceding evaluator commit "
            f"(earliest test: commit {t.label()} lands after it)",
            commits,
        )
    return Verdict("FAIL", f"{f.label()} has no evaluator commit at all in range", commits)


def gate_one(repo: str, branch_ref: str, base_ref: str) -> Verdict:
    branch_sha = resolve(repo, branch_ref)
    base_ref_sha = resolve(repo, base_ref)
    base_sha = run_git(repo, "merge-base", base_ref_sha, branch_sha).strip()
    commits = scope_to_code(repo, commits_between(repo, base_sha, branch_sha))
    return classify(commits)


def sweep(repo: str, range_spec: str) -> list:
    """Every first-parent merge commit in range_spec (a git revision range,
    e.g. 'BASE..TIP') -- one node per merge, base = merge-base(p1, p2), tip
    = p2. An octopus merge (3+ parents) has no single node tip and is
    reported SKIP rather than silently folded into either verdict."""
    out = run_git(repo, "log", "--merges", "--first-parent", "--format=%H", range_spec)
    results = []
    for merge_sha in out.split():
        parents = run_git(repo, "show", "-s", "--format=%P", merge_sha).split()
        if len(parents) != 2:
            results.append(
                (merge_sha, None, Verdict("SKIP", f"{len(parents)}-parent octopus merge -- no single node tip"))
            )
            continue
        p1, p2 = parents
        base_sha = run_git(repo, "merge-base", p1, p2).strip()
        node_commits = scope_to_code(repo, commits_between(repo, base_sha, p2))
        results.append((merge_sha, p2, classify(node_commits)))
    return results


def render_verdict(label: str, v: Verdict) -> None:
    print(f"{v.status}  {label}")
    print(f"  {v.reason}")
    if v.commits:
        print("  commits (oldest first):")
        for c in v.commits:
            ctype = c.ctype or "UNPARSED"
            print(f"    {ctype:>8}  {c.label()}")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[2])
    parser.add_argument("branch_ref", nargs="?", help="branch or sha to gate")
    parser.add_argument("--against", default="master", help="base ref (default: master)")
    parser.add_argument("--repo", default=".", help="git repo (default: cwd)")
    parser.add_argument("--sweep", metavar="RANGE", help="gate every first-parent merge in RANGE (e.g. BASE..TIP)")
    args = parser.parse_args()

    if bool(args.branch_ref) == bool(args.sweep):
        print("red_baseline: usage: pass exactly one of <branch-ref> or --sweep RANGE", file=sys.stderr)
        return 2

    try:
        if args.sweep:
            results = sweep(args.repo, args.sweep)
            counts = {"PASS": 0, "FAIL": 0, "AMBIGUOUS": 0, "SKIP": 0}
            for merge_sha, tip_sha, v in results:
                label = f"merge {merge_sha[:9]}" + (f" (tip {tip_sha[:9]})" if tip_sha else "")
                render_verdict(label, v)
                counts[v.status] += 1
                print()
            total_rated = counts["PASS"] + counts["FAIL"] + counts["AMBIGUOUS"]
            print(
                f"red_baseline: sweep of {args.sweep}: "
                f"{counts['PASS']} PASS, {counts['FAIL']} FAIL, "
                f"{counts['AMBIGUOUS']} AMBIGUOUS, {counts['SKIP']} SKIP "
                f"(of {total_rated + counts['SKIP']} merge commit(s), "
                f"{total_rated} rated)"
            )
            if counts["FAIL"] > 0:
                return 1
            if counts["AMBIGUOUS"] > 0:
                return 3
            return 0

        v = gate_one(args.repo, args.branch_ref, args.against)
        render_verdict(f"{args.branch_ref} against {args.against}", v)
        return {"PASS": 0, "FAIL": 1, "AMBIGUOUS": 3}[v.status]
    except EnvError as err:
        print(f"red_baseline: ENV: {err}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main())
