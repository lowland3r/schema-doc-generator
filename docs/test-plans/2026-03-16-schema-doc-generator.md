# Human Test Plan: schema-doc-generator

**Generated:** 2026-03-17
**Plugin version:** 0.1.0
**Coverage:** All 30 acceptance criteria (AC1–AC6)

---

## Prerequisites

- Claude Code installed with the `schema-doc-generator` plugin loaded
- The `ed3d-basic-agents` plugin installed (required dependency)
- Access to an MSSQL database server for extraction testing (or mock data for generation testing)
- Working directory: `C:/Users/jake.wimmer/Repositories/schema-doc-generator`

---

## Phase 1: Plugin Structure Verification

| Step | Action | Expected |
|------|--------|----------|
| 1.1 | Open `.claude-plugin/plugin.json` | Valid JSON. Contains `name: "schema-doc-generator"`, `version: "0.1.0"`, description mentioning "ed3d-basic-agents", `author.name: "lowlander"` (AC6.1, AC6.2) |
| 1.2 | Open each SKILL.md in `skills/*/SKILL.md` | Each starts with `---` YAML frontmatter containing `name`, `description`, and `user-invocable: false` (AC6.3) |
| 1.3 | Open each command file in `commands/*.md` | Each has YAML frontmatter with `description`. Body is a single sentence delegating via "Skill tool". No logic in command files. (AC6.4) |

---

## Phase 2: Extraction Script Generation

| Step | Action | Expected |
|------|--------|----------|
| 2.1 | Invoke `/extract-schema` without providing server or database name | Skill prompts for missing values. No error produced. (AC1.5) |
| 2.2 | Provide engine=MSSQL, server=`YOURSERVER`, database=`TESTDB` on a system with PowerShell + dbatools | A `.ps1` script is displayed. Script calls `Invoke-DbaQuery` and `Export-Csv -Delimiter '\|'`. Script is NOT executed. No database connection attempted. (AC1.1, AC1.4) |
| 2.3 | Simulate no-PowerShell environment (or test on system without it) and invoke `/extract-schema` | Output contains `sqlcmd` invocations with per-section commands. (AC1.2) |
| 2.4 | After step 2.2 completes, verify target directory | `references/databases/TESTDB/` exists with exactly 17 `.txt` files (`01_database_metadata.txt` through `17_lookup_data.txt`). All files empty. (AC1.3) |
| 2.5 | Write content into one file, invoke `/extract-schema` again for same database | Skill warns files exist and asks to proceed or cancel. Cancel leaves content untouched. (AC1.6) |
| 2.6 | Inspect `skills/generate-extraction-script/templates/mssql.sql` | Contains 17 numbered T-SQL sections. Uses `FOR XML PATH` (not `STRING_AGG`). Section 17 uses `QUOTENAME` and synthetic `_table_header` column. (AC4.1) |
| 2.7 | Read "Adding a New Engine" section in `skills/generate-extraction-script/SKILL.md` | Documents: (1) create `templates/{engine}.sql`, (2) produce 17 pipe-delimited sections, (3) add command-pattern block. States generation skill requires no changes. (AC4.2) |

---

## Phase 3: Single-Pass Doc Generation

| Step | Action | Expected |
|------|--------|----------|
| 3.1 | Populate `references/databases/TESTDB/` with 17 files, total < 50KB | Files ready for generation |
| 3.2 | Invoke `/generate-docs` for TESTDB | Reports file count, which are empty, which have data. No error for empty files. Reports "single-pass" mode. (AC2.1) |
| 3.3 | Observe agent dispatch | Single `ed3d-basic-agents:opus-general-purpose` agent dispatched. (AC2.2) |
| 3.4 | After generation, list `docs/database_reference/TESTDB/` | Contains: `00_overview.md`, `01_type_reference.md`, `03_stored_procedures.md`, `04_views.md`, `05_functions.md`, `06_business_logic.md`, `07_annotations_needed.md`. Subdirectory `02_tables/` exists. (AC2.3) |
| 3.5 | List files in `docs/database_reference/TESTDB/02_tables/` | Each file follows `{nn}_{domain}.md` pattern. At least one file present. (AC2.4) |
| 3.6 | Open docs corresponding to empty input files (e.g., triggers, functions) | Sections contain "none found" or equivalent. No errors, no fabricated content. (AC2.6) |
| 3.7 | Invoke `/generate-docs` for a database with no extraction directory (e.g., `NONEXISTENT`) | Error message includes expected path `references/databases/NONEXISTENT/` and suggests `/extract-schema` first. No crash. (AC2.5) |
| 3.8 | Read `skills/generate-reference-docs/job-spec.md` end to end | No MSSQL-specific references (`sys.`, `T-SQL`, `SQL Server`). All processing instructions use generic 17-file interface terms. (AC4.3) |

---

## Phase 4: Fan-Out Doc Generation

