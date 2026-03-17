# Schema Doc Generator — Phase 2: Extraction Script Generation Skill

**Goal:** The `generate-extraction-script` skill produces a runnable extraction script for MSSQL databases, including lookup table data discovery.

**Architecture:** The skill is a SKILL.md that instructs Claude to gather database connection details, detect the runtime environment, generate a PowerShell (.ps1) or sqlcmd extraction script, create the target directory with placeholder files, and present the script to the user without executing it. The MSSQL extraction SQL is bundled as a companion file in `templates/mssql.sql`.

**Tech Stack:** Markdown (SKILL.md), T-SQL (extraction template), PowerShell (dbatools/Export-Csv)

**Scope:** Phase 2 of 6 from design plan

**Codebase verified:** 2026-03-16. Plugin scaffold from Phase 1 expected at `C:\Users\jake.wimmer\Repositories\schema-doc-generator\`. Source extraction script at `C:\Users\jake.wimmer\Repositories\defect-tracking-reference\.github\scripts\schema_extraction.sql` (430 lines, 16 sections). Source PowerShell wrapper at `C:\Users\jake.wimmer\Repositories\defect-tracking-reference\Extract-Schema.ps1` (hardcoded params, dbatools `Invoke-DbaQuery`, regex split on `(?m)(?=^-- ={10,}\r?\n-- \d+\.)`, `Export-Csv -Delimiter '|' -NoTypeInformation`).

---

## Acceptance Criteria Coverage

### schema-doc-generator.AC1: Extraction Script Generation
- **AC1.1 Success:** MSSQL extraction produces a `.ps1` script using dbatools `Invoke-DbaQuery` when PowerShell is detected
- **AC1.2 Success:** MSSQL extraction falls back to `sqlcmd` command when PowerShell is not available
- **AC1.3 Success:** Target directory `references/databases/{DB_NAME}/` is created with 17 empty placeholder files
- **AC1.4 Success:** Generated script is presented to user in output, NOT auto-executed
- **AC1.5 Failure:** Missing database name or server prompts user for input rather than erroring
- **AC1.6 Edge:** Existing target directory is not overwritten; user is warned if files already exist

### schema-doc-generator.AC4: Multi-Engine Template Architecture
- **AC4.1 Success:** `templates/` directory under extraction skill contains `mssql.sql`
- **AC4.2 Success:** Adding a new engine requires only a new `.sql` template file and a command-pattern block in SKILL.md

---

<!-- START_SUBCOMPONENT_A (tasks 1-2) -->

<!-- START_TASK_1 -->
### Task 1: Copy MSSQL extraction template into plugin

**Files:**
- Create: `skills/generate-extraction-script/templates/mssql.sql`

**Implementation:**

Copy the existing extraction script from `C:\Users\jake.wimmer\Repositories\defect-tracking-reference\.github\scripts\schema_extraction.sql` into the plugin at `skills/generate-extraction-script/templates/mssql.sql`.

The file is 430 lines of T-SQL with 16 numbered sections. Copy it verbatim — no modifications needed. This is the MSSQL extraction template that the skill will bundle into generated scripts.

Additionally, append a 17th section for lookup table data extraction. After the existing section 16 (row counts), add:

```sql
-- =============================================================================
-- 17. LOOKUP TABLE DATA
-- =============================================================================
-- Dynamically extracts all rows from tables with fewer than 100 rows.
-- Uses row counts from sys.partitions to identify candidates, then
-- builds and executes SELECT statements for each.
-- Output: one result set per lookup table, separated by a header row
-- containing the table name.

DECLARE @sql NVARCHAR(MAX) = N'';
DECLARE @schema NVARCHAR(128), @table NVARCHAR(128), @rows BIGINT;

DECLARE lookup_cursor CURSOR LOCAL FAST_FORWARD FOR
    SELECT s.name AS schema_name, t.name AS table_name, SUM(p.rows) AS row_count
    FROM sys.tables t
    INNER JOIN sys.schemas s ON t.schema_id = s.schema_id
    INNER JOIN sys.partitions p ON t.object_id = p.object_id
    WHERE p.index_id IN (0, 1)
      AND t.is_ms_shipped = 0
    GROUP BY s.name, t.name
    HAVING SUM(p.rows) > 0 AND SUM(p.rows) < 100
    ORDER BY s.name, t.name;

OPEN lookup_cursor;
FETCH NEXT FROM lookup_cursor INTO @schema, @table, @rows;

