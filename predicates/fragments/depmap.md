---
name: "DepMap Integration"
description: "DepMap MCP server usage for repository and dependency mapping"
---

# DepMap Integration

DepMap provides comprehensive repository and dependency analysis. Use it liberally to avoid API hallucinations and reduce manual exploration overhead.

> **Core Principle:** DepMap gives a more comprehensive view of API surfaces than manual searches. Leverage it to prevent dependency API hallucinations.

---

## When to Use DepMap

| Scenario                          | Tool                   | Why                                             |
| :-------------------------------- | :--------------------- | :---------------------------------------------- |
| Exploring new/large codebase      | `repo_map`             | Get structure overview before diving in         |
| Understanding external library    | `dep_map`              | Map API surface of dependencies                 |
| Finding function/type definitions | `search_identifiers`   | Faster and more accurate than grep              |
| Setting up new project            | `resolve_dependencies` | Detect toolchains and locate dependency sources |

---

## Tools Reference

### `repo_map`

Generate a repository map showing function prototypes, variables, and file relationships.

**Use when:**

- Starting work on unfamiliar codebase
- Need overview of module structure
- Want to understand file relationships via PageRank

**Key parameters:**

| Parameter          | Purpose                                        |
| :----------------- | :--------------------------------------------- |
| `project_root`     | Absolute path to project (required)            |
| `chat_files`       | Files in current context (highest ranking)     |
| `mentioned_files`  | Files referenced in conversation (mid ranking) |
| `mentioned_idents` | Identifiers to boost in ranking                |
| `token_limit`      | Max tokens for output (default: 8192)          |
| `force_refresh`    | Bypass cache for fresh analysis                |

**Returns:** Map string + report with included/excluded files, match counts.

---

### `search_identifiers`

Search for identifier definitions and references across the codebase.

**Use when:**

- Finding where a function/type is defined
- Locating all usages of an identifier
- Navigating to implementation before making changes

**Key parameters:**

| Parameter             | Purpose                             |
| :-------------------- | :---------------------------------- |
| `project_root`        | Absolute path to project (required) |
| `query`               | Identifier name (case-insensitive)  |
| `max_results`         | Limit results (default: 50)         |
| `context_lines`       | Lines of context around match       |
| `include_definitions` | Include definition occurrences      |
| `include_references`  | Include reference occurrences       |

**Returns:** List of matches with file, line number, and context.

> **Tip:** Use plain identifier names without special characters or prefixes.

---

### `resolve_dependencies`

Detect project toolchains and resolve dependency source locations.

**Use when:**

- Setting up work on new project
- Need to understand dependency structure
- Want to locate local source paths for dependencies

**Key parameters:**

| Parameter      | Purpose                                           |
| :------------- | :------------------------------------------------ |
| `project_root` | Absolute path to project (required)               |
| `toolchains`   | Specific toolchains to check (e.g., `rust`, `go`) |
| `deps`         | Specific dependency names to resolve              |

**Returns:**

- `toolchains_detected`: List of detected toolchains
- `dependencies`: Resolved deps with name, version, source_path
- `unresolved`: Deps that couldn't be located

---

### `dep_map`

Generate API surface map for external dependencies.

**Use when:**

- Need to understand library API before using it
- Avoiding hallucination of non-existent functions/types
- Learning unfamiliar dependency

**Key parameters:**

| Parameter      | Purpose                               |
| :------------- | :------------------------------------ |
| `project_root` | Absolute path to project (required)   |
| `deps`         | List of dependency names to map       |
| `token_limit`  | Max tokens for output (default: 4096) |
| `verbose`      | Enable verbose logging                |

**Returns:**

- `map`: Generated API map for dependencies
- `resolved`: Successfully resolved deps
- `unresolved`: Deps that couldn't be located

> **Anti-Hallucination:** Always use `dep_map` before calling unfamiliar library functions. Verify the API exists before generating code.

---

## Best Practices

### Before Writing Code

1. **New codebase?** → `repo_map` first
2. **Using external library?** → `dep_map` to verify API
3. **Modifying existing code?** → `search_identifiers` to find all usages

### Avoiding Hallucinations

```
❌ Assume library has function `foo.doThing()`
✅ Use dep_map to verify foo's actual API surface
```

### Caching

- DepMap caches analysis for performance
- Use `force_refresh: true` if project structure has changed significantly

---

## Quick Reference

| Task                 | Tool                   | Key Params                   |
| :------------------- | :--------------------- | :--------------------------- |
| Codebase overview    | `repo_map`             | `project_root`, `chat_files` |
| Find definition      | `search_identifiers`   | `project_root`, `query`      |
| Check dependency API | `dep_map`              | `project_root`, `deps`       |
| Detect toolchains    | `resolve_dependencies` | `project_root`               |
