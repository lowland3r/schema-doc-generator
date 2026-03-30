# Human Test Plan: schema-doc-revamp

**Implementation plan:** `docs/implementation-plans/2026-03-30-schema-doc-revamp/`
**Base SHA:** `90b7bc56ddd60f6489e279c94e70c2681455d6c7`
**HEAD SHA:** `3de5f3d4b5ba5b6e709b189bd86dee43607be96a`

## Prerequisites

- Claude Code installed with this plugin active (`claude plugin install` from repo root or remote URL)
- `ed3d-basic-agents` plugin installed (required for fan-out path)
- Access to a test MSSQL database (or willingness to cancel at the human gate)
- A prepared `database-hints.json` test fixture with the following entries:
  - One entry whose `name` matches your target database, with 2–3 tables marked `probable_lookup: true`
  - One entry whose `name` matches your target database, with zero `probable_lookup: true` tables
  - One entry whose `name` does not match any target database
  - Two entries whose `name` fields both substring-match the target database (for disambiguation)

---

## Phase 1: Plugin-Dev Removal and CLAUDE.md Consolidation (AC1, AC2)

| Step | Action | Expected |
|------|--------|----------|
| 1.1 | Open `.claude/CLAUDE.md` in an editor | No "Plugin-Dev Enforcement" section. No mention of `plugin-dev-kit`. |
| 1.2 | Open `docs/design-plans/2026-03-17-lowlanders-plugin-dev-kit.md` | File exists and is unmodified from its original commit. |
| 1.3 | Verify no files at `skills/generate-extraction-script/CLAUDE.md`, `skills/generate-reference-docs/CLAUDE.md`, `skills/plan-schema-docs/CLAUDE.md` | All three are absent. |
| 1.4 | Read the "## Skill Contracts" section in `.claude/CLAUDE.md`. Compare against the deleted companions by running `git show 90b7bc5:skills/generate-extraction-script/CLAUDE.md` (and the other two). | Every contract, boundary, and invariant from the three original companion files is represented in the consolidated section. No information was lost. |

---

## Phase 2: Command File Compliance (AC3)

| Step | Action | Expected |
|------|--------|----------|
| 2.1 | Open each of the three SKILL.md files and check frontmatter | All contain `user-invocable: true` |
| 2.2 | Open each of the three command files (`commands/extract-schema.md`, `commands/generate-docs.md`, `commands/schema-docs.md`) | All contain `allowed-tools: Skill` in frontmatter |
| 2.3 | Check `commands/extract-schema.md` and `commands/schema-docs.md` for argument forwarding | Both contain `ARGUMENTS: $ARGUMENTS`. `commands/generate-docs.md` does NOT contain any ARGUMENTS reference. |
| 2.4 | Open `.claude-plugin/plugin.json` | Version is `"0.2.0"` |
| 2.5 | Read `README.md` end to end | Describes what the plugin does. Lists all three commands with descriptions. Provides a working `claude plugin install` command. Installation section mentions the `ed3d-basic-agents` dependency. Content is clear enough for a first-time user. |

---

## Phase 3: Hints Integration — Extraction Skill (AC4)

These tests require a live Claude Code session.

| Step | Action | Expected |
|------|--------|----------|
| 3.1 | Run `/extract-schema path/to/database-hints.json` where the hints file has an entry matching the target database with `probable_lookup: true` tables | Agent uses the provided path directly (no Glob search). After collecting database details, the generated script's section 17 contains `WHERE t.name IN (N'Table1', N'Table2', ...)` with the correct table names. The cursor structure with `_table_header` synthetic column and `sp_executesql` pattern is preserved. |
| 3.2 | Place a `database-hints.json` in the working directory. Run `/extract-schema` with no arguments. | Agent uses Glob to find the file. Prompts with "Use it to identify lookup tables?" and Yes/No options. |
| 3.3 | When prompted in step 3.2, select "No — use row-count heuristic". | Generated script's section 17 contains `HAVING SUM(p.rows) > 0 AND SUM(p.rows) < 100` (the original heuristic). No hints-driven WHERE IN clause. |
| 3.4 | Run `/extract-schema` with no hints file present in the working directory. | No prompt about hints. Section 17 uses the original heuristic. |
| 3.5 | Run `/extract-schema path/to/database-hints.json` where no entry in the hints file matches the target database name. | Agent warns: "No entry in database-hints.json matches database {DB_NAME}. Falling back to row-count heuristic for section 17." Section 17 uses the heuristic. |
| 3.6 | Run `/extract-schema path/to/database-hints.json` where the matching entry has zero `probable_lookup: true` tables. | Agent warns about zero lookup tables and falls back to the heuristic. |
| 3.7 | Run `/extract-schema path/to/database-hints.json` where two entries both substring-match the target database name. | Agent lists both entries and prompts the user to select one via AskUserQuestion. |

