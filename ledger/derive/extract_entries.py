#!/usr/bin/env python3
"""Extract typed-claim entries from graded prose into the contract's shape.

The prose record is the SOURCE; this export is DERIVED and regenerated, never
maintained. The output is JSON (a YAML subset nickel imports either way):

    {entries, directives, grades, external_refs, findings}

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
              map to fields; conversion-path is recognized prose and stays in
              the statement; anything else token-shaped is reported.
  refs        derives-from carries doc-local `[ID]` refs (edges), `[[wiki]]`
              refs and free prose (external provenance — outside the corpus,
              so never emitted as edges the contract would reject as dangling).
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
MARKER_RE = re.compile(r"^\s*(?:-\s+)?`\[([A-Za-z][A-Za-z0-9-]*)\]\s+grade::([a-z]+)`\s*")
SPAN_RE = re.compile(r"`([^`]+)`")
COMPANION_RE = re.compile(r"^([a-z][a-z-]*)::\s*(.*)$", re.DOTALL)
WIKILINK_RE = re.compile(r"\[\[([^\]]+)\]\]")
BRACKET_REF_RE = re.compile(r"\[([A-Za-z][A-Za-z0-9-]*)\]")
# a source/derives-from value continues past its span as `, [[wiki]]` segments
CONTINUATION_RE = re.compile(r"^\s*,?\s*(?:`(\[\[[^\]]+\]\])`|(\[\[[^\]]+\]\]))")
SIGNER_RE = re.compile(r"`signer::\s*([^`]+)`")
AT_RE = re.compile(r"`at::\s*([0-9a-f]{7,40})`")

MAPPED = {"check", "source", "derives-from", "discharge", "closer", "provenance"}
RECOGNIZED = MAPPED | {"conversion-path", "signer", "at", "grade"}
SIGNER_KINDS = {"human", "agent", "source", "derived", "unattributed"}


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
class Extraction:
    entries: list[dict] = field(default_factory=list)
    directives: list[dict] = field(default_factory=list)
    grades: dict[str, str] = field(default_factory=dict)
    external_refs: list[dict] = field(default_factory=list)
    findings: list[dict] = field(default_factory=list)

    def report(self, kind: str, doc: str, marker: str | None, reason: str) -> None:
        self.findings.append(
            {"kind": kind, "doc": doc, "marker": marker, "reason": reason}
        )


def parse_signer(raw: str) -> dict | None:
    kind, _, name = raw.strip().partition("/")
    if kind not in SIGNER_KINDS:
        return None
    return {"kind": kind, "name": name} if name else {"kind": kind}


def split_refs(value: str) -> tuple[list[str], list[str]]:
    """Partition a derives-from value into doc-local refs and external refs."""
    external = WIKILINK_RE.findall(value)
    remainder = WIKILINK_RE.sub("", value)
    local = BRACKET_REF_RE.findall(remainder)
    residue = BRACKET_REF_RE.sub("", remainder).strip(" ,;")
    if residue:
        external.append(residue)
    return local, external


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

    for block in paragraphs(text):
        if block.startswith("#"):
            last_marker = None  # a heading is a section boundary: no
            continue            # attribution crosses it
        marker_match = MARKER_RE.match(block)
        if marker_match is None:
            report_unplaced(block, out, doc)
            report_orphaned_companions(block, out, doc, last_marker)
            continue
        marker, grade = marker_match.groups()
        last_marker = marker
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
            entry["check"] = {"command": companions["check"], "ran": True,
                              "at": anchor}
        if "source" in companions:
            entry["witness"] = {"name": companions["source"], "at": anchor}
        if "discharge" in companions:
            entry["discharge"] = companions["discharge"]
        if "closer" in companions:
            entry["closer"] = companions["closer"]
        if "derives-from" in companions:
            local, external = split_refs(companions["derives-from"])
            if local:
                entry["because"] = [f"{doc}:{ref}" for ref in local]
            if external:
                out.external_refs.append({"entry": node_id, "refs": external})
        out.entries.append(entry)
        out.grades[node_id] = grade


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

    export = {
        "entries": out.entries,
        "directives": out.directives,
        "grades": out.grades,
        "external_refs": out.external_refs,
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