| Step | Action | Expected |
|------|--------|----------|
| 4.1 | Populate `references/databases/LARGEDB/` with extraction files totaling ≥ 50KB | Files ready for fan-out |
| 4.2 | Invoke `/generate-docs` for LARGEDB | Reports "fan-out" mode selected. (AC3.1) |
| 4.3 | Observe worker dispatch | Two workers dispatched using `ed3d-basic-agents:opus-general-purpose`, both in a single message (parallel). (AC3.1) |
| 4.4 | Observe critic dispatch (after workers complete) | Six critics dispatched using `ed3d-basic-agents:sonnet-general-purpose`. Critics launch only after workers finish. (AC3.1) |
| 4.5 | Observe summarizer dispatch (after critics complete) | One summarizer using `ed3d-basic-agents:opus-general-purpose`. Launches only after all 6 critics complete. (AC3.1) |
| 4.6 | Inspect critic review files in `$env:TEMP\fanout-LARGEDB\critics\` (Windows) | Each of segments S01–S06 appears in exactly 3 critic reviews. Compare against `fanout-layout.md` sliding window table. (AC3.2) |
| 4.7 | Read QA report at `$env:TEMP\fanout-LARGEDB\final-report.md` (Windows) | Report exists. Contains "corrections applied" section and "open questions" section. Non-empty, references specific documents. (AC3.4) |
| 4.8 | In QA report, find corrections where 2+ critics agreed | Report lists corrections with critic agreement count. (AC3.3) |
| 4.9 | In QA report, find any single-critic flags | Report shows summarizer verified against source input files before applying or rejecting. Reasoning provided. (AC3.5) |

---

## Phase 5: End-to-End Pipeline

| Step | Action | Expected |
|------|--------|----------|
| 5.1 | Invoke `/schema-docs` | Skill asks for database engine, server name, and database name. (AC5.1) |
| 5.2 | Provide MSSQL, server, and database | Proceeds to Stage 2 — generates and presents extraction script. (AC5.1) |
| 5.3 | After script is presented, observe conversation | Skill explicitly asks if extraction is complete. Does NOT automatically begin generation. Cancel option present. (AC5.2) |
| 5.4 | Choose "Cancel — I'll come back to this later" | Skill acknowledges cancellation. No generation dispatched. Extraction directory and files remain. Suggests resuming with `/generate-docs`. (AC5.5) |
| 5.5 | Re-invoke `/schema-docs`, complete extraction, choose "Yes, extraction is complete" | Stage 4 validation: lists files with data/sizes, empty files, and warnings for any missing critical files (01–03, 16). (AC5.4) |
| 5.6 | Observe generation stage | `generate-reference-docs` skill invoked; measures corpus; chooses single-pass or fan-out; produces docs. (AC5.1) |
| 5.7 | Observe post-generation summary | Reads `07_annotations_needed.md`; lists top-level question categories; suggests reviewing and filling in answers. (AC5.3) |

---

## End-to-End: Full Pipeline with Real Database

**Purpose:** Validate end-to-end with actual data.

1. Invoke `/schema-docs` with a real MSSQL server and database.
2. Review the generated extraction script for syntactic correctness.
3. Execute the script against the database.
4. Confirm 17 files are populated in `references/databases/{DB_NAME}/`.
5. Return to Claude Code and confirm extraction is complete.
6. Observe validation report.
7. Observe generation mode selection.
8. After generation, spot-check each output document:
   - Column types include full precision (e.g., `decimal(18,4)` not `decimal`)
   - FK relationships correctly documented
   - "None found" for empty inputs
   - No fabricated data
   - `07_annotations_needed.md` contains actionable questions

---

## Human Verification Required

| Criterion | Why Manual |
|-----------|------------|
| AC1.1, AC1.2 | Generated scripts must be syntactically valid; only live execution confirms correctness |
| AC2.2, AC2.6, AC3.3 | Content quality requires human judgment; file existence ≠ accuracy |
| AC5.2, AC5.5 | Human gate is a conversational interaction pattern; must observe in real time |
| AC3.1 | Verifying parallel/sequential dispatch timing requires observing agent launches live |
| AC3.2, AC3.5 | Critic review quality requires reading reviews and judging substance |
| AC4.3 | Engine-agnosticism requires reading job-spec.md and judging whether any phrasing implicitly assumes MSSQL |

---

## Traceability Matrix

| AC | Structurally Verified | Manual Step |
|----|----------------------|-------------|
| AC1.1 | — | 2.2 |
| AC1.2 | — | 2.3 |
| AC1.3 | — | 2.4 |
| AC1.4 | — | 2.2 |
| AC1.5 | — | 2.1 |
| AC1.6 | — | 2.5 |
| AC2.1 | — | 3.2 |
| AC2.2 | — | 3.3 |
| AC2.3 | ✓ (SKILL.md output paths) | 3.4 |
| AC2.4 | — | 3.5 |
| AC2.5 | — | 3.7 |
| AC2.6 | — | 3.6 |
| AC3.1 | — | 4.2–4.5 |
| AC3.2 | ✓ (fanout-layout.md sliding window) | 4.6 |
| AC3.3 | — | 4.8 |
| AC3.4 | — | 4.7 |
| AC3.5 | — | 4.9 |
| AC4.1 | ✓ (mssql.sql content) | 2.6 |
| AC4.2 | ✓ (SKILL.md "Adding a New Engine") | 2.7 |
| AC4.3 | ✓ (job-spec.md zero MSSQL matches) | 3.8 |
| AC5.1 | — | 5.1–5.7 |
| AC5.2 | — | 5.3 |
| AC5.3 | — | 5.7 |
| AC5.4 | — | 5.5 |
| AC5.5 | — | 5.4 |
| AC6.1 | ✓ (plugin.json fields) | 1.1 |
| AC6.2 | ✓ (description field) | 1.1 |
| AC6.3 | ✓ (all 3 SKILL.md frontmatter) | 1.2 |
| AC6.4 | ✓ (all 3 command files) | 1.3 |
| AC6.5 | ✓ (all agent refs qualified) | — |
