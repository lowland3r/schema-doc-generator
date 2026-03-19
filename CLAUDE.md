# schema-doc-generator

Last verified: 2026-03-19

## What This Is

A Claude Code plugin that automates database schema extraction and reference documentation generation. Currently supports MSSQL only.

Requires the `ed3d-basic-agents` plugin for fan-out generation workers.

## Plugin Structure
- `.claude-plugin/plugin.json` - Plugin manifest (v0.1.0)
- `commands/` - User-facing slash commands (thin wrappers that invoke skills)
- `skills/` - Implementation logic (3 skills with bundled companion files)
- `docs/` - Design plans, implementation plans (not generated output)

## Commands
- `/extract-schema` - Generate a database extraction script
- `/generate-docs` - Generate reference docs from extraction files
- `/schema-docs` - Full pipeline (extraction + generation with human gates)

## Key Contracts

### The 17-File Interface
The extraction skill produces 17 pipe-delimited text files in `references/databases/{DB_NAME}/`. The generation skill consumes these same 17 files. This is the primary contract between the two skills. Files are numbered `01_` through `17_` with fixed names. Adding a new database engine means producing these same 17 files.

### Output Structure
Generated reference docs go to `docs/database_reference/{DB_NAME}/` with 8 output targets including a `02_tables/` subdirectory for per-domain table files.

### Generation Paths
- Corpus <50KB: single-pass (one agent)
- Corpus >=50KB: fan-out (2 workers, 6 critics, 1 summarizer)

## Conventions
- Skills are prompt-only (no executable code besides the SQL template)
- Commands are thin: each just invokes its corresponding skill
- The extraction script is generated but NOT executed by the plugin (human gate)
- Skills activate `ed3d-house-style` sub-skills for coding and writing quality

## Plugin-Dev Enforcement

`plugin-dev-kit` is the active enforcement mechanism for plugin-dev skills in this repo. When writing or editing SKILL.md files, updating plugin.json, or writing documentation for this plugin, those skills activate contextually — no explicit invocation required.

Install at user level: `claude plugin install https://github.com/lowland3r/plugin-dev-kit`
