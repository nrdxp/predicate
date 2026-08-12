#!/usr/bin/env python3
"""candidate_links.py — co-citation and stem/title candidate surfacing for a
staged recorder document (ledger/README.md: "derive/ — derivations computed
*from* an artifact, not hand-authored"; this derives a candidate SET from the
corpus's own citation graph, never from a model or an index).

The problem this closes (.ledger/log/2026-08-12-search-before-write.md, [S1]):
"A promotion begins with a search for correlated records" is recorded and was
not operative — nothing ran it. This makes it fire, structurally:

  CO-CITATION   If the staged document cites A, and some other document cites
                A alongside B, B is a candidate — "what tends to travel with
                what I already cite."
  STEM/TITLE    A document whose filename STEM shares significant tokens with
                the staged document's own stem-or-title is a candidate — the
                cold-start cover co-citation cannot provide: a draft citing
                nothing surfaces nothing from co-citation alone, and the first
                note on a new topic is exactly where a missed link costs most.

Both are purely structural and deterministic: no model call, no embedding
index (grepai's index is still building and is explicitly out of scope here —
see the module docstring in recorder-pre-commit.sh for the seam).

This module REPORTS; it never BLOCKS. Every entry point degrades to a
diagnostic + exit 0 rather than raising — a missing/empty record, an
unreadable document, or an internal error must never be the reason a commit
cannot happen (see main()). Whether a surfaced candidate is the RIGHT link is
not machine-decidable; only whether it correlates structurally is, so the gate
data model separates the two: every candidate is emitted with an
`already_linked` flag rather than filtered by it, so a document that ignored
what it was shown stays visible in the record.

CLI:
    candidate_links.py <ledger_root> <staged_doc_path> [<staged_doc_path> ...] [-o out.json]

`staged_doc_path` is ledger-root-relative (the same coordinate space
`git diff --cached --name-only` emits inside the .ledger subrepo). Prints a
human-readable report per document to stdout; `-o` additionally writes the
full structured report (list of DocReport, JSON) for machine consumption —
tests assert against that export, never against the rendered text (a
candidate SET is a value; grepping rendered prose for it reintroduces the
"last number in the output" class of bug this project has already paid for).
"""

from __future__ import annotations

import dataclasses
import json
import re
import sys
from pathlib import Path
from typing import Dict, FrozenSet, List, Optional, Tuple

# Directories under a .ledger checkout that are not corpus documents: git
# internals, worktree/session scaffolding, and the recorder's own scratch
# mirror (never the record — constitution: "Scratch is the MIRROR, never the
# record").
SKIP_DIRS = frozenset({".git", ".claude", ".scratch", ".worktrees"})

WIKILINK_RE = re.compile(r"\[\[([^\]]+)\]\]")
TITLE_RE = re.compile(r"^#\s+(.*\S)\s*$", re.MULTILINE)
TOKEN_RE = re.compile(r"[a-z0-9]+")
DATE_PREFIX_RE = re.compile(r"^\d{4}-\d{2}-\d{2}-")

# A significant-token filter for the stem/title heuristic: short tokens and a
# small closed stopword list. Deliberately crude (this is the cold-start
# cover, not the precise signal — co-citation is) rather than tuned to the
# live corpus's vocabulary, so it stays valid as the corpus grows.
STOPWORDS = frozenset(
    {
        "the", "a", "an", "is", "are", "was", "were", "be", "been", "being",
        "and", "or", "not", "no", "never", "always", "this", "that", "these",
        "those", "it", "its", "as", "at", "by", "for", "from", "in", "into",
        "of", "on", "onto", "over", "to", "with", "without", "than", "then",
        "when", "what", "why", "how", "which", "who", "one", "two", "three",
        "own", "only", "also", "any", "every", "each", "same", "has", "have",
        "had", "does", "do", "did", "can", "could", "should", "would",
        "must", "may", "might", "will", "shall", "new", "old", "log",
    }
)

# Minimum shared significant tokens for the stem/title heuristic to surface a
# candidate. A single shared token is too common to be informative on its own
# (jargon words recur constantly in this corpus); two is the cheapest bound
# that discriminates coincidence from a genuine shared topic.
MIN_STEM_OVERLAP = 2

KNOWN_EXTS = (".md", ".yaml", ".yml")


@dataclasses.dataclass(frozen=True)
class DocInfo:
    doc_id: str  # ledger-root-relative path, extension stripped
    targets: FrozenSet[str]  # normalized wikilink targets this doc cites
    stem_tokens: FrozenSet[str]
    title_tokens: FrozenSet[str]


