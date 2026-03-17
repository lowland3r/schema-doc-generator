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

On Windows, replace `/tmp/` with `$env:TEMP\` (i.e., `$env:TEMP\fanout-{DB_NAME}\workers\`, `$env:TEMP\fanout-{DB_NAME}\critics\`). The SKILL.md Stage 1 documents platform-adaptive creation commands.

Output documents go directly to `docs/database_reference/{DB_NAME}/`.
