#!/usr/bin/env python3
"""session_start.py — Claude Code SessionStart hook: injects a structural
open-surface signal from the record into a fresh agent's context.

Two contributions, independently computed and independently degradable:

  1. RELATED DOCUMENTS (compute_surface) — the problem this closes
     (.ledger/log/2026-08-12-search-before-write.md, [S1]): "a promotion
     begins with a search for correlated records" is recorded and was not
     operative. ledger/derive/candidate_links.py made that search runnable
     against a staged document; this makes it fire automatically at the one
     moment a walk has no staged document yet to search FROM — session
     start — by using what actually is available then: the record's own
     recent activity (which documents were just touched) and the branch
     name (which often names the topic).
  2. OPEN CLAIMS NEAR THE WORK (compute_claim_surface, node/surface-
     injection) — the same "what was just touched" anchor, but walked
     through the typed-claim graph instead of the document-citation graph:
     the entry ids declared inside recently-touched documents seed
     ledger/derive/anchored_surface.sh's anchored-reachability open surface,
     consumed via its --json structured export (candidates/excluded_backed
     fields), never its rendered prose.

BUDGET_CHARS splits evenly between the two (DOC_BUDGET/CLAIM_BUDGET): no
corpus property makes one contribution a priori more valuable than the
other, and giving each its own fixed half means either can report an honest
dropped-count against ITS OWN budget rather than a moving target set by how
much the other one used. A contribution that finds nothing (no anchors, an
uninjectable corpus, or the primitive itself failing — see its own
docstring) degrades to an empty string and simply drops out of the merged
additionalContext, never to a placeholder or an error.

Contract (Claude Code SessionStart hooks), verified against two shipped
official plugins on this machine (explanatory-output-style, security-
guidance) and plugin-dev's hook-development skill, cross-checked against
Claude Code's own changelog where noted:
  - Input: JSON on stdin. Documented common fields: session_id,
    transcript_path, cwd, permission_mode, hook_event_name; SessionStart
    additionally carries `source` ("startup"/"resume"/"fork") and
    `agent_type` when specified (changelog-only, not independently
    verified here since no live SessionStart harness was available to
    trigger from within this same walk).
  - Output: JSON on stdout, `{"hookSpecificOutput": {"hookEventName":
    "SessionStart", "additionalContext": "<string>"}}` — this exact shape
    is the live body of the shipped explanatory-output-style plugin's
    session-start.sh, so it is verified rather than taken on the
    documentation's word alone.
  - Size: hook output over 50,000 characters is saved to disk and the
    model sees a file path + preview instead of the text (Claude Code
    changelog, verified independently of anything relayed) — a path is
    not read, so this hook budgets to BUDGET_CHARS, far under that floor.
  - Exit: this hook NEVER exits non-zero. Exit 2 is documented as a
    blocking error for SessionStart specifically (changelog: "Fixed
    SessionStart... hooks silently hiding stderr when exiting with code
    2") — an advisory context injector must never be able to block a
    session from starting, so every failure mode here degrades to
    printing `{}` (no injection) and exiting 0, never to a non-zero exit
    or an uncaught exception.
  - Emit nothing rather than something wrong: an absent .ledger, an empty
    corpus, or zero candidates all print `{}` — no additionalContext key
    at all, never an apologetic empty string.
"""

from __future__ import annotations

import dataclasses
import json
import os
import subprocess
import sys
import tempfile
from pathlib import Path
from typing import Dict, FrozenSet, List, Optional, Tuple

HERE = Path(__file__).resolve().parent
PLUGIN_ROOT = HERE.parent
sys.path.insert(0, str(PLUGIN_ROOT / "ledger" / "derive"))

# Budget deliberately far under the 50,000-character harness ceiling (see
# module docstring) — the point is that the content is READ, and content
# near the ceiling risks the harness's own disk-spill behavior on a future
# growth of this hook's output. Split evenly across the two contributions —
# see the module docstring for why an even split rather than a weighted one.
BUDGET_CHARS = 4000
DOC_BUDGET = BUDGET_CHARS // 2
CLAIM_BUDGET = BUDGET_CHARS - DOC_BUDGET

# How many of the most-recently-modified corpus documents anchor the
# co-citation query. Small on purpose: this is "what was just touched", not
# a history sweep — a large window dilutes toward "the whole corpus is
# recent" in an actively-written record.
RECENT_ANCHOR_COUNT = 5


