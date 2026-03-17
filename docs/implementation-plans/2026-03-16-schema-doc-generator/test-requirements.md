# Test Requirements: schema-doc-generator

## Overview

Maps each acceptance criterion to a verification approach. This plugin has no executable code or automated test framework — all criteria are verified operationally (invoke and observe) or structurally (file/content inspection).

**Verification types:**
- **Operational** — invoke a slash command or skill and observe that the behavior matches the criterion
- **Structural** — inspect file existence, content, or structure without invoking the plugin

---

## Verification Matrix

### AC1: Extraction Script Generation

| AC | Text | Type | Verification | Phase |
|----|------|------|-------------|-------|
| AC1.1 | MSSQL extraction produces a `.ps1` script using dbatools `Invoke-DbaQuery` when PowerShell is detected | Operational | On a system with PowerShell and dbatools installed, invoke `/extract-schema` with engine=MSSQL. Confirm the output contains a `.ps1` script body that calls `Invoke-DbaQuery` and `Export-Csv -Delimiter '\|'`. | Phase 2 |
| AC1.2 | MSSQL extraction falls back to `sqlcmd` command when PowerShell is not available | Operational | On a system without PowerShell (or simulate by temporarily renaming the binary), invoke `/extract-schema`. Confirm the output contains `sqlcmd` invocations with `-s"\|"` flag and per-section commands. | Phase 2 |
| AC1.3 | Target directory `references/databases/{DB_NAME}/` is created with 17 empty placeholder files | Structural | After invoking `/extract-schema`, verify: (1) directory `references/databases/{DB_NAME}/` exists, (2) exactly 17 `.txt` files are present named `01_database_metadata.txt` through `17_lookup_data.txt`, (3) all files are empty (0 bytes). | Phase 2 |
| AC1.4 | Generated script is presented to user in output, NOT auto-executed | Operational | Invoke `/extract-schema`. Confirm: (1) the script text appears in the conversation output, (2) no database connection is attempted, (3) no `sqlcmd` or `Invoke-DbaQuery` command is executed by the agent. Check that no network calls or process spawns occur beyond environment detection. | Phase 2 |
| AC1.5 | Missing database name or server prompts user for input rather than erroring | Operational | Invoke `/extract-schema` without providing server or database name. Confirm the skill uses AskUserQuestion (or equivalent prompt) to request the missing values rather than producing an error or stack trace. | Phase 2 |
| AC1.6 | Existing target directory is not overwritten; user is warned if files already exist | Operational | (1) Run `/extract-schema` once to create the directory and placeholders. (2) Manually populate one file with non-empty content. (3) Run `/extract-schema` again for the same DB_NAME. Confirm the skill warns that files already exist and asks the user whether to proceed or cancel. Confirm that choosing "Cancel" leaves existing files untouched. | Phase 2 |

### AC2: Single-Pass Doc Generation

