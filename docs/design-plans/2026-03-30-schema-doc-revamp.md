# Schema Doc Generator Revamp Design

## Summary

This revamp addresses accumulated technical debt in the `schema-doc-generator` plugin across two areas: housekeeping and a new capability. The housekeeping work removes a dependency on the `plugin-dev-kit` external plugin, deletes per-skill `CLAUDE.md` companion files (consolidating their contracts into the project-level `CLAUDE.md`), and brings all command and skill files into conformance with current `creating-a-plugin` and `writing-skills` conventions — including `user-invocable: true` frontmatter on every skill and `allowed-tools: Skill` on every command.

The new capability is hints-driven lookup table identification. Today, the extraction script identifies lookup tables by a row-count heuristic (`< 100 rows`). After this revamp, users can optionally provide a `database-hints.json` file that explicitly marks tables as `probable_lookup: true`. When the skill detects or is given a hints file, it replaces the heuristic filter in section 17 of the generated SQL with an explicit `WHERE t.name IN (...)` clause built from the hints. The rest of the generated script — sections 1–16, both dbatools and sqlcmd paths, the human execution gate — is unchanged. The hints path is threaded from the top-level `schema-docs` command through `plan-schema-docs` to `generate-extraction-script`; the downstream `generate-reference-docs` skill requires no changes because it consumes the 17-file output regardless of how it was produced.

## Definition of Done

1. All plugin-dev-kit references removed from `CLAUDE.md` (the historical design doc at `docs/design-plans/2026-03-17-lowlanders-plugin-dev-kit.md` stays as-is)
2. All three skill `CLAUDE.md` companion files deleted; any contract/invariant information consolidated into the project `CLAUDE.md`
3. All `SKILL.md` files and `plugin.json` updated to comply with `creating-a-plugin` and `writing-skills` best practices
4. The `generate-extraction-script` skill updated to accept an optional hints file path; if omitted, recursively searches CWD for `database-hints.json` and prompts the user; if hints present, uses `probable_lookup: true` tables for section 17 (lookup data); if absent, falls back to the existing `<100 rows` heuristic
5. The `plan-schema-docs` and `generate-reference-docs` skills updated as needed to thread the hints path through the full pipeline

## Acceptance Criteria

### schema-doc-revamp.AC1: plugin-dev-kit references removed
- **schema-doc-revamp.AC1.1 Success:** "Plugin-Dev Enforcement" section is absent from `CLAUDE.md`
- **schema-doc-revamp.AC1.2 Success:** `docs/design-plans/2026-03-17-lowlanders-plugin-dev-kit.md` is unchanged

### schema-doc-revamp.AC2: CLAUDE.md companions removed and content consolidated
- **schema-doc-revamp.AC2.1 Success:** `skills/*/CLAUDE.md` files do not exist
- **schema-doc-revamp.AC2.2 Success:** Project `CLAUDE.md` contains a Skill Contracts section with the key contracts/invariants from the deleted companions

### schema-doc-revamp.AC3: Plugin files comply with best practices
- **schema-doc-revamp.AC3.1 Success:** All three SKILL.md files have `user-invocable: true`
- **schema-doc-revamp.AC3.2 Success:** All three command files have `allowed-tools: Skill` in frontmatter
- **schema-doc-revamp.AC3.3 Success:** `extract-schema.md` and `schema-docs.md` forward `$ARGUMENTS` to their skills
- **schema-doc-revamp.AC3.4 Success:** `plugin.json` version is `0.2.0`
- **schema-doc-revamp.AC3.5 Success:** `README.md` exists at repo root with plugin description, commands, and installation instructions

### schema-doc-revamp.AC4: Hints integration in generate-extraction-script
- **schema-doc-revamp.AC4.1 Success:** Hints path passed as arg is used directly without CWD search
- **schema-doc-revamp.AC4.2 Success:** If no arg and `database-hints.json` found in CWD, user is prompted whether to use it
- **schema-doc-revamp.AC4.3 Success:** If no hints file or user declines, section 17 uses the original `<100 rows` heuristic unchanged
- **schema-doc-revamp.AC4.4 Success:** When hints are active and database matches, section 17 SQL uses `WHERE t.name IN (...)` with `probable_lookup: true` tables; synthetic `_table_header` column and `sp_executesql` pattern are preserved
- **schema-doc-revamp.AC4.5 Failure:** If hints file provided but no database entry matches, skill warns and falls back to heuristic
- **schema-doc-revamp.AC4.6 Edge:** If matched database entry has zero `probable_lookup: true` tables, skill warns and falls back to heuristic
- **schema-doc-revamp.AC4.7 Edge:** If multiple entries match the database name, skill lists matches and prompts user to select one

