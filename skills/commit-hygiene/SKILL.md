---
name: commit-hygiene
description: |
  Rules, conventions, and constraints for formatting git commit messages.
  Trigger when:
  - Drafting, revising, or validating git commit messages.
  - Pausing at commit boundaries under the CORE or CONTINUE workflows.
  - Prompt contains keywords: commit message, git commit, conventional commits, commit hygiene, commit guidelines.
---

# Commit Hygiene

Guidelines and constraints for writing clear, structured, and reviewer-centric git commit messages. Every commit is a unit of structured information designed to optimize human comprehension and git history utility.

## Hard Constraints

All commit messages MUST satisfy these structural invariants:
1. **Header Line Limit:** The summary line MUST NOT exceed **50 characters**.
2. **Body Line Limit:** No line in the body or footer may exceed **72 characters**.
3. **Blank Line Separation:** A single blank line MUST separate the header from the body.
4. **No Auto-Commit:** Never run `git commit` directly. Present the proposed commit message to the user for explicit review and manual execution.

---

## Conventional Commits Structure

Commits must conform to the Conventional Commits v1.0.0 specification:

```
<type>(<scope>): <description>

[optional body]

[optional footer(s)]
```

### Allowed Types

- `feat`: Introduction of a new capability or feature.
- `fix`: Resolution of a bug or regression.
- `docs`: Additions or modifications to documentation.
- `style`: Formatting, whitespace adjustments, or cosmetic corrections (no functional change).
- `refactor`: Structural codebase changes that neither modify behavior nor add features.
- `perf`: Optimizations that improve execution speed or resource utilization.
- `test`: Addition, restructuring, or correction of tests.
- `build`: Modifications to build configuration, dependencies, or packaging (e.g. `Cargo.toml`, `package.json`, `go.mod`).
- `ci`: Alterations to CI pipeline or automation configurations.
- `chore`: Auxiliary tasks, infrastructure tooling updates, or miscellaneous maintenance.
- `revert`: Reversion of a previous commit.

### Summary Header Formatting

- **Imperative Mood:** Use active, imperative verbs ("add", "fix", "refactor", "remove") rather than past-tense or present-participle ("added", "fixing", "refactored", "removes").
- **No Trailing Period:** The header line must not end with a period.
- **Lower Case:** The description after the colon should start with a lowercase letter (unless referencing a proper noun or acronym).

---

## Human-Centric Communication

Commits are written for human reviewers, not systems. Prioritize cognitive clarity:

### Focus on "Why" and "What"

- **The "Why":** Explain the motivation behind the change. What problem is this resolving? What context is required to understand this design decision?
- **The "What":** Describe what was changed at a conceptual level. Avoid summarizing the raw code diff (which the reviewer can already see); instead, describe the logical transition of the system.
- **Explain the Tradeoffs:** If a non-obvious design pattern or workaround was employed, document it honestly.

### Atomicity and Focus

- Each commit must represent a single, cohesive logical change.
- **Anti-pattern:** Blending unrelated concerns (e.g., `feat: add user login and fix lint errors`). If a change contains the word "and" in its header description, evaluate if it should be split into multiple commits.

---

## Commit Message Checklist

Before presenting a commit message, run this audit:

- [ ] Is the header length ≤ 50 characters?
- [ ] Are all body and footer lines ≤ 72 characters?
- [ ] Is there a blank line between the header and the body?
- [ ] Is the header in the imperative mood?
- [ ] Does it use a valid Conventional Commit type?
- [ ] Does the body explain the *why* and *what*, rather than just reproducing the diff?
- [ ] Are breaking changes explicitly noted in the footer (e.g., `BREAKING CHANGE: <description>`)?