| AC | Text | Type | Verification | Phase |
|----|------|------|-------------|-------|
| AC2.1 | All 17 extraction files are located and validated (exist check, empty-is-OK noted) | Operational | Populate `references/databases/{DB_NAME}/` with 17 files (some empty, some with data). Invoke `/generate-docs`. Confirm the skill reports the count of files found, which are empty, and which have data. Confirm no error is raised for empty files. | Phase 3 |
| AC2.2 | Corpus <50KB dispatches one opus agent with full job spec; all 8 doc targets produced | Operational | Prepare extraction files totaling <50KB. Invoke `/generate-docs`. Confirm: (1) the skill reports "single-pass" mode, (2) a single `ed3d-basic-agents:opus-general-purpose` agent is dispatched, (3) all 8 output targets are created in the output directory. | Phase 3 |
| AC2.3 | Output written to `docs/database_reference/{DB_NAME}/` with correct directory structure | Structural | After generation, verify: (1) `docs/database_reference/{DB_NAME}/` exists, (2) files `00_overview.md`, `01_type_reference.md`, `03_stored_procedures.md`, `04_views.md`, `05_functions.md`, `06_business_logic.md`, `07_annotations_needed.md` exist at the top level, (3) `02_tables/` subdirectory exists. | Phase 3 |
| AC2.4 | `02_tables/` subdirectory contains per-domain files named `{nn}_{domain}.md` | Structural | After generation, list files in `docs/database_reference/{DB_NAME}/02_tables/`. Confirm each file follows the pattern `{nn}_{domain}.md` where `{nn}` is a two-digit number and `{domain}` is a descriptive domain name (e.g., `01_defects.md`). Confirm at least one file exists. | Phase 3 |
| AC2.5 | Missing extraction directory produces clear error message with expected path | Operational | Invoke `/generate-docs` for a DB_NAME that has no extraction directory. Confirm the output contains an error message that includes the expected path `references/databases/{DB_NAME}/` and suggests running `/extract-schema` first. Confirm no crash or unhandled exception. | Phase 3 |
| AC2.6 | Empty extraction files (e.g., no triggers) produce brief "none found" doc sections, not errors | Operational | Prepare extraction files where files 07, 12, 13, 14, 15 are empty. Invoke `/generate-docs`. Confirm: (1) no errors during generation, (2) the corresponding output document sections contain "none found" or equivalent brief notation rather than missing content or error markers. | Phase 3 |

### AC3: Fan-Out Doc Generation

| AC | Text | Type | Verification | Phase |
|----|------|------|-------------|-------|
| AC3.1 | Corpus >=50KB triggers fan-out with parallel workers (opus), parallel critics (sonnet), sequential summarizer (opus) | Operational | Prepare extraction files totaling >=50KB. Invoke `/generate-docs`. Confirm: (1) the skill reports "fan-out" mode, (2) two worker agents are dispatched using `ed3d-basic-agents:opus-general-purpose`, (3) six critic agents are dispatched using `ed3d-basic-agents:sonnet-general-purpose`, (4) one summarizer agent is dispatched using `ed3d-basic-agents:opus-general-purpose`, (5) workers run before critics, critics run before summarizer. | Phase 4 |
| AC3.2 | Each output document is reviewed by exactly 3 critics via sliding window | Structural | After fan-out generation, inspect critic review files at `/tmp/fanout-{DB_NAME}/critics/C01.md` through `C06.md`. Confirm each of the 6 segments (S01-S06) appears in exactly 3 critic reviews. Cross-reference against the sliding window table in `fanout-layout.md`. | Phase 4 |
| AC3.3 | Summarizer applies corrections where 2+ critics agree on an issue | Operational | After fan-out generation, read the QA report at `/tmp/fanout-{DB_NAME}/final-report.md`. Confirm it lists corrections that were applied and notes that each applied correction had agreement from 2 or more critics. Compare output documents before and after summarizer to verify edits were made. | Phase 4 |
| AC3.4 | Final QA report is produced listing corrections applied and open questions | Structural | After fan-out generation, verify: (1) `/tmp/fanout-{DB_NAME}/final-report.md` exists, (2) it contains a "corrections applied" section, (3) it contains an "open questions" section, (4) content is non-empty and references specific documents. | Phase 4 |
| AC3.5 | Single critic flags an issue -- summarizer verifies against source before applying | Operational | After fan-out generation, inspect the QA report for any issue flagged by only one critic. Confirm the report indicates the summarizer verified it against source input files. If the correction was applied, the report should note the source verification. If rejected, the report should explain why. | Phase 4 |

### AC4: Multi-Engine Template Architecture

