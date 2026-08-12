#!/usr/bin/env python3
"""Measurement engine for the conditioning-discipline gate.

The gate that drives this (`test_conditioning_discipline.sh`) sweeps the
MATERIALIZED conditioning install, never the `.ncl` sources. A source grep
cannot see what composition duplicates or drops: a rule stated once in
`core.ncl` and once in a module is a single occurrence in each source file and
a DOUBLE carry in every prompt that pulls both. Sweeping the composed output
closes that gap by construction.

Two facts make the materialized tree measurable:

  * `compose.ncl` puts `core.ncl`'s text FIRST and verbatim in every role's
    prompt, so the rendered core is a contiguous substring of every surface.
    `verify-core` proves that, and every other subcommand relies on it.
  * A file's DELTA is therefore the file with that one core occurrence
    removed — the modules and the role persona, isolated from the always-on
    law. Presence measured on a delta cannot be satisfied by text living in
    core, which is what makes the "present at the rung AND absent from core"
    conjunction a real three-condition check rather than two restatements.

All matching runs on NORMALIZED text: unicode punctuation folded to ASCII and
whitespace collapsed to single spaces. Both are load-bearing. Folding stops a
check passing merely because prose uses an em dash where the needle used a
hyphen — an absence-by-grep check has already passed four separate hands in
this repository for exactly that reason. Collapsing lets a needle span a line
wrap, which every hard-wrapped rule in these prompts does.

Subcommands print to stdout and exit 0 on success; a usage or environment
fault exits 2. Assertion is the caller's job — this engine only measures.
"""

from __future__ import annotations

import argparse
import collections
import os
import re
import sys

# ── normalization ────────────────────────────────────────────────────────────

# Unicode punctuation the prompts use freely, folded to the ASCII a needle can
# be typed in. Anything not listed here is left alone: folding is for
# typographic variants of ASCII, never for semantic characters (⊂, ΔE, …).
_FOLD = {
    "—": "-",   # em dash
    "–": "-",   # en dash
    "‒": "-",   # figure dash
    "−": "-",   # minus sign
    "‘": "'",   # left single quote
    "’": "'",   # right single quote
    "‚": "'",
    "‛": "'",
    "“": '"',   # left double quote
    "”": '"',   # right double quote
    "„": '"',
    "…": "...",  # ellipsis
    "→": "->",  # rightwards arrow
    " ": " ",   # non-breaking space
}

_WS = re.compile(r"\s+")


def normalize(text: str) -> str:
    for src, dst in _FOLD.items():
        text = text.replace(src, dst)
    return _WS.sub(" ", text).strip()


# ── the materialized tree ────────────────────────────────────────────────────

_STYLE = os.path.join("output-styles", "predicate-composer.md")
_GEMINI = "GEMINI.md"


def load_tree(tree: str) -> "collections.OrderedDict[str, str]":
    """Map surface-label -> raw text for every materialized surface.

    Labels are the install's own vocabulary: `agent:<role>` for a persisted
    subagent, `style` for the output style, `gemini` for the agy surface.
    """
    surfaces: "collections.OrderedDict[str, str]" = collections.OrderedDict()
    agents_dir = os.path.join(tree, ".claude", "agents")
    if not os.path.isdir(agents_dir):
        fail(f"no agents directory under {tree} — was the install run?")
    for name in sorted(os.listdir(agents_dir)):
        if not name.startswith("predicate-") or not name.endswith(".md"):
            continue
        role = name[len("predicate-"):-len(".md")]
        surfaces[f"agent:{role}"] = read(os.path.join(agents_dir, name))
    style = os.path.join(tree, ".claude", _STYLE)
    if os.path.isfile(style):
        surfaces["style"] = read(style)
    gemini = os.path.join(tree, ".gemini", _GEMINI)
    if os.path.isfile(gemini):
        surfaces["gemini"] = read(gemini)
    if not surfaces:
        fail(f"no materialized surfaces found under {tree}")
    return surfaces


def read(path: str) -> str:
    with open(path, encoding="utf-8") as handle:
        return handle.read()


