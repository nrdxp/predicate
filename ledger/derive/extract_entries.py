#!/usr/bin/env python3
"""Extract typed-claim entries from graded prose into the contract's shape.

The prose record is the SOURCE; this export is DERIVED and regenerated, never
maintained. The output is JSON (a YAML subset nickel imports either way):

    {entries, directives, grades, findings}

`entries` is validated by the EXISTING ledger/contracts/entry_apply.ncl —
this script is a grammar, not a validator: everything it cannot place is
REPORTED in `findings` (exit 3), never silently skipped, and everything the
contract can decide (id uniqueness, edge resolution, field shapes) is left to
the contract.

Grammar (the docs/entries.md §grammar standard, ledger dialect):
  header      `signer:: <kind>[/<name>]` and `at:: <commit>` spans, first
              occurrence each; a doc without both is pre-standard — countable,
              not extractable.
  node        a paragraph opening with `[ID] grade::<grade>`.
  companions  backticked `token:: value` spans inside the node's paragraph:
              check / source / derives-from / discharge / closer / provenance
              / axes / freshness / discharges / supersedes / tags map to
              fields; conversion-path is recognized prose and stays in the
              statement; anything else token-shaped is reported.
  mentions    a span of ANY mapped token with an EMPTY value is a MENTION of
              the token, not a use of it: prose ABOUT the grammar. It fills no
              field, never overwrites an earlier real use, and stays in the
              statement where it was written. The rule is general over the
              mapped set — present and future — not a per-token exception.
  refs        a bracketed ref names the document whose stem it carries
              (`[stem:ID]`, QUALIFIED) or the document that wrote it (`[ID]`,
              PLAIN) — plain never widens to the corpus, so a reference's
              scope never depends on what else the extraction covered. Only
              the qualified form asserts corpus membership, so only it is
              checked against the corpus, and one naming an id no document
              declares is reported and dropped rather than emitted.
              `[[wiki]]` refs and free prose are external ALWAYS, including
              when the text reads like an id: an external name colliding with
              one is not a declaration. derives-from tags them `external` and
              a corpus ref `corpus`, both landing in `because` as one list of
              `{kind, name}` records (ruling-provenance-representation) —
              because is the ONLY tagged field; the closure edges stay plain
              corpus ids and report an external name instead, since a closure
              onto something outside the corpus closes nothing.
  axes        `axes:: +determined -certifiable +monotone` — polarity tokens in
              any order. `certifiable` is OMITTED where determination fails:
              the coordinate is undefined there, not false, and the grammar
              must be able to say so (CertifiabilityFibered enforces it).
              `freshness:: <prose>` names the T3 cure a non-monotone claim owes.
  tags        `tags:: D1, D2` — comma/space-separated tag tokens, order
              preserved. The extractor is a GRAMMAR, not a validator: it
              collects whatever tokens are written and leaves admission
              against the registry (ledger/contracts/tag_registry.ncl) to the
              contract, exactly as every other companion here does.
  census      --census reproduces the two commands graded documents publish:
              per-grade counts (sort -rn semantics) then `---` then the bare
              `grade::` occurrence count, scoped to before any `## 7` heading.

Questions are emitted with `backing: unclosed` (residual excepted), matching
the entry fixtures' practice: CorroborationBacked/VouchBacked carry no
assertion guard, so the cell-table backings (dispatchable = corroborated,
routed = vouched) would demand evidence a question by definition lacks. The
prose grade survives in the `grades` sidecar, which the query reads.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from collections import Counter
from dataclasses import dataclass, field
from pathlib import Path

# grade -> (assertion, backing); directive is out-of-vocabulary for Entry
# (it closes by authority, not evidence) and routes to the `directives` list.
GRADE_CELLS = {
    "proved": ("claim", "corroborated"),
    "cited": ("claim", "vouched"),
    "synthesis": ("claim", "unclosed"),
    "dispatchable": ("question", "unclosed"),
    "routed": ("question", "unclosed"),
    "frontier": ("question", "unclosed"),
    "residual": ("question", "residual"),
}
VOCAB = tuple(GRADE_CELLS) + ("directive",)

TOKEN_RE = re.compile(r"grade::(%s)" % "|".join(VOCAB))
BARE_RE = re.compile(r"grade::")
# The grade is captured as ANY non-space token, and the vocabulary below is the
# only thing that judges it. A narrower capture judges the grade HERE, where a
# rejection is not a finding but a paragraph that quietly stops being a node —
# so a grade carrying a hyphen, a digit or a capital would take its whole claim
# out of the record with nothing said, which is the failure every other report
# in this file exists to prevent.
MARKER_RE = re.compile(
    r"^\s*(?:-\s+)?`\[([A-Za-z][A-Za-z0-9-]*)\]\s+grade::([^\s`]*)`\s*")
SPAN_RE = re.compile(r"`([^`]+)`")
COMPANION_RE = re.compile(r"^([a-z][a-z-]*)::\s*(.*)$", re.DOTALL)
WIKILINK_RE = re.compile(r"\[\[([^\]]+)\]\]")
# One pattern for both ref forms: the stem is optional, and its absence IS
# the plain form. Stems are document stems, which lead with a date in the
# landed record (`2026-08-11-state-typed`), so digits open them.
BRACKET_REF_RE = re.compile(
    r"\[(?:([A-Za-z0-9][A-Za-z0-9-]*):)?([A-Za-z][A-Za-z0-9-]*)\]")
# a source/derives-from value continues past its span as `, [[wiki]]` segments
CONTINUATION_RE = re.compile(r"^\s*,?\s*(?:`(\[\[[^\]]+\]\])`|(\[\[[^\]]+\]\]))")
# A `check::` span carries no independent, parser-observable mark of whether
# the command actually ran — no punctuation convention stands in for that.
# Authorship IS the attestation: a signer who writes `check:: <cmd>` into a
# signed record is vouching they ran it, the same way any other testimony in
# this grammar is trusted to its signer rather than re-derived from prose
# shape. So a check companion's mere presence sets `ran = true`; a reader who
# doubts a specific claim re-runs the named command themselves, which is
# the whole point of the grade being falsifiable at all.
# The record's assertive form: a paragraph led by a bolded sentence. It is the
# shape an unmarked claim keeps when its writer declines to type it, and the
# only handle the grammar has on a claim that opens no marker at all.
BOLD_LEAD_RE = re.compile(r"^\*\*(.+?)\*\*")
SIGNER_RE = re.compile(r"`signer::\s*([^`]+)`")
AT_RE = re.compile(r"`at::\s*([0-9a-f]{7,40})`")

# `discharge` (prospective prose) and `discharges` (retrospective edge) are
# one letter apart on purpose — the source's own names, kept rather than
# renamed. The hazard is stated in docs/entries.md; here they are simply two
# distinct keys, and a typo lands on the wrong one loudly rather than quietly.
CLOSURE_EDGES = ("discharges", "supersedes")
MAPPED = {"check", "source", "derives-from", "discharge", "closer",
          "provenance", "axes", "freshness", "tags"} | set(CLOSURE_EDGES)
RECOGNIZED = MAPPED | {"conversion-path", "signer", "at", "grade"}
SIGNER_KINDS = {"human", "agent", "source", "derived", "unattributed"}
# A closer designates a party who COULD close; the signer modes that assert no
# reachable party (derived, unattributed) are incoherent for it, so this set is
# narrower by construction and mirrors the contract's CloserKind.
CLOSER_KINDS = {"human", "agent", "source"}
# `machine` is the legacy corpus's word for an unnamed agent, not a fourth
# kind: the landed notes say `closer:: machine` and mean "any agent will do".
CLOSER_ALIASES = {"machine": "agent"}
AXIS_TOKEN_RE = re.compile(r"([+-])(determined|certifiable|monotone)\b")
# The contract's own field order, so the export diffs cleanly against a golden.
AXIS_ORDER = ("determined", "certifiable", "monotone")


def census(text: str) -> str:
    """Reproduce the published census commands: scope, counts, bare total."""
    scope_lines: list[str] = []
    for line in text.splitlines():
        scope_lines.append(line)
        if line.startswith("## 7"):
            break  # sed -n '1,/^## 7/p' prints through the matching line
    scope = "\n".join(scope_lines)
    counts = Counter(TOKEN_RE.findall(scope))
    rows = [f"{n:7d} grade::{grade}" for grade, n in counts.items()]
    # sort -rn: numeric desc, whole-line descending as the tie-break
    rows.sort(key=lambda row: (int(row.split()[0]), row), reverse=True)
    bare = len(BARE_RE.findall(scope))
    return "\n".join(rows + ["---", str(bare)])


def paragraphs(text: str) -> list[str]:
    """Blank-line-delimited blocks, lines joined; fenced code is skipped."""
    blocks: list[str] = []
    current: list[str] = []
    in_fence = False
    for line in text.splitlines():
        if line.lstrip().startswith("```"):
            in_fence = not in_fence
            continue
        if in_fence:
            continue
        if not line.strip():
            if current:
                blocks.append(" ".join(current))
                current = []
        else:
            current.append(line.strip())
    if current:
        blocks.append(" ".join(current))
    return blocks


@dataclass(slots=True)
class QualifiedRef:
    """A ref that named its own document — the one form asserting corpus
    membership, so the one form the corpus can refute. It is held against the
    entry it was written into, because the corpus it asserts is only known
    once every document has been read."""
    entry: dict
    edge: str
    ref: str
    doc: str
    marker: str


@dataclass(slots=True)
class Extraction:
    entries: list[dict] = field(default_factory=list)
    directives: list[dict] = field(default_factory=list)
    grades: dict[str, str] = field(default_factory=dict)
    findings: list[dict] = field(default_factory=list)
    qualified: list[QualifiedRef] = field(default_factory=list)

    def report(self, kind: str, doc: str, marker: str | None, reason: str) -> None:
        self.findings.append(
            {"kind": kind, "doc": doc, "marker": marker, "reason": reason}
        )

    def attach_refs(self, entry: dict, key: str, value: str, doc: str,
                    marker: str, *, tagged: bool = False) -> list[str]:
        """Namespace an edge value onto `entry[key]`, holding its qualified
        refs for the corpus to answer; return what stayed external. Derivation
        and closure share this whole rule and differ only in what they do with
        that remainder, so the rule is written once. `tagged` is `because`
        alone (ruling-provenance-representation): its corpus refs land as
        `{kind: corpus, name: ...}` records rather than bare strings, so the
        field can carry an external counterpart beside them; every other edge
        kind stays the plain corpus-id list it always was."""
        refs, qualified, external = split_refs(value, doc)
        entry_refs = [{"kind": "corpus", "name": r} for r in refs] if tagged else refs
        if entry_refs:
            entry[key] = entry_refs
        self.qualified.extend(
            QualifiedRef(entry, key, ref, doc, marker) for ref in qualified)
        return external


def parse_signer(raw: str) -> dict | None:
    kind, _, name = raw.strip().partition("/")
    if kind not in SIGNER_KINDS:
        return None
    return {"kind": kind, "name": name} if name else {"kind": kind}


def parse_closer(raw: str) -> dict | None:
    """`kind[/name]` into a designation record; None when it is neither."""
    kind, _, name = raw.strip().partition("/")
    kind = CLOSER_ALIASES.get(kind, kind)
    if kind not in CLOSER_KINDS:
        return None
    return {"kind": kind, "name": name} if name else {"kind": kind}


def parse_axes(raw: str) -> tuple[dict, str]:
    """Polarity tokens into the contract's Axes shape, plus what it could not
    place — an unreadable axis is reported, never a half-recorded coordinate
    set that reads as a deliberate omission."""
    found = {m.group(2): m.group(1) == "+" for m in AXIS_TOKEN_RE.finditer(raw)}
    residue = AXIS_TOKEN_RE.sub("", raw).strip(" ,;")
    return {name: found[name] for name in AXIS_ORDER if name in found}, residue


def parse_tags(raw: str) -> list[str]:
    """Comma/space-separated tag tokens, order preserved, empties dropped.
    Admission against the registry is the CONTRACT's job (module docstring);
    this only tokenizes."""
    return [t for t in re.split(r"[,\s]+", raw.strip()) if t]


def split_refs(value: str, doc: str) -> tuple[list[str], list[str], list[str]]:
    """Partition a value into corpus refs and external refs.

    Both bracketed forms leave here already namespaced — a ref names the
    document it declares a stem for, or `doc` when it declares none — so the
    caller holds edges and never marker fragments. The qualified subset comes
    back beside them because a declared stem is an assertion ABOUT the corpus,
    and the corpus is not known until every document is read."""
    external = WIKILINK_RE.findall(value)
    remainder = WIKILINK_RE.sub("", value)
    refs: list[str] = []
    qualified: list[str] = []
    for stem, marker in BRACKET_REF_RE.findall(remainder):
        ref = f"{stem or doc}:{marker}"
        refs.append(ref)
        if stem:
            qualified.append(ref)
    residue = BRACKET_REF_RE.sub("", remainder).strip(" ,;")
    if residue:
        external.append(residue)
    return refs, qualified, external


def resolve_qualified(out: Extraction) -> None:
    """Refute the qualified refs the finished corpus does not declare.

    Dropped rather than emitted: an edge onto an id nothing declares is
    refused by the contract, and one bad ref must not cost a claim the
    provenance beside it — so the ref goes and its neighbours stay. Reported
    rather than filed as external provenance: a bracketed id asserts the
    target is IN the record, and demoting it would read as a deliberate
    pointer out of the record instead of the mistake it is."""
    declared = set(out.grades)
    for qual in out.qualified:
        if qual.ref in declared:
            continue
        out.report("bad-edge", qual.doc, qual.marker,
                   f"`[{qual.ref}]` is a qualified reference to an id the "
                   "corpus does not declare; the edge is dropped")
        current = qual.entry.get(qual.edge, [])
        # `because` alone carries tagged {kind, name} records; every other
        # edge this walk holds is still the plain corpus-id string it always
        # was, so the comparison is keyed off the edge name rather than
        # introspecting the element's shape.
        if qual.edge == "because":
            remaining = [r for r in current if r["name"] != qual.ref]
        else:
            remaining = [r for r in current if r != qual.ref]
        if remaining:
            qual.entry[qual.edge] = remaining
        else:
            qual.entry.pop(qual.edge, None)


def parse_node(rest: str, out: Extraction, doc: str, marker: str,
               last_source: list[str]) -> tuple[str, dict[str, str]]:
    """Walk the node's spans: collect companions, keep the rest as statement."""
    companions: dict[str, str] = {}
    statement_parts: list[str] = []
    pos = 0
    while (span := SPAN_RE.search(rest, pos)) is not None:
        statement_parts.append(rest[pos : span.start()])
        content = span.group(1)
        match = COMPANION_RE.match(content)
        token = match.group(1) if match else None
        if token in MAPPED:
            value = match.group(2).strip()
            end = span.end()
            if token in ("source", "derives-from"):
                while (cont := CONTINUATION_RE.match(rest[end:])) is not None:
                    link = cont.group(1) or cont.group(2)
                    value = f"{value}, {link}" if value else link
                    end += cont.end()
            if not value:
                # MENTION, not use — the span names the token in prose about
                # the grammar. Tested AFTER continuations, so `derives-from::`
                # carrying only a trailing [[wiki]] ref is still a use. It
                # fills no field, so it cannot clobber an earlier real value
                # with the empty string the contract would then reject.
                statement_parts.append(span.group(0))
                pos = span.end()
                continue
            if token == "source" and value == "same":
                if last_source:
                    value = last_source[0]
                else:
                    out.report("unresolved-anaphora", doc, marker,
                               "source:: same with no prior source in the document")
            elif token == "source":
                last_source[:] = [value]
            companions[token] = value
            pos = end
        elif token is not None and token not in RECOGNIZED:
            out.report("unknown-companion", doc, marker,
                       f"companion token `{token}::` is not in the grammar")
            pos = span.end()
        else:
            # plain spans (commands, conversion-path, mentions) stay as prose
            statement_parts.append(span.group(0))
            pos = span.end()
    statement_parts.append(rest[pos:])
    statement = re.sub(r"\s+", " ", "".join(statement_parts)).strip()
    return statement, companions


