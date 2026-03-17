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

- **<50KB total**: Use single-pass generation (Step 3). Report: "Corpus size: {size}. Using single-pass generation."
- **>=50KB total**: Use fan-out generation (Fan-Out Path section below). Report: "Corpus size: {size}. Using fan-out generation with parallel workers, critics, and summarizer."

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

## Fan-Out Path (corpus >=50KB)

When the corpus exceeds 50KB, use the fan-out layout defined in this skill's `fanout-layout.md` companion file.

### Stage 1: Setup

Create the temporary working directory. Use a platform-appropriate temp path (`/tmp/` on Unix, `$env:TEMP` or `C:\tmp\` on Windows):
```bash
mkdir -p /tmp/fanout-{DB_NAME}/workers /tmp/fanout-{DB_NAME}/critics
```

On Windows, use:
```powershell
New-Item -ItemType Directory -Force -Path "$env:TEMP\fanout-{DB_NAME}\workers","$env:TEMP\fanout-{DB_NAME}\critics"
```

### Stage 2: Launch Workers (parallel)

Read the job spec from `job-spec.md`. Launch both workers simultaneously using the Agent tool — issue both calls in a single message for parallel execution.

**W01 invoke example:**
```xml
<invoke name="Agent">
<parameter name="description">Generate reference docs for {DB_NAME}</parameter>
<parameter name="subagent_type">ed3d-basic-agents:opus-general-purpose</parameter>
<parameter name="run_in_background">true</parameter>
<parameter name="prompt">
You are Worker W01 for database {DB_NAME}.

## Your Job Specification
{contents of job-spec.md}

## Input Files
Read ALL of the following files before generating any output:
{list all 17 file paths from references/databases/{DB_NAME}/}

## Your Assigned Output Segments
S01: Write docs/database_reference/{DB_NAME}/00_overview.md
S02: Write docs/database_reference/{DB_NAME}/01_type_reference.md
S03: Write all files in docs/database_reference/{DB_NAME}/02_tables/ (one file per domain)

## Writing Style
Activate the ed3d-house-style:writing-for-a-technical-audience skill. Apply it to all output.

## Report
When done, write your completion summary to /tmp/fanout-{DB_NAME}/workers/W01.md
Include: segments completed, files written, and any gaps you encountered.
</parameter>
</invoke>
```

**W02 invoke example:**
```xml
<invoke name="Agent">
<parameter name="description">Generate reference docs for {DB_NAME}</parameter>
<parameter name="subagent_type">ed3d-basic-agents:opus-general-purpose</parameter>
<parameter name="run_in_background">true</parameter>
<parameter name="prompt">
You are Worker W02 for database {DB_NAME}.

## Your Job Specification
{contents of job-spec.md}

## Input Files
Read ALL of the following files before generating any output:
{list all 17 file paths from references/databases/{DB_NAME}/}

## Your Assigned Output Segments
S04: Write docs/database_reference/{DB_NAME}/03_stored_procedures.md
S05: Write docs/database_reference/{DB_NAME}/04_views.md and 05_functions.md
S06: Write docs/database_reference/{DB_NAME}/06_business_logic.md and 07_annotations_needed.md

## Writing Style
Activate the ed3d-house-style:writing-for-a-technical-audience skill. Apply it to all output.

## Report
When done, write your completion summary to /tmp/fanout-{DB_NAME}/workers/W02.md
Include: segments completed, files written, and any gaps you encountered.
</parameter>
</invoke>
```

**Note:** Issue both Worker invokes in a single message to enable parallel execution. Both use `ed3d-basic-agents:opus-general-purpose` with `run_in_background: true`.

### Stage 3: Launch Critics (parallel, after workers)

After both workers complete, launch all 6 critics simultaneously. Each critic:
- Reads the output documents for its assigned segments
- Reads the relevant worker reports
- Spot-checks against source input files
- Checks writing quality against `ed3d-house-style:writing-for-a-technical-audience` principles (concise, specific, no filler)
- Writes a structured review to `/tmp/fanout-{DB_NAME}/critics/C0X.md`

Use `ed3d-basic-agents:sonnet-general-purpose` for all critics. Set `run_in_background: true`.

**C01 invoke example:**
```xml
<invoke name="Agent">
<parameter name="description">Critic C01 review for {DB_NAME}</parameter>
<parameter name="subagent_type">ed3d-basic-agents:sonnet-general-purpose</parameter>
<parameter name="run_in_background">true</parameter>
<parameter name="prompt">
You are Critic C01 for database {DB_NAME}.

## Your Review Segments
Review these output documents: S01 (00_overview.md), S05 (04_views.md + 05_functions.md), S06 (06_business_logic.md + 07_annotations_needed.md)

Read the relevant worker reports from /tmp/fanout-{DB_NAME}/workers/. Spot-check against the original source files in references/databases/{DB_NAME}/.

Check writing quality against ed3d-house-style:writing-for-a-technical-audience principles.

Write your structured review to /tmp/fanout-{DB_NAME}/critics/C01.md. For each issue: note the file, quote the problematic text, state the correction, and note whether you verified against source.
</parameter>
</invoke>
```

**Note:** Critics C02–C06 follow the same pattern with their assigned segments from `fanout-layout.md`. Issue all 6 critic invokes in a single message (or grouped by dependency as noted below).

**Optimization:** C03 only needs W01; C06 only needs W02. If one worker finishes first, launch its sole-dependency critics immediately. (This is optional — waiting for both workers before launching all 6 critics is also correct.)

### Stage 4: Summarizer (sequential, after all critics)

After all 6 critics complete, launch one summarizer:
- Reads all 6 critic reviews
- Builds deduplicated correction list
- **2+ critics agree**: Apply correction directly
- **1 critic flags**: Verify against source input files before applying
- Applies corrections to output documents using Edit tool
- Writes QA report to `/tmp/fanout-{DB_NAME}/final-report.md`

Use `ed3d-basic-agents:opus-general-purpose`.

### Stage 5: Report

After summarizer completes, report to user:
- List of generated files
- Number of corrections applied
- Corrections where critics disagreed
- Open questions from `07_annotations_needed.md`
- Location of full QA report
