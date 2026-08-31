#!/usr/bin/env python3
"""Currency verdict for an anchored freshness cure -- the lapse predicate
the architect ruling names (.ledger/deposits/expiry-mechanics/
architect-seat/2026-08-24-ruling-expiry-mechanics.md [R1]/[R5]) and the
compiled model behind it (factoring-trust/.scratch/Lapse.lean, read via
.ledger/log/2026-08-24-the-lapse-split-holds-given-four-things.md):

    A currency verdict is current iff nothing under its declared scope
    (a git pathspec) has changed since its anchor commit.

`git diff --quiet <at> HEAD -- <scope>` IS the evaluator [R1]/[EX5]. This
script wraps it with the FOUR PRECONDITIONS the compiled model requires
before that evaluator's answer means anything ([LM6]):

  H1  extension-only futures -- HEAD must extend the anchor. Outside that,
      `Monotone` promises nothing in either direction
      (`rewrite_escapes_monotonicity`, [LM3]): a lapsed record does not
      imply the anchor is an ancestor. This script checks ancestry
      EXPLICITLY and reports `anchor-not-an-ancestor` rather than reading
      silence as "current" -- a hash-anchored verdict survives a rewrite
      as ORPHANED, never falsified, and validity and pertinence are
      different questions.
  H1b committed state only -- both endpoints are commits; there is no
      flag here that ever reads the working tree.
  H2  content-addressed anchors, never movable refs -- the CommitRef shape
      (entry.ncl) already refuses this upstream; this script independently
      refuses to resolve the anchor unless it is bare hex AND git resolves
      it directly to a commit object (defense in depth against a
      pathological all-hex ref name).
  H3  frozen, record-determined scope evaluation -- the scope is whatever
      the caller passes, evaluated by `git diff`/`git merge-base` alone;
      no tree-walking, no attribute handling of its own.

Usage:
  currency.py --anchor <hash> --scope <pathspec> [--repo <path>]

Exit codes:
  0  current                 -- nothing under scope changed since anchor
  1  lapsed                  -- something under scope changed (named)
  2  anchor-not-an-ancestor  -- HEAD does not extend anchor: orphaned, not lapsed
  3  usage / environment error (movable-ref anchor, unresolvable repo, ...)
"""

from __future__ import annotations

import argparse
import re
import subprocess
import sys

HEX_RE = re.compile(r"^[0-9a-f]{7,40}$")


class EnvError(Exception):
    """A usage or environment problem -- never a verdict about the record."""


def run_git(repo: str, *args: str) -> subprocess.CompletedProcess:
    return subprocess.run(
        ["git", "-C", repo, *args], capture_output=True, text=True
    )


def require_bare_commit(repo: str, anchor: str) -> None:
    """H2: refuse anything but a content-addressed anchor. The regex alone
    (entry.ncl's CommitRef) is the primary refusal; resolving it against the
    repository is the second, independent check -- a hex-looking string
    that git resolves to something other than a commit (or does not resolve
    at all) is refused here too, never silently treated as current."""
    if not HEX_RE.match(anchor):
        raise EnvError(
            f"movable-ref: anchor `{anchor}` is not a bare commit hash "
            "(7-40 lowercase hex) -- refused"
        )
    resolved = run_git(repo, "rev-parse", "--verify", "--quiet", f"{anchor}^{{commit}}")
    if resolved.returncode != 0:
        raise EnvError(
            f"anchor `{anchor}` does not resolve to a commit object in {repo}"
        )


def require_ancestor(repo: str, anchor: str) -> bool:
    """H1: does HEAD extend anchor? Returns True/False rather than raising --
    the caller distinguishes this from an environment error, since a
    non-ancestor anchor is a REPORTABLE record condition
    (`anchor-not-an-ancestor`), not a usage mistake."""
    result = run_git(repo, "merge-base", "--is-ancestor", anchor, "HEAD")
    if result.returncode not in (0, 1):
        raise EnvError(
            f"merge-base --is-ancestor failed unexpectedly (rc={result.returncode}): "
            f"{result.stderr.strip()}"
        )
    return result.returncode == 0


def lapsed(repo: str, anchor: str, scope: str) -> tuple[bool, list[str]]:
    """H1b/H3: committed-state-only, frozen scope evaluation -- exactly
    `git diff --quiet <anchor> HEAD -- <scope>`, plus the changed paths for
    a lapsed verdict's diagnostic."""
    diff = run_git(repo, "diff", "--quiet", anchor, "HEAD", "--", scope)
    if diff.returncode == 0:
        return False, []
    if diff.returncode != 1:
        raise EnvError(
            f"git diff failed unexpectedly (rc={diff.returncode}): {diff.stderr.strip()}"
        )
    changed = run_git(repo, "diff", "--name-only", anchor, "HEAD", "--", scope)
    return True, [p for p in changed.stdout.splitlines() if p]


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--anchor", required=True, help="the freshness cure's commit hash")
    parser.add_argument("--scope", required=True, help="the freshness cure's git pathspec")
    parser.add_argument("--repo", default=".", help="repository root (default: cwd)")
    opts = parser.parse_args()

    try:
        require_bare_commit(opts.repo, opts.anchor)
        if not require_ancestor(opts.repo, opts.anchor):
            print(
                f"currency: anchor-not-an-ancestor: HEAD does not extend "
                f"{opts.anchor} -- the verdict is ORPHANED, not lapsed",
                file=sys.stderr,
            )
            return 2
        is_lapsed, changed_paths = lapsed(opts.repo, opts.anchor, opts.scope)
    except EnvError as err:
        print(f"currency: ENV: {err}", file=sys.stderr)
        return 3

    if is_lapsed:
        print("lapsed")
        for path in changed_paths:
            print(f"  changed: {path}")
        return 1

    print("current")
    return 0


if __name__ == "__main__":
    sys.exit(main())
