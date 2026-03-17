# Schema Doc Generator — Phase 6: Marketplace Registration

**Goal:** Plugin is registered in a GitHub-hosted marketplace and installable by other users.

**Architecture:** Create a new marketplace repository following ed3d-plugins conventions. The marketplace contains a `marketplace.json` manifest and the plugin source directory. Users install via Claude Code's plugin system.

**Tech Stack:** JSON (marketplace.json), Git

**Scope:** Phase 6 of 6 from design plan

**Codebase verified:** 2026-03-16. Ed3d marketplace at `C:\Users\jake.wimmer\.claude\plugins\marketplaces\ed3d-plugins\.claude-plugin\marketplace.json` uses flat plugin list with `source` relative paths.

---

## Acceptance Criteria Coverage

This phase is infrastructure — verified operationally.

### schema-doc-generator.AC6: Plugin Conventions
- **AC6.1 Success:** `plugin.json` follows ed3d manifest format (name, version, description, author)
- **AC6.2 Success:** Description field documents `ed3d-basic-agents` dependency
- **AC6.5 Success:** Agent references use qualified `plugin-name:agent-name` syntax

---

<!-- START_TASK_1 -->
### Task 1: Create marketplace repository structure

**Files:**
- Create: New git repository for the marketplace
- Create: `.claude-plugin/marketplace.json`
- Create: `plugins/schema-doc-generator/` (symlink or copy of plugin source)

**Implementation:**

The marketplace is a separate GitHub repository that indexes one or more plugins. Structure follows ed3d-plugins:

```
{marketplace-name}/
  .claude-plugin/
    marketplace.json
  plugins/
    schema-doc-generator/     # Plugin source (or git submodule)
      .claude-plugin/
        plugin.json
      skills/
      commands/
```

Create `marketplace.json`:

```json
{
    "$schema": "https://anthropic.com/claude-code/marketplace.schema.json",
    "name": "{marketplace-name}",
    "version": "1.0.0",
    "description": "Claude Code plugins for database documentation and schema analysis",
    "owner": {
        "name": "lowlander"
    },
    "plugins": [
        {
            "name": "schema-doc-generator",
            "description": "Automates database schema extraction and reference documentation generation. Requires ed3d-basic-agents.",
            "version": "0.1.0",
            "source": "./plugins/schema-doc-generator",
            "author": {
                "name": "lowlander"
            },
            "license": "UNLICENSED",
            "keywords": [
                "database",
                "schema",
                "documentation",
                "mssql"
            ]
        }
    ]
}
```

The `source` field uses a relative path to the plugin directory within the marketplace repo.

**Note:** The user needs to decide on:
- Marketplace repository name
- Whether to use git submodules (plugin stays in its own repo, marketplace references it) or direct inclusion (plugin source copied into marketplace repo)
- GitHub organization or personal account

Use AskUserQuestion to gather these details before proceeding.

**Verification:**

Marketplace repo exists with valid `marketplace.json`. Plugin source is accessible at the path specified in `source`.

**Commit:**

```bash
git add .claude-plugin/marketplace.json plugins/
git commit -m "feat: initialize marketplace with schema-doc-generator plugin"
```
<!-- END_TASK_1 -->

<!-- START_TASK_2 -->
### Task 2: Verify plugin.json accuracy

**Files:**
- Verify: `plugins/schema-doc-generator/.claude-plugin/plugin.json`

**Implementation:**

After placing the plugin in the marketplace, verify `plugin.json` is accurate:

1. `name` matches the marketplace entry name
2. `version` matches the marketplace entry version
3. `description` includes "Requires ed3d-basic-agents"
4. All skill and command files are present and correctly structured

Run a manual verification:
- List all skills: `ls plugins/schema-doc-generator/skills/*/SKILL.md`
- List all commands: `ls plugins/schema-doc-generator/commands/*.md`
- Verify each SKILL.md has valid YAML frontmatter
- Verify each command delegates to a skill

**Verification:**

Plugin installs from marketplace. All three slash commands (`/extract-schema`, `/generate-docs`, `/schema-docs`) are available after installation.

**Commit:**

No additional commit needed if plugin.json is already correct.
<!-- END_TASK_2 -->

<!-- START_TASK_3 -->
### Task 3: Push marketplace to GitHub

**Files:**
- None (git operation only)

**Implementation:**

1. Create a GitHub repository for the marketplace
2. Push the marketplace repo
3. Test installation by adding the marketplace to Claude Code's plugin settings

The user should verify:
- Plugin appears in Claude Code after marketplace installation
- `/extract-schema`, `/generate-docs`, and `/schema-docs` commands are available
- Skills are discoverable and invocable

**Verification:**

Commands are functional after fresh installation from marketplace.

**Commit:**

```bash
git push -u origin main
```
<!-- END_TASK_3 -->
