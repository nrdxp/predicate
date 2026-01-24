# Project Agent Configuration

<!--
  This is a template AGENT.md for projects using the predicate ruleset.
  Copy this to your project root and customize the sections below.
  See: https://agent.md for the AGENT.md standard.
-->

## Predicates

This project uses [predicate](https://github.com/nrdxp/predicate) for agent configuration.

**Installation Location:** `.agent/predicate/`

The agent MUST read and adhere to the global engineering ruleset and any active fragments:

```
.agent/
├── predicate/
│   ├── global.md              # Base engineering ruleset (required)
│   └── fragments/             # Active extensions (optional)
│       └── ...                # e.g., go.md, rust.md, depmap.md
└── workflows/
    └── ...                    # Task-specific workflows
```

**Active Fragments:**

<!-- List the fragments installed in .agent/predicate/fragments/ -->
<!-- Example: -->
<!-- - Go idioms -->
<!-- - MCP tools -->

**Available Workflows:**

<!-- List workflows installed in .agent/workflows/ -->

- `/ai-audit` — Audit code for AI-generated patterns
- `/core` — C.O.R.E. structured interaction protocol

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
