# Schema Doc Generator — Phase 4: Reference Doc Generation Skill (Fan-Out Path)

**Goal:** Extend the `generate-reference-docs` skill to adaptively fan out to workers/critics/summarizer for large databases (>=50KB corpus).

**Architecture:** Fan-out is split by output document ownership (not input file slicing), since the job spec requires all 17 input files to be parsed before any output. Workers each read all input files but generate disjoint output segments. Critics review via sliding window. Summarizer reconciles corrections. Uses `ed3d-basic-agents:opus-general-purpose` for workers/summarizer and `ed3d-basic-agents:sonnet-general-purpose` for critics.

**Tech Stack:** Markdown (SKILL.md, fanout-layout.md), Agent tool with parallel dispatch

**Scope:** Phase 4 of 6 from design plan

**Codebase verified:** 2026-03-16. Fan-out skill at ed3d-basic-agents uses Task-based tracking with dependency graphs. Workers/critics dispatched in parallel via multiple Agent tool calls in a single message. File existence verification between stages.

---

## Acceptance Criteria Coverage

### schema-doc-generator.AC3: Fan-Out Doc Generation
- **AC3.1 Success:** Corpus >=50KB triggers fan-out with parallel workers (opus), parallel critics (sonnet), sequential summarizer (opus)
- **AC3.2 Success:** Each output document is reviewed by exactly 3 critics via sliding window
- **AC3.3 Success:** Summarizer applies corrections where 2+ critics agree on an issue
- **AC3.4 Success:** Final QA report is produced listing corrections applied and open questions
- **AC3.5 Edge:** Single critic flags an issue — summarizer verifies against source before applying

---

<!-- START_TASK_1 -->
### Task 1: Create the fan-out layout companion file

**Verifies:** schema-doc-generator.AC3.1, AC3.2

**Files:**
- Create: `skills/generate-reference-docs/fanout-layout.md`

**Implementation:**

This companion file defines the segment-to-output mapping, worker assignments, and critic sliding window. It serves as a template that the SKILL.md references when orchestrating a fan-out.

```markdown
# Fan-Out Layout for Reference Doc Generation

## Segment Definitions

Fan-out is organized by **output document ownership**. Every worker reads all 17 input files but produces only its assigned output segments.

| Segment | Output Documents | Worker |
|---------|-----------------|--------|
| S01 | `00_overview.md` | W01 |
| S02 | `01_type_reference.md` | W01 |
| S03 | `02_tables/{nn}_{domain}.md` (full directory) | W01 |
| S04 | `03_stored_procedures.md` | W02 |
| S05 | `04_views.md` + `05_functions.md` | W02 |
| S06 | `06_business_logic.md` + `07_annotations_needed.md` | W02 |

## Worker Assignments

| Worker | Segments | Model |
|--------|----------|-------|
| W01 | S01, S02, S03 | `ed3d-basic-agents:opus-general-purpose` |
| W02 | S04, S05, S06 | `ed3d-basic-agents:opus-general-purpose` |

Both workers run in parallel. Each receives:
- The full job spec (`job-spec.md`)
- All 17 input file paths
- Their specific segment assignments
- The output directory path

## Critic Assignments (Sliding Window)

Each segment is reviewed by exactly 3 critics. Each critic reviews exactly 3 segments.

| Critic | Reviews Segments | Needs Worker Reports | Model |
|--------|-----------------|---------------------|-------|
| C01 | S01, S05, S06 | W01, W02 | `ed3d-basic-agents:sonnet-general-purpose` |
| C02 | S01, S02, S06 | W01, W02 | `ed3d-basic-agents:sonnet-general-purpose` |
| C03 | S01, S02, S03 | W01 | `ed3d-basic-agents:sonnet-general-purpose` |
| C04 | S02, S03, S04 | W01, W02 | `ed3d-basic-agents:sonnet-general-purpose` |
| C05 | S03, S04, S05 | W01, W02 | `ed3d-basic-agents:sonnet-general-purpose` |
| C06 | S04, S05, S06 | W02 | `ed3d-basic-agents:sonnet-general-purpose` |

Verification: each segment appears in exactly 3 critic lists; each critic reviews exactly 3 segments.

## Task Dependencies

- **C03** blocked by W01 only (can launch as soon as W01 completes)
- **C06** blocked by W02 only (can launch as soon as W02 completes)
- **C01, C02, C04, C05** blocked by both W01 and W02
- **Summarizer** blocked by all 6 critics

## Summarizer

Single `ed3d-basic-agents:opus-general-purpose` agent that:
1. Reads all 6 critic reviews
2. Builds a deduplicated correction list (2+ critics agree = confirmed; 1 critic = verify against source)
3. Applies corrections to output files
4. Writes a QA report listing corrections applied and open questions

## Working Directory

Fan-out uses a temporary directory for intermediate files:
```
/tmp/fanout-{DB_NAME}/
├── workers/
│   ├── W01.md  (worker summary report)
│   └── W02.md
├── critics/
│   ├── C01.md ... C06.md  (structured reviews)
└── final-report.md  (QA summary)
```

Output documents go directly to `docs/database_reference/{DB_NAME}/`.
```