@dataclasses.dataclass(frozen=True)
class Candidate:
    target: str
    kind: str  # 'co-citation' | 'stem'
    via: Tuple[str, ...]  # co-citation: shared anchor doc_ids; stem: shared tokens
    strength: int
    already_linked: bool


@dataclasses.dataclass
class DocReport:
    doc: str
    status: str  # 'ok' | 'not-found' | 'malformed' | 'no-corpus' | 'not-indexed'
    candidates: List[Candidate]
    actionable_count: int
    already_linked_count: int
    note: str = ""
    ambiguous: List[str] = dataclasses.field(default_factory=list)


def strip_ext(relpath: str) -> str:
    for ext in KNOWN_EXTS:
        if relpath.endswith(ext):
            return relpath[: -len(ext)]
    return relpath


def normalize_target(raw: str) -> str:
    """A wikilink target as authored may carry a node-level qualifier
    (`stem:X2`, the corpus's own qualified-id grammar — see
    .ledger/deposits/core-amendment/lead-maintainer-seat/gate-qualified-ids.md)
    or a redundant `.md` suffix; both are stripped to the bare document id so
    two citations of the same document co-cite regardless of which node or
    extension form was named."""
    t = raw.strip().split(":", 1)[0]
    for ext in KNOWN_EXTS:
        if t.endswith(ext):
            return t[: -len(ext)]
    return t


def tokenize(text: str) -> FrozenSet[str]:
    toks = TOKEN_RE.findall(text.lower())
    return frozenset(t for t in toks if len(t) > 2 and not t.isdigit() and t not in STOPWORDS)


def doc_tokens(doc_id: str, content: str) -> Tuple[FrozenSet[str], FrozenSet[str]]:
    stem = doc_id.rsplit("/", 1)[-1]
    stem = DATE_PREFIX_RE.sub("", stem)
    stem_tokens = tokenize(stem.replace("-", " "))
    m = TITLE_RE.search(content)
    title_tokens = tokenize(m.group(1)) if m else frozenset()
    return stem_tokens, title_tokens


def build_corpus(ledger_root: Path) -> Tuple[Dict[str, DocInfo], List[str]]:
    """Never raises. An absent/empty root returns an empty corpus (the
    'no-corpus' case main() reports); an individual unreadable document is
    skipped with a warning rather than aborting the whole build — one
    malformed note must not blind the check to the rest of the record."""
    corpus: Dict[str, DocInfo] = {}
    warnings: List[str] = []
    if not ledger_root.is_dir():
        return corpus, [f"ledger root not found: {ledger_root}"]
    for path in sorted(ledger_root.rglob("*.md")):
        rel = path.relative_to(ledger_root)
        if SKIP_DIRS & set(rel.parts):
            continue
        doc_id = strip_ext(rel.as_posix())
        try:
            content = path.read_text(encoding="utf-8")
        except (OSError, UnicodeDecodeError) as exc:
            warnings.append(f"unreadable, skipped from corpus: {rel} ({exc})")
            continue
        targets = frozenset(normalize_target(t) for t in WIKILINK_RE.findall(content))
        stem_tokens, title_tokens = doc_tokens(doc_id, content)
        corpus[doc_id] = DocInfo(
            doc_id=doc_id, targets=targets, stem_tokens=stem_tokens, title_tokens=title_tokens
        )
    return corpus, warnings


def resolve_target(target: str, corpus: Dict[str, DocInfo]) -> Tuple[Optional[str], bool]:
    """Best-effort resolution of a citation target to a real corpus document.
    Exact path match first; a bare (no '/') target falls back to a unique
    basename match, since wikilinks are sometimes authored without their
    directory prefix.

    Returns (resolved_doc_id_or_None, is_ambiguous). A dangling reference
    (zero matches) and an AMBIGUOUS one (multiple basename matches) are
    different failures: the first means the record doesn't have the
    information; the second means it does and can't tell which one is
    meant. Collapsing both into a bare None (the previous shape) reported
    an ambiguity exactly like a dangling link — a silent wrong answer on an
    advisory surface, the same failure direction this project keeps
    catching elsewhere. Link-health REPAIR is still a separate,
    already-running audit (out of scope here); this only makes the
    ambiguous case visible rather than resolving it."""
    if target in corpus:
        return target, False
    if "/" not in target:
        matches = [d for d in corpus if d.rsplit("/", 1)[-1] == target]
        if len(matches) == 1:
            return matches[0], False
        if len(matches) > 1:
            return None, True
    return None, False


