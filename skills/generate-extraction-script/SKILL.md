---
name: generate-extraction-script
description: Use when you need to generate a database schema extraction script for MSSQL (future: MySQL, PostgreSQL) — detects PowerShell/dbatools, creates extraction commands, and sets up the target directory
user-invocable: true
---

# Generate Extraction Script

Generate a database schema extraction script and prepare the target directory for output.

## Prerequisites: Activate Coding Skills

Before generating any script code, activate these ed3d-house-style skills using the Skill tool:
- `ed3d-house-style:coding-effectively` — error handling, cross-platform principles, file organization
- `ed3d-house-style:defense-in-depth` — validate inputs at every layer (connection params, file paths, query results)

Apply their guidance when generating the PowerShell or sqlcmd extraction script below.

## Step 0: Resolve Hints File — Part A: File Discovery

Hints files allow explicit lookup table identification, replacing the row-count heuristic for section 17.

Perform Part A now, before gathering database details. Part B (database matching) runs after Step 1 once the database name is known.

**0a. Check for explicit hints path in arguments.**
If `ARGUMENTS` contains a file path (e.g., `path/to/database-hints.json`), use that path directly. Skip the CWD search. Record the path as `HINTS_PATH`. Proceed to Step 1, then continue with Part B.

**0b. Search CWD for database-hints.json.**
If no path was provided in arguments, use the Glob tool to search recursively for `database-hints.json` starting from the current working directory.
- If **not found**: hints are inactive. Record hint state as `inactive`. Proceed to Step 1. (Skip Part B.)
- If **found**: prompt the user using AskUserQuestion:
  "Found `database-hints.json` at `[path]`. Use it to identify lookup tables for section 17 instead of the row-count heuristic?"
  Options: "Yes — use hints" / "No — use row-count heuristic"
  - If user selects "No": hints are inactive. Record hint state as `inactive`. Proceed to Step 1. (Skip Part B.)
  - If user selects "Yes": record the path as `HINTS_PATH`. Proceed to Step 1, then continue with Part B.

---

## Step 1: Gather Database Details

If the user has not provided these details, use AskUserQuestion to collect:

1. **Database engine** — Currently only MSSQL is supported. If the user requests MySQL or PostgreSQL, inform them that only MSSQL templates exist currently and ask if they'd like to proceed with MSSQL or wait for template development.
2. **Server/instance** — The SQL Server hostname or `server\instance` or `server,port` format.
3. **Database name** — The target database to extract schema from.

If any required value is missing, prompt for it. Do NOT error out or guess.

## Step 0 (continued) — Part B: Hints Database Matching

Complete this step only if `HINTS_PATH` was recorded in Part A. If hint state is `inactive`, skip to Step 2.

**0c. Parse and match database entry.**
Read the hints file at `HINTS_PATH` with the Read tool. The format is JSON with a `databases` array. Each entry has a `name` field and a `tables` array. Each table entry has a `name` field and may have `probable_lookup: true`.

Example structure:
```json
{
  "databases": [
    {
      "name": "Made2Manage ERP",
      "tables": [
        { "name": "FGSTAT", "probable_lookup": true },
        { "name": "INMAST", "probable_lookup": false }
      ]
    }
  ]
}
```

Perform a **case-insensitive substring match** between the database name collected in Step 1 and each entry's `name` field.

- **Zero matches**: Warn the user: "No entry in `database-hints.json` matches database `{DB_NAME}`. Falling back to row-count heuristic for section 17." Record hint state as `inactive`.
- **Multiple matches**: List all matching entries by name and prompt the user with AskUserQuestion to select one. Use the selected entry.
- **Exactly one match**: Use that entry.

**0d. Extract probable_lookup tables.**
From the matched entry, collect all table names where `probable_lookup: true`.

- If the matched entry has **zero** `probable_lookup: true` tables: Warn the user: "Database entry `{matched name}` has no tables marked `probable_lookup: true`. Falling back to row-count heuristic for section 17." Record hint state as `inactive`.
- Otherwise: Record hint state as `active` with the list of lookup table names.

## Step 2: Detect Runtime Environment

Check the user's platform:
- Use Bash to run: Try `pwsh` first, then fall back to `powershell`. Run: `pwsh -Command "Get-Module -ListAvailable dbatools" 2>/dev/null` or `powershell -Command "Get-Module -ListAvailable dbatools" 2>/dev/null`
- If PowerShell + dbatools are available: use the **dbatools path**
- If PowerShell is available but dbatools is not: suggest `Install-Module dbatools -Scope CurrentUser` and fall back to **sqlcmd path**
- If PowerShell is not available: use the **sqlcmd path**

## Step 3: Create Target Directory

Create the directory `references/databases/{DB_NAME}/` in the user's working directory. Create 17 empty placeholder files using the Write tool to create each file with empty content:

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
| `17_lookup_data.txt` | Actual data from lookup tables |

**If the directory already exists and contains non-empty files**, warn the user: "Target directory `references/databases/{DB_NAME}/` already contains extraction data. Running extraction again will overwrite these files (hints: [active — N lookup tables identified / inactive — using row-count heuristic]). Proceed?" Use AskUserQuestion with options: "Proceed (overwrite)" / "Cancel".

## Step 4: Generate Extraction Script

Read the bundled SQL template from this skill's `templates/mssql.sql` file. Sections 1–16 always come from the template unchanged.

**Section 17 has two paths depending on hint state from Step 0:**

### Section 17 — Hints-driven path (hint state: active)

When hints are active, replace the template's section 17 body with a version that uses an explicit table list instead of the row-count cursor filter. The cursor structure, `_table_header` synthetic column, and `sp_executesql` pattern must be preserved.

Replace the cursor's `WHERE`/`HAVING` filter with `WHERE t.name IN (...)` built from the `probable_lookup: true` table names collected in Step 0:

```sql
DECLARE lookup_cursor CURSOR LOCAL FAST_FORWARD FOR
    SELECT s.name AS schema_name, t.name AS table_name
    FROM sys.tables t
    INNER JOIN sys.schemas s ON t.schema_id = s.schema_id
    WHERE t.name IN (N'Table1', N'Table2', N'Table3')  -- from hints
      AND t.is_ms_shipped = 0
    ORDER BY s.name, t.name;
```

The cursor execution loop, `_table_header` injection, and `EXEC sp_executesql @sql` remain identical to the template. Only the `SELECT` inside the cursor declaration changes.

Both dbatools and sqlcmd generation paths use this same hints-driven section 17 SQL.

### Section 17 — Heuristic path (hint state: inactive)

Use the template's section 17 exactly as written (the cursor with `HAVING SUM(p.rows) > 0 AND SUM(p.rows) < 100`). Do not modify it.

---

### dbatools Path (preferred)

Generate a PowerShell script that:

1. Accepts parameters for SqlInstance, Database, and OutputDir
2. Reads the bundled SQL template
3. Splits it into sections using regex: `(?m)(?=^-- ={10,}\r?\n-- \d+\.)`
4. Filters sections containing a `SELECT` statement
5. For each section, runs `Invoke-DbaQuery` and exports results via `Export-Csv -Delimiter '|' -NoTypeInformation -Encoding UTF8`
6. Handles empty results by writing empty files
7. Section 17 (lookup data) produces multiple result sets, each with a synthetic `_table_header` first column containing the table name. Invoke-DbaQuery captures these rows in the result set, which are then exported to `17_lookup_data.txt` with the header rows intact

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