**Verification:**

File exists. Segment count = 6. Each segment in exactly 3 critic lists. Each critic reviews 3 segments.

**Commit:**

```bash
git add skills/generate-reference-docs/fanout-layout.md
git commit -m "feat: add fan-out layout template for large database generation"
```
<!-- END_TASK_1 -->

<!-- START_TASK_2 -->
### Task 2: Extend SKILL.md with the fan-out path

**Verifies:** schema-doc-generator.AC3.1, AC3.3, AC3.4, AC3.5

**Files:**
- Modify: `skills/generate-reference-docs/SKILL.md`

**Implementation:**

Replace the "Fan-Out Path" stub section at the bottom of the SKILL.md with the full fan-out orchestration logic. The section should be placed after Step 4 (Post-Generation Summary).

The new content replaces everything from the line "## Fan-Out Path" through the end of the file (the placeholder section added in Phase 3 Task 2).

```markdown
## Fan-Out Path (corpus >=50KB)

When the corpus exceeds 50KB, use the fan-out layout defined in this skill's `fanout-layout.md` companion file.

### Stage 1: Setup

Create the temporary working directory. Use a platform-appropriate temp path (`/tmp/` on Unix, `$env:TEMP` or `C:\tmp\` on Windows):
```bash
mkdir -p /tmp/fanout-{DB_NAME}/workers /tmp/fanout-{DB_NAME}/critics
```

### Stage 2: Launch Workers (parallel)

Read the job spec from `job-spec.md`. Launch both workers simultaneously using the Agent tool — issue both calls in a single message for parallel execution:

**W01 prompt template:**
- Role: "You are Worker W01"
- Segments: S01 (00_overview.md), S02 (01_type_reference.md), S03 (02_tables/ directory)
- Instructions: Read all 17 input files. Follow the job spec. Generate only your assigned output documents.
- Writing style: Activate `ed3d-house-style:writing-for-a-technical-audience` before generating output. Be concise, specific, and honest. No filler or AI writing patterns.
- Output path: `docs/database_reference/{DB_NAME}/`
- Report path: `/tmp/fanout-{DB_NAME}/workers/W01.md`

**W02 prompt template:**
- Role: "You are Worker W02"
- Segments: S04 (03_stored_procedures.md), S05 (04_views.md + 05_functions.md), S06 (06_business_logic.md + 07_annotations_needed.md)
- Same input/output paths
- Report path: `/tmp/fanout-{DB_NAME}/workers/W02.md`

Use `ed3d-basic-agents:opus-general-purpose` for both workers. Set `run_in_background: true`.

### Stage 3: Launch Critics (parallel, after workers)

After both workers complete, launch all 6 critics simultaneously. Each critic:
- Reads the output documents for its assigned segments
- Reads the relevant worker reports
- Spot-checks against source input files
- Checks writing quality against `ed3d-house-style:writing-for-a-technical-audience` principles (concise, specific, no filler)
- Writes a structured review to `/tmp/fanout-{DB_NAME}/critics/C0X.md`

Use `ed3d-basic-agents:sonnet-general-purpose` for all critics. Set `run_in_background: true`.

**Optimization:** C03 only needs W01; C06 only needs W02. If one worker finishes first, launch its sole-dependency critics immediately.

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
```

**Verification:**

SKILL.md now contains both single-pass (Step 3) and fan-out paths. The adaptive decision in Step 2 gates between them. Fan-out uses correct qualified agent names, parallel dispatch pattern, and three-stage pipeline (workers → critics → summarizer).

**Commit:**

```bash
git add skills/generate-reference-docs/SKILL.md
git commit -m "feat: add fan-out generation path for large databases"
```
<!-- END_TASK_2 -->
