# Project Agent Configuration

<!--
  This is a template AGENTS.md for projects using the predicate system.
  Copy this to your project root and customize the sections below.
  See: https://agent.md for the AGENT.md standard.
-->

## Predicate System

This project uses [predicate](https://github.com/nrdxp/predicate) for agent configuration.

**Installation Location:** `.agent/predicates/`

### How Predicates Work

**Predicates** are foundational rulesets. Any file placed directly in `predicates/` is **always active** — the agent must read and adhere to all of them unconditionally. These are the non-negotiable rules that govern agent behavior.

**Fragments** are context-specific extensions stored in `predicates/fragments/`. These are **opt-in** — only fragments explicitly listed below as "active" are loaded, and typically only when relevant to the current task (e.g., load `rust.md` when working on Rust code).

```
.agent/
├── predicates/
│   ├── engineering.md         # Base engineering ruleset (predicate, always active)
│   └── fragments/             # Context-specific extensions (opt-in)
│       └── ...                # e.g., go.md, rust.md, depmap.md
└── workflows/
    └── ...                    # Task-specific workflows
```

> [!IMPORTANT]
> The agent must read **all** files directly in `predicates/` before beginning work. These predicates are non-negotiable.

**Active Fragments:**

<!-- List the fragments installed in .agent/predicates/fragments/ that should be active -->
<!-- Example: -->
<!-- - go.md (Go idioms) -->
<!-- - depmap.md (MCP tools) -->

**Available Workflows:**

<!-- List workflows installed in .agent/workflows/ -->

- `/ai-audit` — Audit code for AI-generated patterns
- `/core` — C.O.R.E. structured interaction protocol
- `/humanizer` — Remove AI writing patterns from text
- `/predicate` — Re-read global rules; combats context drift

---

## Project Overview

<!-- Brief description of the project's purpose and architecture -->

---

## Build & Commands

<!-- Development, testing, and deployment commands -->
<!-- Example:
- Run tests: `npm test`
- Build: `npm run build`
- Lint: `npm run lint`
-->

---

## Code Style

<!-- Formatting rules, naming conventions, and best practices -->
<!-- Example:
- TypeScript strict mode
- Prefer functional patterns
- No `any` types
-->

---

## Architecture

<!-- High-level architecture overview -->
<!-- Example:
- Frontend: React
- Backend: Express
- Database: PostgreSQL
-->

---

## Testing

<!-- Testing frameworks, conventions, and execution guidelines -->
<!-- Example:
- Test runner: Vitest
- Naming: `test_<scenario>_<expected_outcome>`
- Run single test: `npm test -- path/to/file.test.ts`
-->

---

## Security

<!-- Security considerations and data protection guidelines -->
<!-- Example:
- Never commit secrets
- Validate all inputs
- Use environment variables for config
-->

---

## Configuration

<!-- Environment setup and configuration management -->
<!-- Example:
- Copy `.env.example` to `.env`
- Required variables: DATABASE_URL, API_KEY
-->
