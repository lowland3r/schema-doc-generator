# Schema Doc Generator — Phase 3: Reference Doc Generation Skill (Single-Pass Path)

**Goal:** The `generate-reference-docs` skill generates all 8 reference documents from 17 extraction files using a single opus agent when corpus size is <50KB.

**Architecture:** The skill validates input files, measures corpus size, and dispatches one `ed3d-basic-agents:opus-general-purpose` agent with the bundled job spec and all input files. Output is placed in `docs/database_reference/{DB_NAME}/`.

**Tech Stack:** Markdown (SKILL.md, job-spec.md), Agent tool with qualified subagent_type

**Scope:** Phase 3 of 6 from design plan

**Codebase verified:** 2026-03-16. Job spec at `C:\Users\jake.wimmer\Repositories\defect-tracking-reference\.github\jobs\generate_reference_docs.md` (159 lines). 8 output targets. 7 processing rules requiring full corpus parse before generation.

---

## Acceptance Criteria Coverage

### schema-doc-generator.AC2: Single-Pass Doc Generation
- **AC2.1 Success:** All 17 extraction files are located and validated (exist check, empty-is-OK noted)
- **AC2.2 Success:** Corpus <50KB dispatches one opus agent with full job spec; all 8 doc targets produced
- **AC2.3 Success:** Output written to `docs/database_reference/{DB_NAME}/` with correct directory structure
- **AC2.4 Success:** `02_tables/` subdirectory contains per-domain files named `{nn}_{domain}.md`
- **AC2.5 Failure:** Missing extraction directory produces clear error message with expected path
- **AC2.6 Edge:** Empty extraction files (e.g., no triggers) produce brief "none found" doc sections, not errors

### schema-doc-generator.AC4: Multi-Engine Template Architecture
- **AC4.3 Success:** Job spec (`job-spec.md`) is engine-agnostic; same spec used regardless of source RDBMS

---

<!-- START_TASK_1 -->
### Task 1: Copy and adapt the job spec as a bundled companion file

**Verifies:** schema-doc-generator.AC4.3

**Files:**
- Create: `skills/generate-reference-docs/job-spec.md`

**Implementation:**

Copy `C:\Users\jake.wimmer\Repositories\defect-tracking-reference\.github\jobs\generate_reference_docs.md` into the plugin at `skills/generate-reference-docs/job-spec.md`.

Make one addition: append a section about lookup table data (file 17) to the Input Format table:

```markdown
| `17_lookup_data.txt` | Actual row data from tables with <100 rows (lookup/enum tables). Format: `--- TABLE: schema.table ---` delimiter between tables, followed by pipe-delimited rows. May be empty if no lookup tables exist or extraction did not include this step. |
```

Add a processing instruction that references this data:

```markdown
8. **Lookup table data enriches documentation.** If `17_lookup_data.txt` contains data, use it to document actual enum/code values in the type reference, table specs, and business logic documents. For example, if `tblDefectCodes` has 108 rows of defect code definitions, include those values (or a representative sample for large lookup tables) in the relevant table spec and cross-reference them in the business logic document.
```

The job spec is engine-agnostic — it describes the 17-file interface without referencing any specific RDBMS.

**Verification:**

File exists. Contains the full generation specification. References 17 input files. No RDBMS-specific language.

**Commit:**

```bash
git add skills/generate-reference-docs/job-spec.md
git commit -m "feat: add generation job spec as bundled companion file"
```
<!-- END_TASK_1 -->

<!-- START_TASK_2 -->
### Task 2: Write the generate-reference-docs SKILL.md (single-pass path)

**Verifies:** schema-doc-generator.AC2.1, AC2.2, AC2.3, AC2.4, AC2.5, AC2.6

**Files:**
- Modify: `skills/generate-reference-docs/SKILL.md` (replace stub from Phase 1)

**Implementation:**

Replace the stub with the full skill. In this phase, implement only the single-pass path (the adaptive fan-out gate and fan-out logic will be added in Phase 4).

