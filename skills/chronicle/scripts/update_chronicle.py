#!/usr/bin/env python3
"""Prepare git history since the last cutoff and update docs/chronicle.md.

Two-step workflow:

  --prepare
      Print a batch of commits (oldest first) since the cutoff recorded in the
      chronicle frontmatter, along with a suggested TARGET_END_SHA for the batch.

  --write --end-sha SHA --summary TEXT
      Append the summary to docs/chronicle.md and advance the cutoff to SHA.
      The SHA is authoritative: it binds the recorded range to exactly the
      commits that were summarized, so the step is immune to HEAD moving
      between prepare and write.
"""

import argparse
import datetime
import subprocess
import sys
from pathlib import Path

BATCH_SIZE = 50


def get_git_root() -> Path:
    """Get the absolute path of the git root directory."""
    try:
        res = subprocess.run(
            ["git", "rev-parse", "--show-toplevel"],
            capture_output=True,
            text=True,
            check=True,
        )
        return Path(res.stdout.strip())
    except subprocess.SubprocessError:
        print("Error: Not a git repository.", file=sys.stderr)
        sys.exit(1)


def run_git(args: list[str]) -> str:
    """Run a git command and return its stdout, raising on a non-zero exit."""
    res = subprocess.run(["git"] + args, capture_output=True, text=True, check=True)
    return res.stdout


def git_ok(args: list[str]) -> bool:
    """Run a git command, returning True on exit 0 and False otherwise."""
    res = subprocess.run(["git"] + args, capture_output=True, text=True)
    return res.returncode == 0


def commit_exists(sha: str) -> bool:
    """Return True if sha resolves to an object in the repository."""
    return git_ok(["cat-file", "-e", f"{sha}^{{commit}}"])


def is_ancestor(ancestor: str, descendant: str) -> bool:
    """Return True if ancestor is reachable from descendant (inclusive)."""
    return git_ok(["merge-base", "--is-ancestor", ancestor, descendant])


def count_commits(range_str: str) -> int:
    """Count commits in a rev range (e.g. ``A..B``)."""
    return int(run_git(["rev-list", "--count", range_str]).strip() or "0")


def parse_frontmatter(content: str) -> tuple[dict[str, str], str]:
    """Parse simple YAML frontmatter manually to avoid PyYAML dependencies."""
    metadata = {}
    body = content
    if content.startswith("---"):
        parts = content.split("---", 2)
        if len(parts) >= 3:
            yaml_lines = parts[1].strip().splitlines()
            for line in yaml_lines:
                if ":" in line:
                    key, val = line.split(":", 1)
                    metadata[key.strip()] = val.strip()
            body = parts[2].lstrip()
    return metadata, body


def format_frontmatter(metadata: dict[str, str]) -> str:
    """Format metadata dict as YAML frontmatter."""
    lines = ["---"]
    for k, v in metadata.items():
        lines.append(f"{k}: {v}")
    lines.append("---")
    return "\n".join(lines) + "\n"


def resolve_cutoff(metadata: dict[str, str]) -> str | None:
    """Return the recorded cutoff SHA, or None if absent or no longer in history."""
    latest = metadata.get("latest_commit")
    if not latest:
        return None
    if not commit_exists(latest):
        print(
            f"Warning: recorded cutoff {latest[:8]} not found in history; "
            "treating the chronicle as uninitialized.",
            file=sys.stderr,
        )
        return None
    return latest


def cmd_prepare(cutoff: str | None) -> None:
    """Print the next batch of commits to summarize."""
    range_str = "HEAD" if cutoff is None else f"{cutoff}..HEAD"
    shas = run_git(["rev-list", "--reverse", range_str]).strip().splitlines()

    if not shas:
        print("Chronicle is already up to date with HEAD.")
        return

    batch = shas[:BATCH_SIZE]
    remaining = len(shas) - len(batch)

    print(f"Preparing {len(batch)} commits out of {len(shas)} pending commits.")
    if remaining > 0:
        print(f"Note: {remaining} commits will remain for future runs.")

    # --no-walk=unsorted preserves the command-line order (oldest first); plain
    # --no-walk re-sorts by commit date, which scrambles same-second commits.
    log_output = run_git(["log", "--stat", "--oneline", "--no-walk=unsorted"] + batch)
    print(f"--- START OF NEW COMMITS ({batch[0][:8]}..{batch[-1][:8]}) ---")
    print(log_output)
    print("--- END OF NEW COMMITS ---")
    print(f"TARGET_END_SHA:{batch[-1]}")


