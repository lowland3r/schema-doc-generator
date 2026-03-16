# Schema Doc Generator Plugin Design

## Summary

The `schema-doc-generator` plugin automates the two-step workflow currently performed manually in this repository: extracting a SQL Server database schema into structured text files, and then generating a set of human-readable reference documents from those files. It packages the existing extraction SQL and generation job specification as companion files inside a Claude Code plugin, exposing three slash commands — `/extract-schema`, `/generate-docs`, and `/schema-docs` — that are thin entry points into three underlying skills. The skills contain all orchestration logic; no custom agents are defined. Worker, critic, and summarizer agents are borrowed from the `ed3d-basic-agents` plugin via qualified references.

The generation skill makes an adaptive dispatch decision based on how much data the extraction produced. For smaller databases (under 50KB of extracted text), a single high-capability agent receives the full job specification and all 16 input files and produces all 8 output documents in one pass. For larger databases, the work fans out to parallel workers that each own a disjoint slice of the output, followed by parallel critic agents that review every document under a sliding window, and a final summarizer agent that reconciles their feedback before writing the result. The 16-file pipe-delimited format produced by extraction templates is the central contract: engine-specific SQL templates produce it, the generation job spec consumes it, and nothing else in the plugin needs to understand either the source database dialect or the output document format.

## Definition of Done

1. A standalone Claude Code plugin (`schema-doc-generator`) exists with `plugin.json`, `skills/`, and `commands/` directories following ed3d conventions.
2. `/extract-schema` command generates a PowerShell (dbatools-preferred) or sqlcmd extraction script for MSSQL databases. Script is presented to the user, not auto-executed.
3. `/generate-docs` command reads 16 extraction files from `references/databases/{DB_NAME}/`, adaptively chooses single-pass or fan-out based on corpus size, and produces 8 reference doc targets in `docs/database_reference/{DB_NAME}/`.
4. `/schema-docs` command orchestrates the full pipeline with human gates between extraction and generation stages.
5. Plugin references `ed3d-basic-agents` for worker/critic/summarizer agents (no custom agents).
6. Extraction template architecture supports future MySQL/PostgreSQL engines via additional template files without changing skill logic.
7. The 16-file pipe-delimited interface is the contract between extraction and generation. Engine-specific templates produce it; the generation job spec consumes it.

## Acceptance Criteria

### schema-doc-generator.AC1: Extraction Script Generation
- **AC1.1 Success:** MSSQL extraction produces a `.ps1` script using dbatools `Invoke-DbaQuery` when PowerShell is detected
- **AC1.2 Success:** MSSQL extraction falls back to `sqlcmd` command when PowerShell is not available
- **AC1.3 Success:** Target directory `references/databases/{DB_NAME}/` is created with 16 empty placeholder files
- **AC1.4 Success:** Generated script is presented to user in output, NOT auto-executed
- **AC1.5 Failure:** Missing database name or server prompts user for input rather than erroring
- **AC1.6 Edge:** Existing target directory is not overwritten; user is warned if files already exist

### schema-doc-generator.AC2: Single-Pass Doc Generation
- **AC2.1 Success:** All 16 extraction files are located and validated (exist check, empty-is-OK noted)
- **AC2.2 Success:** Corpus <50KB dispatches one opus agent with full job spec; all 8 doc targets produced
- **AC2.3 Success:** Output written to `docs/database_reference/{DB_NAME}/` with correct directory structure
- **AC2.4 Success:** `02_tables/` subdirectory contains per-domain files named `{nn}_{domain}.md`
- **AC2.5 Failure:** Missing extraction directory produces clear error message with expected path
- **AC2.6 Edge:** Empty extraction files (e.g., no triggers) produce brief "none found" doc sections, not errors

### schema-doc-generator.AC3: Fan-Out Doc Generation
- **AC3.1 Success:** Corpus >=50KB triggers fan-out with parallel workers (opus), parallel critics (sonnet), sequential summarizer (opus)
- **AC3.2 Success:** Each output document is reviewed by exactly 3 critics via sliding window
- **AC3.3 Success:** Summarizer applies corrections where 2+ critics agree on an issue
- **AC3.4 Success:** Final QA report is produced listing corrections applied and open questions
- **AC3.5 Edge:** Single critic flags an issue — summarizer verifies against source before applying