def fail(msg: str) -> "None":
    sys.stderr.write(f"conditioning_probe: {msg}\n")
    raise SystemExit(2)


# ── scopes ───────────────────────────────────────────────────────────────────
#
# A scope names a set of measurement UNITS. `core` is the rendered core law as
# a single unit; every `*-delta` scope is a set of surfaces with their core
# occurrence excised. The split is what lets one signature carry a DIFFERENT
# expected count per rung — `count == 1` universally is wrong here, because a
# seat prompt legitimately carries the deposits path from two segments.

_SEAT_SUFFIX = "-seat"
_REVIEWER_SUFFIX = "-reviewer"


def scope_units(scope: str, surfaces: dict, core: str) -> "list[tuple[str, str]]":
    """Return [(label, normalized text)] for the named scope."""
    ncore = normalize(core)

    def delta(label: str) -> str:
        text = normalize(surfaces[label])
        if text.count(ncore) != 1:
            fail(
                f"{label}: rendered core occurs {text.count(ncore)} times "
                "(expected exactly 1) — run verify-core"
            )
        return text.replace(ncore, " ")

    agents = [k for k in surfaces if k.startswith("agent:")]
    seats = [k for k in agents if k.endswith(_SEAT_SUFFIX)]
    reviewers = [k for k in agents if k.endswith(_REVIEWER_SUFFIX)]
    nonseat = [k for k in agents if not k.endswith(_SEAT_SUFFIX)]
    composer = [k for k in ("style", "gemini") if k in surfaces]

    if scope == "core":
        return [("core", ncore)]
    if scope == "surfaces":
        return [(k, normalize(v)) for k, v in surfaces.items()]
    groups = {
        "agents-delta": agents,
        "seats-delta": seats,
        "reviewers-delta": reviewers,
        "nonseat-delta": nonseat,
        "composer-delta": composer,
    }
    if scope not in groups:
        fail(f"unknown scope '{scope}'")
    labels = groups[scope]
    if not labels:
        fail(f"scope '{scope}' selected no surfaces")
    return [(label, delta(label)) for label in labels]


# ── subcommands ──────────────────────────────────────────────────────────────


def cmd_verify_core(args) -> int:
    """Prove the rendered core is a verbatim, single occurrence everywhere.

    This is the identity anchor for every other measurement: it is what makes
    "the core region" a property of the SHIPPED artifact rather than a claim
    about a source file.
    """
    surfaces = load_tree(args.tree)
    ncore = normalize(read(args.core))
    bad = []
    for label, text in surfaces.items():
        found = normalize(text).count(ncore)
        if found != 1:
            bad.append(f"{label}: core occurs {found}x")
    print(f"surfaces={len(surfaces)}")
    for line in bad:
        print(f"  MISMATCH {line}")
    return 1 if bad else 0


def _matcher(args):
    if args.regex is not None:
        pattern = re.compile(args.regex)
        return lambda text: len(pattern.findall(text))
    needle = normalize(args.needle)
    if not needle:
        fail("empty needle")
    return lambda text: text.count(needle)


def cmd_count(args) -> int:
    """Print `MIN MAX UNITS` for a signature over a scope.

    Reporting the range rather than a sum is deliberate: an expectation like
    "every seat prompt carries this exactly twice" is a statement about each
    unit, and a sum hides one surface at zero behind another at four.
    """
    surfaces = load_tree(args.tree)
    core = read(args.core)
    units = scope_units(args.scope, surfaces, core)
    count = _matcher(args)
    counts = [count(text) for _, text in units]
    print(f"{min(counts)} {max(counts)} {len(counts)}")
    if args.verbose:
        for (label, _), n in zip(units, counts):
            print(f"  {label}: {n}", file=sys.stderr)
    return 0


# Sentence boundary on normalized prose: a terminator followed by whitespace
# and an opening character, or end of text. The lookahead is what keeps
# `pre-1.0` and `.ledger/` from registering as sentence ends.
_SENTENCE_END = re.compile(r"[.!?](?:\s+(?=[A-Z*`\"(\[])|\s*$)")