### schema-doc-revamp.AC5: Pipeline threading and SKILL.md compliance
- **schema-doc-revamp.AC5.1 Success:** `plan-schema-docs` Stage 1 collects hints file path from arguments
- **schema-doc-revamp.AC5.2 Success:** `plan-schema-docs` Stage 2 passes hints path to `generate-extraction-script`
- **schema-doc-revamp.AC5.3 Success:** `generate-reference-docs` SKILL.md contains no direct `ed3d-house-style:writing-for-a-technical-audience` skill reference; writing style guidance uses plain language

## Glossary

- **17-file interface**: The fixed set of pipe-delimited text files (`01_` through `17_`) produced by the extraction skill and consumed by the reference docs generation skill. This is the primary contract between the two halves of the pipeline.
- **database-hints.json**: An optional JSON file that carries metadata about a database, including which tables should be treated as lookup tables (`probable_lookup: true`). External to this plugin — expected to already exist in the user's project.
- **dbatools**: A PowerShell module for SQL Server administration. The extraction skill can generate scripts that use dbatools commands as an alternative to the bare `sqlcmd` path.
- **ed3d-basic-agents**: A separate Claude Code plugin that provides fan-out generation workers. Required by `schema-doc-generator` for the large-corpus (>=50 KB) documentation generation path.
- **ed3d-house-style**: A separate Claude Code plugin supplying writing and coding style sub-skills. The revamp removes a direct reference to its `writing-for-a-technical-audience` sub-skill and replaces it with equivalent inline guidance.
- **fan-out**: A multi-agent pattern where a corpus is split across parallel worker agents whose outputs are then reconciled by a summarizer. Used when the extraction corpus exceeds 50 KB.
- **human gate**: An intentional stopping point in the pipeline where the plugin hands off a generated artifact to the user for manual review and execution, rather than running it automatically. Specifically: the extraction SQL script is generated but never executed by the plugin.
- **plugin-dev-kit**: A Claude Code plugin that enforces plugin development conventions at authoring time. This revamp removes the dependency on it, inlining the relevant conventions directly.
- **probable_lookup**: A field in `database-hints.json` entries. When `true`, the table is included in the hints-driven section 17 SQL instead of being identified by the row-count heuristic.
- **section 17**: The last section of the generated extraction SQL script, responsible for capturing lookup table data. Its generation logic is the primary target of the hints integration.
- **SKILL.md**: The prompt file that defines a skill's behavior. All business logic for this plugin lives in these files; there is no executable code besides the SQL template.
- **sp_executesql**: A SQL Server stored procedure used to execute dynamically constructed SQL strings. The section 17 generation preserves this pattern in both the heuristic and hints-driven paths.
- **sqlcmd**: A command-line SQL Server client. The extraction skill generates scripts in two variants — one using dbatools, one using sqlcmd — for users without the dbatools module installed.
- **synthetic `_table_header` column**: A column injected into section 17 query output to mark row boundaries between tables in the pipe-delimited output file. Required for downstream parsing.
- **user-invocable**: A frontmatter field on `SKILL.md` files indicating that a skill can be called directly by users (not only by other skills or commands). Required by current plugin conventions.

## Architecture

The revamp makes no structural changes to the plugin layout. Three skills and three commands remain; the 17-file extraction contract is unchanged. Changes are in-place rewrites of existing files.

**Hints integration path (generate-extraction-script):**

When the user provides a hints file (or one is discovered in CWD), the skill reads `database-hints.json`, locates the database entry matching the target database name, and extracts all table names where `probable_lookup: true`. It then generates a custom section 17 SQL — replacing the row-count cursor's `HAVING SUM(p.rows) < 100` filter with `WHERE t.name IN (N'table1', N'table2', ...)` built from that list. The rest of the generated script (sections 1–16, dbatools/sqlcmd paths, parameter handling) is unchanged.

When no hints file is present or the user declines, the original template section 17 is used without modification.

**Pipeline threading (plan-schema-docs):**

The `plan-schema-docs` orchestration skill receives the hints path via command arguments and passes it explicitly when invoking `generate-extraction-script` in Stage 2. Downstream (`generate-reference-docs`) requires no changes — it consumes `17_lookup_data.txt` regardless of how it was populated.

**Database name matching:**

The skill performs a case-insensitive substring match between the user-provided SQL Server database name and `hints.databases[].name`. If exactly one entry matches, it is used. If no entry matches, the skill warns the user and falls back to the heuristic. If `probable_lookup: true` yields zero tables for the matched entry, the skill warns and falls back.

## Existing Patterns

This revamp follows patterns already established in the plugin:

- **Thin commands**: `commands/*.md` files remain one-line Skill invocations with frontmatter. No logic lives in commands.
- **Skills as prompt files**: All business logic lives in `SKILL.md` files. The revamp adds hints resolution as a new numbered step in `generate-extraction-script`, consistent with the existing step structure.
- **Template-driven generation**: The extraction script is generated by reading `templates/mssql.sql` and building a PowerShell or sqlcmd script around it. The hints integration follows this pattern — the skill selects or replaces section 17's SQL at generation time, keeping the generated script self-contained.
- **Human gate on execution**: The extraction script is never auto-executed. This contract is unchanged.

