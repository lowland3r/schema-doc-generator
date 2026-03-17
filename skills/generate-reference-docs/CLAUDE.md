# generate-reference-docs

Last verified: 2026-03-17

## Purpose
Transforms the 17 extraction files into 8 structured reference documents that analysts and AI models use to write queries, understand relationships, and make safe data modifications.

## Contracts
- **Exposes**: Skill invoked by `/generate-docs` command and `plan-schema-docs` pipeline
- **Guarantees**: Produces 8 output targets in `docs/database_reference/{DB_NAME}/`. Adaptively selects single-pass (<50KB) or fan-out (>=50KB) based on corpus size.
- **Expects**: 17 extraction files in `references/databases/{DB_NAME}/`. Files 01-03 and 16 are critical; others may be empty.

## Dependencies
- **Uses**: `job-spec.md` (generation rules), `fanout-layout.md` (parallel architecture)
- **Uses**: `ed3d-basic-agents` plugin (opus-general-purpose, sonnet-general-purpose)
- **Used by**: `commands/generate-docs.md`, `skills/plan-schema-docs/SKILL.md`
- **Boundary**: Does not create extraction files. Does not connect to databases.

## Key Decisions
- 50KB threshold for fan-out: balances context window limits against orchestration overhead
- Fan-out uses 2 workers + 6 critics + 1 summarizer: sliding-window critic assignment ensures each segment gets 3 independent reviews
- Workers use opus, critics use sonnet: cost optimization (critics need less reasoning)

## Invariants
- All 17 input files are read before any output is generated (Rule 1 in job-spec)
- Output files never fabricate data; unknowns go to `07_annotations_needed.md`
- Fan-out temp files go to platform-appropriate temp directory, not the repo

## Key Files
- `SKILL.md` - Full skill definition (single-pass and fan-out paths)
- `job-spec.md` - Bundled generation rules and output format specification
- `fanout-layout.md` - Worker/critic/summarizer assignment matrix