def _section(core_text: str, heading: str) -> "list[str]":
    """Return the raw lines of the `## <heading>...` section, heading first."""
    lines = core_text.splitlines()
    start = None
    for index, line in enumerate(lines):
        if line.startswith("## ") and normalize(line[3:]).startswith(normalize(heading)):
            start = index
            break
    if start is None:
        fail(f"section '## {heading}' not found in the rendered core")
    end = len(lines)
    for index in range(start + 1, len(lines)):
        if lines[index].startswith("## "):
            end = index
            break
    return lines[start:end]


def cmd_section(args) -> int:
    """Print one integer measuring a core section.

    `sentences` and `body-lines` encode the audit's two tightening criteria
    directly — "exactly two sentences survive", "this rule is 2 lines, not 5"
    — so the gate asserts the ruling rather than a proxy for it.
    """
    core_text = read(args.core)
    section = _section(core_text, args.heading)
    body = section[1:]
    if args.metric == "body-lines":
        print(sum(1 for line in body if line.strip()))
    elif args.metric == "sentences":
        print(len(_SENTENCE_END.findall(normalize(" ".join(body)))))
    elif args.metric == "contains":
        if args.needle is None and args.regex is None:
            fail("--metric contains needs --needle or --regex")
        print(_matcher(args)(normalize(" ".join(body))))
    else:
        fail(f"unknown metric '{args.metric}'")
    return 0


# Word shingling for the unbounded half. Whole-sentence identity is the wrong
# grain for this property class and measurably finds nothing: core and a module
# state the same rule in different words, so they share a phrase, never a
# sentence. A k-word shingle shared between a prompt's core region and its own
# delta is a rule the walker reads twice in one prompt — the defect itself.
_WORD = re.compile(r"[a-z0-9][a-z0-9'/<>._-]*")


def _shingles(text: str, k: int) -> set:
    words = _WORD.findall(text.lower())
    return {tuple(words[i:i + k]) for i in range(len(words) - k + 1)}


def cmd_dupes(args) -> int:
    """Report every k-gram carried by BOTH the core region and a delta.

    Output is one `<surface-count>\\t<phrase>` line per shared shingle, sorted
    — exhaustive by construction over the whole materialized tree, with no
    signature enumerated in advance. That is the point of the unbounded half:
    it catches the duplication the enumerated half did not think to name.
    """
    surfaces = load_tree(args.tree)
    ncore = normalize(read(args.core))
    core_shingles = _shingles(ncore, args.k)
    hits: "collections.defaultdict[tuple, set]" = collections.defaultdict(set)
    for label, raw in surfaces.items():
        text = normalize(raw)
        if text.count(ncore) != 1:
            fail(f"{label}: rendered core occurs {text.count(ncore)}x — run verify-core")
        for shingle in core_shingles & _shingles(text.replace(ncore, " "), args.k):
            hits[shingle].add(label)
    for shingle in sorted(hits):
        print(f"{len(hits[shingle])}\t{' '.join(shingle)}")
    return 0


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--tree", required=True, help="temp HOME the install wrote to")
    parser.add_argument("--core", required=True, help="file holding the rendered core law")
    sub = parser.add_subparsers(dest="cmd", required=True)

    sub.add_parser("verify-core").set_defaults(func=cmd_verify_core)

    count = sub.add_parser("count")
    count.add_argument("--scope", required=True)
    count.add_argument("--needle")
    count.add_argument("--regex")
    count.add_argument("--verbose", action="store_true")
    count.set_defaults(func=cmd_count)

    section = sub.add_parser("section")
    section.add_argument("--heading", required=True)
    section.add_argument("--metric", required=True)
    section.add_argument("--needle")
    section.add_argument("--regex")
    section.set_defaults(func=cmd_section)

    dupes = sub.add_parser("dupes")
    dupes.add_argument("--k", type=int, default=5)
    dupes.set_defaults(func=cmd_dupes)

    args = parser.parse_args(argv)
    if getattr(args, "needle", None) is None and getattr(args, "regex", None) is None:
        if args.cmd == "count":
            fail("count needs --needle or --regex")
    return args.func(args)


if __name__ == "__main__":
    raise SystemExit(main())