def report_unplaced(block: str, out: Extraction, doc: str) -> None:
    """Vocabulary tokens outside any span were counted but collected by no
    node — the census/extraction gap this report keeps visible."""
    for hit in TOKEN_RE.finditer(SPAN_RE.sub("", block)):
        out.report("unplaced-token", doc, None,
                   f"`{hit.group(0)}` appears outside any node marker")


def report_orphaned_companions(block: str, out: Extraction, doc: str,
                                marker: str | None) -> None:
    """A recognized companion span outside its node's own paragraph is
    invisible to parse_node, which only ever walks that one paragraph — the
    node scope docs/entries.md states. Report it against the nearest
    preceding marker (None before the document's first node) rather than
    letting it vanish with the field it would have filled."""
    for span in SPAN_RE.finditer(block):
        match = COMPANION_RE.match(span.group(1))
        if match and match.group(1) in MAPPED:
            out.report("orphaned-companion", doc, marker,
                       f"`{match.group(1)}::` is outside its node's "
                       "paragraph and cannot be attached to an entry")


def report_unmarked_assertions(leads: list[str], out: Extraction, doc: str,
                               grades_its_claims: bool) -> None:
    """A claim that opens no marker is invisible to every other report here.
    They all fire on a claim that was marked and then malformed; simply
    declining to mark one evades the discipline at no cost, so this is the
    only report that can see that evasion.

    Scoped on whether the DOCUMENT grades its claims, never on whether the
    extractor could read it: the header is not the discriminator. Most of the
    landed record is untyped prose under a header that parses perfectly, and
    reporting that prose would bury this signal under an order of magnitude of
    legacy — the finding would then be true and useless."""
    if not grades_its_claims:
        return
    for lead in leads:
        excerpt = lead if len(lead) <= 60 else lead[:57] + "..."
        out.report("unmarked-assertion", doc, None,
                   f"`{excerpt}` asserts with no `[ID] grade::` marker in a "
                   "document that grades its claims; nothing types or counts it")


