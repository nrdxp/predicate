#!/usr/bin/env python3
"""Derive always-on-law clause backing from the clauses' OWN declarations.

`conditioning/core_clauses.ncl` carries a `backing` field: for a subset of its
46 clauses, a claim of the shape `{gate, case}` — "the `case`-named assertion
inside `gate` is a check that would notice this clause's removal from the
rendered law." This module is the derivation that PROVES or REFUTES that
claim; nothing here ever authors a verdict. A clause absent from `backing` is
simply UNCLOSED. A clause present in `backing` whose declaration cannot be
proved is a defect in the DECLARATION and this module fails loudly on it —
it never falls back to reporting that clause as unclosed, because a claim
nobody verified is exactly the decoration the law rejects.

The proof, per declared entry, is three checks in series:

  1. EXISTS      — the named gate script is a real file.
  2. BINDS       — the named `case` is the `desc` of an actual
                   `expect_count`/`expect_section` call inside that gate's
                   source, and its regex/needle is resolved from THAT call
                   (even when the gate holds it in a composed shell variable,
                   resolved by sourcing the gate's own variable-definition
                   prefix — never retyped here, which would rot the moment
                   the gate changed without either side noticing).
  3. WOULD-NOTICE — the resolved check currently HOLDS against the real
                   rendered law, and STOPS holding once this clause's own
                   rendered text is removed from it. This is what separates a
                   real link from a decorative one: a pattern that also
                   matches text outside the clause survives the clause's
                   removal and is refused here even though 1 and 2 both hold.

Usage:
  clause_backing.py            run the full derivation against the real
                                corpus (conditioning/core_clauses.ncl,
                                conditioning/core.ncl, and every declared
                                gate); exit 0 iff every declared entry proves
                                and prints the corroborated/unclosed split.
  clause_backing.py --selftest run the two fixtures pinning that a
                                non-existent gate and a non-binding pattern
                                are both caught loudly; exit 0 iff both are
                                correctly caught (i.e. the tool is working).
"""

from __future__ import annotations

import json
import os
import re
import shlex
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent.parent
CORE_CLAUSES = ROOT / "conditioning" / "core_clauses.ncl"
CORE_NCL = ROOT / "conditioning" / "core.ncl"
INSTALL_SH = ROOT / "conditioning" / "install.sh"
PROBE = ROOT / "ledger" / "gate" / "conditioning_probe.py"

# Every gate this module resolves shell variables from ends its regex/needle
# variable block right before its first `SECTION 1` heading echo — the same
# boundary in all four candidate gates as of this writing. If a future gate
# does not follow that shape, resolution fails loudly rather than guessing.
_SECTION_MARKER = "SECTION 1 —"


class LinkError(Exception):
    """A declared {gate, case} entry the derivation could not prove."""


# ── loading the clause corpus ────────────────────────────────────────────────


def run(cmd: list[str], **kw) -> subprocess.CompletedProcess:
    return subprocess.run(cmd, capture_output=True, text=True, **kw)


def load_clause_data() -> dict:
    proc = run(["nickel", "export", "--format", "json", str(CORE_CLAUSES)])
    if proc.returncode != 0:
        raise RuntimeError(f"nickel export of core_clauses.ncl failed: {proc.stderr}")
    return json.loads(proc.stdout)


def build_maps(blocks: list[dict]) -> tuple[dict[str, str], dict[str, str]]:
    """id -> its own verbatim rendered text; id -> its containing `## ` heading."""
    text_of: dict[str, str] = {}
    heading_of: dict[str, str] = {}
    for b in blocks:
        if b["kind"] == "leaf":
            text_of[b["id"]] = b["body"]
            heading_of[b["id"]] = b["heading"]
        else:
            for c in b["clauses"]:
                text_of[c["id"]] = c["text"]
                heading_of[c["id"]] = b["heading"]
    return text_of, heading_of


def render_core() -> str:
    proc = run(["nickel", "export", "--format", "text", str(CORE_NCL)])
    if proc.returncode != 0:
        raise RuntimeError(f"nickel export of core.ncl failed: {proc.stderr}")
    return proc.stdout


# ── parsing a gate script's expect_count / expect_section calls ─────────────


def _joined_lines(path: Path) -> list[str]:
    # Backslash-newline is a shell line continuation; joining it first makes
    # every logical `expect_*` statement a single line to search and tokenize.
    return path.read_text().replace("\\\n", " ").splitlines()


