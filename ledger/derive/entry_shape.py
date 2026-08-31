#!/usr/bin/env python3
"""Print an entry's field shape, and flag which attributes are computed.

The record is fully queryable with `jq` over the extracted corpus
(ledger/derive/extract_entries.py's JSON output) or over an entries_query
result -- but nothing tells a walk the SHAPE, so it reaches for `grep`
instead, or guesses wrong when it does reach for `jq`. Two measured mistakes
from one session (both from guessing, neither from reading the law):

  * `closer` is a RECORD `{kind, name}`, not a string. `.closer=="human"`
    silently returns 0 -- the correct form is `.closer.kind=="human"`.
  * Openness is NOT A FIELD. It is a fold over every `discharges`/
    `supersedes` edge in the whole corpus (ledger/contracts/entries_query.ncl's
    exported `is_open`). Filtering questions by `closer` alone over the real
    corpus returned 76; openness-aware filtering returned 61 -- the extra
    fifteen were already answered, and nothing on THEM says so.

This tool closes the gap the smallest way that stops the next guess: it
DERIVES the STORED shape from the live `Entry` record in entry.ncl (via
`nickel query`, never a hand-copied field list -- a field entry.ncl adds
tomorrow shows up here without this file being touched), and DERIVES the
COMPUTED view names by actually running entries_query_apply.ncl over a
trivial empty corpus and reading its real output keys. Nothing here is
project-specific data: entry.ncl and entries_query.ncl are predicate's own
shipped contracts, identical in every project that installs it, so this
walks correctly against any project's `.ledger` without an argument -- the
prior tag-registry mistake (ruling: the registry is project-local data, not
universal law) is the reason this tool is checked against exactly that
question before being written: nothing here is corpus CONTENT, only corpus
SHAPE.

Usage: entry_shape.py [--json]
Exit:  0 = shape printed. 2 = nickel unavailable or a contract file missing.
"""
import json
import os
import subprocess
import sys

HERE = os.path.dirname(os.path.realpath(__file__))
CONTRACTS = os.path.normpath(os.path.join(HERE, "..", "contracts"))
ENTRY_NCL = os.path.join(CONTRACTS, "entry.ncl")
QUERY_APPLY_NCL = os.path.join(CONTRACTS, "entries_query_apply.ncl")

# Record-shaped contracts entry.ncl names for a field's TYPE and ALSO defines
# as one of its own top-level fields -- these are the ones worth drilling
# into one level, so a nested shape like Closer's {kind, name} is shown
# rather than just the bare name "Closer". Anything a field's contract names
# that is NOT in this set (NonEmptyString, Assertion, Backing, CommitRef,
# SignerKind, CloserKind, RefKind, Ref, FreshnessValue, TagName, Array X) is
# either a scalar/enum contract or an opaque custom predicate with no static
# sub-shape `nickel query` can report -- printed as a bare type name.
_RECORD_FIELDS = {"Signer", "Closer", "Check", "Witness", "Axes", "Freshness", "ProvenanceRef"}


def nq(field, source=ENTRY_NCL):
    """`nickel query --field <field> --format json <source>`, parsed."""
    try:
        out = subprocess.run(
            ["nickel", "query", "--field", field, "--format", "json", source],
            capture_output=True,
            text=True,
            timeout=30,
        )
    except FileNotFoundError:
        print("entry_shape: nickel not on PATH", file=sys.stderr)
        sys.exit(2)
    if out.returncode != 0:
        return None
    try:
        return json.loads(out.stdout)
    except json.JSONDecodeError:
        return None


def entry_fields():
    """Entry's own field list, in entry.ncl's declared order -- read off
    nickel's `sub_fields`, which preserves it (unlike a Python dict built
    from --field listings, which nickel query itself already sorts)."""
    meta = nq("Entry")
    if meta is None or "sub_fields" not in meta:
        print(f"entry_shape: could not query Entry from {ENTRY_NCL}", file=sys.stderr)
        sys.exit(2)
    return meta["sub_fields"]


def field_shape(path):
    """One field's {optional, type, subfields}. `type` is the joined
    contract name(s) nickel reports; `subfields` is populated (one level)
    only when the type names something in _RECORD_FIELDS."""
    meta = nq(f"Entry.{path}")
    if meta is None:
        return {"optional": None, "type": "?", "subfields": None}
    optional = meta.get("optional", False)
    contracts = meta.get("contracts") or []
    type_name = " & ".join(contracts) if contracts else "(inline record)"
    subfields = None
    bare = type_name.replace("Array ", "")
    if bare in _RECORD_FIELDS:
        nested = nq(bare)
        if nested and "sub_fields" in nested:
            subfields = []
            for sub in nested["sub_fields"]:
                sub_meta = nq(f"{bare}.{sub}", source=ENTRY_NCL)
                sub_type = " & ".join((sub_meta or {}).get("contracts") or []) or "?"
                subfields.append(
                    {
                        "name": sub,
                        "type": sub_type,
                        "optional": (sub_meta or {}).get("optional", False),
                    }
                )
    return {"optional": optional, "type": type_name, "subfields": subfields}