def _run(cmd: List[str], cwd: Path, timeout: int = 5) -> Optional[str]:
    """Best-effort subprocess capture. Returns stripped stdout on success,
    None on any failure (missing binary, non-git dir, non-zero exit,
    timeout) — never raises. This hook has no gate to fail; every subprocess
    call here is an optional signal, not a requirement. A non-zero exit
    collapses to None on purpose: anchored_surface.sh's own exit 1 (corpus
    extraction/validation failure — a pre-existing, out-of-scope corpus
    defect, see that script's header) is exactly the "primitive returns
    nothing" case this hook's contributions must degrade through, not
    surface as an error."""
    try:
        r = subprocess.run(
            cmd, cwd=str(cwd), capture_output=True, text=True, timeout=timeout,
        )
    except (OSError, subprocess.TimeoutExpired):
        return None
    if r.returncode != 0:
        return None
    return r.stdout.strip() or None


def resolve_project_root(input_data: dict) -> Path:
    """cwd from the hook's own stdin JSON first (the documented common
    field), then $CLAUDE_PROJECT_DIR, then the process cwd — in that order,
    each a fallback for the one before it. Whichever is found is then
    widened to the git toplevel if it sits inside a git work tree (a
    SessionStart cwd could in principle be a subdirectory), and used as-is
    otherwise — an absent .ledger under it degrades gracefully downstream,
    the same non-fatal path as every other failure mode here."""
    candidate = input_data.get("cwd") or os.environ.get("CLAUDE_PROJECT_DIR") or os.getcwd()
    path = Path(candidate)
    toplevel = _run(["git", "rev-parse", "--show-toplevel"], path if path.is_dir() else Path.cwd())
    if toplevel:
        return Path(toplevel)
    return path


def current_branch_tokens(project_root: Path) -> FrozenSet[str]:
    from candidate_links import tokenize  # local import: sys.path is set up by caller

    branch = _run(["git", "branch", "--show-current"], project_root)
    if not branch:
        return frozenset()
    return tokenize(branch.replace("/", " ").replace("-", " ").replace("_", " "))


def recent_anchor_ids(corpus: dict, ledger_root: Path, count: int) -> FrozenSet[str]:
    """The `count` corpus documents with the most recent mtime on disk.
    Mtime rather than `git -C .ledger log` — it reflects live, possibly
    uncommitted edits (exactly what a walk mid-session has just written),
    and needs no assumption about the recorder's git history shape."""
    with_mtime: List[Tuple[float, str]] = []
    for doc_id in corpus:
        path = ledger_root / f"{doc_id}.md"
        try:
            with_mtime.append((path.stat().st_mtime, doc_id))
        except OSError:
            continue
    with_mtime.sort(reverse=True)
    return frozenset(doc_id for _, doc_id in with_mtime[:count])


@dataclasses.dataclass
class Surface:
    """The structured result of this hook's computation — asserted on
    directly by tests, never scraped back out of rendered text (the
    candidate-links suite's own governing rule)."""
    anchor_count: int
    candidate_count: int
    included_count: int
    dropped_count: int
    text: str  # "" means nothing to inject


