# Getting Started with Predicate

Install Predicate as a global plugin, wire it into a project end to end, and verify the integration.

**Audience:** Developers integrating Predicate skills.

---

## 1. Install the Global Plugin

Predicate installs once, globally, and is then available across every project. Agent runners that support plugin manifests (Antigravity CLI, Claude Code, and other compliant environments using `plugin.json`) discover its skills from the global plugin directory — no per-project repository nesting.

Clone the repository into your runner's global plugin directory:

```bash
# Claude Code
git clone https://github.com/nrdxp/predicate.git ~/.claude/plugins/predicate

# Antigravity CLI
git clone https://github.com/nrdxp/predicate.git ~/.gemini/antigravity-cli/plugins/predicate
```

To update the global plugin later, pull the latest changes:

```bash
git -C <plugin-dir> pull
```

---

## 2. Bootstrap a Project

From any project you want Predicate to govern, run the bootstrap once. It is a single command that performs every setup step and is safe to re-run:

```bash
<plugin-dir>/bootstrap/install.sh --project .
```

The bootstrap detects your harness (Claude Code or Antigravity) and:

1. **Registers the plugin** into the harness's plugin directory, so its skills load globally.
2. **Installs the commit gate** by calling `hooks/install-hooks.sh` — the `commit-msg` and `pre-commit` hooks that enforce Conventional Commits form, self-containment, and referential integrity.
3. **Initializes the `.ledger` subrepo** — the project's flight-recorder for durable agent history — and configures its remote (it never pushes; pushing is left to you).
4. **Wires the always-on rules** by appending two `@import` lines to your global `CLAUDE.md`:

   ```
   @<plugin-dir>/rules.md
   @<plugin-dir>/ambient.md
   ```

   This append is idempotent and non-clobbering: the lines live inside a sentinel-delimited managed block, so re-running the bootstrap is a no-op and your existing `CLAUDE.md` content is preserved untouched. Predicate's rules and ambient layer load in every session via the `@import` reference, which auto-propagates plugin updates (no copy is frozen into your config).

To point the `.ledger` remote at your own repository, set the remote URL when bootstrapping:

```bash
PREDICATE_LEDGER_REMOTE=git@github.com:you/yourproject-ledger.git \
  <plugin-dir>/bootstrap/install.sh --project .
```

When you are ready, push the `.ledger` subrepo yourself:

```bash
git -C .ledger push -u origin main
```

---

## 3. Configure AGENTS.md (Optional)

The bootstrap wires rules loading for you, so an `AGENTS.md` is no longer required for skills to load. It remains useful for *project-specific* context the global rules cannot know — build commands, an architecture overview, and explicit skill routing.

Create an `AGENTS.md` in your project root and fill in:

1. **Project Overview** — what the project does and its high-level architecture.
2. **Active Skills** — the skills that apply to your project.
3. **Build & Commands** — how to test, build, and lint.

Example active skills for a Go project:

```markdown
**Active Skills:**

- go (Go idioms)
- sdma (Domain modeling)
```

---

## 4. Verify Integration

Confirm your agent runner detects and loads the Predicate configuration.

1. **Verify the rules `@import`**: Check that your global `CLAUDE.md` ends with the predicate managed block (the two `@import` lines between the `# >>> predicate managed block >>>` sentinels). A new session loads `rules.md` and `ambient.md` from there.
2. **Verify the skills list**: When you launch your runner, the startup metadata's **Available skills** block should list the Predicate skills (`constitution`, `engineering`, a language skill such as `rust` or `go`, and a workflow such as `core` or `refine`).
3. **Verify semantic triggering**: Direct the agent in natural language (e.g., *"Let's run the core workflow"*). The runner matches your request against the skill descriptions and loads the required skill context.
4. **Verify the commit gate**: Attempt a commit with a non-conforming message; the `commit-msg` hook should reject it. To scan the whole repository for stale workflow references at any time, run the orphan gate directly:

   ```bash
   gates/check_orphans.sh . plan charter sketch
   ```

---

## Next Steps

- **Custom content:** See [docs/authoring.md](authoring.md) for writing your own custom skills.
- **Forking:** Fork the Predicate repository and point your global plugin clone at your fork to maintain custom organizational skills.