def resolved_targets(info: DocInfo, corpus: Dict[str, DocInfo]) -> FrozenSet[str]:
    """A document's own citations, resolved to real corpus doc ids (dangling
    or ambiguous targets drop silently from this set — see
    ambiguous_targets to recover which ones were ambiguous rather than
    merely absent). Public: a caller building its own anchor set from a
    document's citations (e.g. a SessionStart hook seeding from several
    recently-touched documents at once) needs this directly, not just the
    staged-single-document wrappers below."""
    return frozenset(r for t in info.targets for r, _ in [resolve_target(t, corpus)] if r is not None)


def ambiguous_targets(info: DocInfo, corpus: Dict[str, DocInfo]) -> FrozenSet[str]:
    """The raw (unresolved) citation strings from `info` that matched more
    than one corpus document by basename — reported rather than silently
    treated as dangling, so a report_for caller can surface them."""
    return frozenset(t for t in info.targets if resolve_target(t, corpus)[1])


def co_citation_candidates_for_anchors(
    anchors: FrozenSet[str], corpus: Dict[str, DocInfo], exclude_id: Optional[str] = None
) -> Dict[str, Candidate]:
    """For every document A in `anchors`, every OTHER document that also
    cites A contributes its remaining citations as candidates — "what tends
    to travel with what I already cite". General over any anchor set, not
    just one staged document's own citations: a SessionStart hook has no
    staged document to derive anchors from, only recent activity, so this is
    the primitive both `co_citation_candidates` and the hook build on.

    Traversal is per-anchor (A), not per shared-set: a candidate B may itself
    be one of the anchors (already_linked reports that honestly rather than
    the traversal silently excluding it) — the only exclusion is `exclude_id`,
    a hypothetical document (e.g. a staged doc) that is not itself a real
    citing source in the corpus."""
    anchors_seen: Dict[str, set] = {}  # candidate -> set of anchor A's that produced it
    co_citing_docs: Dict[str, set] = {}  # candidate -> set of doc_ids providing the evidence

    for a in anchors:
        for d_id, d_info in corpus.items():
            if d_id == exclude_id:
                continue
            d_targets = resolved_targets(d_info, corpus)
            if a not in d_targets:
                continue
            for b in d_targets:
                if b == a or b == exclude_id:
                    continue
                anchors_seen.setdefault(b, set()).add(a)
                co_citing_docs.setdefault(b, set()).add(d_id)

    return {
        b: Candidate(
            target=b,
            kind="co-citation",
            via=tuple(sorted(anchors_seen[b])),
            strength=len(co_citing_docs[b]),
            already_linked=b in anchors,
        )
        for b in anchors_seen
    }


def co_citation_candidates(staged_id: str, corpus: Dict[str, DocInfo]) -> Dict[str, Candidate]:
    """Co-citation candidates for a staged document, from what IT cites."""
    staged = corpus[staged_id]
    anchors = resolved_targets(staged, corpus)
    return co_citation_candidates_for_anchors(anchors, corpus, exclude_id=staged_id)


def token_overlap_candidates(
    query_tokens: FrozenSet[str], corpus: Dict[str, DocInfo], exclude_ids: FrozenSet[str] = frozenset()
) -> Dict[str, Candidate]:
    """A document whose filename STEM shares >= MIN_STEM_OVERLAP significant
    tokens with `query_tokens` is a candidate. General over any token query,
    not just one staged document's stem-or-title: a SessionStart hook's query
    may be a branch name or other free text with no corpus doc behind it.
    `already_linked` is always False here — the caller decides linkage
    against whatever citation set (if any) actually applies to its query."""
    result: Dict[str, Candidate] = {}
    for d_id, d_info in corpus.items():
        if d_id in exclude_ids:
            continue
        overlap = query_tokens & d_info.stem_tokens
        if len(overlap) >= MIN_STEM_OVERLAP:
            result[d_id] = Candidate(
                target=d_id, kind="stem", via=tuple(sorted(overlap)),
                strength=len(overlap), already_linked=False,
            )
    return result


def stem_candidates(staged_id: str, corpus: Dict[str, DocInfo]) -> Dict[str, Candidate]:
    """Stem/title-overlap candidates for a staged document. The comparison is
    deliberately asymmetric: the candidate side is its stem ALONE (a
    title-vs-title comparison would just be co-citation's job done badly),
    the staged side is stem UNION title (a document's title is often the
    more legible summary of what it is about)."""
    staged = corpus[staged_id]
    anchors = resolved_targets(staged, corpus)
    staged_side = staged.stem_tokens | staged.title_tokens
    raw = token_overlap_candidates(staged_side, corpus, exclude_ids={staged_id})
    return {
        d_id: dataclasses.replace(c, already_linked=(d_id in anchors))
        for d_id, c in raw.items()
    }