WHILE @@FETCH_STATUS = 0
BEGIN
    -- Print a delimiter line so the output can be split per-table
    SET @sql = N'PRINT ''--- TABLE: ' + @schema + N'.' + @table + N' ---'';'
             + N' SELECT * FROM ' + QUOTENAME(@schema) + N'.' + QUOTENAME(@table) + N';';
    EXEC sp_executesql @sql;
    FETCH NEXT FROM lookup_cursor INTO @schema, @table, @rows;
END

CLOSE lookup_cursor;
DEALLOCATE lookup_cursor;
```

Update the file map in the SKILL.md (Task 2) to include `17_lookup_data.txt`.

**Verification:**

File exists at `skills/generate-extraction-script/templates/mssql.sql`. Contains 16 original sections plus section 17 for lookup data.

**Commit:**

```bash
git add skills/generate-extraction-script/templates/mssql.sql
git commit -m "feat: add MSSQL extraction template with lookup data discovery"
```
<!-- END_TASK_1 -->

<!-- START_TASK_2 -->
### Task 2: Write the generate-extraction-script SKILL.md

**Verifies:** schema-doc-generator.AC1.1, AC1.2, AC1.3, AC1.4, AC1.5, AC1.6, AC4.1, AC4.2

**Files:**
- Modify: `skills/generate-extraction-script/SKILL.md` (replace stub from Phase 1)

**Implementation:**

Replace the stub SKILL.md with the full skill. The skill instructs Claude to:

1. Gather database details (engine, server, database name) via AskUserQuestion if not provided
2. Detect if the user's platform has PowerShell available
3. Generate the appropriate extraction script
4. Create the target directory with placeholder files
5. Present the script to the user without executing it

```markdown
---
name: generate-extraction-script
description: Use when you need to generate a database schema extraction script for MSSQL (future: MySQL, PostgreSQL) — detects PowerShell/dbatools, creates extraction commands, and sets up the target directory
user-invocable: false
---

# Generate Extraction Script

Generate a database schema extraction script and prepare the target directory for output.

## Prerequisites: Activate Coding Skills

Before generating any script code, activate these ed3d-house-style skills using the Skill tool:
- `ed3d-house-style:coding-effectively` — error handling, cross-platform principles, file organization
- `ed3d-house-style:defense-in-depth` — validate inputs at every layer (connection params, file paths, query results)

Apply their guidance when generating the PowerShell or sqlcmd extraction script below.

## Step 1: Gather Database Details

If the user has not provided these details, use AskUserQuestion to collect:

1. **Database engine** — Currently only MSSQL is supported. If the user requests MySQL or PostgreSQL, inform them that only MSSQL templates exist currently and ask if they'd like to proceed with MSSQL or wait for template development.
2. **Server/instance** — The SQL Server hostname or `server\instance` or `server,port` format.
3. **Database name** — The target database to extract schema from.

If any required value is missing, prompt for it. Do NOT error out or guess.

## Step 2: Detect Runtime Environment

Check the user's platform:
- Use Bash to run: `powershell -Command "Get-Module -ListAvailable dbatools" 2>/dev/null` or `pwsh -Command "Get-Module -ListAvailable dbatools" 2>/dev/null`
- If PowerShell + dbatools are available: use the **dbatools path**
- If PowerShell is available but dbatools is not: suggest `Install-Module dbatools -Scope CurrentUser` and fall back to **sqlcmd path**
- If PowerShell is not available: use the **sqlcmd path**

## Step 3: Create Target Directory

Create the directory `references/databases/{DB_NAME}/` in the user's working directory. Create 17 empty placeholder files:

| File | Content Section |
|------|----------------|
| `01_database_metadata.txt` | Database-level properties |
| `02_schemas.txt` | Schema inventory |
| `03_tables_columns.txt` | All table columns with types |
| `04_primary_keys.txt` | Primary key definitions |
| `05_foreign_keys.txt` | Foreign key relationships |
| `06_indexes.txt` | Index definitions |
| `07_unique_constraints.txt` | Unique constraints |
| `08_check_constraints.txt` | Check constraints |
| `09_views.txt` | View definitions |
| `10_stored_procedures.txt` | Stored procedure definitions |
| `11_procedure_parameters.txt` | Procedure parameter details |
| `12_functions.txt` | Function definitions |
| `13_triggers.txt` | Trigger definitions |
| `14_user_defined_types.txt` | User-defined types |
| `15_extended_properties.txt` | Extended properties |
| `16_row_counts.txt` | Table row counts |
| `17_lookup_data.txt` | Actual data from lookup tables (<100 rows) |

**If the directory already exists and contains non-empty files**, warn the user: "Target directory `references/databases/{DB_NAME}/` already contains extraction data. Running extraction again will overwrite these files. Proceed?" Use AskUserQuestion with options: "Proceed (overwrite)" / "Cancel".

