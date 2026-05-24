# Getting Started with Predicate

Configure Predicate in your environment, activate skills, and verify correct agent integration.

**Audience:** Developers integrating Predicate skills.

---

## 1. Installation Pathways

Depending on your agent runner's capabilities, choose between a centralized plugin installation or a project-level Git submodule.

### Option A: Global Plugin Installation (Recommended)

For agent runners supporting standardized plugin manifests (e.g., Antigravity CLI, Claude Code, and other compliant agentic environments utilizing `plugin.json`), you can install Predicate globally. This exposes all skills across your workspaces without manual repository nesting.

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

While modern agent runners can discover and execute skills directly from a globally loaded plugin without local files, placing an `AGENTS.md` configuration file in your project's root directory is highly recommended. It provides project-specific context (e.g., build commands and architectural overviews) and explicit skill routing.

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
2. Set **Active Skills** — list the skills that apply to your project.
3. Add **Build & Commands** — how to test, build, and lint your project.

Example active skills for a Go project:

```markdown
**Active Skills:**

- go (Go idioms)
- sdma (Domain modeling)
```

---

## 3. Verify Integration

Verify that your agent runner successfully detects and loads the Predicate configuration.

### For Antigravity CLI (`agy`)

Antigravity CLI natively discovers and mounts Predicate skills from the global plugin directory or the local `.agents/` workspace path.

1. **Verify Startup Skills List**: When you launch the CLI, check the startup metadata block. Under the **Available skills** header, you should see the loaded Predicate skills:
   - `constitution` — Foundational ethics and structural principles.
   - `engineering` — Technical guidelines and safety rules.
   - `rust` or `go` — Language-specific idioms and conventions.
   - `plan` or `core` — Workflow SOPs.
2. **Verify Semantic Triggering**: To start a workflow, simply direct the agent using natural language (e.g., *"Let's run the plan workflow"* or *"Help me sketch out this design"*). The runner will match your request against the skill descriptions and load the required skill context.

---

## Next Steps

- **Custom content:** See [docs/authoring.md](authoring.md) for writing your own custom skills.
- **Forking:** Fork the Predicate repository and point your submodule to your fork to maintain custom organizational skills.