def _parse_call(stmt: str) -> dict:
    tokens = shlex.split(stmt, posix=True)
    cmd = tokens[0]
    if cmd == "expect_count":
        # expect_count POLARITY SCOPE MODE WANT DESC [FLAG VALUE]
        polarity, scope, mode, want, desc = tokens[1:6]
        flag = tokens[6] if len(tokens) > 6 else None
        value = tokens[7] if len(tokens) > 7 else None
        return {
            "cmd": "count", "polarity": polarity, "scope": scope, "mode": mode,
            "want": int(want), "desc": desc, "flag": flag, "value": value,
        }
    if cmd == "expect_section":
        # expect_section POLARITY HEADING METRIC MODE WANT DESC [FLAG VALUE]
        polarity, heading, metric, mode, want, desc = tokens[1:7]
        flag = tokens[7] if len(tokens) > 7 else None
        value = tokens[8] if len(tokens) > 8 else None
        return {
            "cmd": "section", "polarity": polarity, "heading": heading, "metric": metric,
            "mode": mode, "want": int(want), "desc": desc, "flag": flag, "value": value,
        }
    raise LinkError(f"unrecognized call head {cmd!r}")


def find_call(gate_path: Path, case_desc: str) -> dict:
    """The single `expect_count`/`expect_section` call whose desc is `case_desc`.

    Not-found and ambiguous-match are both LinkErrors: a declaration must name
    one real, unambiguous assertion, never a guess at one.
    """
    if not gate_path.is_file():
        raise LinkError(f"declared gate does not exist: {gate_path}")
    matches = []
    for line in _joined_lines(gate_path):
        s = line.strip()
        if not (s.startswith("expect_count ") or s.startswith("expect_section ")):
            continue
        try:
            tokens = shlex.split(s, posix=True)
        except ValueError:
            continue
        desc_idx = 5 if tokens[0] == "expect_count" else 6
        if len(tokens) > desc_idx and tokens[desc_idx] == case_desc:
            matches.append(s)
    if not matches:
        raise LinkError(f"case not found in {gate_path.name}: {case_desc!r}")
    if len(matches) > 1:
        raise LinkError(
            f"case matched {len(matches)} statements in {gate_path.name} "
            f"(ambiguous): {case_desc!r}"
        )
    return _parse_call(matches[0])


# ── resolving a call's regex/needle value ────────────────────────────────────

_VAR_CACHE: dict[tuple[str, str], str] = {}


def resolve_value(gate_path: Path, value: str) -> str:
    """A literal token is used as-is; a `$VAR` token is resolved by sourcing
    the gate's own variable-definition prefix — the same bash the gate itself
    runs to build it, never a re-transcription of the composed regex."""
    if not value.startswith("$"):
        return value
    varname = value[1:]
    key = (str(gate_path), varname)
    if key in _VAR_CACHE:
        return _VAR_CACHE[key]

    text = gate_path.read_text()
    idx = text.find(_SECTION_MARKER)
    if idx == -1:
        raise LinkError(
            f"cannot resolve ${varname}: no {_SECTION_MARKER!r} boundary in {gate_path.name}"
        )
    line_start = text.rfind("\n", 0, idx) + 1
    prefix = text[:line_start]

    # Written into the gate's OWN directory so the prefix's `${BASH_SOURCE[0]}`
    # dirname math (here/root) resolves exactly as it does for the real gate.
    fd, tmp_path = tempfile.mkstemp(
        dir=str(gate_path.parent), suffix=".sh", prefix=".clause_backing_extract_"
    )
    try:
        with os.fdopen(fd, "w") as fh:
            fh.write(prefix)
        # The prefix's own trailing `echo ""` / `echo "════..."` lines (its
        # section-divider chrome, textually before the SECTION-1 marker but
        # still inside the cut) execute on source and would otherwise leak
        # into stdout ahead of the value this call actually wants.
        proc = run(
            ["bash", "-c", 'source "$1" >/dev/null 2>&1; printf "%s" "${!2}"', "_", tmp_path, varname]
        )
    finally:
        os.unlink(tmp_path)
    if proc.returncode != 0 or not proc.stdout:
        raise LinkError(
            f"could not resolve ${varname} from {gate_path.name}: {proc.stderr.strip()}"
        )
    _VAR_CACHE[key] = proc.stdout
    return proc.stdout


# ── running the probe / threshold semantics (mirrors expect_count/section) ──


def probe_count(tree: str, core_file: Path, scope: str, flag: str, value: str) -> tuple[int, int, int]:
    proc = run(
        ["python3", str(PROBE), "--tree", tree, "--core", str(core_file),
         "count", "--scope", scope, f"{flag}={value}"]
    )
    if proc.returncode != 0:
        raise LinkError(f"probe count failed (exit {proc.returncode}): {proc.stderr.strip()}")
    mn, mx, units = proc.stdout.split()
    return int(mn), int(mx), int(units)