### schema-doc-generator.AC4: Multi-Engine Template Architecture
- **AC4.1 Success:** `templates/` directory under extraction skill contains `mssql.sql`
- **AC4.2 Success:** Adding a new engine requires only a new `.sql` template file and a command-pattern block in SKILL.md
- **AC4.3 Success:** Job spec (`job-spec.md`) is engine-agnostic; same spec used regardless of source RDBMS

### schema-doc-generator.AC5: End-to-End Pipeline
- **AC5.1 Success:** `/schema-docs` walks through setup, extraction, validation, generation, summary in order
- **AC5.2 Success:** Human gate exists between extraction script presentation and generation start
- **AC5.3 Success:** Post-generation summary highlights items from `07_annotations_needed.md`
- **AC5.4 Success:** Validation step reports which of 16 files have data and which are empty
- **AC5.5 Edge:** User cancels after extraction; no generation runs, partial state is clean

### schema-doc-generator.AC6: Plugin Conventions
- **AC6.1 Success:** `plugin.json` follows ed3d manifest format (name, version, description, author)
- **AC6.2 Success:** Description field documents `ed3d-basic-agents` dependency
- **AC6.3 Success:** Skills use SKILL.md with correct YAML frontmatter (name, description, user-invocable)
- **AC6.4 Success:** Commands are thin `.md` wrappers delegating to skills
- **AC6.5 Success:** Agent references use qualified `plugin-name:agent-name` syntax

## Glossary

- **ed3d plugin ecosystem**: A family of Claude Code plugins sharing a common convention for manifests (`plugin.json`), skill definitions (`SKILL.md`), and cross-plugin agent references. This plugin is designed to be compatible with and installable alongside those plugins.
- **ed3d-basic-agents**: A companion plugin that provides reusable named agents (e.g., `opus-general-purpose`, `sonnet-general-purpose`). This plugin references those agents via qualified `plugin-name:agent-name` syntax rather than defining its own.
- **skill**: In the ed3d plugin convention, a skill is a `SKILL.md` file containing instructions that tell a model how to perform a specific task. Skills contain the real logic; commands are thin wrappers that invoke them.
- **command (slash command)**: A `.md` file registered as a `/command-name` entry point in Claude Code. In this plugin, commands delegate immediately to a skill with no additional logic.
- **plugin.json**: The plugin manifest file. Declares name, version, description, and author. Dependencies on other plugins are noted in the description field (no formal dependency mechanism exists).
- **fan-out**: A generation pattern in which work is divided across multiple parallel worker agents, each responsible for a disjoint subset of output documents. Results are subsequently reviewed and reconciled by critic and summarizer agents.
- **sliding window (critic review)**: An arrangement in which each output document segment is reviewed by exactly 3 critics, and each critic reviews exactly 3 segments, ensuring cross-document consistency.
- **corpus**: The combined content of the 16 pipe-delimited extraction files for a given database. Used as a measure of total input size to decide between single-pass and fan-out generation.
- **16-file interface**: The contract between extraction and generation: exactly 16 pipe-delimited text files, one per schema information category, produced by an engine-specific SQL template and consumed by the engine-agnostic generation job spec.
- **job spec (job-spec.md)**: A generation specification written as a model prompt. Defines the expected inputs (the 16 files), the 8 output documents to produce, processing rules, and style requirements. Engine-agnostic by design.
- **dbatools**: A PowerShell module for SQL Server administration. The extraction skill uses its `Invoke-DbaQuery` cmdlet as the preferred mechanism for running extraction SQL.
- **sqlcmd**: The Microsoft command-line utility for running T-SQL scripts against SQL Server. Used as the fallback extraction mechanism when PowerShell/dbatools is not available.
- **FOR XML PATH**: A T-SQL technique for aggregating multiple rows into a delimited string. Used in the extraction script as a substitute for `STRING_AGG` (which requires SQL Server 2017+).
- **compatibility level**: A SQL Server database setting that controls which T-SQL features are available. The extraction script targets level 100 (SQL Server 2008).
- **pipe-delimited**: A text file format using the `|` character as a column separator, chosen to avoid conflicts with commas in SQL definitions.
- **marketplace**: A GitHub-hosted registry of ed3d plugins. Phase 6 registers the plugin there for installation by other users.
- **human gate**: A deliberate pause in the pipeline where the skill waits for the user to take a manual action before proceeding.
- **UDT (user-defined type)**: A named SQL Server type built on a base type. Captured in extraction file 14.
- **extended properties**: SQL Server metadata key-value pairs attached to database objects. Captured in extraction file 15.

