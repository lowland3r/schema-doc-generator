# Schema Doc Generator — Phase 1: Plugin Scaffold

**Goal:** Create the plugin directory structure with `plugin.json` and empty skill/command stubs.

**Architecture:** Standalone Claude Code plugin following ed3d conventions. Skills contain logic; commands are thin wrappers. No custom agents — references `ed3d-basic-agents`.

**Tech Stack:** Markdown (SKILL.md, commands), JSON (plugin.json)

**Scope:** Phase 1 of 6 from design plan

**Codebase verified:** 2026-03-16. Plugin repo at `C:\Users\jake.wimmer\Repositories\schema-doc-generator\` contains only `docs/design-plans/`. No `.claude-plugin/`, `skills/`, or `commands/` directories exist.

---

## Acceptance Criteria Coverage

This phase is infrastructure — verified operationally, not by tests.

### schema-doc-generator.AC6: Plugin Conventions
- **AC6.1 Success:** `plugin.json` follows ed3d manifest format (name, version, description, author)
- **AC6.2 Success:** Description field documents `ed3d-basic-agents` dependency
- **AC6.3 Success:** Skills use SKILL.md with correct YAML frontmatter (name, description, user-invocable)
- **AC6.4 Success:** Commands are thin `.md` wrappers delegating to skills

---

<!-- START_TASK_1 -->
### Task 1: Create plugin.json

**Files:**
- Create: `.claude-plugin/plugin.json`

**Step 1: Create the file**

```json
{
    "name": "schema-doc-generator",
    "description": "Automates database schema extraction and reference documentation generation. Requires ed3d-basic-agents.",
    "version": "0.1.0",
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
```

**Step 2: Verify**

File exists and is valid JSON.

**Step 3: Commit**

```bash
git add .claude-plugin/plugin.json
git commit -m "chore: initialize plugin manifest"
```
<!-- END_TASK_1 -->

<!-- START_TASK_2 -->
### Task 2: Create skill stubs

**Files:**
- Create: `skills/generate-extraction-script/SKILL.md`
- Create: `skills/generate-reference-docs/SKILL.md`
- Create: `skills/plan-schema-docs/SKILL.md`

**Step 1: Create generate-extraction-script stub**

```markdown
---
name: generate-extraction-script
description: Use when you need to generate a database schema extraction script for MSSQL (future: MySQL, PostgreSQL) — detects PowerShell/dbatools, creates extraction commands, and sets up the target directory
user-invocable: false
---

# Generate Extraction Script

Stub — to be implemented in Phase 2.
```

All three skills use `user-invocable: false` because they are invoked indirectly via their corresponding slash commands (`/extract-schema`, `/generate-docs`, `/schema-docs`), not called directly by users.

**Step 2: Create generate-reference-docs stub**

```markdown
---
name: generate-reference-docs
description: Use when you have populated schema extraction files and need to generate structured reference documentation — adaptively chooses single-pass or fan-out based on corpus size
user-invocable: false
---

# Generate Reference Docs

Stub — to be implemented in Phase 3.
```

**Step 3: Create plan-schema-docs stub**

```markdown
---
name: plan-schema-docs
description: Use when you need to walk through the full database documentation pipeline from extraction to reference doc generation — orchestrates skills with human gates between stages
user-invocable: false
---

# Plan Schema Docs

Stub — to be implemented in Phase 5.
```

**Step 4: Verify**

Each file exists at the correct path and has valid YAML frontmatter with `name`, `description`, and `user-invocable` fields.

**Step 5: Commit**

```bash
git add skills/
git commit -m "chore: add skill stubs for extraction, generation, and pipeline"
```
<!-- END_TASK_2 -->

<!-- START_TASK_3 -->
### Task 3: Create command stubs

**Files:**
- Create: `commands/extract-schema.md`
- Create: `commands/generate-docs.md`
- Create: `commands/schema-docs.md`

**Step 1: Create extract-schema command**

```markdown
---
description: Generate a database schema extraction script
---

Use your Skill tool to engage the `generate-extraction-script` skill. Follow it exactly as written.
```

**Step 2: Create generate-docs command**

```markdown
---
description: Generate reference documentation from schema extraction files
---

Use your Skill tool to engage the `generate-reference-docs` skill. Follow it exactly as written.
```

**Step 3: Create schema-docs command**

```markdown
---
description: Walk through the full database documentation pipeline (extraction + generation)
---

Use your Skill tool to engage the `plan-schema-docs` skill. Follow it exactly as written.
```

**Step 4: Verify**

Each file exists and has YAML frontmatter with a `description` field. Body delegates to the corresponding skill.

**Step 5: Commit**

```bash
git add commands/
git commit -m "chore: add command stubs for extract-schema, generate-docs, schema-docs"
```
<!-- END_TASK_3 -->