| AC | Text | Type | Verification | Phase |
|----|------|------|-------------|-------|
| AC4.1 | `templates/` directory under extraction skill contains `mssql.sql` | Structural | Verify file exists at `skills/generate-extraction-script/templates/mssql.sql`. Confirm it contains 17 numbered T-SQL sections (look for `-- 1.` through `-- 17.` section headers). Confirm it uses `FOR XML PATH` (not `STRING_AGG`) for SQL Server 2008+ compatibility. | Phase 2 |
| AC4.2 | Adding a new engine requires only a new `.sql` template file and a command-pattern block in SKILL.md | Structural | Read `skills/generate-extraction-script/SKILL.md`. Confirm it contains an "Adding a New Engine" section that documents: (1) creating a new `templates/{engine}.sql` file, (2) adding a command-pattern block to SKILL.md, (3) no changes needed to the generation skill. Confirm the skill logic uses the engine parameter to select the template file rather than hardcoding MSSQL. | Phase 2 |
| AC4.3 | Job spec (`job-spec.md`) is engine-agnostic; same spec used regardless of source RDBMS | Structural | Read `skills/generate-reference-docs/job-spec.md`. Confirm it does not contain MSSQL-specific references (no `sys.`, no `T-SQL`, no `SQL Server` in processing instructions). Confirm it describes the 17-file interface in terms of content categories, not engine-specific catalog queries. | Phase 3 |

### AC5: End-to-End Pipeline

| AC | Text | Type | Verification | Phase |
|----|------|------|-------------|-------|
| AC5.1 | `/schema-docs` walks through setup, extraction, validation, generation, summary in order | Operational | Invoke `/schema-docs` and observe the full pipeline. Confirm the skill proceeds through stages in order: (1) Setup -- gathers database details, (2) Extraction -- generates and presents script, (3) Human gate -- waits for user confirmation, (4) Validation -- reports file status, (5) Generation -- produces reference docs, (6) Summary -- presents final results. | Phase 5 |
| AC5.2 | Human gate exists between extraction script presentation and generation start | Operational | Invoke `/schema-docs`. After the extraction script is presented, confirm the skill explicitly asks the user whether extraction is complete before proceeding. Confirm it does not automatically begin generation. Confirm the prompt offers a cancel option. | Phase 5 |
| AC5.3 | Post-generation summary highlights items from `07_annotations_needed.md` | Operational | Complete a full `/schema-docs` pipeline run. Confirm the post-generation summary: (1) reads `docs/database_reference/{DB_NAME}/07_annotations_needed.md`, (2) lists the top-level question categories from that file, (3) suggests the user review and fill in answers. | Phase 5 |
| AC5.4 | Validation step reports which of 17 files have data and which are empty | Operational | After confirming extraction is complete during a `/schema-docs` run, observe the validation output. Confirm it lists: (1) files with data and their sizes, (2) empty files, (3) any missing files with warnings for critical files (01-03, 16). | Phase 5 |
| AC5.5 | User cancels after extraction; no generation runs, partial state is clean | Operational | Invoke `/schema-docs`. After the extraction script is presented, choose the cancel option at the human gate. Confirm: (1) the skill acknowledges the cancellation, (2) no generation agent is dispatched, (3) the extraction directory and placeholder files remain intact (harmless partial state), (4) the skill suggests resuming later with `/generate-docs`. | Phase 5 |

### AC6: Plugin Conventions

| AC | Text | Type | Verification | Phase |
|----|------|------|-------------|-------|
| AC6.1 | `plugin.json` follows ed3d manifest format (name, version, description, author) | Structural | Read `.claude-plugin/plugin.json`. Confirm it contains all four required fields: `name` (string), `version` (semver string), `description` (string), `author` (object with `name` field). Confirm JSON is valid. | Phase 1 |
| AC6.2 | Description field documents `ed3d-basic-agents` dependency | Structural | Read `.claude-plugin/plugin.json`. Confirm the `description` field contains the substring "ed3d-basic-agents" or "Requires ed3d-basic-agents". | Phase 1 |
| AC6.3 | Skills use SKILL.md with correct YAML frontmatter (name, description, user-invocable) | Structural | For each of the three SKILL.md files (`skills/generate-extraction-script/SKILL.md`, `skills/generate-reference-docs/SKILL.md`, `skills/plan-schema-docs/SKILL.md`): confirm the file begins with YAML frontmatter delimited by `---` and contains the fields `name`, `description`, and `user-invocable`. | Phase 1 |
| AC6.4 | Commands are thin `.md` wrappers delegating to skills | Structural | For each of the three command files (`commands/extract-schema.md`, `commands/generate-docs.md`, `commands/schema-docs.md`): confirm (1) the file has YAML frontmatter with a `description` field, (2) the body is 1-2 sentences delegating to the corresponding skill using "Skill tool" language, (3) no substantive logic exists in the command file. | Phase 1 |
| AC6.5 | Agent references use qualified `plugin-name:agent-name` syntax | Structural | Search all SKILL.md files for agent references. Confirm every agent reference uses the format `ed3d-basic-agents:{agent-name}` (e.g., `ed3d-basic-agents:opus-general-purpose`, `ed3d-basic-agents:sonnet-general-purpose`). Confirm no unqualified agent names appear. | Phase 2, 3, 4 |

