#!/usr/bin/env python3
import os
import sys
import subprocess
import shutil

def run_cmd(args, cwd=None):
    try:
        res = subprocess.run(args, capture_output=True, text=True, cwd=cwd)
        return res.returncode, res.stdout, res.stderr
    except FileNotFoundError:
        return -1, "", f"Command {args[0]} not found."

def detect_languages(path):
    langs = set()
    if not os.path.exists(path):
        return langs

    # Handle if path is a single file
    if os.path.isfile(path):
        ext = os.path.splitext(path)[1]
        if ext == '.py': langs.add('python')
        elif ext == '.sol': langs.add('solidity')
        elif ext == '.go': langs.add('go')
        elif ext in ('.rs', '.toml') and 'Cargo.toml' in path: langs.add('rust')
        elif ext in ('.js', '.ts', '.tsx', '.jsx', '.json') and 'package.json' in path: langs.add('javascript')
        return langs

    for root, dirs, files in os.walk(path):
        # Skip hidden directories like .git
        dirs[:] = [d for d in dirs if not d.startswith('.')]
        for file in files:
            ext = os.path.splitext(file)[1]
            if ext == '.py' or file in ('requirements.txt', 'pyproject.toml'):
                langs.add('python')
            elif ext == '.sol':
                langs.add('solidity')
            elif ext == '.go' or file == 'go.mod':
                langs.add('go')
            elif ext == '.rs' or file == 'Cargo.toml':
                langs.add('rust')
            elif ext in ('.js', '.ts', '.tsx', '.jsx') or file in ('package.json', 'yarn.lock', 'pnpm-lock.yaml'):
                langs.add('javascript')
    return langs

def audit_python(path):
    print(f"\n=== Auditing Python files under: {path} ===")
    if shutil.which("bandit"):
        code, out, err = run_cmd(["bandit", "-r", path])
        print(out)
        if err and code != 0:
            print(f"Errors: {err}", file=sys.stderr)
    else:
        print("Note: 'bandit' is not installed. To run static analysis, install it via: pip install bandit")

def audit_solidity(path):
    print(f"\n=== Auditing Solidity contracts under: {path} ===")
    if shutil.which("slither"):
        code, out, err = run_cmd(["slither", path])
        print(out)
        if err and code != 0:
            print(f"Errors: {err}", file=sys.stderr)
    else:
        print("Note: 'slither' is not installed. To run static analysis, install it via: npm install -g slither-analyzer")

def audit_rust(path):
    print(f"\n=== Auditing Rust codebase under: {path} ===")
    cwd = path if os.path.isdir(path) else os.path.dirname(path)
    
    # 1. Clippy check
    if shutil.which("cargo"):
        print("Running cargo clippy...")
        code, out, err = run_cmd(["cargo", "clippy", "--", "-D", "warnings"], cwd=cwd)
        if code == 0:
            print("  Clippy: Clean")
        else:
            print(out)
            print(err, file=sys.stderr)
            
        # 2. Cargo audit check
        if shutil.which("cargo-audit") or (shutil.which("cargo") and run_cmd(["cargo", "audit", "--help"])[0] == 0):
            print("Running cargo audit...")
            code, out, err = run_cmd(["cargo", "audit"], cwd=cwd)
            print(out)
            if err and code != 0:
                print(err, file=sys.stderr)
        else:
            print("Note: 'cargo-audit' is not installed. To audit dependencies, install it via: cargo install cargo-audit")
    else:
        print("Note: 'cargo' toolchain not found. Unable to run Rust audits.")

def audit_go(path):
    print(f"\n=== Auditing Go codebase under: {path} ===")
    cwd = path if os.path.isdir(path) else os.path.dirname(path)
    if shutil.which("govulncheck"):
        print("Running govulncheck...")
        code, out, err = run_cmd(["govulncheck", "./..."], cwd=cwd)
        print(out)
        if err and code != 0:
            print(err, file=sys.stderr)
    else:
        print("Note: 'govulncheck' is not installed. Install it via: go install golang.org/x/vuln/cmd/govulncheck@latest")

def audit_javascript(path):
    print(f"\n=== Auditing JavaScript/TypeScript dependencies under: {path} ===")
    cwd = path if os.path.isdir(path) else os.path.dirname(path)
    
    # Check for lockfiles to determine manager
    has_yarn = os.path.exists(os.path.join(cwd, "yarn.lock"))
    has_pnpm = os.path.exists(os.path.join(cwd, "pnpm-lock.yaml"))
    
    if has_yarn and shutil.which("yarn"):
        print("Running yarn audit...")
        code, out, err = run_cmd(["yarn", "audit"], cwd=cwd)
        print(out)
    elif has_pnpm and shutil.which("pnpm"):
        print("Running pnpm audit...")
        code, out, err = run_cmd(["pnpm", "audit"], cwd=cwd)
        print(out)
    elif shutil.which("npm"):
        print("Running npm audit...")
        code, out, err = run_cmd(["npm", "audit"], cwd=cwd)
        print(out)
    else:
        print("Note: Node package manager (npm/yarn/pnpm) not found. Unable to run dependency audits.")

def main():
    if len(sys.argv) < 2:
        print("Usage: python3 run_audit.py <path-to-audit>")
        sys.exit(1)
        
    target_path = sys.argv[1]
    langs = detect_languages(target_path)
    
    if not langs:
        print("No supported project files or source languages detected for auditing.")
        sys.exit(0)
        
    print(f"Detected languages/environments for audit: {', '.join(sorted(langs))}")
    
    if 'python' in langs:
        audit_python(target_path)
    if 'solidity' in langs:
        audit_solidity(target_path)
    if 'rust' in langs:
        audit_rust(target_path)
    if 'go' in langs:
        audit_go(target_path)
    if 'javascript' in langs:
        audit_javascript(target_path)

if __name__ == "__main__":
    main()
