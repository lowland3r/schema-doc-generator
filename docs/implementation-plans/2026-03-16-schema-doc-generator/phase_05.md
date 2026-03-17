# Schema Doc Generator — Phase 5: End-to-End Pipeline Skill

**Goal:** The `plan-schema-docs` skill orchestrates the full extraction-to-documentation pipeline with human gates between stages.

**Architecture:** This skill is the top-level orchestrator. It delegates to `generate-extraction-script` and `generate-reference-docs` skills at the appropriate stages, with human gates between extraction and generation. The user runs `/schema-docs` to start the full pipeline.

**Tech Stack:** Markdown (SKILL.md), Skill tool for inter-skill delegation

**Scope:** Phase 5 of 6 from design plan

**Codebase verified:** 2026-03-16. Skills from Phases 2-4 expected to exist. Ed3d skills chain to other skills via `Use your Skill tool to engage the [skill-name] skill` directive (pattern from `ed3d-plan-and-execute` commands).

---

## Acceptance Criteria Coverage

### schema-doc-generator.AC5: End-to-End Pipeline
- **AC5.1 Success:** `/schema-docs` walks through setup, extraction, validation, generation, summary in order
- **AC5.2 Success:** Human gate exists between extraction script presentation and generation start
- **AC5.3 Success:** Post-generation summary highlights items from `07_annotations_needed.md`
- **AC5.4 Success:** Validation step reports which of 17 files have data and which are empty
- **AC5.5 Edge:** User cancels after extraction; no generation runs, partial state is clean

---

<!-- START_TASK_1 -->
### Task 1: Write the plan-schema-docs SKILL.md

**Verifies:** schema-doc-generator.AC5.1, AC5.2, AC5.3, AC5.4, AC5.5

**Files:**
- Modify: `skills/plan-schema-docs/SKILL.md` (replace stub from Phase 1)

**Implementation:**

Replace the stub with the full orchestration skill:

```markdown
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
   - If fan-out was used: "A QA report is available at `/tmp/fanout-{DB_NAME}/final-report.md`"

## Multi-Database Awareness

If `docs/database_reference/` already contains documentation for other databases, note any cross-database references found during generation (e.g., linked server references, cross-database queries in views or procedures). Suggest documenting these in a top-level `docs/database_reference/databases.md` index if one does not already exist.
```

**Verification:**

SKILL.md exists. Has correct frontmatter. Contains 6 stages in order. Human gate at Stage 3 with cancel option. Delegates to both `generate-extraction-script` and `generate-reference-docs` skills. Post-generation summary reads `07_annotations_needed.md`.

**Commit:**

```bash
git add skills/plan-schema-docs/SKILL.md
git commit -m "feat: implement plan-schema-docs pipeline skill with human gates"
```
<!-- END_TASK_1 -->

<!-- START_TASK_2 -->
### Task 2: Update schema-docs command

**Files:**
- Verify: `commands/schema-docs.md` (exists from Phase 1)

**Implementation:**

Verify the command delegates to `plan-schema-docs` skill. Update description if needed:

```markdown
---
description: Walk through the full database documentation pipeline (extraction + generation)
---

Use your Skill tool to engage the `plan-schema-docs` skill. Follow it exactly as written.
```

**Commit:**

```bash
git add commands/schema-docs.md
git commit -m "feat: finalize schema-docs command"
```
<!-- END_TASK_2 -->