def compute_surface(ledger_root: Path, project_root: Path, budget: int = BUDGET_CHARS) -> Surface:
    from candidate_links import (
        Candidate, build_corpus, co_citation_candidates_for_anchors,
        resolved_targets, token_overlap_candidates,
    )

    corpus, _warnings = build_corpus(ledger_root)
    if not corpus:
        return Surface(0, 0, 0, 0, "")

    recent_ids = recent_anchor_ids(corpus, ledger_root, RECENT_ANCHOR_COUNT)
    # The co-citation anchor set is what the recently-touched documents
    # THEMSELVES cite, not their own ids — a brand-new document has no
    # inbound citations yet (nothing has had the chance to reference it),
    # so anchoring on its own id would starve the query exactly when it
    # matters most. Unioning several recent documents' citations is the
    # multi-document generalization of what co_citation_candidates does
    # for one staged document.
    anchor_targets: set = set()
    for doc_id in recent_ids:
        anchor_targets |= resolved_targets(corpus[doc_id], corpus)
    anchors = frozenset(anchor_targets)

    branch_tokens = current_branch_tokens(project_root)

    merged: Dict[Tuple[str, str], Candidate] = {}
    if anchors:
        for c in co_citation_candidates_for_anchors(anchors, corpus, exclude_id=None).values():
            merged[(c.kind, c.target)] = c
    if branch_tokens:
        for c in token_overlap_candidates(branch_tokens, corpus, exclude_ids=recent_ids).values():
            merged[(c.kind, c.target)] = c

    # A candidate that is itself a recently-touched document or one of its
    # own citations is not new information — it is what the query was
    # seeded from.
    exclude_from_output = recent_ids | anchors
    candidates = [c for c in merged.values() if c.target not in exclude_from_output]
    candidates.sort(key=lambda c: (-c.strength, c.kind, c.target))

    if not candidates:
        return Surface(len(recent_ids), 0, 0, 0, "")

    topic_clause = " and the current branch" if branch_tokens else ""
    lines = [
        "## Record open surface (structural, session-start)",
        f"Documents correlated with recent record activity{topic_clause}, by "
        "co-citation and filename/title overlap — never a semantic judgment, "
        "surfaced so a promotion can search before it writes "
        "(.ledger/log/2026-08-12-search-before-write.md, [S1]).",
        "",
    ]
    budget_for_lines = budget - sum(len(line) + 1 for line in lines) - 200  # headroom for the trailer
    included = 0
    body_lines: List[str] = []
    for c in candidates:
        via = ", ".join(c.via)
        row = f"- [{c.kind}] {c.target}  (via: {via}; strength={c.strength})"
        if sum(len(r) + 1 for r in body_lines) + len(row) + 1 > budget_for_lines:
            break
        body_lines.append(row)
        included += 1

    dropped = len(candidates) - included
    lines.extend(body_lines)
    lines.append("")
    # Reproducible without the hook (degrade-to-the-primitive): querying each
    # recently-touched document directly and taking the union of their
    # candidates reproduces this surface's document set — the CLI has no
    # flag for a raw anchor-set query, but recent_ids are real files it
    # accepts directly.
    lines.append(
        f"{included} shown, {dropped} dropped for budget. Full surface: "
        f"python3 ledger/derive/candidate_links.py .ledger "
        + " ".join(sorted(f"{r}.md" for r in recent_ids))
    )
    text = "\n".join(lines)
    return Surface(len(recent_ids), len(candidates), included, dropped, text)


@dataclasses.dataclass
class ClaimSurface:
    """The structured result of the second contribution — same shape as
    Surface, asserted on directly by tests, never scraped back out of
    rendered text."""
    anchor_count: int
    candidate_count: int
    included_count: int
    dropped_count: int
    text: str  # "" means nothing to inject


def _entry_anchors_near_recent(ledger_root: Path, recent_ids: FrozenSet[str]) -> List[str]:
    """Entry ids declared INSIDE the recently-touched documents themselves —
    the anchor set for 'open claims near the work'. A different id space
    than `recent_ids` (candidate_links' document ids, e.g. `log/foo`):
    extract_entries.py qualifies an entry id with its document's own
    filename STEM only, never a directory prefix (its own `[stem:ID]`
    convention), so `recent_ids` is narrowed to bare stems before matching.

    Runs extract_entries.py over the WHOLE corpus once, independently of
    whatever anchored_surface.sh does with its own --corpus internally —
    the two extractions serve different purposes (anchor DISCOVERY here,
    reachability computation there) and this one tolerates partial corpus
    findings that would make the other exit non-zero (the export is written
    even when extract_entries.py itself exits 3 for findings elsewhere in
    the corpus; only the finding's own doc is missing entries, not every
    doc). Never raises: any failure (missing script, bad exit with no
    export, malformed JSON, timeout) degrades to no anchors found."""
    if not recent_ids:
        return []
    extractor = PLUGIN_ROOT / "ledger" / "derive" / "extract_entries.py"
    try:
        with tempfile.TemporaryDirectory() as td:
            out_path = Path(td) / "extract.json"
            subprocess.run(
                [sys.executable, str(extractor), str(ledger_root), "-o", str(out_path)],
                capture_output=True, text=True, timeout=15,
            )
            if not out_path.exists():
                return []
            export = json.loads(out_path.read_text(encoding="utf-8"))
    except (OSError, subprocess.TimeoutExpired, json.JSONDecodeError):
        return []

    recent_stems = {doc_id.rsplit("/", 1)[-1] for doc_id in recent_ids}
    anchors = []
    for entry in export.get("entries", []):
        entry_id = entry.get("id", "")
        stem = entry_id.split(":", 1)[0] if ":" in entry_id else ""
        if stem in recent_stems:
            anchors.append(entry_id)
    return anchors