def stored_shape():
    return {name: field_shape(name) for name in entry_fields()}


def computed_views():
    """The real, live output-key set of entries_query_apply.ncl's Views
    contract, derived by actually RUNNING it over a trivial empty corpus --
    not a hand-maintained list. `with_tags` is excluded from this set by
    construction (a `not_exported` function field never reaches JSON, per
    entries_query.ncl's own header comment) and reported separately below."""
    try:
        out = subprocess.run(
            ["nickel", "export", "--apply-contract", QUERY_APPLY_NCL],
            input="{ entries = [] }",
            capture_output=True,
            text=True,
            timeout=30,
        )
    except FileNotFoundError:
        print("entry_shape: nickel not on PATH", file=sys.stderr)
        sys.exit(2)
    if out.returncode != 0:
        print(
            f"entry_shape: could not run {QUERY_APPLY_NCL} over an empty corpus:\n{out.stderr}",
            file=sys.stderr,
        )
        sys.exit(2)
    try:
        return sorted(json.loads(out.stdout).keys())
    except json.JSONDecodeError:
        print(f"entry_shape: non-JSON output from {QUERY_APPLY_NCL}", file=sys.stderr)
        sys.exit(2)


VIEW_NOTES = {
    "awaiting_human": "OPEN questions whose closer.kind == human",
    "chain_floor": "per-claim support bottoms (closed/unbacked/external)",
    "dependents_of": "per-claim transitive dependents -- chain_floor's dual",
    "impeachment_queue": "refutations rows colliding with a CLOSED target",
    "refutations": "{refutation, target, species} -- species is COMPUTED per row, never authored",
    "runnable_now": "OPEN questions graded dispatchable (the extractor's grades sidecar)",
    "unbacked": "unclosed claims and their inbound edges",
    "unpaid_cures": "{violations, unassessed} -- non-monotone claims missing their T3 cure",
    "untagged": "entries carrying no tags at all",
}

WITH_TAGS_NOTE = (
    "a function field (`not_exported`) -- NEVER appears in plain --apply-contract "
    "JSON output. Reached only inside a small generated Nickel expression "
    "(`corpus | (import entries_query_apply.ncl) |> .with_tags [...]`) -- see "
    "entries_query.ncl's own header for the exact invocation shape."
)

IS_OPEN_NOTE = (
    "NOT A FIELD on any stored entry. An entry's openness is a fold over every "
    "OTHER entry's discharges/supersedes edges in the WHOLE corpus "
    "(entries_query.ncl's exported `is_open`). An answered entry's own record "
    "carries no marker saying so -- filtering by `closer` or `discharge` alone "
    "answers a different question than filtering by openness."
)


def render_text(stored, views):
    subfield_names = [
        sub["name"] for shape in stored.values() if shape["subfields"] for sub in shape["subfields"]
    ]
    subfield_types = [
        sub["type"] for shape in stored.values() if shape["subfields"] for sub in shape["subfields"]
    ]
    name_w = max([len(n) for n in stored] + [len(n) + 1 for n in subfield_names])
    type_w = max([len(shape["type"]) for shape in stored.values()] + [len(t) for t in subfield_types])
    view_w = max([len(n) for n in views] + [len("is_open"), len("with_tags")])

    lines = []
    lines.append(
        "STORED -- fields on an extracted/authored entry (entry.ncl's Entry "
        "record; what extract_entries.py emits and what `jq` sees):"
    )
    lines.append("")
    for name, shape in stored.items():
        req = "required" if not shape["optional"] else "optional"
        lines.append(f"  {name:<{name_w}} {shape['type']:<{type_w}} {req}")
        if shape["subfields"]:
            for sub in shape["subfields"]:
                sreq = "required" if not sub["optional"] else "optional"
                lines.append(f"    .{sub['name']:<{name_w - 1}} {sub['type']:<{type_w}} {sreq}")
    lines.append("")
    lines.append(
        "COMPUTED -- never a field on a stored entry; derived at QUERY TIME "
        "over the WHOLE corpus by ledger/contracts/entries_query_apply.ncl "
        "(the live output keys, run over an empty corpus -- not a hand-"
        "maintained list):"
    )
    lines.append("")
    lines.append(f"  {'is_open':<{view_w}} {IS_OPEN_NOTE}")
    for name in views:
        note = VIEW_NOTES.get(name, "")
        lines.append(f"  {name:<{view_w}} {note}")
    lines.append(f"  {'with_tags':<{view_w}} {WITH_TAGS_NOTE}")
    return "\n".join(lines)


def main(argv):
    stored = stored_shape()
    views = computed_views()
    if "--json" in argv:
        json.dump(
            {
                "stored": stored,
                "computed": {
                    "is_open": IS_OPEN_NOTE,
                    "views": {name: VIEW_NOTES.get(name, "") for name in views},
                    "with_tags": WITH_TAGS_NOTE,
                },
            },
            sys.stdout,
            indent=2,
        )
        print()
    else:
        print(render_text(stored, views))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
