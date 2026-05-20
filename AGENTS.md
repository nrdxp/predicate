# Project Agent Configuration

## Predicate System

This project **is** [predicate](https://github.com/nrdxp/predicate) — a system for portable, composable agent configuration.

> [!IMPORTANT]
> You **must** review [PREDICATE.md](PREDICATE.md) and follow its protocol before beginning work.

**Active Rules:** None (except always-active axioms)

This is a documentation-only repository. The language-specific rules (go.md, rust.md, etc.) are provided as templates/configurations for other projects, but are not active here. The `rules/integral.md` rule guides meta-project reasoning.

> [!NOTE]
> This repository **is** the Predicate source. The `rules/`, `skills/`, and `workflows/` directories live at the repo root — not under `.agents/` — because this is the upstream that other projects consume via submodule or symlink. When mounted into a consuming project, these directories appear under `.agents/` as described in `PREDICATE.md`.

---

## Project Overview

Predicate is a framework for configuring AI coding agents with reusable rulesets, composable skills (actions/capabilities), and task-specific procedures (workflows).

**Purpose:** Replace ad-hoc system prompts with version-controlled, shareable agent configuration.

---

## Repository Structure

| Directory     | Purpose                             |
| :------------ | :---------------------------------- |
| `rules/`      | Workspace rules (Axioms & Personas) |
| `skills/`     | Custom skills and execution scripts |
| `workflows/`  | Manually-triggered slash commands   |
| `templates/`  | Project templates (AGENTS.md)       |
| `docs/`       | Guides, plans, and ADRs             |

---

## Build & Commands

This is a documentation-only repository. No build required.

- Validate markdown: `markdownlint .` (if installed)
- Check links: `python3 skills/doc-audit/scripts/check_docs.py .`

---

## Code Style

- **Markdown:** Follow GitHub Flavored Markdown
- **Tables:** Align columns for readability
- **Lists:** Use `-` for unordered lists
- **Headers:** Use `##` sections with `---` separators

---

## Contributing

See [README.md](README.md#contributing) for contribution guidelines.

When adding content:

- New rules → `rules/`
- New skills → `skills/`
- New workflows → `workflows/` with proper front-matter

---

## Version

Pre-1.0: Breaking changes expected. Design over stability.
