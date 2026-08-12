#!/usr/bin/env python3
"""Bind the prose grammar's documented vocabulary to the extractor's own.

docs/entries.md is the single home of the typed-claim vocabulary, and
ledger/derive/extract_entries.py is the grammar that reads it. Nothing has ever
held the two together: a companion token could be added to the extractor and
never reach the home, leaving an author unable to write an edge the machine
already accepts. That drift is mechanically decidable, so it is checked here
rather than carried in prose.

Two directions, because drift runs both ways:

  COVERAGE   every token the extractor MAPS to a field is named in the home as
             a backticked `<token>::` span. Failing this is the silent case —
             the machine grows a feature the vocabulary never mentions.
  VOCABULARY every backticked `<token>::` span in the home is RECOGNIZED by the
             extractor. Failing this is the loud case — the home documents a
             token that will be reported as unknown the moment an author uses
             it.

The extractor's sets are read by IMPORT, not by scraping its source: the check
must bind to the values the extractor actually runs on, so a set that is later
computed rather than written as a literal still lands here truthfully.

A backticked span with an empty value is a MENTION of the token, which is
exactly how a document names a token without using it — so the home's
enumeration is spans with or without values, matching the extractor's own
mention rule.

Usage: check_grammar_home.py [--doc PATH] [--extractor PATH]
Exit:  0 = the two agree, 1 = drift, 2 = environment error.
"""

from __future__ import annotations

import argparse
import importlib.util
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DOC = ROOT / "docs" / "entries.md"
EXTRACTOR = ROOT / "ledger" / "derive" / "extract_entries.py"

# A backticked span opening with a token name, value optional. This is the
# home's enumeration: `check:: <cmd>` uses the token, `check::` mentions it,
# and either one documents it.
SPAN_TOKEN_RE = re.compile(r"`([a-z][a-z-]*)::")

# `token` is the grammar's METAVARIABLE — the home writes `token:: value` to
# describe the companion span's shape. It names no companion, so it is the one
# span the vocabulary direction must not read as an invented token.
METAVARIABLE = "token"


def load_sets(path: Path) -> tuple[set[str], set[str]]:
    """Import the extractor and read its live MAPPED / RECOGNIZED sets."""
    spec = importlib.util.spec_from_file_location("extract_entries", path)
    if spec is None or spec.loader is None:
        raise ImportError(f"cannot load a module from {path}")
    module = importlib.util.module_from_spec(spec)
    # Registered BEFORE execution: the extractor's `@dataclass(slots=True)`
    # rebuilds its class and resolves `__module__` through sys.modules, which
    # fails on a module that is not yet there.
    sys.modules[spec.name] = module
    try:
        spec.loader.exec_module(module)
    except Exception as err:
        raise ImportError(f"{path} failed to import: {err}") from err
    try:
        return set(module.MAPPED), set(module.RECOGNIZED)
    except AttributeError as err:
        raise ImportError(f"{path} does not define MAPPED and RECOGNIZED") from err


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--doc", type=Path, default=DOC,
                        help="the vocabulary home (default: docs/entries.md)")
    parser.add_argument("--extractor", type=Path, default=EXTRACTOR,
                        help="the grammar (default: ledger/derive/extract_entries.py)")
    opts = parser.parse_args()

    for path in (opts.doc, opts.extractor):
        if not path.is_file():
            print(f"check_grammar_home: ENV: no such file: {path}", file=sys.stderr)
            return 2
    try:
        mapped, recognized = load_sets(opts.extractor)
    except (ImportError, SyntaxError) as err:
        print(f"check_grammar_home: ENV: {err}", file=sys.stderr)
        return 2

    documented = set(SPAN_TOKEN_RE.findall(opts.doc.read_text(encoding="utf-8")))

    undocumented = mapped - documented
    unrecognized = documented - recognized - {METAVARIABLE}

    if undocumented or unrecognized:
        print("check_grammar_home: FAIL — the grammar and its home disagree:",
              file=sys.stderr)
        for token in sorted(undocumented):
            print(f"  COVERAGE:   `{token}::` maps to a field in "
                  f"{opts.extractor.name} but {opts.doc.name} never names it — "
                  "an author cannot write what the home does not document",
                  file=sys.stderr)
        for token in sorted(unrecognized):
            print(f"  VOCABULARY: `{token}::` is documented in {opts.doc.name} "
                  f"but {opts.extractor.name} does not recognize it — an author "
                  "following the home would have the span reported as unknown",
                  file=sys.stderr)
        return 1

    print(f"check_grammar_home: PASS — all {len(mapped)} mapped token(s) are "
          f"documented, and all {len(documented)} documented token(s) are "
          "recognized")
    return 0


if __name__ == "__main__":
    sys.exit(main())
