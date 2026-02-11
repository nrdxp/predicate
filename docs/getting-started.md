# Getting Started with Predicate

Add predicate to your project, configure active personas, and verify the agent loads everything correctly.

**Audience:** Developers integrating predicate into an existing project.

---

## 1. Add Predicate to Your Project

Three options, depending on your setup:

### Git Submodule (Recommended)

```bash
git submodule add https://github.com/nrdxp/predicate.git .agent
cp .agent/templates/AGENTS.md ./AGENTS.md
```

Update to latest:

```bash
git submodule update --remote .agent
```

### Symlinks

Clone once, symlink into each project:

```bash
git clone https://github.com/nrdxp/predicate.git ~/predicate

mkdir -p .agent
ln -s ~/predicate/axioms .agent/axioms
ln -s ~/predicate/personas .agent/personas
ln -s ~/predicate/workflows .agent/workflows
ln -s ~/predicate/PREDICATE.md .agent/PREDICATE.md

cp ~/predicate/templates/AGENTS.md ./AGENTS.md
```

### Copy

For projects that can't use submodules or symlinks:

```bash
cp -r /path/to/predicate/axioms .agent/axioms
cp -r /path/to/predicate/personas .agent/personas
cp -r /path/to/predicate/workflows .agent/workflows
cp /path/to/predicate/PREDICATE.md .agent/PREDICATE.md
cp /path/to/predicate/templates/AGENTS.md ./AGENTS.md
```

## 2. Configure AGENTS.md

Edit the `AGENTS.md` you copied to your project root:

1. Fill in the **Project Overview** — what the project does, its architecture
2. Set **Active Personas** — only the ones relevant to your project
3. Add **Build & Commands** — how to test, build, lint
4. Fill in remaining sections as applicable

Example active personas for a Go project using DepMap:

```markdown
**Active Personas:**

- go.md (Go idioms)
- depmap.md (MCP tools)
```

## 3. Verify the Agent Bootstraps Correctly

When an agent starts working in your project, it follows the protocol in `.agent/PREDICATE.md`:

1. Scans `.agent/axioms/` and reads all axioms
2. Checks `AGENTS.md` for active personas
3. Loads required personas from `.agent/personas/`
4. Outputs a structured confirmation

You should see something like:

```
PREDICATE CONFIRMATION:
- Axioms: [engineering.md, documentation.md, integral.md]
- Active Personas: [go.md, depmap.md]
- Workflow-Required: [none]
- Discretionary: [none]
```

If the agent skips this confirmation or can't find the axioms directory, check that your `.agent/` symlinks or submodule resolved correctly.

## 4. Your Project Structure

After setup, your project should look like:

```
your-project/
├── .agent/
│   ├── PREDICATE.md       # Agent protocol (read first)
│   ├── axioms/            # Always-active rulesets
│   ├── personas/          # Opt-in context extensions
│   └── workflows/         # Slash-command SOPs
└── AGENTS.md              # Project config + active personas
```

## Next Steps

- **Workflows:** Use `/sketch`, `/plan`, `/core`, `/doc` and others — browse `.agent/workflows/` for the full set
- **Custom content:** See [authoring.md](authoring.md) for writing your own axioms, personas, and workflows
- **Forking:** Fork the predicate repo and use your fork as the submodule source to maintain custom rulesets