---

## Human Verification Plan

The following criteria require human judgment beyond simple structural checks. Each entry describes what the human verifier must evaluate and the specific steps to follow.

### 1. Script correctness (AC1.1, AC1.2)

**Why human judgment is needed:** The generated extraction scripts must be syntactically valid PowerShell/sqlcmd and must correctly reference the bundled SQL template. Structural checks cannot confirm the script would actually run.

**Steps:**
1. Invoke `/extract-schema` with a real MSSQL server and database name
2. Review the generated `.ps1` script for correct parameter handling, dbatools import, section splitting regex, and output file naming
3. Optionally execute the script against a test database and confirm 17 files are populated

### 2. Generation quality (AC2.2, AC2.6, AC3.3)

**Why human judgment is needed:** The content quality of generated reference documents depends on how well the opus agent follows the job spec. Structural checks confirm files exist but not that content is accurate or useful.

**Steps:**
1. Run `/generate-docs` against the DEFECT_TRACKING extraction data
2. Open each of the 8 output documents
3. Spot-check: do column types include full precision (e.g., `decimal(18,4)`)? Are foreign key relationships correctly documented? Do "none found" sections appear for empty input files instead of fabricated content?
4. For fan-out (AC3.3): compare documents before and after summarizer corrections to judge whether corrections improved accuracy

### 3. Human gate behavior (AC5.2, AC5.5)

**Why human judgment is needed:** The human gate is a conversational interaction pattern. The verifier must confirm the skill actually pauses and waits rather than proceeding automatically.

**Steps:**
1. Invoke `/schema-docs`
2. After the extraction script is presented, observe whether the skill waits for user input
3. Test the cancel path: choose "Cancel" and confirm the pipeline stops cleanly
4. Test the proceed path: choose "Yes, extraction is complete" and confirm validation begins

### 4. Fan-out orchestration timing (AC3.1)

**Why human judgment is needed:** Verifying that workers run in parallel, critics wait for workers, and the summarizer waits for all critics requires observing the agent dispatch sequence in real time.

**Steps:**
1. Prepare a >=50KB extraction corpus
2. Invoke `/generate-docs` and observe the agent dispatch messages
3. Confirm workers are launched simultaneously (both in a single message)
4. Confirm critics launch only after both workers complete (or after their specific dependency completes for C03/C06)
5. Confirm summarizer launches only after all 6 critics complete

### 5. Cross-document consistency (AC3.2, AC3.5)

**Why human judgment is needed:** Critic reviews must actually check for cross-document consistency (e.g., a table referenced in `06_business_logic.md` matches its definition in `02_tables/`). Only a human can judge whether the reviews are substantive.

**Steps:**
1. After a fan-out run, read all 6 critic review files
2. Confirm each review references the specific output documents assigned to that critic
3. Confirm reviews contain specific observations (not generic "looks good" responses)
4. Check the QA report for any single-critic issues and verify the summarizer's source-check reasoning

### 6. Engine-agnostic job spec (AC4.3)

**Why human judgment is needed:** Confirming engine-agnosticism requires reading the job spec and judging whether any phrasing implicitly assumes a specific RDBMS.

**Steps:**
1. Read `skills/generate-reference-docs/job-spec.md` end to end
2. Flag any reference to MSSQL-specific concepts (T-SQL syntax, SQL Server catalog views, dbatools, sqlcmd)
3. Confirm all references to input data use the generic 17-file interface terms, not engine-specific terminology
