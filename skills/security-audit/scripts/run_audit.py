#!/usr/bin/env python3
import sys
import subprocess
import shutil

def run_cmd(args):
    try:
        res = subprocess.run(args, capture_output=True, text=True)
        return res.returncode, res.stdout, res.stderr
    except FileNotFoundError:
        return -1, "", f"Command {args[0]} not found."

def audit_python(path):
    print(f"=== Auditing Python files under: {path} ===")
    if shutil.which("bandit"):
        code, out, err = run_cmd(["bandit", "-r", path])
        print(out)
        if err:
            print(f"Errors: {err}", file=sys.stderr)
    else:
        print("Note: 'bandit' is not installed. To run static analysis, install it via: pip install bandit")

def audit_solidity(path):
    print(f"=== Auditing Solidity contracts under: {path} ===")
    if shutil.which("slither"):
        code, out, err = run_cmd(["slither", path])
        print(out)
        if err:
            print(f"Errors: {err}", file=sys.stderr)
    else:
        print("Note: 'slither' is not installed. To run static analysis, install it via: npm install -g slither-analyzer")

def main():
    if len(sys.argv) < 2:
        print("Usage: python3 run_audit.py <path-to-audit>")
        sys.exit(1)
        
    target_path = sys.argv[1]
    audit_python(target_path)
    audit_solidity(target_path)

if __name__ == "__main__":
    main()
