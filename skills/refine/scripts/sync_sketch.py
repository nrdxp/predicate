#!/usr/bin/env python3
import os
import sys
import re
import subprocess

def run_git(args, cwd):
    res = subprocess.run(["git"] + args, cwd=cwd, capture_output=True, text=True)
    if res.returncode != 0:
        print(f"Git error in {cwd}: {res.stderr.strip()}", file=sys.stderr)
        sys.exit(res.returncode)
    return res.stdout.strip()

def main():
    # Find repository root
    script_dir = os.path.dirname(os.path.abspath(__file__))
    repo_root = os.path.abspath(os.path.join(script_dir, "..", "..", ".."))
    sketches_dir = os.path.join(repo_root, ".sketches")
    
    if not os.path.exists(sketches_dir):
        print(f"Error: .sketches directory not found at {sketches_dir}", file=sys.stderr)
        sys.exit(1)
        
    # Find modified or untracked .md files in .sketches
    status_output = run_git(["status", "--porcelain"], cwd=sketches_dir)
    modified_files = []
    for line in status_output.splitlines():
        if line.strip():
            # Match status codes like M, A, ?? followed by file path
            parts = line.strip().split(maxsplit=1)
            if len(parts) == 2:
                file_path = parts[1]
                if file_path.endswith(".md") and file_path != "README.md":
                    modified_files.append(file_path)
                    
    if not modified_files:
        print("No modified sketch files found in .sketches sub-repository.")
        return

    # Select the first modified sketch file (usually there is only one active)
    active_sketch = modified_files[0]
    if len(modified_files) > 1:
        print(f"Warning: Multiple modified sketch files found. Only processing the first one: {active_sketch}", file=sys.stderr)

    full_path = os.path.join(sketches_dir, active_sketch)
    
    # Read the YAML frontmatter to construct commit message context
    topic = "unknown"
    status = "UNKNOWN"
    loop = "0"
    
    try:
        # Bounded read to prevent memory exhaustion / catastrophic regex backtracking
        with open(full_path, "r", encoding="utf-8") as f:
            content = f.read(4096)
            
        yaml_match = re.search(r"^```yaml\s*\n(.*?)\n```", content, re.DOTALL | re.MULTILINE)
        if yaml_match:
            yaml_text = yaml_match.group(1)
            topic_match = re.search(r"^TOPIC:\s*\"?([^\n\"]+)\"?", yaml_text, re.MULTILINE)
            if topic_match:
                topic = topic_match.group(1).strip()
                
            status_match = re.search(r"^STATUS:\s*([^\n]+)", yaml_text, re.MULTILINE)
            if status_match:
                status = status_match.group(1).strip()
                
            # Search for CURRENT_LOOP under TRACE:
            trace_match = re.search(r"^TRACE:\s*\n(.*?)(?=\n\w|\Z)", yaml_text, re.DOTALL | re.MULTILINE)
            if trace_match:
                trace_text = trace_match.group(1)
                loop_match = re.search(r"CURRENT_LOOP:\s*(\d+)", trace_text)
                if loop_match:
                    loop = loop_match.group(1).strip()
            else:
                loop_match = re.search(r"CURRENT_LOOP:\s*(\d+)", yaml_text)
                if loop_match:
                    loop = loop_match.group(1).strip()
    except Exception as e:
        print(f"Warning: Failed to parse sketch frontmatter: {e}", file=sys.stderr)

    # Fallback to date-prefixed filename for topic extraction if frontmatter topic is unknown
    if topic == "unknown":
        basename = os.path.basename(active_sketch)
        fn_match = re.match(r"^\d{4}-\d{2}-\d{2}-(.+)\.md$", basename)
        if fn_match:
            topic = fn_match.group(1).strip()

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
    commit_out = run_git(["commit", "-m", commit_msg], cwd=sketches_dir)
    print(f"Successfully committed sketch in .sketches:")
    print(commit_out)

if __name__ == "__main__":
    main()
