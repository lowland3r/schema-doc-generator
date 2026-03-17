# generate-extraction-script

Last verified: 2026-03-17

## Purpose
Generates a database schema extraction script so users can pull catalog metadata into 17 structured text files. The plugin never connects to the database itself -- it produces a script the user runs manually.

## Contracts
- **Exposes**: Skill invoked by `/extract-schema` command and `plan-schema-docs` pipeline
- **Guarantees**: Produces a PowerShell or sqlcmd script targeting the 17-file output format. Creates target directory with empty placeholder files before user runs extraction.
- **Expects**: User provides database engine (MSSQL only), server/instance, and database name

## Dependencies
- **Uses**: `templates/mssql.sql` (bundled SQL template, 17 sections)
- **Used by**: `commands/extract-schema.md`, `skills/plan-schema-docs/SKILL.md`
- **Boundary**: Does not execute database queries. Does not consume extraction output.

## Key Decisions
- dbatools preferred over sqlcmd: richer PowerShell integration, better error handling
- Script presented to user, never auto-executed: security and trust boundary
- 17 fixed sections: matches generation skill's expected input contract

## Invariants
- Output file names are `{NN}_{snake_name}.txt` (01 through 17), never changed
- Section 17 (lookup data) uses synthetic `_table_header` column for table delimiters
- Only MSSQL templates exist; new engines require new `templates/{engine}.sql`

## Key Files
- `SKILL.md` - Full skill definition with dbatools and sqlcmd paths
- `templates/mssql.sql` - The SQL extraction template (17 sections)