def report_for(staged_path: str, ledger_root: Path, corpus: Dict[str, DocInfo]) -> DocReport:
    if not corpus:
        return DocReport(
            doc=staged_path, status="no-corpus", candidates=[], actionable_count=0,
            already_linked_count=0, note="the record is empty or absent — nothing to compare against",
        )

    doc_id = strip_ext(Path(staged_path).as_posix())
    if doc_id not in corpus:
        abspath = ledger_root / staged_path
        if not abspath.is_file():
            return DocReport(
                doc=staged_path, status="not-found", candidates=[], actionable_count=0,
                already_linked_count=0, note=f"staged path not found under ledger root: {staged_path}",
            )
        try:
            abspath.read_text(encoding="utf-8")
        except (OSError, UnicodeDecodeError) as exc:
            return DocReport(
                doc=staged_path, status="malformed", candidates=[], actionable_count=0,
                already_linked_count=0, note=f"could not read as text: {exc}",
            )
        return DocReport(
            doc=staged_path, status="not-indexed", candidates=[], actionable_count=0,
            already_linked_count=0, note="not a document this check indexes (non-.md, or outside the ledger root)",
        )

    merged: Dict[Tuple[str, str], Candidate] = {}
    for c in list(co_citation_candidates(doc_id, corpus).values()) + list(
        stem_candidates(doc_id, corpus).values()
    ):
        merged[(c.kind, c.target)] = c
    candidates = sorted(merged.values(), key=lambda c: (-c.strength, c.kind, c.target))
    actionable = sum(1 for c in candidates if not c.already_linked)
    linked = len(candidates) - actionable
    ambiguous = sorted(ambiguous_targets(corpus[doc_id], corpus))
    return DocReport(
        doc=staged_path, status="ok", candidates=candidates,
        actionable_count=actionable, already_linked_count=linked,
        ambiguous=ambiguous,
    )


def render(report: DocReport) -> str:
    lines = [f"candidate-links: {report.doc}"]
    if report.status != "ok":
        lines.append(f"  ({report.note})")
        return "\n".join(lines)
    if report.ambiguous:
        targets = ", ".join(report.ambiguous)
        lines.append(
            f"  {len(report.ambiguous)} ambiguous citation(s) — matched more than one document "
            f"by basename, not resolved: {targets}"
        )
    if not report.candidates:
        lines.append("  no candidates found (co-citation or stem/title overlap)")
        return "\n".join(lines)
    for c in report.candidates:
        mark = " [already linked]" if c.already_linked else ""
        via = ", ".join(c.via)
        lines.append(f"  [{c.kind}] {c.target}  (via: {via}; strength={c.strength}){mark}")
    if report.actionable_count == 0:
        lines.append(f"  all {report.already_linked_count} candidate(s) already linked — nothing to act on")
    else:
        lines.append(
            f"  {report.actionable_count} candidate(s) not yet linked; {report.already_linked_count} already linked"
        )
    return "\n".join(lines)


def main(argv: List[str]) -> int:
    # This check is advisory-only by contract (recorder-pre-commit.sh never
    # gates on its exit code), but the contract is enforced HERE too: no
    # branch below may propagate an exception or return non-zero. An error
    # degrades to a diagnostic on stderr, never a blocked commit.
    try:
        args = list(argv)
        outfile: Optional[str] = None
        if "-o" in args:
            i = args.index("-o")
            if i + 1 >= len(args):
                sys.stderr.write("candidate-links: -o requires a path argument; ignoring\n")
                del args[i:]
            else:
                outfile = args[i + 1]
                del args[i : i + 2]

        if len(args) < 2:
            sys.stderr.write(
                "candidate-links: usage: candidate_links.py <ledger_root> <staged_doc_path> [...] [-o out.json]\n"
            )
            return 0

        ledger_root = Path(args[0])
        staged_paths = args[1:]

        corpus, warnings = build_corpus(ledger_root)
        for w in warnings:
            sys.stderr.write(f"candidate-links: {w}\n")

        reports = [report_for(p, ledger_root, corpus) for p in staged_paths]
        for r in reports:
            print(render(r))

        if outfile:
            with open(outfile, "w", encoding="utf-8") as f:
                json.dump([dataclasses.asdict(r) for r in reports], f, indent=2, sort_keys=True)

        return 0
    except Exception as exc:  # last-resort: this check must never block a commit
        sys.stderr.write(f"candidate-links: internal error (advisory check skipped): {exc}\n")
        return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