## Architecture

### Approach

Skill-heavy plugin with thin slash commands and no custom agents. Three skills contain the orchestration logic; three commands expose them as `/extract-schema`, `/generate-docs`, and `/schema-docs`. Worker and critic agents are borrowed from `ed3d-basic-agents` via qualified references (`ed3d-basic-agents:opus-general-purpose`, `ed3d-basic-agents:sonnet-general-purpose`).

### Plugin Structure

```
schema-doc-generator/
  .claude-plugin/
    plugin.json                         # Manifest; description notes ed3d-basic-agents dependency
  skills/
    generate-extraction-script/
      SKILL.md                          # Orchestrates: detect engine, generate script, create dirs
      templates/
        mssql.sql                       # 16-section T-SQL extraction (from .github/scripts/)
    generate-reference-docs/
      SKILL.md                          # Orchestrates: measure corpus, single-pass or fan-out
      job-spec.md                       # Generation spec (from .github/jobs/)
      fanout-layout.md                  # Worker/critic segment definitions and sliding window
    plan-schema-docs/
      SKILL.md                          # End-to-end pipeline with human gates
  commands/
    extract-schema.md                   # Thin wrapper -> generate-extraction-script skill
    generate-docs.md                    # Thin wrapper -> generate-reference-docs skill
    schema-docs.md                      # Thin wrapper -> plan-schema-docs skill
```

### Data Flow

```
User provides: engine, server, database name
  |
  v
[generate-extraction-script]
  |-- Selects template (templates/mssql.sql)
  |-- Detects PowerShell availability
  |-- Generates: .ps1 (dbatools) or sqlcmd shell command
  |-- Creates: references/databases/{DB_NAME}/ with 16 placeholders
  |-- Presents script to user
  |
  === HUMAN GATE: user executes script ===
  |
  v
16 pipe-delimited text files in references/databases/{DB_NAME}/
  |
  v
[generate-reference-docs]
  |-- Validates 16 files exist (empty is OK for some sections)
  |-- Measures total corpus size
  |-- IF <50KB: single opus agent with job-spec.md
  |-- IF >=50KB: fan-out per fanout-layout.md
  |     |-- Workers (opus, parallel): each owns output document segments
  |     |-- Critics (sonnet, parallel): sliding window review
  |     |-- Summarizer (opus): apply corrections, produce QA report
  |-- Writes output to docs/database_reference/{DB_NAME}/
  |
  v
8 reference documents:
  00_overview.md, 01_type_reference.md, 02_tables/{nn}_{domain}.md,
  03_stored_procedures.md, 04_views.md, 05_functions.md,
  06_business_logic.md, 07_annotations_needed.md
```

### Key Contracts

**The 16-file interface** is the central contract. Extraction templates produce these files; the generation job spec consumes them. Each file is pipe-delimited with a header row. The mapping:

| File | Content |
|------|---------|
| `01_database_metadata.txt` | Name, compat level, collation, create date |
| `02_schemas.txt` | Schema names and object counts |
| `03_tables_columns.txt` | All columns: table, name, type, nullable, default, identity |
| `04_primary_keys.txt` | PK name, table, columns |
| `05_foreign_keys.txt` | FK name, parent/referenced table, columns, cascade rules |
| `06_indexes.txt` | Index name, table, columns, type, uniqueness |
| `07_unique_constraints.txt` | Unique constraint definitions |
| `08_check_constraints.txt` | Check constraint definitions |
| `09_views.txt` | View names and full SQL definitions |
| `10_stored_procedures.txt` | Procedure names and full SQL definitions |
| `11_procedure_parameters.txt` | Parameter names, types, directions, defaults |
| `12_functions.txt` | Function names and definitions |
| `13_triggers.txt` | Trigger names, tables, events, definitions |
| `14_user_defined_types.txt` | UDT names and base types |
| `15_extended_properties.txt` | Extended property values on objects |
| `16_row_counts.txt` | Table names and row counts |

Files 07, 12, 13, 14, 15 are commonly empty depending on database design. The generation skill must handle empty files gracefully.

**The fan-out layout** defines how documents are segmented across workers when corpus exceeds the single-pass threshold:

| Segment | Output Documents | Worker |
|---------|-----------------|--------|
| S01 | `00_overview.md` | W01 |
| S02 | `01_type_reference.md` | W01 |
| S03 | `02_tables/` | W01 |
| S04 | `03_stored_procedures.md` | W02 |
| S05 | `04_views.md` + `05_functions.md` | W02 |
| S06 | `06_business_logic.md` + `07_annotations_needed.md` | W02 |

Critics use a sliding window (each segment reviewed by 3 critics, each critic reviews 3 segments) to ensure cross-document consistency.

### Adaptive Generation Decision

The skill measures total byte size of the 16 input files:

- **<50KB:** Single `ed3d-basic-agents:opus-general-purpose` agent receives the full job spec and all 16 files. Produces all 8 output targets in one pass. No critic review.
- **>=50KB:** Fan-out with 2 workers (opus, parallel), 6 critics (sonnet, parallel after workers), 1 summarizer (opus, sequential after critics). Workers read all 16 files but own disjoint output segments. Critics verify accuracy against source data.

The 50KB threshold is based on the DEFECT_TRACKING experience: ~25K tokens of extraction data fit comfortably in a single pass; the fan-out added quality via critic review but was not strictly necessary for context reasons. The threshold balances quality (critic review for larger databases) against cost and speed.

## Existing Patterns

### From This Repository

The current repo has a proven manual workflow:
- `.github/scripts/schema_extraction.sql` — 431-line T-SQL extraction script with 16 sections, compatible with SQL Server 2008+ (compat level 100). Uses `FOR XML PATH` instead of `STRING_AGG`.
- `Extract-Schema.ps1` — PowerShell wrapper using dbatools `Invoke-DbaQuery`, splits the SQL by section dividers, exports pipe-delimited CSV.
- `.github/jobs/generate_reference_docs.md` — 160-line generation spec written in second person as a model prompt. Defines input format, 8 output targets, 7 processing rules, and style requirements.

The plugin bundles the extraction SQL and job spec as companion files in their respective skill directories. These are the same files, relocated into the plugin structure.

### From ed3d Plugin Ecosystem

The plugin follows conventions established by `ed3d-basic-agents`, `ed3d-plan-and-execute`, and `ed3d-research-agents`:
- `plugin.json` uses the minimal manifest format (name, description, version, author)
- Skills use SKILL.md with YAML frontmatter (`name`, `description`, `user-invocable`)
- Commands are thin `.md` wrappers that delegate to skills
- Cross-plugin agent references use qualified `plugin-name:agent-name` syntax
- Plugin dependency is communicated via `plugin.json` description field (no formal dependency mechanism exists)

### New Patterns Introduced

- **Bundled SQL templates** in skill directories (`templates/mssql.sql`). No precedent in ed3d plugins, but follows the pattern of companion files alongside SKILL.md (similar to `compute_layout.py` in the fan-out skill).
- **Adaptive agent dispatch** based on measured input size. The fan-out skill always fans out; this skill decides between single-pass and fan-out. The decision logic lives in the SKILL.md itself.

## Implementation Phases

<!-- START_PHASE_1 -->
### Phase 1: Plugin Scaffold

**Goal:** Create the plugin directory structure with `plugin.json` and empty skill/command stubs.

**Components:**
- `.claude-plugin/plugin.json` — manifest with name, version, description (noting ed3d-basic-agents dependency)
- `skills/generate-extraction-script/SKILL.md` — stub
- `skills/generate-reference-docs/SKILL.md` — stub
- `skills/plan-schema-docs/SKILL.md` — stub
- `commands/extract-schema.md` — stub
- `commands/generate-docs.md` — stub
- `commands/schema-docs.md` — stub

**Dependencies:** None (first phase)

**Done when:** Plugin directory exists with valid `plugin.json` and all stub files. Plugin can be registered in a marketplace manifest.
<!-- END_PHASE_1 -->

<!-- START_PHASE_2 -->
### Phase 2: Extraction Script Generation Skill

**Goal:** The `generate-extraction-script` skill produces a runnable extraction script for MSSQL databases.

**Components:**
- `skills/generate-extraction-script/SKILL.md` — full skill logic: detect PowerShell/engine, generate script, create target directory with placeholders
- `skills/generate-extraction-script/templates/mssql.sql` — the 16-section T-SQL extraction script (sourced from `.github/scripts/schema_extraction.sql`)
- `commands/extract-schema.md` — thin wrapper delegating to the skill

**Dependencies:** Phase 1 (plugin scaffold)

**Covers:** schema-doc-generator.AC1.x (extraction script generation), schema-doc-generator.AC4.x (multi-engine template architecture)