def cmd_write(
    chronicle_path: Path,
    content: str,
    metadata: dict[str, str],
    cutoff: str | None,
    end_sha: str,
    summary: str,
) -> None:
    """Append the summary and advance the cutoff to the resolved end_sha."""
    if not commit_exists(end_sha):
        print(f"Error: --end-sha {end_sha} is not a commit in this repository.", file=sys.stderr)
        sys.exit(1)
    full_end = run_git(["rev-parse", end_sha]).strip()

    if not is_ancestor(full_end, "HEAD"):
        print(f"Error: --end-sha {end_sha[:8]} is not reachable from HEAD.", file=sys.stderr)
        sys.exit(1)

    if cutoff is not None:
        if full_end == cutoff:
            print("Error: --end-sha equals the current cutoff; nothing to record.", file=sys.stderr)
            sys.exit(1)
        if not is_ancestor(cutoff, full_end):
            print(
                f"Error: --end-sha {end_sha[:8]} does not descend from the "
                f"current cutoff {cutoff[:8]}; re-run --prepare.",
                file=sys.stderr,
            )
            sys.exit(1)
        commit_range = f"{cutoff[:8]}..{full_end[:8]}"
    else:
        commit_range = f"Inception..{full_end[:8]}"

    _, body = parse_frontmatter(content)
    body = body.strip()
    if not body:
        body = (
            "# Project Chronicle\n\n"
            "This document tracks the conceptual evolution of the project.\n"
        )

    date_str = datetime.date.today().isoformat()
    body = f"{body}\n\n## [{date_str}] Commits: {commit_range}\n\n{summary.strip()}"

    metadata["latest_commit"] = full_end
    metadata["updated_at"] = datetime.datetime.now().isoformat()

    chronicle_path.parent.mkdir(parents=True, exist_ok=True)
    chronicle_path.write_text(format_frontmatter(metadata) + body + "\n")
    print(
        f"Successfully updated docs/chronicle.md with range {commit_range} "
        f"(cutoff: {full_end[:8]})"
    )

    remaining = count_commits(f"{full_end}..HEAD")
    if remaining > 0:
        print(
            f"Remaining pending commits: {remaining}. Run chronicle update again to continue."
        )


def main() -> None:
    parser = argparse.ArgumentParser(description="Chronicle Git Log Updater")
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument(
        "--prepare", action="store_true", help="Prepare logs since the last cutoff"
    )
    group.add_argument(
        "--write", action="store_true", help="Append summary and advance the cutoff"
    )
    parser.add_argument(
        "--end-sha",
        type=str,
        help="The TARGET_END_SHA from --prepare; the new cutoff (required with --write)",
    )
    parser.add_argument(
        "--summary", type=str, help="The conceptual summary text to write"
    )
    args = parser.parse_args()

    git_root = get_git_root()
    chronicle_path = git_root / "docs" / "chronicle.md"

    content = chronicle_path.read_text() if chronicle_path.exists() else ""
    metadata, _ = parse_frontmatter(content)
    cutoff = resolve_cutoff(metadata)

    if args.prepare:
        cmd_prepare(cutoff)
        return

    # --write
    missing = [name for name, val in (("--end-sha", args.end_sha), ("--summary", args.summary)) if not val]
    if missing:
        print(f"Error: {' and '.join(missing)} required when using --write.", file=sys.stderr)
        sys.exit(1)
    cmd_write(chronicle_path, content, metadata, cutoff, args.end_sha, args.summary)


if __name__ == "__main__":
    main()
