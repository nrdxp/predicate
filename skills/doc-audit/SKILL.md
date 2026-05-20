---
name: doc-audit
description: Verify markdown documentation files for syntax, formatting standards, and broken URLs/links.
---

# Documentation Audit Skill

This skill provides constraints and verification scripts to validate markdown file formatting, check for linting errors, and detect broken external/internal links.

---

## Guidelines for Markdown Auditing

- **Link Integrity**: All links must follow standard Markdown format `[text](url)`. Absolute file paths must use the `file://` scheme where applicable.
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