**Done when:** `/extract-schema` invocation prompts for database details, generates a PowerShell/dbatools script (or sqlcmd fallback), creates the target directory, and presents the script to the user without executing it.
<!-- END_PHASE_2 -->

<!-- START_PHASE_3 -->
### Phase 3: Reference Doc Generation Skill (Single-Pass Path)

**Goal:** The `generate-reference-docs` skill can generate all 8 reference documents from a set of 16 extraction files using a single opus agent.

**Components:**
- `skills/generate-reference-docs/SKILL.md` — input validation, corpus measurement, single-pass agent dispatch, output placement
- `skills/generate-reference-docs/job-spec.md` — the generation specification (sourced from `.github/jobs/generate_reference_docs.md`)
- `commands/generate-docs.md` — thin wrapper delegating to the skill

**Dependencies:** Phase 1 (plugin scaffold)

**Covers:** schema-doc-generator.AC2.x (single-pass generation)

**Done when:** `/generate-docs` invocation reads 16 extraction files, dispatches an opus agent with the job spec, and writes 8 reference documents to the correct output directory. Handles empty input files gracefully.
<!-- END_PHASE_3 -->

<!-- START_PHASE_4 -->
### Phase 4: Reference Doc Generation Skill (Fan-Out Path)

**Goal:** The `generate-reference-docs` skill can adaptively fan out to workers/critics/summarizer for large databases.

**Components:**
- `skills/generate-reference-docs/SKILL.md` — extended with adaptive decision gate and fan-out orchestration logic
- `skills/generate-reference-docs/fanout-layout.md` — segment definitions, worker assignments, critic sliding window template

**Dependencies:** Phase 3 (single-pass path must work first)

**Covers:** schema-doc-generator.AC3.x (fan-out generation and critic review)

**Done when:** For input corpora >=50KB, the skill dispatches parallel workers (opus), parallel critics (sonnet), and a summarizer (opus). Critics produce structured reviews. Summarizer applies corrections. Output documents are placed correctly.
<!-- END_PHASE_4 -->

<!-- START_PHASE_5 -->
### Phase 5: End-to-End Pipeline Skill

**Goal:** The `plan-schema-docs` skill orchestrates the full extraction-to-documentation pipeline with human gates.

**Components:**
- `skills/plan-schema-docs/SKILL.md` — full pipeline orchestration: setup, extraction (delegates to generate-extraction-script), validation, generation (delegates to generate-reference-docs), summary
- `commands/schema-docs.md` — thin wrapper delegating to the skill

**Dependencies:** Phase 2 (extraction skill), Phase 3 or 4 (generation skill)

**Covers:** schema-doc-generator.AC5.x (end-to-end pipeline with human gates)

**Done when:** `/schema-docs` walks the user through the full pipeline. Human gates exist between extraction and generation. Post-generation summary highlights `07_annotations_needed.md` items for review.
<!-- END_PHASE_5 -->

<!-- START_PHASE_6 -->
### Phase 6: Marketplace Registration

**Goal:** Plugin is registered in a GitHub-hosted marketplace and installable.

**Components:**
- Marketplace repository structure (following ed3d-plugins conventions)
- `marketplace.json` with the schema-doc-generator plugin entry
- Plugin source directory within the marketplace repo

**Dependencies:** Phase 5 (all skills and commands functional)

**Done when:** Plugin is installable from the marketplace. `plugin.json` description accurately documents the `ed3d-basic-agents` dependency.
<!-- END_PHASE_6 -->

## Additional Considerations

**Multi-engine extensibility:** Adding MySQL or PostgreSQL requires only a new `templates/{engine}.sql` file and a command-pattern block in the extraction skill's SKILL.md. The 16-file interface and generation job spec are engine-agnostic. The extraction SQL templates will need to produce equivalent output despite differences in system catalog schemas (`information_schema` vs `pg_catalog` vs `sys.*`).

**Corpus size threshold:** The 50KB adaptive threshold is a starting heuristic. It may need tuning as more databases are processed. The threshold is a single value in the generation skill's SKILL.md, easy to adjust.

**Empty extraction files:** Files 07 (unique constraints), 12 (functions), 13 (triggers), 14 (UDTs), and 15 (extended properties) are commonly empty for Access-backed SQL Server databases. The generation skill and job spec both handle this — empty sections produce brief "none found" documentation rather than errors.
