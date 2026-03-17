# plan-schema-docs

Last verified: 2026-03-17

## Purpose
Orchestrates the full database documentation pipeline with human gates between stages, ensuring the user reviews and runs the extraction script before generation proceeds.

## Contracts
- **Exposes**: Skill invoked by `/schema-docs` command
- **Guarantees**: Walks through 6 stages in order. Never skips the human gate (Stage 3). Validates extraction files before generation.
- **Expects**: User provides database engine, server, and database name at Stage 1

## Dependencies
- **Uses**: `generate-extraction-script` skill (Stage 2), `generate-reference-docs` skill (Stage 5)
- **Used by**: `commands/schema-docs.md`
- **Boundary**: This skill orchestrates; it does not generate scripts or documents itself

## Key Decisions
- Human gate at Stage 3: the user must run extraction and confirm completion before generation starts
- Validation at Stage 4: checks all 17 files exist and flags missing critical files (01-03, 16)
- Cancel is clean: placeholder files remain harmless; user can resume via `/generate-docs` later

## Invariants
- Stages execute in order: setup, extraction, human gate, validation, generation, summary
- Pipeline never auto-executes database queries
- Fan-out QA report path referenced in Stage 6 comes from the generation skill's own output

## Key Files
- `SKILL.md` - Full 6-stage pipeline definition
