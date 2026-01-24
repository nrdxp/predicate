---
name: "Go Idioms"
description: "Go-specific language conventions and patterns"
---

# Go Language Idioms

- Errors are values. Check explicitly; never discard with `_`.
- Prefer `(T, error)` over panicking.
- Use `fmt.Errorf("%w", err)` to wrap errors with context.
- Avoid naked returns in non-trivial functions.
- Reference: [Effective Go](https://go.dev/doc/effective_go).