def compute_claim_surface(ledger_root: Path, budget: int = CLAIM_BUDGET) -> ClaimSurface:
    """Second hook contribution: open claims/questions structurally near the
    just-touched work, via the anchored-reachability open-surface primitive
    (ledger/derive/anchored_surface.sh --json). Consumes the primitive's
    STRUCTURED value only (candidates/excluded_backed fields) — its own
    rendered prose is never parsed here, the same discipline `compute_surface`
    and the candidate-links suite already hold to. Degrades to an empty
    contribution whenever anchors can't be determined or the primitive
    itself returns nothing (a pre-existing corpus defect, an unusable/absent
    corpus, or a genuinely empty open surface) — never an error, matching
    this hook's own never-block contract (module docstring)."""
    from candidate_links import build_corpus

    corpus, _warnings = build_corpus(ledger_root)
    if not corpus:
        return ClaimSurface(0, 0, 0, 0, "")

    recent_ids = recent_anchor_ids(corpus, ledger_root, RECENT_ANCHOR_COUNT)
    anchors = sorted(set(_entry_anchors_near_recent(ledger_root, recent_ids)))
    if not anchors:
        return ClaimSurface(0, 0, 0, 0, "")

    cmd = [
        str(PLUGIN_ROOT / "ledger" / "derive" / "anchored_surface.sh"),
        "--corpus", str(ledger_root), "--budget", "100000", "--json",
    ]
    for a in anchors:
        cmd += ["--anchor", a]
    out = _run(cmd, ledger_root, timeout=15)
    if out is None:
        return ClaimSurface(len(anchors), 0, 0, 0, "")

    try:
        result = json.loads(out)
        candidates = result["candidates"]
    except (json.JSONDecodeError, KeyError, TypeError):
        return ClaimSurface(len(anchors), 0, 0, 0, "")

    if not candidates:
        return ClaimSurface(len(anchors), 0, 0, 0, "")

    lines = [
        "## Open claims near the work (structural, session-start)",
        "Claims and questions reachable within two hops of entries declared "
        "in recently-touched documents, via the anchored-reachability open-"
        "surface primitive (ledger/derive/anchored_surface.sh).",
        "",
    ]
    budget_for_lines = budget - sum(len(line) + 1 for line in lines) - 200  # headroom for the trailer
    included = 0
    body_lines: List[str] = []
    for c in candidates:
        row = f"- [{c['id']}] {c['statement']}  (distance={c['distance']})"
        if sum(len(r) + 1 for r in body_lines) + len(row) + 1 > budget_for_lines:
            break
        body_lines.append(row)
        included += 1

    dropped = len(candidates) - included
    lines.extend(body_lines)
    lines.append("")
    # Points to the RENDERED form (no --json) — a stranger reproducing this
    # without the hook reads prose, the same convention compute_surface's own
    # trailer follows for its reproduction command.
    lines.append(
        f"{included} shown, {dropped} dropped for budget. Full surface: "
        f"ledger/derive/anchored_surface.sh --corpus .ledger --budget 100000 "
        + " ".join(f"--anchor {a}" for a in anchors)
    )
    text = "\n".join(lines)
    return ClaimSurface(len(anchors), len(candidates), included, dropped, text)


def main() -> int:
    # This hook must NEVER exit non-zero and must NEVER raise past this
    # point — see the module docstring's exit-code contract.
    try:
        raw = sys.stdin.read() if not sys.stdin.isatty() else ""
        try:
            input_data = json.loads(raw) if raw.strip() else {}
        except json.JSONDecodeError:
            input_data = {}

        project_root = resolve_project_root(input_data)
        ledger_root = project_root / ".ledger"

        surface = compute_surface(ledger_root, project_root, budget=DOC_BUDGET)
        claims = compute_claim_surface(ledger_root, budget=CLAIM_BUDGET)
        parts = [s.text for s in (surface, claims) if s.text]
        if not parts:
            print(json.dumps({}))
            return 0

        print(json.dumps({
            "hookSpecificOutput": {
                "hookEventName": "SessionStart",
                "additionalContext": "\n\n".join(parts),
            }
        }))
        return 0
    except Exception as exc:  # last-resort: this hook must never block a session
        sys.stderr.write(f"session_start: internal error (no injection): {exc}\n")
        print(json.dumps({}))
        return 0


if __name__ == "__main__":
    sys.exit(main())
