---
name: doc-audit
description: "Trigger when auditing documentation, checking markdown link integrity, formatting tables, checking headers, or verifying absolute/relative paths."
---

# Documentation Audit Skill

This skill provides constraints and verification scripts to validate markdown file formatting, check for linting errors, and detect broken external/internal links.

---

## Guidelines for Markdown Auditing

- **Link Integrity & Portability**: All links must follow standard Markdown format `[text](url)`. Cross-references between files MUST be relative paths (e.g. `[core](../core/SKILL.md)`). Hardcoded, machine-specific absolute file URIs (e.g., `file:///var/home/...` or `file:///absolute/path/...`) are strictly forbidden as they will fail to resolve in other environments.
- **Header Hierarchy**: Ensure a single `<h1>` tag per page with sequential header levels (`##`, `###`, etc.).
- **Linting Standards**:
  - Column alignment in tables.
  - Consistent list symbols (use `-`).
  - No trailing spaces.

---

## Utility Script Usage
You can run automated markdown checks using the script located in `scripts/check_docs.py`:
- Checks markdown files for broken local and external links.
- Uses `markdown-link-check` or `markdownlint` where available.