## Step 4: Generate Extraction Script

### dbatools Path (preferred)

Read the bundled SQL template from this skill's `templates/mssql.sql` file. Generate a PowerShell script that:

1. Accepts parameters for SqlInstance, Database, and OutputDir
2. Reads the bundled SQL template
3. Splits it into sections using regex: `(?m)(?=^-- ={10,}\r?\n-- \d+\.)`
4. Filters sections containing a `SELECT` statement
5. For each section, runs `Invoke-DbaQuery` and exports results via `Export-Csv -Delimiter '|' -NoTypeInformation -Encoding UTF8`
6. Handles empty results by writing empty files
7. Section 17 (lookup data) requires special handling: the dynamic SQL produces multiple result sets with `PRINT` delimiters — capture all output to `17_lookup_data.txt`

The generated script should follow the pattern established in the existing `Extract-Schema.ps1` but be parameterized instead of hardcoded:

```powershell
param(
    [Parameter(Mandatory)][string]$SqlInstance,
    [Parameter(Mandatory)][string]$Database,
    [string]$OutputDir = (Join-Path $PSScriptRoot "references\databases\$Database")
)

# Requires: Install-Module dbatools -Scope CurrentUser
Import-Module dbatools -ErrorAction Stop
Set-DbatoolsInsecureConnection -SessionOnly
```

Use `Invoke-DbaQuery -SqlInstance $SqlInstance -Database $Database -Query $section -EnableException` for each section.

Use `Export-Csv -Path $outFile -Delimiter '|' -NoTypeInformation -Encoding UTF8` for output.

### sqlcmd Path (fallback)

Generate a shell command (or batch of commands) that runs `sqlcmd` for each section. Since sqlcmd concatenates all result sets into one output file, the generated script should either:
- Run sqlcmd once per section (17 invocations), OR
- Run once and post-process the output to split by section headers

Recommended pattern (one invocation per section, simpler):
```
sqlcmd -S {server} -d {database} -Q "{section_sql}" -s"|" -W -w 65535 -o "references/databases/{DB_NAME}/{nn}_{name}.txt"
```

For each of the 17 sections, generate one `sqlcmd` command.

## Step 5: Present Script to User

**DO NOT execute the script.** Present it to the user as output text:

1. Show the full generated script
2. Explain what it will do: "This script connects to `{server}/{database}` and extracts schema metadata into 17 files in `references/databases/{DB_NAME}/`"
3. Provide the run command:
   - dbatools: `.\Extract-{DB_NAME}.ps1 -SqlInstance "{server}" -Database "{database}"`
   - sqlcmd: `bash extract_{db_name}.sh` or paste individual commands

4. Note: "After running the extraction, use `/generate-docs` to generate reference documentation from the extracted files."

## Adding a New Engine

To add MySQL or PostgreSQL support:
1. Create a new template file: `templates/mysql.sql` or `templates/postgresql.sql`
2. The template must produce the same 17 output sections in pipe-delimited format
3. Add a new command-pattern block in this SKILL.md for the engine's CLI tool
4. The generation skill (`generate-reference-docs`) requires no changes — it consumes the 17-file interface regardless of source engine
```

**Verification:**

SKILL.md exists at `skills/generate-extraction-script/SKILL.md`. Has correct YAML frontmatter. Body covers all 5 steps. References `templates/mssql.sql` as bundled companion file.

**Commit:**

```bash
git add skills/generate-extraction-script/SKILL.md
git commit -m "feat: implement generate-extraction-script skill with dbatools and sqlcmd paths"
```
<!-- END_TASK_2 -->

<!-- END_SUBCOMPONENT_A -->

<!-- START_TASK_3 -->
### Task 3: Update extract-schema command

**Files:**
- Modify: `commands/extract-schema.md` (already exists from Phase 1, verify delegation is correct)

**Implementation:**

The command stub from Phase 1 should already delegate correctly. Verify it contains:

```markdown
---
description: Generate a database schema extraction script
---

Use your Skill tool to engage the `generate-extraction-script` skill. Follow it exactly as written.
```

No changes needed if stub is correct. If the description needs updating to reflect the lookup table feature, update to:

```markdown
---
description: Generate a database schema extraction script (includes lookup table data discovery)
---

Use your Skill tool to engage the `generate-extraction-script` skill. Follow it exactly as written.
```

**Verification:**

File exists at `commands/extract-schema.md`. Frontmatter has `description`. Body delegates to skill.

**Commit:**

```bash
git add commands/extract-schema.md
git commit -m "feat: update extract-schema command description"
```
<!-- END_TASK_3 -->