def extract_doc(path: Path, out: Extraction) -> None:
    text = path.read_text(encoding="utf-8")
    doc = path.stem
    signer_match = SIGNER_RE.search(text)
    at_match = AT_RE.search(text)
    if signer_match is None or at_match is None:
        out.report(
            "pre-standard-doc", doc, None,
            f"no `signer::`/`at::` header; {len(TOKEN_RE.findall(text))} "
            "grade tokens are countable but not extractable",
        )
        return
    signer = parse_signer(signer_match.group(1))
    if signer is None:
        out.report("bad-header", doc, None,
                   f"signer kind not in {sorted(SIGNER_KINDS)}: "
                   f"`{signer_match.group(1)}`")
        return
    anchor = at_match.group(1)
    last_source: list[str] = []
    last_marker: str | None = None
    # Held until the whole document has been read: whether an unmarked
    # assertion is a defect depends on whether THIS document grades anything,
    # and that is not known at the paragraph where the assertion is written.
    unmarked: list[str] = []
    grades_its_claims = False

    for block in paragraphs(text):
        if block.startswith("#"):
            last_marker = None  # a heading is a section boundary: no
            continue            # attribution crosses it
        marker_match = MARKER_RE.match(block)
        if marker_match is None:
            report_unplaced(block, out, doc)
            report_orphaned_companions(block, out, doc, last_marker)
            if block.startswith("**"):
                # The bolded LEAD is the excerpt, not the test: an unclosed
                # `**` is still an assertion in the record's assertive form,
                # and matching on the closing pair would drop it unreported.
                lead = BOLD_LEAD_RE.match(block)
                unmarked.append(lead.group(1) if lead else block)
            continue
        marker, grade = marker_match.groups()
        last_marker = marker
        grades_its_claims = True
        node_id = f"{doc}:{marker}"
        rest = block[marker_match.end():]
        statement, companions = parse_node(rest, out, doc, marker, last_source)
        report_unplaced(rest, out, doc)

        if grade == "directive":
            entry = {"id": node_id, "statement": statement}
            if "provenance" in companions:
                entry["provenance"] = companions["provenance"]
            out.directives.append(entry)
            out.grades[node_id] = grade
            continue
        if grade not in GRADE_CELLS:
            out.report("unknown-grade", doc, marker,
                       f"grade::{grade} is not in the vocabulary; node dropped")
            continue

        assertion, backing = GRADE_CELLS[grade]
        entry = {
            "id": node_id,
            "statement": statement,
            "assertion": assertion,
            "backing": backing,
            "signer": signer,
        }
        if "check" in companions:
            # `ran` is unconditionally true here: the signer wrote this span
            # into a SIGNED record, and that authorship is itself the
            # attestation that the command ran (ruling AI13's correction —
            # no punctuation convention stands in for a signer's testimony).
            # The parser cannot observe a run and does not try to; a reader
            # who doubts a specific claim re-runs the named command.
            entry["check"] = {"command": companions["check"],
                              "ran": True, "at": anchor}
        if "source" in companions:
            entry["witness"] = {"name": companions["source"], "at": anchor}
        if "discharge" in companions:
            entry["discharge"] = companions["discharge"]
        if "closer" in companions:
            closer = parse_closer(companions["closer"])
            if closer is None:
                out.report("bad-closer", doc, marker,
                           "closer designation is not `kind[/name]` over "
                           f"{sorted(CLOSER_KINDS)}: `{companions['closer']}`")
            else:
                entry["closer"] = closer
        if "derives-from" in companions:
            external = out.attach_refs(entry, "because",
                                       companions["derives-from"], doc, marker,
                                       tagged=True)
            if external:
                entry.setdefault("because", []).extend(
                    {"kind": "external", "name": x} for x in external)
        if "axes" in companions:
            axes, residue = parse_axes(companions["axes"])
            if residue or not axes:
                out.report("bad-axes", doc, marker,
                           "axes:: expects +/- polarity tokens over "
                           f"{list(AXIS_ORDER)}: `{companions['axes']}`")
            if axes:
                entry["axes"] = axes
        if "freshness" in companions:
            entry["freshness"] = companions["freshness"]
        for token in CLOSURE_EDGES:
            if token not in companions:
                continue
            external = out.attach_refs(entry, token, companions[token],
                                       doc, marker)
            if external:
                # A closure edge onto something outside the corpus closes
                # nothing queryable, so unlike derives-from it is NOT
                # preserved as an external ref — that would file it where
                # provenance lives and quietly lose the closure.
                out.report("bad-edge", doc, marker,
                           f"`{token}::` takes bracketed ids, plain or "
                           f"qualified; cannot resolve {external}")
        if "tags" in companions:
            tags = parse_tags(companions["tags"])
            if tags:
                entry["tags"] = tags
            else:
                out.report("bad-tags", doc, marker,
                           f"tags:: expects one or more tokens: `{companions['tags']}`")
        out.entries.append(entry)
        out.grades[node_id] = grade

    report_unmarked_assertions(unmarked, out, doc, grades_its_claims)