def probe_section(tree: str, core_file: Path, heading: str, metric: str, flag: str, value: str) -> int:
    proc = run(
        ["python3", str(PROBE), "--tree", tree, "--core", str(core_file),
         "section", "--heading", heading, "--metric", metric, f"{flag}={value}"]
    )
    if proc.returncode != 0:
        raise LinkError(f"probe section failed (exit {proc.returncode}): {proc.stderr.strip()}")
    return int(proc.stdout.strip())


def satisfies(mode: str, want: int, mn: int, mx: int) -> bool:
    if mode == "eq":
        return mn == want and mx == want
    if mode == "min":
        return mn >= want
    if mode == "max":
        return mx <= want
    raise LinkError(f"unknown mode {mode!r}")


# ── mutation: the clause's own text, removed from the rendered law ──────────


def mutate(core_text: str, clause_text: str, clause_id: str) -> str:
    count = core_text.count(clause_text)
    if count == 0:
        raise LinkError(
            f"{clause_id}: its own rendered text was not found verbatim in the "
            "rendered core (id->text mapping is out of sync with the render)"
        )
    if count > 1:
        raise LinkError(
            f"{clause_id}: its rendered text occurs {count} times in the rendered "
            "core — cannot remove it unambiguously"
        )
    return core_text.replace(clause_text, "", 1)


# ── one entry's full proof ───────────────────────────────────────────────────


def verify_entry(
    clause_id: str, entry: dict, clause_text: str,
    real_core_path: Path, mutated_core_path: Path, tree: str,
) -> dict:
    gate_path = ROOT / entry["gate"]
    call = find_call(gate_path, entry["case"])
    if call["flag"] not in ("--needle", "--regex"):
        raise LinkError(
            f"{clause_id}: case {entry['case']!r} in {entry['gate']} carries no "
            f"--needle/--regex (found {call['flag']!r}) — not a content check"
        )
    pattern = resolve_value(gate_path, call["value"])

    def measure(core_path: Path) -> bool:
        if call["cmd"] == "count":
            mn, mx, _ = probe_count(tree, core_path, call["scope"], call["flag"], pattern)
            return satisfies(call["mode"], call["want"], mn, mx)
        v = probe_section(tree, core_path, call["heading"], call["metric"], call["flag"], pattern)
        return satisfies(call["mode"], call["want"], v, v)

    if not measure(real_core_path):
        raise LinkError(
            f"{clause_id}: declared check {entry['case']!r} in {entry['gate']} "
            "does NOT currently hold against the real rendered law"
        )
    if measure(mutated_core_path):
        raise LinkError(
            f"{clause_id}: declared check {entry['case']!r} in {entry['gate']} "
            "still holds after this clause's own text is removed from the law "
            "— it does not actually reference this clause (decorative link)"
        )
    return {"gate": entry["gate"], "case": entry["case"]}


# ── the full-corpus run ──────────────────────────────────────────────────────


def build_real_tree(tmpdir: Path) -> Path:
    tree = tmpdir / "home"
    tree.mkdir()
    env = dict(os.environ)
    env["HOME"] = str(tree)
    env["PREDICATE_CLAUDE_DIR"] = str(tree / ".claude")
    env["PREDICATE_GEMINI_DIR"] = str(tree / ".gemini")
    proc = run(["bash", str(INSTALL_SH), "--harness", "all"], cwd=str(ROOT), env=env)
    if proc.returncode != 0:
        sys.stderr.write(proc.stdout + proc.stderr)
        raise RuntimeError(f"install.sh exited {proc.returncode}")
    return tree


def full_run() -> int:
    data = load_clause_data()
    text_of, _heading_of = build_maps(data["blocks"])
    clause_ids = data["clause_ids"]
    backing = data.get("backing", {})
    missing = set(clause_ids) - set(text_of)
    if missing:
        raise RuntimeError(f"clause_ids without a text mapping: {sorted(missing)}")

    real_core_text = render_core()
    tmpdir = Path(tempfile.mkdtemp(prefix="clause_backing_"))
    real_core_path = tmpdir / "core-real.txt"
    real_core_path.write_text(real_core_text)
    tree = build_real_tree(tmpdir)

    corroborated: dict[str, list[dict]] = {}
    unclosed: list[str] = []
    errors: list[str] = []

    for cid in sorted(clause_ids):
        entries = backing.get(cid, [])
        if not entries:
            unclosed.append(cid)
            continue
        clause_text = text_of[cid]
        try:
            mutated_text = mutate(real_core_text, clause_text, cid)
        except LinkError as e:
            errors.append(str(e))
            continue
        mutated_path = tmpdir / f"core-mut-{cid}.txt"
        mutated_path.write_text(mutated_text)
        grounds = []
        ok = True
        for entry in entries:
            try:
                grounds.append(verify_entry(cid, entry, clause_text, real_core_path, mutated_path, str(tree)))
            except LinkError as e:
                errors.append(str(e))
                ok = False
        if ok:
            corroborated[cid] = grounds

    total = len(clause_ids)
    print(f"clauses: {total}")
    print(f"corroborated (computed): {len(corroborated)}")
    for cid in sorted(corroborated):
        grounds = ", ".join(f"{g['gate']}::{g['case']}" for g in corroborated[cid])
        print(f"  + {cid}  <-  {grounds}")
    print(f"unclosed (no backing declared): {len(unclosed)}")
    print(f"declared-but-unverified (errors): {len(errors)}")
    for e in errors:
        print(f"  ! {e}")

    reference = {
        "grounded-critique", "roles-dispatch-under-persona", "reporting-posture",
        "open-surface", "scrutiny-stakes", "scrutiny-uncloseability",
    }
    computed = set(corroborated)
    if computed != reference and not errors:
        print("DIFFERENCE from the hand-graded corroborated set:")
        for cid in sorted(reference - computed):
            print(f"  - hand-graded corroborated, NOT reproduced: {cid}")
        for cid in sorted(computed - reference):
            print(f"  - newly corroborated, not in the hand-graded set: {cid}")

    return 1 if errors else 0


