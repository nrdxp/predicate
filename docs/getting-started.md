# Getting Started with Predicate

Configure Predicate in your environment, activate rulesets, and verify correct agent integration.

**Audience:** Developers integrating Predicate rules, skills, and workflows.

---

## 1. Installation Pathways

Depending on your agent runner's capabilities, choose between a centralized plugin installation or a project-level Git submodule.

### Option A: Global Plugin Installation (Recommended)

For agent runners supporting standardized plugin manifests (e.g., Antigravity CLI, Claude Code, and other compliant agentic environments utilizing `plugin.json`), you can install Predicate globally. This exposes all rules, skills, and workflows across your workspaces without manual repository nesting.

Clone the repository directly into your runner's global plugin directory:

```bash
git clone https://github.com/nrdxp/predicate.git ~/.gemini/config/plugins/predicate
```

To update the global plugin in the future, pull the latest changes:

```bash
git -C ~/.gemini/config/plugins/predicate pull
```

### Option B: Project-Level Git Submodule

For environments requiring direct directory mounting within a specific repository, mount Predicate as a Git submodule under the standard `.agents/` path:

```bash
git submodule add https://github.com/nrdxp/predicate.git .agents
```

To update the submodule:

```bash
git submodule update --remote .agents
```

---

## 2. Configure AGENTS.md (Recommended)

While modern agent runners can discover and execute rules, skills, and workflows directly from a globally loaded plugin without local files, placing an `AGENTS.md` configuration file in your project's root directory is highly recommended. It provides project-specific context (e.g., build commands and architectural overviews) and explicit ruleset routing.

### Step 1: Initialize AGENTS.md

Initialize `AGENTS.md` by copying the template file based on your installation pathway:

```bash
# If using the plugin installation
cp ~/.gemini/config/plugins/predicate/templates/AGENTS.md ./AGENTS.md

# If using the submodule installation
cp .agents/templates/AGENTS.md ./AGENTS.md
```

### Step 2: Configure Settings

Edit the `AGENTS.md` file in your project root:

1. Fill in the **Project Overview** — what the project does and its high-level architecture.
2. Set **Active Rules** — list the rules that apply to your project.
3. Add **Build & Commands** — how to test, build, and lint your project.
4. Fill in remaining sections as applicable.

Example active rules for a Go project:

```markdown
**Active Rules:**

- go.md (Go idioms)
- sdma.md (Domain modeling)
```

---

## 3. Verify Integration

Verify that your project structure conforms to the chosen installation method:

**If using the Submodule installation:**
```
your-project/
├── .agents/               # The Predicate submodule
│   ├── rules/             # Axioms and glob/model rules
│   ├── skills/            # Custom skills and scripts
│   └── workflows/         # Slash command workflow files
└── AGENTS.md              # Project metadata & active rules
```

**If using the Global Plugin installation:**
```
your-project/
└── AGENTS.md              # Project metadata & active rules (plugin loads rules/skills/workflows globally)
```

Verify that your agent of choice (e.g., Claude Code or Antigravity CLI) detects the configuration:
- In the agent chat, type `/` to see the workflows (like `/core`, `/plan`, `/sketch`) listed in the commands menu.
- Open files to verify glob rules load automatically (e.g., editing a Rust file triggers the rules in `rules/rust.md`).

---

## Next Steps

- **Workflows:** Trigger procedures like `/sketch`, `/plan`, `/core`, or `/doc` directly.
- **Custom content:** See [docs/authoring.md](authoring.md) for writing your own rules, skills, and workflows.
- **Forking:** Fork the Predicate repository and point your submodule to your fork to maintain custom organizational rulesets.

