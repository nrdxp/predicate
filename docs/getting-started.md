# Getting Started with Predicate

Predicate sets up in two phases: install it once globally, then initialize each
project you want it to govern.

**Audience:** Developers integrating Predicate skills.

---

## Prerequisites

Clone the repository somewhere stable — this checkout is the live source for the
plugin and the always-on rules, so keep it around and `git pull` it to update.
The commands below write the clone path as `<predicate-dir>`; substitute wherever
you cloned it:

```bash
git clone https://github.com/nrdxp/predicate.git <predicate-dir>
```

The two phases below are both subcommands of `bootstrap/install.sh` and are safe
to re-run.

---

## 1. Install Globally (once per machine)

The `install` phase registers Predicate with your agent runner and wires the
always-on rules into your global `CLAUDE.md`. Run it once:

```bash
<predicate-dir>/bootstrap/install.sh install
```

It detects your harness and registers Predicate via that harness's real
mechanism:

**Claude Code** — Predicate ships a plugin manifest (`.claude-plugin/plugin.json`)
and a marketplace catalog (`.claude-plugin/marketplace.json`) that catalogs the
checkout as an installable plugin. The `install` phase runs the supported Claude
Code CLI registration:

```bash
claude plugin marketplace add <predicate-dir>
claude plugin install predicate@predicate
```

