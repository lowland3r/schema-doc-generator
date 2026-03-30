# schema-doc-generator

Last verified: 2026-03-30

## What This Is

A Claude Code plugin that automates database schema extraction and reference documentation generation. Currently supports MSSQL only.

Requires the `ed3d-basic-agents` plugin for fan-out generation workers.

## Plugin Structure
- `.claude-plugin/plugin.json` - Plugin manifest (v0.2.0)
- `commands/` - User-facing slash commands (thin wrappers that invoke skills)
- `skills/` - Implementation logic (3 skills with bundled resources)
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

## Skill Contracts

Contracts and invariants for each skill, consolidated from former per-skill CLAUDE.md companions.

### generate-extraction-script

- **Exposes**: Invoked by `/extract-schema` command and `plan-schema-docs` pipeline
- **Guarantees**: Produces a PowerShell or sqlcmd script targeting the 17-file output format. Creates target directory with empty placeholder files before user runs extraction.
- **Expects**: User provides database engine (MSSQL only), server/instance, and database name
- **Boundary**: Does not execute database queries. Does not consume extraction output.
- **Invariants**:
  - Output file names are `{NN}_{snake_name}.txt` (01 through 17), never changed
  - Section 17 (lookup data) uses synthetic `_table_header` column for table delimiters
  - Only MSSQL templates exist; new engines require new `templates/{engine}.sql`

### generate-reference-docs

- **Exposes**: Invoked by `/generate-docs` command and `plan-schema-docs` pipeline
- **Guarantees**: Produces 8 output targets in `docs/database_reference/{DB_NAME}/`. Adaptively selects single-pass (<50KB) or fan-out (>=50KB) based on corpus size.
- **Expects**: 17 extraction files in `references/databases/{DB_NAME}/`. Files 01-03 and 16 are critical; others may be empty.
- **Boundary**: Does not create extraction files. Does not connect to databases.
- **Invariants**:
  - All 17 input files are read before any output is generated (Rule 1 in job-spec)
  - Output files never fabricate data; unknowns go to `07_annotations_needed.md`
  - Fan-out temp files go to platform-appropriate temp directory, not the repo

### plan-schema-docs

- **Exposes**: Invoked by `/schema-docs` command
- **Guarantees**: Walks through 6 stages in order. Never skips the human gate (Stage 3). Validates extraction files before generation.
- **Expects**: User provides database engine, server, and database name at Stage 1
- **Boundary**: Orchestrates only; does not generate scripts or documents itself
- **Invariants**:
  - Stages execute in order: setup, extraction, human gate, validation, generation, summary
  - Pipeline never auto-executes database queries
  - Fan-out QA report path referenced in Stage 6 comes from the generation skill's own output
