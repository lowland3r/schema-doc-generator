---
name: plan-schema-docs
description: Use when you need to walk through the full database documentation pipeline from extraction to reference doc generation — orchestrates skills with human gates between stages
user-invocable: false
---

# Database Documentation Pipeline

Walk through the complete database schema documentation process: extraction script generation, schema extraction (user-executed), validation, and reference doc generation.

## Stage 1: Setup

Gather database details from the user if not already provided:
- Database engine (currently MSSQL only)
  (If the user names an unsupported engine, the generate-extraction-script skill will handle it at Stage 2.)
- Server/instance name
- Database name

These values will be passed to the extraction skill.

## Stage 2: Extraction Script Generation

Use the Skill tool to invoke the `generate-extraction-script` skill. This will:
- Detect the user's runtime environment (PowerShell/dbatools vs sqlcmd)
- Generate the appropriate extraction script
- Create the target directory with placeholder files
- Present the script to the user

**The skill handles all interaction with the user for this stage.**

## Stage 3: Human Gate — Extraction Execution

After the extraction script is presented, inform the user:

"The extraction script has been generated. Please:
1. Review the script
2. Run it against your database
3. Confirm when extraction is complete

I'll validate the extraction files once you confirm."

Use AskUserQuestion:
- "Have you run the extraction script?"
  - "Yes, extraction is complete" — proceed to Stage 4
  - "Cancel — I'll come back to this later" — end the pipeline cleanly

**If the user cancels:** Acknowledge and stop. The target directory and placeholder files remain (they're harmless). The user can resume later by running `/generate-docs` directly after completing extraction manually.

## Stage 4: Validation

After the user confirms extraction is complete, validate the extraction files at `references/databases/{DB_NAME}/`:

For each of the 17 expected files:
- Check if it exists
- Check if it is non-empty
- Report file size

Present a validation summary:

"Extraction validation for **{DB_NAME}**:
- **{N} files with data**: [list files with sizes]
- **{M} empty files**: [list] (normal for databases without triggers, functions, UDTs, etc.)
- **{K} missing files**: [list] (if any — warn if critical files 01-03 or 16 are missing)"

If critical files are missing (01_database_metadata, 02_schemas, 03_tables_columns, 16_row_counts), warn the user and ask if they want to proceed anyway.

## Stage 5: Reference Doc Generation

Use the Skill tool to invoke the `generate-reference-docs` skill. This will:
- Measure corpus size
- Adaptively choose single-pass or fan-out generation
- Generate all 8 reference document targets
- Place output in `docs/database_reference/{DB_NAME}/`

**The skill handles all interaction and reporting for this stage.**

## Stage 6: Post-Generation Summary

After generation completes, provide a final summary:

1. List all generated reference documents with brief descriptions
2. Highlight the `07_annotations_needed.md` file: "The following questions require human review to complete the documentation:"
   - Read `docs/database_reference/{DB_NAME}/07_annotations_needed.md`
   - List the top-level question categories
3. Suggest next steps:
   - "Review `07_annotations_needed.md` and fill in answers based on your domain knowledge"
   - "The reference docs can be used immediately for querying and understanding the database"
   - If fan-out was used: "A QA report was produced by the generation skill — the path was reported in the generation summary above."

## Multi-Database Awareness

If `docs/database_reference/` already contains documentation for other databases, note any cross-database references found during generation (e.g., linked server references, cross-database queries in views or procedures). Suggest documenting these in a top-level `docs/database_reference/databases.md` index if one does not already exist.
