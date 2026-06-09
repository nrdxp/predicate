#!/usr/bin/env python3
import os
import sys
import re
import subprocess
import stat

def run_git(args, cwd):
    res = subprocess.run(["git"] + args, cwd=cwd, capture_output=True, text=True)
    if res.returncode != 0:
        print(f"Git error in {cwd}: {res.stderr.strip()}", file=sys.stderr)
        sys.exit(res.returncode)
    return res.stdout.strip()

def main():
    # Find repository root by searching directories upwards for .git or .sketches
    script_dir = os.path.dirname(os.path.abspath(__file__))
    current = os.path.abspath(script_dir)
    repo_root = None
    while True:
        if os.path.exists(os.path.join(current, ".sketches")) or os.path.exists(os.path.join(current, ".git")):
            repo_root = current
            break
        parent = os.path.dirname(current)
        if parent == current:
            break
        current = parent
        
    if not repo_root:
        repo_root = os.path.abspath(os.path.join(script_dir, "..", "..", ".."))
        
    sketches_dir = os.path.join(repo_root, ".sketches")
    
    if not os.path.exists(sketches_dir):
        print(f"Error: .sketches directory not found at {sketches_dir}", file=sys.stderr)
        sys.exit(1)
        
    # Find modified or untracked .md files in .sketches using -z for robust parsing
    res = subprocess.run(["git", "status", "--porcelain", "-z"], cwd=sketches_dir, capture_output=True, text=True)
    if res.returncode != 0:
        print(f"Git error in {sketches_dir}: {res.stderr.strip()}", file=sys.stderr)
        sys.exit(res.returncode)
    status_output = res.stdout
    modified_files = []
    
    # Split NUL-terminated fields
    fields = status_output.split("\x00")
    i = 0
    while i < len(fields):
        field = fields[i]
        if not field:
            i += 1
            continue
        
        # Format: XY path (status is at index 0..1, path starts at index 3)
        if len(field) >= 4:
            status = field[:2]
            file_path = field[3:]
            
            # For renames (R) or copies (C), the next field is the from_path, skip it
            if status.startswith("R") or status.startswith("C"):
                i += 1
                
            if file_path.endswith(".md") and file_path != "README.md":
                modified_files.append(file_path)
        i += 1
                    
    if not modified_files:
        print("No modified sketch files found in .sketches sub-repository.")
        return

    for active_sketch in modified_files:
        full_path = os.path.join(sketches_dir, active_sketch)
        
        # Read the YAML frontmatter to construct commit message context
        topic = ""
        status = "UNKNOWN"
        loop = "0"
        
        try:
            # Security Checks: Avoid symlinks outside .sketches and non-regular files (FIFOs/pipes)
            real_sketches_dir = os.path.realpath(sketches_dir)
            real_file_path = os.path.realpath(full_path)
            
            # 1. Path traversal / symlink escape check
            if not real_file_path.startswith(real_sketches_dir + os.sep) and real_file_path != real_sketches_dir:
                print(f"Warning: Skipping {active_sketch} as it resolves outside .sketches boundary.", file=sys.stderr)
                continue
                
            # 2. Regular file check (prevents hanging on Named Pipes / FIFOs)
            file_stat = os.lstat(full_path)
            if not stat.S_ISREG(file_stat.st_mode):
                print(f"Warning: Skipping {active_sketch} as it is not a regular file.", file=sys.stderr)
                continue

            # Bounded read (1MB) to prevent memory exhaustion on abnormally large markdown files,
            # while still allowing large YAML blocks containing workspace file hashes.
            with open(real_file_path, "r", encoding="utf-8") as f:
                content = f.read(1024 * 1024)
                
            yaml_match = re.search(r"^```yaml\s*\n(.*?)\n```", content, re.DOTALL | re.MULTILINE)
            if yaml_match:
                yaml_text = yaml_match.group(1)
                
                topic_match = re.search(r"^\s*TOPIC:\s*(.*)$", yaml_text, re.MULTILINE)
                if topic_match:
                    topic = topic_match.group(1).split("#", 1)[0].strip(" \"'")
                    
                status_match = re.search(r"^\s*STATUS:\s*(.*)$", yaml_text, re.MULTILINE)
                if status_match:
                    status = status_match.group(1).split("#", 1)[0].strip(" \"'")
                    
                loop_match = re.search(r"^\s*CURRENT_LOOP:\s*(\d+)", yaml_text, re.MULTILINE)
                if loop_match:
                    loop = loop_match.group(1).strip()
        except Exception as e:
            print(f"Warning: Failed to parse sketch frontmatter for {active_sketch}: {e}", file=sys.stderr)

        # Fallback to filename for topic extraction if frontmatter topic is empty or unknown
        if not topic or topic == "unknown":
            basename = os.path.basename(active_sketch)
            fn_match = re.match(r"^\d{4}-\d{2}-\d{2}-(.+)\.md$", basename)
            if fn_match:
                topic = fn_match.group(1).strip()
            else:
                topic = os.path.splitext(basename)[0]

        # Stage the file using double dash to prevent git option injection
        run_git(["add", "--", active_sketch], cwd=sketches_dir)
        
        # Determine commit message
        if len(sys.argv) > 1:
            commit_msg = " ".join(sys.argv[1:])
        else:
            commit_msg = f"docs(sketch): sync {topic} to Loop {loop} [{status}]"
            # Ensure header is <= 50 chars
            if len(commit_msg) > 50:
                commit_msg = f"docs(sketch): sync {topic} L{loop} [{status}]"
                if len(commit_msg) > 50:
                    commit_msg = f"docs(sketch): update {topic[:15]} L{loop}"
                
        # Commit
        commit_out = run_git(["commit", "-m", commit_msg, "--", active_sketch], cwd=sketches_dir)
        print(f"Successfully committed sketch {active_sketch} in .sketches:")
        print(commit_out)


if __name__ == "__main__":
    main()