Both commands are idempotent, so re-running `install` is a no-op. After this,
Predicate's skills are available in every project under the `predicate:`
namespace (the `core` workflow, for instance, is invoked as `predicate:core`).
The `claude` CLI must be on your `PATH`; if it is not, install
[Claude Code](https://code.claude.com) first.

**Antigravity CLI** — Antigravity discovers plugins from a file-based directory,
so the `install` phase symlinks the checkout into its plugins directory under
`~/.gemini/antigravity-cli/plugins/predicate`.

After registering the plugin, `install` delivers the always-on conditioning
layer natively into each harness. Predicate ships a conditioning layer
(`conditioning/`) that generates a structured system prompt for each role.
The generator (`conditioning/compose.ncl`) composes `invariant-core ++
persona(role)` and enforces a contract (`HasCore`) that makes it structurally
impossible for any persona to drop the always-on law. The `install` phase
materializes the generated prompts into each harness's **native system-prompt
surface** at install time:

- **Claude Code** — writes an output style to
  `~/.claude/output-styles/predicate-composer.md` (frontmatter
  `keep-coding-instructions: false`, which empties Claude Code's built-in
  software-engineering block while preserving tool definitions, environment
  info, agent identity, and safety scaffolding). It also materializes every
  worker permutation as a subagent under `~/.claude/agents/predicate-<role>.md`
  (the subagent body becomes that role's full system prompt).
- **agy** — writes the composer law as a managed block into
  `~/.gemini/GEMINI.md`.

See [conditioning-layer.md](conditioning-layer.md) for the composition contract
and delivery details.

The output style is the single always-on surface. No `@import` of `rules.md` or
`ambient.md` is written to CLAUDE.md; `rules.md` is the authoritative source for
the invariants and is loaded by invoked skills — the conditioning prompt already
carries the invariant core into every session.

> The `install` phase touches only your global config. It installs **no** git
> hooks and creates **no** `.ledger` — those are per-project, and belong to `init`.

---

## 2. Initialize a Project (once per repo)

From inside any repository you want Predicate to govern, run the `init` phase:

```bash
cd /path/to/your/project
<predicate-dir>/bootstrap/install.sh init --project .
```

It performs the per-repository setup:

1. **Installs the three-tier commit gate** by calling `hooks/install-hooks.sh` — the
   `commit-msg` and `pre-commit` hooks. `commit-msg` enforces Conventional Commits
   form plus self-containment (no internal campaign references a stranger reading
   `git log` could not resolve). `pre-commit` runs three tiers: the structural tier
   always runs (referential integrity, markdown link validity, Nickel contract
   satisfaction); the authority tier runs only when a campaign DAG is active
   (staged paths must be authorized by the DAG); and the process tier fires only
   when an agent walk is registered (procedure deposits are validated against their
   contract class). The installer links the hooks **as symlinks into your repo's
   untracked `.git/hooks/`**, each pointing back to the plugin checkout. Nothing is
   added to your project's tracked tree, and the symlinks are auditable and
   removable (`rm .git/hooks/{pre-commit,commit-msg}`). The hooks self-locate their
   gate machinery from their own path back in the checkout, so they keep working
   with no copy frozen into your project.
2. **Initializes the `.ledger` subrepo** — the project's flight-recorder for
   durable agent history — and configures its remote (it never pushes; pushing is
   left to you).

To point the `.ledger` remote at your own repository, set the remote URL when
initializing:

```bash
PREDICATE_LEDGER_REMOTE=git@github.com:you/yourproject-ledger.git \
  <predicate-dir>/bootstrap/install.sh init --project .
```

When you are ready, push the `.ledger` subrepo yourself:

```bash
git -C .ledger push -u origin main
```

The gates and hooks run with Predicate's own defaults out of the box. To override
them for your project, copy `.ledger/config.sh.example` to `.ledger/config.sh` and
edit it — the example documents every overridable variable (the commit
self-containment pattern, the orphan-scan targets, the removed-workflow set, and
more) with Predicate's defaults shown.

### What lands in your project

Predicate is self-contained: `init` vendors no machinery into your tree. After
initializing, your project's only Predicate footprint is:

- **Untracked `.git/hooks/{pre-commit,commit-msg}` symlinks** pointing back to the
  checkout — auditable, and removable with a plain `rm`. No `hooks/` directory
  appears in your tracked tree.
- **Its own `.ledger/`** — the flight-recorder subrepo plus the
  `config.sh.example` override surface.

For any Nickel artifacts of your own that build on Predicate's ledger contracts,
import them by the logical convention — `import "dag.ncl"` — rather than a path
into the plugin. The gate runner injects the plugin's contract directory on the
Nickel import path, so the logical name resolves without your artifact knowing
where the plugin lives.

**Runtime floor.** Predicate's gates assume a small, standard toolchain on
`PATH`: a coreutils-grade `realpath` (the hooks self-locate the plugin via
`realpath`), plus `bash`, `git`, a stdlib-only `python3`, and either `nickel` or
`nix` for the ledger checks. These are the only host assumptions.

---

## 3. Configure AGENTS.md (Optional for basic use)

The `install` phase delivers the conditioning output style, so an `AGENTS.md` is
not required for skills to load — basic use works without one. It remains useful for
*project-specific* context the global rules cannot know — build commands, an
architecture overview, and explicit skill routing.

It is also the **anchor the prevention layer builds on**: the
[`/orient`](../skills/orient/SKILL.md) workflow maps a repository and authors a
nested `AGENTS.md` hierarchy (ecosystem ⊃ project ⊃ component) holding the goal,
requirements, and invariants so every subsequent walk is anchored against drift.
Optional to start; load-bearing once you adopt the prevention half.

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

1. **Verify the registration**: For Claude Code, run `claude plugin list` and
   confirm `predicate@predicate` appears, enabled. The skills surface under the
   `predicate:` namespace.
2. **Verify the conditioning output style**: For Claude Code, check that
   `~/.claude/output-styles/predicate-composer.md` exists and that worker
   agents appear under `~/.claude/agents/predicate-<role>.md`. For agy, check
   that `~/.gemini/GEMINI.md` contains the predicate managed block (between the
   `# >>> predicate conditioning block >>>` sentinels). A new session receives
   the invariant core via the installed native surface.
3. **Verify the skills list**: When you launch your runner, the startup metadata's
   **Available skills** block should list the Predicate skills (`constitution`,
   `engineering`, a language skill such as `rust` or `go`, and a workflow such as
   `core` or `refine`).
4. **Verify semantic triggering**: Direct the agent in natural language (e.g.,
   *"Let's run the core workflow"*). The runner matches your request against the
   skill descriptions and loads the required skill context.
5. **Verify the commit gate**: In an initialized project, attempt a commit with a
   non-conforming message; the `commit-msg` hook should reject it. To scan the
   whole repository for stale workflow references at any time, run the orphan gate
   directly:

   ```bash
   <predicate-dir>/gates/check_orphans.sh . plan charter sketch
   ```

---

## Next Steps

- **See it in action:** Walk through a real, runnable example of the record
  system at [ledger/examples/walkthrough/](../ledger/examples/walkthrough/README.md).
- **Custom content:** See [authoring.md](authoring.md) for writing your own
  custom skills.
- **Architecture overview:** See [predicate-architecture.md](predicate-architecture.md) for the
  correction/prevention architecture, the gate tiers, and the contract surface.
- **Conditioning layer:** See [conditioning-layer.md](conditioning-layer.md) for the
  system-prompt-as-law mechanism and how the invariant-core is injected.
- **Primitives:** See [primitives.md](primitives.md) for the five cross-cutting primitives
  (P-GROUND, P-ARSENAL, P-COMPOSE, P-INTENT, P-TRACK) that the machinery composes on.
- **Forking:** Fork the Predicate repository and point your global clone at your
  fork to maintain custom organizational skills.
