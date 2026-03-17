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