```markdown
---
name: generate-reference-docs
description: Use when you have populated schema extraction files and need to generate structured reference documentation — adaptively chooses single-pass or fan-out based on corpus size
user-invocable: false
---

# Generate Reference Docs

Generate structured reference documentation from database schema extraction files.

## Step 1: Locate and Validate Input Files

The user should provide or you should determine the database name. Look for extraction files at:
`references/databases/{DB_NAME}/`

Validate that the directory exists. If it does not, output an error:
"Extraction directory `references/databases/{DB_NAME}/` not found. Run `/extract-schema` first to generate extraction files."

Check for the 17 expected files (`01_database_metadata.txt` through `17_lookup_data.txt`). For each file:
- **Exists and non-empty**: Note as available
- **Exists but empty**: Note as empty (this is expected for files 07, 12, 13, 14, 15, 17)
- **Missing**: Warn but continue — files 01-03 and 16 are critical; others are optional

Report to the user: "Found {N}/17 extraction files for {DB_NAME}. {M} are empty (expected for databases without triggers, functions, etc.)."

## Step 2: Measure Corpus Size

Calculate total byte size of all 17 input files:

```bash
wc -c references/databases/{DB_NAME}/*.txt | tail -1
```

- **<50KB total**: Use single-pass generation (this section)
- **>=50KB total**: Use fan-out generation (see Phase 4 addition to this skill)

Report to the user: "Corpus size: {size}. Using {single-pass|fan-out} generation."

## Step 3: Single-Pass Generation

Read the bundled job spec from this skill's `job-spec.md` companion file.

Dispatch a single agent to generate all 8 output targets:

```xml
<invoke name="Agent">
<parameter name="description">Generate reference docs for {DB_NAME}</parameter>
<parameter name="subagent_type">ed3d-basic-agents:opus-general-purpose</parameter>
<parameter name="prompt">
You are generating reference documentation for the {DB_NAME} database.

## Your Job Specification

{contents of job-spec.md}

## Input Files

Read ALL of the following files before generating any output:
{list all 17 file paths with absolute paths}

## Output Directory

Write all output files to: `docs/database_reference/{DB_NAME}/`

Create the `02_tables/` subdirectory for per-domain table files.

## Writing Style

Before generating any output, activate the `ed3d-house-style:writing-for-a-technical-audience` skill using the Skill tool. Apply its guidance to all generated reference documents — be concise, specific, and honest. Avoid filler, throat-clearing, and AI writing patterns.

## Important

- Parse ALL input files before generating ANY output (Rule 1)
- Cross-reference aggressively (Rule 2)
- Never fabricate — use 07_annotations_needed.md for unknowns (Rule 3)
- If 17_lookup_data.txt contains data, incorporate actual lookup values into table specs and business logic
- Empty input files are normal — document "none found" sections, do not error
</parameter>
</invoke>
```

## Step 4: Post-Generation Summary

After the agent completes, verify output files exist:

```bash
ls docs/database_reference/{DB_NAME}/
ls docs/database_reference/{DB_NAME}/02_tables/
```

Report to the user:
- List of generated files
- Number of tables documented
- Number of domain groups in `02_tables/`
- Highlight that `07_annotations_needed.md` contains questions for human review
- Note any files that the agent could not generate

## Fan-Out Path

**Not yet implemented.** For corpora >=50KB, this skill will be extended in a later phase to use parallel workers, critics, and a summarizer. Currently, corpora >=50KB will still attempt single-pass (with a warning that quality may be lower for very large databases).
```

**Verification:**

SKILL.md exists at `skills/generate-reference-docs/SKILL.md`. Has correct YAML frontmatter. References `job-spec.md` companion file. Uses `ed3d-basic-agents:opus-general-purpose` qualified agent name. Handles empty files and missing directory cases.

**Commit:**

```bash
git add skills/generate-reference-docs/SKILL.md
git commit -m "feat: implement generate-reference-docs skill (single-pass path)"
```
<!-- END_TASK_2 -->

<!-- START_TASK_3 -->
### Task 3: Update generate-docs command

**Files:**
- Verify: `commands/generate-docs.md` (exists from Phase 1)

**Implementation:**

Verify the command delegates to `generate-reference-docs` skill. No changes needed unless description should be updated.

**Commit:**

No commit needed if no changes.
<!-- END_TASK_3 -->