## Implementation Phases

<!-- START_PHASE_1 -->
### Phase 1: Plugin housekeeping
**Goal:** Remove plugin-dev-kit dependencies, delete CLAUDE.md companions, consolidate contracts into project CLAUDE.md, and add missing plugin artifacts.

**Components:**
- `CLAUDE.md` — remove Plugin-Dev Enforcement section; add Skill Contracts section with the relevant contracts/invariants from the three deleted companions
- `skills/generate-extraction-script/CLAUDE.md` — delete
- `skills/generate-reference-docs/CLAUDE.md` — delete
- `skills/plan-schema-docs/CLAUDE.md` — delete
- `.claude-plugin/plugin.json` — bump version to `0.2.0`
- `README.md` (new) — plugin description, commands reference, installation instructions

**Dependencies:** None

**Done when:** No `plugin-dev-kit` references remain in any tracked file (excluding the historical design doc). All three skill CLAUDE.md companions are absent. Project CLAUDE.md contains a Skill Contracts section. README.md exists at repo root. plugin.json shows version 0.2.0.
<!-- END_PHASE_1 -->

<!-- START_PHASE_2 -->
### Phase 2: Command file compliance
**Goal:** Bring command files into alignment with `creating-a-plugin` best practices.

**Components:**
- `commands/extract-schema.md` — add `allowed-tools: Skill`; pass `$ARGUMENTS` to skill
- `commands/schema-docs.md` — add `allowed-tools: Skill`; pass `$ARGUMENTS` to skill
- `commands/generate-docs.md` — add `allowed-tools: Skill` (no arguments needed)

**Dependencies:** Phase 1

**Done when:** All three command files have `allowed-tools: Skill` in frontmatter. `extract-schema.md` and `schema-docs.md` forward `$ARGUMENTS` to their invoked skills.
<!-- END_PHASE_2 -->

<!-- START_PHASE_3 -->
### Phase 3: Hints integration in generate-extraction-script
**Goal:** Add optional `database-hints.json` support to the extraction skill, replacing the row-count heuristic for section 17 when hints are present.

**Components:**
- `skills/generate-extraction-script/SKILL.md` — rewrite to add:
  - **Step 0 (new)**: Hints file resolution — check for explicit arg; if absent, recursively search CWD for `database-hints.json`; if found, prompt user (Yes / No); parse and match database entry; extract `probable_lookup: true` table names; warn and fall back if no match or zero lookup tables
  - **Step 4 (modified)**: Two generation paths for section 17 — hints-driven (`WHERE t.name IN (...)`) and fallback (original template section unchanged). Sections 1–16 always come from the template.
  - **Step 3 (modified)**: Overwrite warning notes whether hints were resolved (to indicate the script will regenerate with the same hints state)

**Dependencies:** Phase 2

**Done when:** SKILL.md describes Step 0 fully. Step 4 clearly distinguishes hints and fallback paths. The hints-driven SQL contract matches the template's section 17 structure (cursor, synthetic `_table_header` column, `sp_executesql`). `user-invocable: true` is set in frontmatter.
<!-- END_PHASE_3 -->

<!-- START_PHASE_4 -->
### Phase 4: Remaining SKILL.md compliance updates
**Goal:** Update `plan-schema-docs` and `generate-reference-docs` to thread the hints path and align with `writing-skills` best practices.

**Components:**
- `skills/plan-schema-docs/SKILL.md` — Stage 1 collects hints path from arguments; Stage 2 passes it to `generate-extraction-script`; set `user-invocable: true`
- `skills/generate-reference-docs/SKILL.md` — replace direct `ed3d-house-style:writing-for-a-technical-audience` skill reference with plain-language directive ("All output must be written for a technical audience — concise, specific, factual"); set `user-invocable: true`

**Dependencies:** Phase 3

**Done when:** `plan-schema-docs` Stage 2 explicitly passes the hints path. `generate-reference-docs` contains no direct skill-name references for writing style. All three SKILL.md files have `user-invocable: true`.
<!-- END_PHASE_4 -->

## Additional Considerations

**Hints database name matching:** The `database-hints.json` format uses human-readable names (e.g., `"Made2Manage ERP"`) that may differ from the SQL Server database name (e.g., `M2M_DB`). Case-insensitive substring matching handles common divergences. If ambiguity arises (multiple entries match), the skill reports all matches and prompts the user to confirm which to use.

**sqlcmd path and hints:** The hints integration is described in the skill as a conceptual modification to section 17 SQL. The generated sqlcmd commands follow the same logic — the hints-driven section 17 SQL is substituted the same way for both dbatools and sqlcmd generation paths.
