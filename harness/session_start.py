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
     injection, anchoring corrected by node/dispatch-anchoring) — walked
     through the typed-claim graph rather than the document-citation graph,
     seeding ledger/derive/anchored_surface.sh's anchored-reachability open
     surface, consumed via its --json structured export
     (candidates/excluded_backed fields), never its rendered prose. The
     anchor is the entry ids the WALK'S OWN DISPATCH names (ruling-hooks-
     boundary.md [A6]) — read from the last user-authored message in its
     own transcript, never from what happens to be freshest on disk — with
     recency (entries declared inside recently-touched documents) as the
     fallback for a walk whose dispatch names nothing the corpus
     recognises. Recency-as-primary was this contribution's own shipped
     defect: a filter that is green and useless, since the material most
     likely to need re-surfacing is exactly the material recency cannot see
     ([A3]). Contribution 1 above is untouched by this correction — its
     ranking is a different mechanism (co-citation/token-overlap strength,
     never anchored_surface.sh's anchored/recency ranker) and [A4]/[A6]
     rule only the claim graph.

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
  - Input: JSON on stdin. Documented common fields (code.claude.com/docs/
    en/hooks, cross-checked over two independent fetches for this node,
    node/dispatch-anchoring): session_id, prompt_id (a UUID, absent until
    first user input — never text), transcript_path, cwd, permission_mode,
    effort, hook_event_name, agent_id/agent_type (subagent or `--agent`
    only); SessionStart additionally may carry `model`. NO field on this
    event carries prompt or dispatch TEXT — `prompt` is UserPromptSubmit's
    own field, a different event. The documentation states SessionStart
    does NOT fire when a subagent is spawned via the Task tool; a distinct
    event, SubagentStart, fires instead, and this repository's
    harness/hooks.json wires SessionStart only. This is doc-sourced, not
    independently confirmed by triggering a live subagent SessionStart
    from within this same walk (the gap the original docstring here
    already flagged) — `_last_dispatch_message_text` below reads
    `transcript_path`, the one common field documented to carry prior
    conversation content, as the best mechanism reachable under this
    constraint; see node/dispatch-anchoring's own report for what this
    means for a Task-dispatched worker's reach.
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
import re
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
# co-citation query (contribution 1, unconditionally) and the claim-surface
# fallback (contribution 2, only when its dispatch names no anchor the
# corpus recognises — see compute_claim_surface). Small on purpose: this is
# "what was just touched", not a history sweep — a large window dilutes
# toward "the whole corpus is recent" in an actively-written record.
RECENT_ANCHOR_COUNT = 5

# A qualified entry id (`stem:MARKER`, extract_entries.py's own id shape —
# stems may lead with a date, so digits open them, matching BRACKET_REF_RE's
# stem group in extract_entries.py) found anywhere in a walk's own dispatch
# text. Matched against the corpus's real ids below, never trusted as-is —
# free text is not a source of entry ids on its own say-so.
DISPATCH_QUALIFIED_ID_RE = re.compile(
    r"\b([A-Za-z0-9][A-Za-z0-9-]*):([A-Za-z][A-Za-z0-9-]*)\b")
# A bare document stem (node/dispatch-anchoring, ruling-hooks-boundary.md
# [A6]: "bare document stems may also be worth anchoring on") — the negative
# lookahead excludes the stem half of an already-qualified id immediately
# above, so "ruling-hooks-boundary:A6" anchors on A6 alone rather than also
# expanding to every entry the document declares.
DISPATCH_STEM_RE = re.compile(r"\b([A-Za-z0-9][A-Za-z0-9-]*)\b(?!:)")


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


def resolve_ledger_root(project_root: Path) -> Path:
    """.ledger lives beside the MAIN checkout, never necessarily beside
    whatever `project_root` resolve_project_root() returned — a linked git
    worktree's own toplevel (correct for `current_branch_tokens`, which
    wants THIS walk's own branch) is a different directory than the main
    tree the recorder sub-repository sits next to. Widens via `git rev-parse
    --git-common-dir` (hooks/install-hooks.sh's and
    ledger/gate/install-recorder-hook.sh's own idiom, reused rather than
    reinvented — it names the shared .git regardless of which worktree
    asks) only when project_root's own .ledger is missing, so a plain
    non-worktree checkout — the common case — never pays the extra git
    call. Never raises: any failure here just falls back to project_root's
    own (possibly absent) .ledger, the same degrade-to-empty path every
    other resolution failure in this hook takes."""
    direct = project_root / ".ledger"
    if direct.is_dir():
        return direct
    common_dir = _run(["git", "rev-parse", "--git-common-dir"], project_root)
    if not common_dir:
        return direct
    common_path = Path(common_dir)
    if not common_path.is_absolute():
        common_path = project_root / common_path
    return common_path.resolve().parent / ".ledger"


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
    anchor_source: str = ""  # "dispatch", "recency", or "" (no anchors at all)


def _export_entries(ledger_root: Path) -> List[dict]:
    """Runs extract_entries.py over the WHOLE corpus once and returns its
    `entries` list — the one extraction both anchor sources below draw from
    (dispatch-named ids need it to confirm a match is real; the recency
    fallback needs it to find what a recent document declares), so a single
    hook invocation never pays for the extractor twice. Independent of
    whatever anchored_surface.sh does with its own --corpus internally — the
    two extractions serve different purposes (anchor discovery here,
    reachability computation there) — and tolerant of partial corpus
    findings that would make the other exit non-zero: the export is written
    even when extract_entries.py itself exits 3 for findings elsewhere in
    the corpus, only the finding's own doc is missing entries, not every
    doc. Never raises: any failure (missing script, bad exit with no
    export, malformed JSON, timeout) degrades to an empty list."""
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
    return export.get("entries", [])


def _entry_anchors_near_recent(entries: List[dict], recent_ids: FrozenSet[str]) -> List[str]:
    """Entry ids declared INSIDE the recently-touched documents themselves —
    the FALLBACK anchor set for 'open claims near the work', used only when
    the walk's own dispatch names nothing the corpus recognises
    (compute_claim_surface). A different id space than `recent_ids`
    (candidate_links' document ids, e.g. `log/foo`): extract_entries.py
    qualifies an entry id with its document's own filename STEM only, never
    a directory prefix (its own `[stem:ID]` convention), so `recent_ids` is
    narrowed to bare stems before matching."""
    if not recent_ids:
        return []
    recent_stems = {doc_id.rsplit("/", 1)[-1] for doc_id in recent_ids}
    anchors = []
    for entry in entries:
        entry_id = entry.get("id", "")
        stem = entry_id.split(":", 1)[0] if ":" in entry_id else ""
        if stem in recent_stems:
            anchors.append(entry_id)
    return anchors


def _last_dispatch_message_text(transcript_path: Optional[str]) -> Optional[str]:
    """The text of the most recent user-authored, non-meta message in the
    TOP-LEVEL transcript `transcript_path` names — the closest thing to
    'the walk's dispatch' for a resumed or forked top-level session, where
    it is the most recent thing the walk was asked to continue (what 'about
    to be re-derived' means for that class of session). `isMeta` entries
    (harness-injected system-reminders, not the walk's own words) are
    skipped.

    NOT the right source for a Task-dispatched SUBAGENT (see
    `_subagent_dispatch_text`, tried first when `agent_id` is present):
    empirically, across two isolated `claude -p` probe runs (node/dispatch-
    anchoring), a subagent's OWN `transcript_path` is the PARENT session's
    shared transcript — its dispatch prompt lives inside an ASSISTANT
    tool_use block (`name` "Agent"/"Task"), never as a `type: "user"`
    message this function reads — so called alone here it would find the
    top-level human's own prompt, misattributing the subagent's context to
    whatever last started the whole session. Kept as the fallback for that
    case (the top-level prompt is still more relevant than pure recency)
    and as the primary path for an actual top-level resume/fork, where no
    such misattribution risk exists.

    Never raises: a missing path, an unreadable/malformed file, or a
    transcript with no qualifying message all degrade to None — the same
    non-fatal path every other resolution in this hook takes, and the
    caller's own fallback to recency is exactly the degrade this
    produces."""
    if not transcript_path:
        return None
    path = Path(transcript_path)
    try:
        raw = path.read_text(encoding="utf-8")
    except OSError:
        return None

    last_text: Optional[str] = None
    for line in raw.splitlines():
        line = line.strip()
        if not line:
            continue
        try:
            obj = json.loads(line)
        except json.JSONDecodeError:
            continue
        if obj.get("type") != "user" or obj.get("isMeta"):
            continue
        message = obj.get("message")
        if not isinstance(message, dict) or message.get("role") != "user":
            continue
        text = _message_content_text(message.get("content"))
        if text:
            last_text = text
    return last_text


def _message_content_text(content) -> Optional[str]:
    """A transcript entry's `message.content` in either shape the format
    uses — a plain string, or a list of content blocks — collapsed to its
    text, or None if it carries no non-blank text block. Shared by both
    dispatch-text readers below so the two content shapes are parsed
    identically rather than twice."""
    if isinstance(content, str):
        return content if content.strip() else None
    if isinstance(content, list):
        text = "\n".join(
            block.get("text", "") for block in content
            if isinstance(block, dict) and block.get("type") == "text"
        )
        return text if text.strip() else None
    return None


def _subagent_dispatch_text(
    transcript_path: Optional[str], session_id: Optional[str], agent_id: Optional[str],
) -> Optional[str]:
    """The walk's OWN dispatch text when this hook fires for a Task-
    dispatched subagent (SubagentStart) — the PRIMARY source when
    `agent_id` is present, ahead of `_last_dispatch_message_text`.

    SubagentStart's own `transcript_path` points at the PARENT session's
    shared transcript, not the subagent's own (see
    `_last_dispatch_message_text`'s docstring for how that was confirmed).
    Both probe runs that established this ALSO show a PER-SUBAGENT
    transcript file at a sibling path (`<transcript_path's parent>/
    <session_id>/subagents/*.jsonl`) whose own first entry is a genuine
    `type: "user"` message carrying the real dispatch text — found by
    CONTENT, not filename: every file in that directory is opened and its
    first line's own `agentId` field is compared against the `agent_id`
    this event's stdin already provides, never by guessing the filename's
    naming transform (a real subagent's filename embeds its declared NAME
    when given one, `agent-a<name>-<short-id>.jsonl`, and a bare
    `agent-<agent_id>.jsonl` otherwise — two different shapes this hook has
    no documented way to predict, so it does not try).

    This directory layout is NOT part of the documented hook contract
    (unlike transcript_path/session_id/agent_id themselves, which ARE) —
    it is empirically observed on this harness build, not guaranteed
    stable across versions. Degrades to None on any mismatch: a missing
    session_id/agent_id, an absent or unreadable subagents directory, or
    no file whose first entry's agentId matches — routing straight to
    `_last_dispatch_message_text`'s own fallback, the same non-fatal path
    every other resolution in this hook takes."""
    if not transcript_path or not session_id or not agent_id:
        return None
    subagents_dir = Path(transcript_path).parent / session_id / "subagents"
    try:
        candidates = sorted(subagents_dir.glob("*.jsonl"))
    except OSError:
        return None
    for candidate in candidates:
        try:
            with candidate.open("r", encoding="utf-8") as f:
                first_line = f.readline()
        except OSError:
            continue
        if not first_line.strip():
            continue
        try:
            obj = json.loads(first_line)
        except json.JSONDecodeError:
            continue
        if obj.get("agentId") != agent_id or obj.get("type") != "user":
            continue
        message = obj.get("message")
        if not isinstance(message, dict) or message.get("role") != "user":
            continue
        text = _message_content_text(message.get("content"))
        if text:
            return text
    return None


def _dispatch_anchor_ids(text: str, entries: List[dict]) -> List[str]:
    """Entry ids the walk's OWN dispatch text names — [A6]'s PRIMARY anchor
    source, ahead of recency. A qualified `stem:MARKER` (DISPATCH_QUALIFIED_
    ID_RE) names one entry directly; a bare document stem (DISPATCH_STEM_RE)
    names the whole document and expands to every entry it declares — the
    ruling leaves this choice to this node ('bare document stems may also be
    worth anchoring on'), and expansion is what lets a document named without
    a marker anchor as richly as the old recent-document sweep did. Both
    forms are restricted to ids/stems that actually exist in the extracted
    corpus: free text is not a trusted source of entry ids on its own say-so,
    the same restriction anchored_surface.sh's own callers already hold to
    — an anchor the two-hop walk cannot recognise is worse than no anchor,
    since it silently contributes nothing while looking chosen."""
    by_id = {e.get("id", ""): e for e in entries if e.get("id")}
    by_stem: Dict[str, List[str]] = {}
    for eid in by_id:
        by_stem.setdefault(eid.split(":", 1)[0], []).append(eid)

    found: List[str] = []
    seen = set()

    def _add(eid: str) -> None:
        if eid not in seen:
            seen.add(eid)
            found.append(eid)

    for m in DISPATCH_QUALIFIED_ID_RE.finditer(text):
        candidate = f"{m.group(1)}:{m.group(2)}"
        if candidate in by_id:
            _add(candidate)

    for m in DISPATCH_STEM_RE.finditer(text):
        for eid in by_stem.get(m.group(1), []):
            _add(eid)

    return found


def compute_claim_surface(
    ledger_root: Path,
    input_data: Optional[dict] = None,
    budget: int = CLAIM_BUDGET,
) -> ClaimSurface:
    """Second hook contribution: open claims/questions structurally near the
    just-touched work, via the anchored-reachability open-surface primitive
    (ledger/derive/anchored_surface.sh --json). Consumes the primitive's
    STRUCTURED value only (candidates/excluded_backed fields) — its own
    rendered prose is never parsed here, the same discipline `compute_surface`
    and the candidate-links suite already hold to.

    Anchor priority (node/dispatch-anchoring, ruling-hooks-boundary.md [A6]):
    the entries the WALK'S OWN DISPATCH names come first; recency (entries
    declared in recently-touched documents) is the FALLBACK for a walk
    whose dispatch names nothing the corpus recognises — including every
    walk this is called for with `input_data` omitted, which keeps this
    contribution testable without a transcript fixture. Recency-as-primary
    was this contribution's own shipped defect and is not restored here
    even as a tiebreak: a dispatch anchor, once found, is used exclusively.

    Reading the dispatch itself is TWO readers tried in order, because
    SubagentStart and a top-level SessionStart resume/fork carry it
    differently (empirically confirmed, node/dispatch-anchoring): when
    `agent_id` is present (this walk IS a Task-dispatched subagent),
    `_subagent_dispatch_text` is tried first — its own transcript_path
    points at the PARENT's shared transcript, not this walk's own, so it
    is skipped otherwise. `_last_dispatch_message_text` (the top-level
    transcript's own last user message) is always the fallback reader,
    covering both an actual top-level resume/fork AND a subagent whose
    per-subagent transcript could not be found.

    Degrades to an empty contribution whenever no anchor is found by either
    path or the primitive itself returns nothing (a pre-existing corpus
    defect, an unusable/absent corpus, or a genuinely empty open surface) —
    never an error, matching this hook's own never-block contract (module
    docstring)."""
    from candidate_links import build_corpus

    corpus, _warnings = build_corpus(ledger_root)
    if not corpus:
        return ClaimSurface(0, 0, 0, 0, "")

    entries = _export_entries(ledger_root)

    data = input_data or {}
    dispatch_text = None
    if data.get("agent_id"):
        dispatch_text = _subagent_dispatch_text(
            data.get("transcript_path"), data.get("session_id"), data.get("agent_id"))
    if not dispatch_text:
        dispatch_text = _last_dispatch_message_text(data.get("transcript_path"))

    anchor_source = ""
    anchors: List[str] = []
    if dispatch_text:
        anchors = sorted(set(_dispatch_anchor_ids(dispatch_text, entries)))
        if anchors:
            anchor_source = "dispatch"
    if not anchors:
        recent_ids = recent_anchor_ids(corpus, ledger_root, RECENT_ANCHOR_COUNT)
        anchors = sorted(set(_entry_anchors_near_recent(entries, recent_ids)))
        if anchors:
            anchor_source = "recency"
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
        return ClaimSurface(len(anchors), 0, 0, 0, "", anchor_source)

    try:
        result = json.loads(out)
        candidates = result["candidates"]
    except (json.JSONDecodeError, KeyError, TypeError):
        return ClaimSurface(len(anchors), 0, 0, 0, "", anchor_source)

    if not candidates:
        return ClaimSurface(len(anchors), 0, 0, 0, "", anchor_source)

    anchor_clause = (
        "entries the walk's own dispatch names" if anchor_source == "dispatch"
        else "entries declared in recently-touched documents (the walk's "
        "dispatch named none the corpus recognises)"
    )
    lines = [
        "## Open claims near the work (structural, session-start)",
        f"Claims and questions reachable within two hops of {anchor_clause}, "
        "via the anchored-reachability open-surface primitive "
        "(ledger/derive/anchored_surface.sh).",
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
    return ClaimSurface(len(anchors), len(candidates), included, dropped, text, anchor_source)


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
        ledger_root = resolve_ledger_root(project_root)

        surface = compute_surface(ledger_root, project_root, budget=DOC_BUDGET)
        claims = compute_claim_surface(ledger_root, input_data, budget=CLAIM_BUDGET)
        parts = [s.text for s in (surface, claims) if s.text]
        if not parts:
            print(json.dumps({}))
            return 0

        # node/dispatch-anchoring: this script is now wired to BOTH
        # SessionStart and SubagentStart (harness/hooks.json) — the output
        # contract requires hookEventName to echo whichever one fired
        # (code.claude.com/docs/en/hooks), never a constant, or a
        # SubagentStart invocation reports itself as the wrong event.
        print(json.dumps({
            "hookSpecificOutput": {
                "hookEventName": input_data.get("hook_event_name", "SessionStart"),
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