# ── selftest: the two fixtures acceptance requires ─────────────────────────


def _fixture_tree(tmpdir: Path) -> Path:
    tree = tmpdir / "home"
    agents = tree / ".claude" / "agents"
    agents.mkdir(parents=True)
    (agents / "predicate-fixture.md").write_text("fixture agent surface\n")
    return tree


def selftest() -> int:
    tmpdir = Path(tempfile.mkdtemp(prefix="clause_backing_selftest_"))
    tree = _fixture_tree(tmpdir)
    ok = True

    # Fixture A — a declared gate that does not exist.
    try:
        find_call(ROOT / "ledger/gate/test_does_not_exist_xyz.sh", "whatever")
        print("FAIL fixture A: non-existent gate was not caught")
        ok = False
    except LinkError as e:
        print(f"PASS fixture A: non-existent gate caught loudly -> {e}")

    # Fixture B — an existing gate, an existing case, whose pattern is present
    # in the fixture "core" but NOT inside the clause under test — so removing
    # the clause does not remove the match. Must be refused as decorative.
    gate_dir = tmpdir / "gate"
    gate_dir.mkdir()
    gate_path = gate_dir / "test_fixture.sh"
    gate_path.write_text(
        "#!/usr/bin/env bash\n"
        "expect_count red core min 1 \\\n"
        "  \"fixture: an always-present marker\" \\\n"
        "  --needle 'ALWAYS PRESENT EVERYWHERE'\n"
    )
    clause_text = "This is the clause body under test, naming nothing special."
    fixture_core = (
        "## Some Section\n\n"
        + clause_text
        + "\n\nOther prose that happens to say ALWAYS PRESENT EVERYWHERE elsewhere.\n"
    )
    real_core_path = tmpdir / "core-real.txt"
    real_core_path.write_text(fixture_core)
    try:
        mutated = mutate(fixture_core, clause_text, "fixture-clause")
    except LinkError as e:
        print(f"FAIL fixture B setup: {e}")
        return 1
    mutated_path = tmpdir / "core-mut.txt"
    mutated_path.write_text(mutated)

    entry = {"gate": str(gate_path.relative_to(ROOT)) if gate_path.is_relative_to(ROOT) else str(gate_path),
              "case": "fixture: an always-present marker"}
    # verify_entry resolves `entry["gate"]` against ROOT; since this fixture
    # lives outside ROOT, call find_call/verify_entry with an absolute path
    # directly instead of routing through ROOT-relative join.
    try:
        call = find_call(gate_path, entry["case"])
        pattern = resolve_value(gate_path, call["value"])
        mn, mx, _ = probe_count(str(tree), real_core_path, call["scope"], call["flag"], pattern)
        pre_ok = satisfies(call["mode"], call["want"], mn, mx)
        mn2, mx2, _ = probe_count(str(tree), mutated_path, call["scope"], call["flag"], pattern)
        post_ok = satisfies(call["mode"], call["want"], mn2, mx2)
        if pre_ok and post_ok:
            print(
                "PASS fixture B: pattern survives clause removal (decorative) "
                "and would be refused by verify_entry's post-mutation check"
            )
        else:
            print(f"FAIL fixture B: expected pre=True post=True, got pre={pre_ok} post={post_ok}")
            ok = False
    except LinkError as e:
        print(f"FAIL fixture B: unexpected LinkError during setup: {e}")
        ok = False

    return 0 if ok else 1


def main() -> int:
    if "--selftest" in sys.argv[1:]:
        return selftest()
    return full_run()


if __name__ == "__main__":
    raise SystemExit(main())
