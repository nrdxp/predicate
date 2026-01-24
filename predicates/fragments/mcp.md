---
name: "MCP Integration"
description: "Model Context Protocol tool usage guidance"
---

# MCP Integration

## Usage Triggers

Before proceeding with manual exploration, **consider MCP tools first** for these scenarios:

| Scenario                       | MCP Tool Consideration                          |
| :----------------------------- | :---------------------------------------------- |
| Exploring a new/large codebase | Repo map for structure overview                 |
| Understanding dependency APIs  | Dependency map to map external library surfaces |
| Searching for identifier usage | Identifier search before grep                   |
| Resolving project dependencies | Dependency resolution for toolchain detection   |

## Default Posture

Prefer MCP tools over manual exploration when available. They exist to reduce context-gathering overhead.

## Common MCP Servers

- **DepMap / RepoMapper:** Repository structure and dependency analysis
- **Browser:** Web interaction and verification
- **Filesystem:** Enhanced file operations

Consult your agent's MCP server configuration for available tools.
