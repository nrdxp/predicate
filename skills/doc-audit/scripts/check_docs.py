#!/usr/bin/env python3
import os
import sys
import re
import urllib.request
import urllib.error

def slugify_heading(text):
    """GitHub-style heading slug.

    Lowercase, strip everything but word chars, spaces and hyphens, then map
    runs of spaces to single hyphens. Mirrors GitHub's anchor generation closely
    enough to resolve in-doc `#fragment` links. Inline markdown (links, emphasis,
    backticks) is reduced to its visible text before slugging so the slug matches
    what a reader sees.
    """
    # Reduce inline markdown to visible text: [a](b) -> a, **a**/_a_ -> a, `a` -> a.
    text = re.sub(r'\[([^\]]*)\]\([^)]*\)', r'\1', text)
    text = text.replace('`', '')
    text = re.sub(r'[*_~]', '', text)
    text = text.strip().lower()
    # Drop characters that are neither word chars, whitespace, nor hyphens.
    text = re.sub(r'[^\w\s-]', '', text)
    # Replace each whitespace character with a single hyphen. GitHub maps spaces
    # one-for-one (it does NOT collapse runs), so "a — b" -> "a--b" once the dash
    # punctuation is dropped: two spaces survive as two hyphens.
    text = re.sub(r'\s', '-', text)
    return text


def heading_slugs(filepath):
    """Return the set of GitHub-style anchor slugs for a markdown file's
    headings, or None if the file cannot be read (caller treats unknown).

    A duplicate slug on GitHub gets a numeric suffix (-1, -2, ...); we accept
    both the bare slug and its suffixed forms so a link to a later duplicate
    heading is not falsely flagged.
    """
    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            content = f.read()
    except OSError:
        return None
    # Strip fenced code blocks so a '#' inside code is not read as a heading.
    content = re.sub(r'```.*?```', '', content, flags=re.DOTALL)
    slugs = set()
    counts = {}
    for line in content.splitlines():
        m = re.match(r'^#{1,6}\s+(.*\S)\s*$', line)
        if not m:
            continue
        base = slugify_heading(m.group(1))
        if not base:
            continue
        n = counts.get(base, 0)
        slugs.add(base if n == 0 else f"{base}-{n}")
        counts[base] = n + 1
    return slugs


def file_part_exists(current_file, file_part):
    """True if the file half of a link (anchor stripped) resolves on disk.

    Used only to classify a broken link as a dead anchor (file present, heading
    absent) versus a missing target, for a clearer diagnostic.
    """
    if file_part.startswith("file://"):
        file_part = file_part.replace("file://", "")
    if not file_part:
        return os.path.exists(current_file)
    if os.path.isabs(file_part):
        return os.path.exists(file_part)
    return os.path.exists(os.path.join(os.path.dirname(current_file), file_part))


def check_local_link(current_file, link_path):
    # Split off any #anchor fragment; the file half and the fragment half are
    # validated independently.
    file_part, sep, fragment = link_path.partition('#')

    if file_part.startswith("file://"):
        file_part = file_part.replace("file://", "")

    # Resolve the target file. An empty file part means a same-document anchor,
    # so the target is the current file itself.
    if not file_part:
        target = current_file if fragment else None
        if target is None:
            return True
    elif os.path.isabs(file_part):
        target = file_part
    else:
        dir_name = os.path.dirname(current_file)
        target = os.path.join(dir_name, file_part)

    if not os.path.exists(target):
        return False

    # File exists. If there is no fragment, that is the whole check. With a
    # fragment, the anchor must resolve to a heading slug in the target file —
    # but only for markdown targets (a slug set is undefined for non-.md files,
    # so we do not flag fragments into them).
    if not fragment:
        return True
    if not target.endswith('.md'):
        return True
    slugs = heading_slugs(target)
    if slugs is None:
        # Unreadable despite os.path.exists (race / permissions): do not flag.
        return True
    return fragment in slugs

def check_external_link(url):
    try:
        req = urllib.request.Request(
            url, 
            headers={'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)'}
        )
        with urllib.request.urlopen(req, timeout=5) as response:
            return response.status < 400
    except (urllib.error.HTTPError, urllib.error.URLError, TimeoutError):
        return False
    except Exception:
        return False

def audit_file(filepath):
    print(f"Auditing file: {filepath}")
    if not os.path.exists(filepath):
        print(f"Error: File {filepath} not found.")
        return False
        
    with open(filepath, 'r') as f:
        content = f.read()
        
    # Strip block code blocks
    content = re.sub(r'```.*?```', '', content, flags=re.DOTALL)
    # Strip inline backtick code
    content = re.sub(r'`[^`\n]+`', '', content)
        
    # Find markdown links: [text](link)
    links = re.findall(r'\[[^\]]+\]\(([^)]+)\)', content)
    broken_count = 0
    
    for link in links:
        if link.startswith("http://") or link.startswith("https://"):
            # Skip checking external links by default to avoid slow build times,
            # but provide option to check.
            pass
        else:
            if not check_local_link(filepath, link):
                file_part, sep, fragment = link.partition('#')
                if sep and fragment and file_part_exists(filepath, file_part):
                    print(f"  [DEAD ANCHOR]: {link} "
                          f"(file exists, no heading '#{fragment}')")
                else:
                    print(f"  [BROKEN LINK]: {link}")
                broken_count += 1
                
    if broken_count == 0:
        print("  All local links are valid.")
        return True
    else:
        print(f"  Found {broken_count} broken local links.")
        return False

def main():
    if len(sys.argv) < 2:
        print("Usage: python3 check_docs.py <markdown-file-or-dir>")
        sys.exit(1)
        
    target = sys.argv[1]
    success = True
    
    if os.path.isdir(target):
        for root, dirs, files in os.walk(target):
            # Prune hidden directories in-place to skip walking them
            dirs[:] = [d for d in dirs if not d.startswith('.')]
            for file in files:
                if file.endswith('.md'):
                    filepath = os.path.join(root, file)
                    if not audit_file(filepath):
                        success = False
    else:
        success = audit_file(target)
        
    if not success:
        sys.exit(1)

if __name__ == "__main__":
    main()
