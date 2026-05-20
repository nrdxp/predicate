# Getting Started with Predicate

Add Predicate to your project, configure active rules, and verify the agent integrates correctly.

**Audience:** Developers integrating Predicate into an existing project.

---

## 1. Add Predicate to Your Project

We recommend adding Predicate as a Git Submodule under `.agents/` and then running the integration helper script.

### Step 1: Add the Submodule

At the root of your project, run:

```bash
git submodule add https://github.com/nrdxp/predicate.git .agents
```

### Step 2: Establish Symlinks for Tool Integration

Predicate comes with a setup script that hooks rules, custom skills, and workflows into your environment (creating `.claude/commands`, `.claude/skills`, and `CLAUDE.md` automatically):

```bash
# Run the integration helper script
./.agents/scripts/setup-links.sh
```

### Step 3: Copy AGENTS.md Template

Copy the project-level configuration template to your project root:

```bash
cp .agents/templates/AGENTS.md ./AGENTS.md
```

To update Predicate to the latest version in the future:

```bash
git submodule update --remote .agents
```

---

## 2. Configure AGENTS.md

Edit the `AGENTS.md` you copied to your project root:

1. Fill in the **Project Overview** — what the project does, its architecture.
2. Set **Active Rules** — list the rules from `.agents/rules/` that apply to your project.
3. Add **Build & Commands** — how to test, build, lint.
4. Fill in remaining sections as applicable.

Example active rules for a Go project:

```markdown
**Active Rules:**

- go.md (Go idioms)
- sdma.md (Domain modeling)
```

---

## 3. Verify Integration

Once the integration script has run, your project structure should look like this:

```
your-project/
├── .agents/               # The Predicate submodule
│   ├── rules/             # Axioms and glob/model rules
│   ├── skills/            # Custom skills and scripts
│   ├── workflows/         # Slash command workflow files
│   └── scripts/           # Setup and utility scripts
├── .claude/               # Claude Code configuration (created by setup-links.sh)
│   ├── commands/          # Symlinked workflows (custom slash commands)
│   └── skills/            # Symlinked skill packages
├── AGENTS.md              # Project metadata & active rules
└── CLAUDE.md              # Root-level entry point pointing to constitution.md
```

Verify that your agent of choice (e.g., Claude Code or Antigravity CLI) detects the configuration:
- In Claude Code, type `/` to see the symlinked workflows (like `/core`, `/plan`, `/sketch`) list in the commands menu.
- Open files to verify glob rules load automatically (e.g., editing a Rust file triggers the rules in `.agents/rules/rust.md`).

---

## Next Steps

- **Workflows:** Trigger procedures like `/sketch`, `/plan`, `/core`, or `/doc` directly.
- **Custom content:** See [docs/authoring.md](authoring.md) for writing your own rules, skills, and workflows.
- **Forking:** Fork the Predicate repository and point your submodule to your fork to maintain custom organizational rulesets.

