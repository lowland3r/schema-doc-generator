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

- **<50KB total**: Use single-pass generation (this section). Report: "Corpus size: {size}. Using single-pass generation."
- **>=50KB total**: Use fan-out generation (see Fan-Out Path section below). **Fan-out is not yet implemented — proceeding with single-pass. Quality may be lower for very large databases. Notify the user of this limitation before dispatching the agent.** Report: "Corpus size: {size}. Using single-pass generation (corpus exceeds 50KB — quality may be lower; fan-out is not yet implemented)."

## Step 3: Single-Pass Generation

Read the bundled job spec from this skill's `job-spec.md` companion file.

Dispatch a single agent to generate all 8 output targets:

```xml
<invoke name="Agent">
<parameter name="description">Generate reference docs for {DB_NAME}</parameter>
<parameter name="subagent_type">ed3d-basic-agents:opus-general-purpose</parameter>
<parameter name="prompt">
Your working directory is the repo root. Use absolute paths when reading input files, and relative-from-root paths for output.

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
