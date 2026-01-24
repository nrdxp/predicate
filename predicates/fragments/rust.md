---
name: "Rust Idioms"
description: "Rust-specific language conventions and patterns"
---

# Rust Language Idioms

- Embrace newtypes for domain concepts.
- Prefer `impl Trait` for return types when concrete type is an implementation detail.
- Use `#[must_use]` where ignoring return value is almost always a bug.
- Beware the "Re-serialization Trap"—preserve input bytes for signature fidelity.
- Avoid `.unwrap()` in library code; propagate `Result` instead.
