# Predicate System

This document explains how the predicate agent configuration system works. It is **required reading** before beginning work on any project using predicate.

## Directory Structure

Predicate content lives under `.agent/` at the project root:

```
.agent/
├── predicates/          # Foundational rulesets
│   └── fragments/       # Context-specific extensions
├── workflows/           # Task-specific SOPs
└── PREDICATE.md         # This file
```

## Predicates (Always Active)

**Predicates** are foundational rulesets. Any `.md` file placed directly in `.agent/predicates/` (not in a subdirectory) must be read and followed unconditionally — these are the non-negotiable rules governing agent behavior.

> [!IMPORTANT]
> You **must** scan `.agent/predicates/` and read **all** `.md` files there before beginning work. Do not rely on any file listing — scan the directory itself.

## Fragments (Opt-In)

**Fragments** are context-specific extensions stored in `.agent/predicates/fragments/`. These are **opt-in** — only fragments explicitly listed as "active" in the project's `AGENTS.md` are loaded, typically when relevant to the current task (e.g., a language-specific fragment when working on that language).

## Workflows

**Workflows** are task-specific standard operating procedures stored in `.agent/workflows/`. They are triggered via slash commands (e.g., `/core`, `/ai-audit`) and guide structured agent behavior for specific tasks.

## Hierarchical Configuration

The [AGENTS.md standard](https://agents.md) supports hierarchical configuration. When working in a subdirectory, also check for and read any `AGENTS.md` file in that directory for additional context-specific rules. Subdirectory rules supplement (not replace) the root configuration.

## Summary

| Term          | Location                       | Activation                       |
| :------------ | :----------------------------- | :------------------------------- |
| **Predicate** | `.agent/predicates/*.md`       | Always active — scan directory   |
| **Fragment**  | `.agent/predicates/fragments/` | Opt-in — listed in `AGENTS.md`   |
| **Workflow**  | `.agent/workflows/`            | User-triggered via slash command |