def collect_files(args: list[str]) -> list[Path]:
    files: list[Path] = []
    for raw in args:
        path = Path(raw)
        if path.is_dir():
            files.extend(sorted(path.rglob("*.md")))
        elif path.is_file():
            files.append(path)
        else:
            raise FileNotFoundError(raw)
    return files


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("paths", nargs="+", help="graded markdown files or directories")
    parser.add_argument("--census", action="store_true",
                        help="print the published-census block for ONE file")
    parser.add_argument("-o", "--output", help="write the export here instead of stdout")
    opts = parser.parse_args()

    try:
        files = collect_files(opts.paths)
    except FileNotFoundError as err:
        print(f"extract_entries: no such file: {err}", file=sys.stderr)
        return 2

    if opts.census:
        if len(files) != 1:
            print("extract_entries: --census takes exactly one file", file=sys.stderr)
            return 2
        print(census(files[0].read_text(encoding="utf-8")))
        return 0

    out = Extraction()
    for path in files:
        extract_doc(path, out)
    resolve_qualified(out)

    export = {
        "entries": out.entries,
        "directives": out.directives,
        "grades": out.grades,
        "findings": out.findings,
    }
    rendered = json.dumps(export, indent=2, ensure_ascii=False) + "\n"
    if opts.output:
        Path(opts.output).write_text(rendered, encoding="utf-8")
    else:
        sys.stdout.write(rendered)

    for finding in out.findings:
        where = finding["doc"] + (f":{finding['marker']}" if finding["marker"] else "")
        print(f"extract_entries: {finding['kind']} at {where}: "
              f"{finding['reason']}", file=sys.stderr)
    if out.findings:
        print(f"extract_entries: {len(out.findings)} finding(s); "
              "the export is INCOMPLETE where they point", file=sys.stderr)
        return 3
    return 0


if __name__ == "__main__":
    sys.exit(main())
