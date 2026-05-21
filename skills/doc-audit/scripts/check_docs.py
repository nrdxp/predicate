#!/usr/bin/env python3
import os
import sys
import re
import urllib.request
import urllib.error

def check_local_link(current_file, link_path):
    # Strip anchor links
    link_path = link_path.split('#')[0]
    if not link_path:
        return True
        
    if link_path.startswith("file://"):
        link_path = link_path.replace("file://", "")
        
    # Map .agents/ or .agent/ links to root of current repo for self-testing
    if link_path.startswith(".agents/") or link_path.startswith(".agent/"):
        clean_path = re.sub(r'^\.agents?/', '', link_path)
        if os.path.exists(clean_path):
            return True
        
    if os.path.isabs(link_path):
        return os.path.exists(link_path)
    else:
        dir_name = os.path.dirname(current_file)
        full_path = os.path.join(dir_name, link_path)
        return os.path.exists(full_path)

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