---

## Phase 4: Pipeline Threading (AC5)

| Step | Action | Expected |
|------|--------|----------|
| 4.1 | Run `/schema-docs path/to/database-hints.json` | During Stage 1 (setup), the agent acknowledges the hints file path from arguments. |
| 4.2 | Observe the Stage 2 skill invocation | When the agent invokes `generate-extraction-script`, the Skill tool call includes the hints file path in its ARGUMENTS parameter (visible in the tool invocation). |
| 4.3 | Confirm no ed3d-house-style references in generation | Run the full pipeline through Stage 5 (generation). The agent's writing output follows the inlined style guidance ("concise, specific, factual") without attempting to invoke any `ed3d-house-style` skill. |

---

## End-to-End: Full Pipeline with Hints

**Purpose:** Validate that the hints file flows correctly from `/schema-docs` through argument forwarding, to the extraction skill, through the human gate, and into generation — exercising the complete modified pipeline.

1. Prepare a `database-hints.json` with an entry matching your test database, containing 2–3 tables marked `probable_lookup: true`.
2. Run `/schema-docs path/to/database-hints.json`.
3. Provide database details when prompted (MSSQL, server, database name).
4. Verify Stage 2 forwards the hints path to the extraction skill.
5. Verify the generated extraction script's section 17 uses `WHERE t.name IN (...)` with the correct table names from the hints file.
6. Execute the extraction script against your test database (Stage 3 human gate).
7. Verify the 17 extraction files are created in `references/databases/{DB_NAME}/`.
8. Allow the pipeline to proceed through Stage 4 (validation) and Stage 5 (generation).
9. Verify reference docs are created in `docs/database_reference/{DB_NAME}/`.
10. Verify the generated documentation is written in a concise, factual style without AI writing patterns.

---

## Human Verification Required

| Criterion | Why Manual | Steps |
|-----------|------------|-------|
| AC2.2 (semantic accuracy) | Whether the consolidated Skill Contracts section captures all contracts from the deleted companions requires human judgment | 1.4 |
| AC3.5 (README quality) | Keyword presence does not verify clarity or completeness for a first-time user | 2.5 |
| AC4.1–AC4.7 (behavioral) | These criteria require a live Claude Code agent session to verify the agent follows SKILL.md instructions correctly | 3.1–3.7 |
| AC5.1–AC5.2 (pipeline threading) | Verifying argument forwarding between skills requires observing a live pipeline execution | 4.1–4.2 |
| AC5.3 (writing style) | Confirming the agent uses inlined guidance rather than invoking an external skill requires observing generation output | 4.3 |

---

## Traceability

| Acceptance Criterion | Automated Check | Manual Step |
|----------------------|----------------|-------------|
| AC1.1 | grep for "Plugin-Dev Enforcement" and "plugin-dev-kit" in `.claude/CLAUDE.md` — both 0 | 1.1 |
| AC1.2 | git diff on historical design doc — empty | 1.2 |
| AC2.1 | ls on three `skills/*/CLAUDE.md` paths — all "No such file" | 1.3 |
| AC2.2 | grep for section headings in `.claude/CLAUDE.md` — all found | 1.4 (semantic accuracy) |
| AC3.1 | grep `user-invocable: true` in all SKILL.md — all match | 2.1 |
| AC3.2 | grep `allowed-tools: Skill` in all commands — all match | 2.2 |
| AC3.3 | grep ARGUMENTS in command files — correct forwarding pattern | 2.3 |
| AC3.4 | grep version 0.2.0 in plugin.json — match | 2.4 |
| AC3.5 | grep for command names and install command in README — all found | 2.5 (quality judgment) |
| AC4.1 | grep for direct-path instructions in SKILL.md — found | 3.1 |
| AC4.2 | grep for CWD search and prompt instructions — found | 3.2 |
| AC4.3 | grep for heuristic path and template section 17 — found | 3.3, 3.4 |
| AC4.4 | grep for WHERE IN, _table_header, sp_executesql — all found | 3.1 |
| AC4.5 | grep for "Zero matches" and fallback text — found | 3.5 |
| AC4.6 | grep for zero probable_lookup text — found | 3.6 |
| AC4.7 | grep for "Multiple matches" and select prompt — found | 3.7 |
| AC5.1 | grep for hints file path in plan-schema-docs — found | 4.1 |
| AC5.2 | grep for ARGUMENTS hints forwarding — found | 4.2 |
| AC5.3 | grep confirms no ed3d-house-style references; replacement text present | 4.3 |
