# lowlanders-plugin-dev-kit Design

## Summary

`lowlanders-plugin-dev-kit` is a user-level Claude Code plugin that ships a curated set of skills for plugin development work. Instead of relying on external ed3d marketplace plugins at runtime, it bundles adapted copies of five workflow-oriented skills and one validation agent into a single self-contained package. Once installed globally, the skills activate automatically whenever Claude Code detects relevant plugin-development activity — authoring a skill file, editing marketplace metadata, writing documentation — without the user needing to invoke them explicitly.

The build approach is deliberately meta: the ed3d source skills are used to write and harden each adapted skill during construction, but ed3d is not required once the plugin ships. Each of the seven phases produces concrete, testable artifacts, with two quality gates applied to every skill — behavioral testing via RED-GREEN-REFACTOR subagents and structural validation via the bundled `plugin-validator` agent — before the plugin is registered in the `lowlanders-claude-plugins` marketplace.

## Definition of Done

- A Claude Code plugin named `lowlanders-plugin-dev-kit` is installable at user level and globally available across all sessions
- The plugin contains 5 workflow-oriented skills (adapted from ed3d source material) that activate contextually when working on plugin development tasks
- The plugin contains a bundled `plugin-validator` agent that validates plugin structure on demand
- The plugin is self-contained — no ed3d runtime dependency
- The plugin is registered in `lowlanders-claude-plugins` as a git submodule
- `schema-doc-generator/CLAUDE.md` and `lowlanders-claude-plugins/CLAUDE.md` each reference the monoplugin as the active enforcement mechanism

## Acceptance Criteria

### lowlanders-plugin-dev-kit.AC1: Plugin installs and loads at user level
- **lowlanders-plugin-dev-kit.AC1.1 Success:** Plugin installs at user level without errors
- **lowlanders-plugin-dev-kit.AC1.2 Success:** All 5 skills appear in Claude Code's available skill list after installation
- **lowlanders-plugin-dev-kit.AC1.3 Failure:** Manifest with invalid `name` format (e.g. contains spaces) is rejected at load time
- **lowlanders-plugin-dev-kit.AC1.4 Failure:** Manifest with invalid semver `version` is rejected at load time

### lowlanders-plugin-dev-kit.AC2: Skills activate contextually
- **lowlanders-plugin-dev-kit.AC2.1 Success:** Each skill fires on its intended trigger phrases
- **lowlanders-plugin-dev-kit.AC2.2 Success:** Skills do not fire on unrelated general coding tasks
- **lowlanders-plugin-dev-kit.AC2.3 Failure:** A skill with a missing `description` field does not appear in the skill list

### lowlanders-plugin-dev-kit.AC3: plugin-validator agent validates plugin structure
- **lowlanders-plugin-dev-kit.AC3.1 Success:** Agent produces a structured report (Critical / Warning / Positive) against a valid plugin
- **lowlanders-plugin-dev-kit.AC3.2 Success:** Agent correctly identifies a missing `description` field in a command file as a Warning
- **lowlanders-plugin-dev-kit.AC3.3 Success:** Agent correctly identifies a hardcoded credential as a Critical issue
- **lowlanders-plugin-dev-kit.AC3.4 Failure:** Agent invoked on a non-plugin directory reports "plugin not found" with a clear message

### lowlanders-plugin-dev-kit.AC4: Plugin is self-contained at runtime
- **lowlanders-plugin-dev-kit.AC4.1 Success:** All 5 skills function correctly with ed3d plugins absent from the session
- **lowlanders-plugin-dev-kit.AC4.2 Success:** plugin-validator agent operates without referencing ed3d agents or skills

### lowlanders-plugin-dev-kit.AC5: Registered in lowlanders-claude-plugins as a submodule
- **lowlanders-plugin-dev-kit.AC5.1 Success:** `plugins/lowlanders-plugin-dev-kit/` submodule is present in `lowlanders-claude-plugins` pointing to the correct commit
- **lowlanders-plugin-dev-kit.AC5.2 Success:** `marketplace.json` entry for the plugin passes schema validation
- **lowlanders-plugin-dev-kit.AC5.3 Failure:** Submodule pointing to an uncommitted state is caught before push

### lowlanders-plugin-dev-kit.AC6: CLAUDE.md files updated in both existing repos
- **lowlanders-plugin-dev-kit.AC6.1 Success:** `schema-doc-generator/CLAUDE.md` references `lowlanders-plugin-dev-kit` as the active enforcement mechanism for plugin-dev skills
- **lowlanders-plugin-dev-kit.AC6.2 Success:** `lowlanders-claude-plugins/CLAUDE.md` exists and references `lowlanders-plugin-dev-kit` as the enforcement mechanism

## Glossary

- **Claude Code plugin**: A package installable into Claude Code that adds skills, commands, and agents to a session. Defined by a `.claude-plugin/plugin.json` manifest.
- **Skill**: A prompt-only instruction file (`SKILL.md`) that Claude Code loads and applies when the session context matches the skill's description. Contains frontmatter metadata and a markdown body.
- **Skill frontmatter**: YAML header at the top of a `SKILL.md` file containing metadata fields such as `name` and `description`. The `description` field controls contextual activation.
- **Contextual activation / description-matching**: Claude Code's native mechanism for deciding which skills apply to the current task. Skills fire automatically when the task context matches the trigger phrases in their `description` field — no explicit user invocation required.
- **Agent**: A file (e.g., `agents/plugin-validator.md`) that defines a bounded AI sub-process with a specific goal, its own instructions, and structured output. Distinct from a skill in that it performs work rather than guiding Claude's behavior.
- **`plugin-validator` agent**: The bundled agent that inspects a plugin's file structure and frontmatter, producing a structured report of Critical, Warning, and Positive findings.
- **Monoplugin**: A single plugin package that bundles multiple skills and agents that collectively cover a workflow domain. The term distinguishes it from a plugin providing only one skill.
- **RED-GREEN-REFACTOR**: A test discipline borrowed from test-driven development. In this context: RED establishes a baseline (what the skill fails to do before it is written), GREEN confirms the skill produces the desired behavior, and REFACTOR improves quality while keeping tests green.
- **Subagent testing**: Running a skill's instructions through an isolated Claude sub-process to observe behavioral outputs. Used here to validate that skills hold up under realistic prompts before shipping.
- **Progressive disclosure**: A structural pattern for skill files where core guidance appears in the `SKILL.md` body and supplementary detail is offloaded to `references/` files. Keeps the primary file readable without omitting depth.
- **ed3d / `ed3d-extending-claude`**: A third-party Claude Code plugin marketplace (ed3d) providing source skills that this plugin adapts. The `ed3d-extending-claude` package contains the `writing-skills`, `writing-claude-directives`, `testing-skills-with-subagents`, `maintaining-a-marketplace`, and related skills referenced throughout this document.
- **`lowlanders-claude-plugins`**: The personal plugin marketplace repository where lowlander's plugins are registered. Hosts a `marketplace.json` index and tracks each plugin via a git submodule.
- **Git submodule**: A git mechanism for embedding one repository inside another at a fixed commit reference. Used here to include `lowlanders-plugin-dev-kit` as a versioned entry inside `lowlanders-claude-plugins`.
- **`marketplace.json`**: The index file in `lowlanders-claude-plugins` that lists available plugins with their metadata. Must pass schema validation to be considered well-formed.
- **`plugin.json`**: The manifest file at `.claude-plugin/plugin.json` inside each plugin repository. Declares the plugin's name, version, description, author, and file paths.
- **User-level installation**: Installing a Claude Code plugin at the user scope (as opposed to workspace/project scope) so it is available across all sessions and projects on the machine.
- **Kebab-case**: A naming convention where words are lowercase and separated by hyphens (e.g., `lowlanders-plugin-dev-kit`). Required for plugin `name` fields.
- **Semver**: Semantic versioning — a version format of the form `MAJOR.MINOR.PATCH` (e.g., `1.0.0`). Required for the `version` field in `plugin.json`.
- **`CLAUDE.md`**: A markdown file Claude Code loads as persistent instructions for a project or user scope. Referenced in this document as the mechanism for pointing a project at the active enforcement plugin.

## Architecture

A user-level Claude Code plugin that bundles adapted copies of curated ed3d skills into a single self-contained package. Once installed globally, skills activate automatically based on task context matching their frontmatter descriptions — no user prompting required.

**Plugin identity:**
- Name: `lowlanders-plugin-dev-kit`
- Installation: user-level (available in all Claude Code sessions)
- Runtime dependency on ed3d: none
- Build dependency on ed3d: yes (ed3d skills are used to write and test each adapted SKILL.md; once complete, ed3d is not needed to run the monoplugin)

**Five skills — workflow-oriented naming:**

| Skill | Adapts from | Activates when... |
|---|---|---|
| `before-writing-a-skill` | `testing-skills-with-subagents` (RED phase) | Starting to create or edit a skill file |
| `writing-a-skill` | `writing-skills` + `writing-claude-directives` + skill-development spec | Actively authoring skill content |
| `after-writing-a-skill` | `testing-skills-with-subagents` (GREEN/REFACTOR) | Finalizing or preparing to deploy a skill |
| `maintaining-marketplace` | `maintaining-a-marketplace` | Editing marketplace.json, plugin.json, or managing releases |
| `writing-documentation` | `writing-claude-md-files` + `writing-for-a-technical-audience` | Writing or updating CLAUDE.md, docs, or reference content |

**One agent:**

| Agent | Adapts from | Activates when... |
|---|---|---|
| `plugin-validator` | `plugin-dev:plugin-validator` (Anthropics) | User requests plugin validation, or proactively after creating/modifying plugin components |

**Two quality gates per skill (enforced by `after-writing-a-skill`):**
1. Behavioral: RED-GREEN-REFACTOR subagent testing (does the skill hold up under pressure?)
2. Structural: `plugin-validator` agent (is the SKILL.md well-formed per the canonical spec?)

**Contextual triggering mechanism:**

Skills activate via Claude Code's native description-matching. Each SKILL.md frontmatter `description` field uses the third-person format specified in the official `skill-development` skill: specific trigger phrases scoped to plugin-development contexts. Example:

```
description: This skill should be used when starting to create or edit a skill
  file in a Claude Code plugin — before writing any content. Establishes the
  baseline RED test so that changes can be verified to improve behaviour.
```

Descriptions are narrow enough to not fire on general coding tasks.

## Existing Patterns

No existing patterns in `schema-doc-generator` for a monoplugin of this type — this design introduces the pattern. However, the monoplugin follows the same plugin structure as `schema-doc-generator` itself:

- Plugin manifest at `.claude-plugin/plugin.json`
- Skills at `skills/*/SKILL.md` with optional `references/`, `examples/`, `scripts/` subdirectories
- Agents at `agents/*.md` with YAML frontmatter

Skill frontmatter format follows the official `plugin-dev:skill-development` SKILL.md specification from `anthropics/claude-code`: third-person descriptions, specific trigger phrases, 1,500–2,000 word SKILL.md body, progressive disclosure via `references/`.

The `plugin-validator` agent frontmatter follows the same agent definition format as Anthropics' `plugin-dev:plugin-validator`, adapted for lowlander's context (not copied verbatim).

## Implementation Phases

<!-- START_PHASE_1 -->
### Phase 1: Plugin scaffolding
**Goal:** Create the `lowlanders-plugin-dev-kit` repository with valid plugin structure, empty skill directories, and initial `plugin.json`.

**Components:**
- New git repository `lowlanders-plugin-dev-kit` (local + pushed to `lowland3r` GitHub account)
- `.claude-plugin/plugin.json` — plugin manifest with name, version, description, author, license, repository
- `.gitignore` — excludes `.claude/settings.local.json`
- Empty skill directories: `skills/before-writing-a-skill/`, `skills/writing-a-skill/`, `skills/after-writing-a-skill/`, `skills/maintaining-marketplace/`, `skills/writing-documentation/`
- Empty agent directory: `agents/`

**Dependencies:** None (first phase)

**Done when:** Repository exists on GitHub, `plugin.json` passes Claude Code manifest validation (valid JSON, kebab-case name, semver version, relative paths)
<!-- END_PHASE_1 -->

<!-- START_PHASE_2 -->
### Phase 2: `writing-a-skill` skill
**Goal:** Author the core skill that guides writing new skills — the foundational piece that informs all other skill authoring.

**Components:**
- `skills/writing-a-skill/SKILL.md` — adapted from `ed3d-extending-claude:writing-skills`, `ed3d-extending-claude:writing-claude-directives`, and the official `plugin-dev:skill-development` spec; covers frontmatter requirements (third-person, trigger phrases), body structure (imperative form, 1,500–2,000 words), progressive disclosure, and reference file usage
- `skills/writing-a-skill/references/skill-structure.md` — detailed reference for skill anatomy, frontmatter fields, and progressive disclosure patterns

**Dependencies:** Phase 1 (repository exists)

**Done when:** Skill has valid YAML frontmatter with name and third-person description containing specific trigger phrases; body uses imperative form; progressive disclosure demonstrated; skill passes structural validation
<!-- END_PHASE_2 -->

<!-- START_PHASE_3 -->
### Phase 3: `before-writing-a-skill` skill
**Goal:** Author the RED-phase discipline skill — establishes baseline behaviour before any skill content is written or changed.

**Components:**
- `skills/before-writing-a-skill/SKILL.md` — adapted from `ed3d-extending-claude:testing-skills-with-subagents` (RED phase only); covers baseline subagent test setup, what to observe, how to document failures for comparison

**Dependencies:** Phase 2 (`writing-a-skill` establishes the authoring pattern)

**Done when:** Skill has valid frontmatter; activates on skill-creation contexts; baseline test procedure is clear and actionable
<!-- END_PHASE_3 -->

<!-- START_PHASE_4 -->
### Phase 4: `plugin-validator` agent + `after-writing-a-skill` skill
**Goal:** Author the two post-authoring quality gates — behavioral testing (GREEN/REFACTOR) and structural validation.

**Components:**
- `agents/plugin-validator.md` — adapted from Anthropics' `plugin-dev:plugin-validator`; validates manifest, commands, agents, skills, hooks, MCP config, and security; produces structured report with Critical/Warning/Positive findings
- `skills/after-writing-a-skill/SKILL.md` — adapted from `ed3d-extending-claude:testing-skills-with-subagents` (GREEN/REFACTOR phases); delegates to `plugin-validator` agent for structural validation after behavioral tests pass

**Dependencies:** Phase 3 (RED phase skill exists; agent and GREEN/REFACTOR skill are the complementary gates)

**Done when:** Agent produces valid validation report against a sample plugin; `after-writing-a-skill` skill correctly sequences behavioral then structural gates; both files have valid frontmatter
<!-- END_PHASE_4 -->

<!-- START_PHASE_5 -->
### Phase 5: `maintaining-marketplace` skill
**Goal:** Author the skill for marketplace maintenance operations.

**Components:**
- `skills/maintaining-marketplace/SKILL.md` — adapted from `ed3d-extending-claude:maintaining-a-marketplace`; covers `marketplace.json` schema, version management, release checklists, changelog conventions, and sync drift prevention between `plugin.json` and `marketplace.json`

**Dependencies:** Phase 1 (repository exists)

**Done when:** Skill has valid frontmatter; activates on marketplace editing contexts; covers all key maintenance operations from source material
<!-- END_PHASE_5 -->

<!-- START_PHASE_6 -->
### Phase 6: `writing-documentation` skill
**Goal:** Author the documentation skill covering CLAUDE.md files and technical prose.

**Components:**
- `skills/writing-documentation/SKILL.md` — adapted from `ed3d-extending-claude:writing-claude-md-files` and `ed3d-house-style:writing-for-a-technical-audience`; covers freshness dates, top-level vs domain-level CLAUDE.md organization, architectural intent capture, and anti-patterns in technical writing

**Dependencies:** Phase 1 (repository exists)

**Done when:** Skill has valid frontmatter; activates on CLAUDE.md and documentation-writing contexts; writing guidance is specific and actionable
<!-- END_PHASE_6 -->

<!-- START_PHASE_7 -->
### Phase 7: Integration — marketplace registration and CLAUDE.md updates
**Goal:** Register the monoplugin in `lowlanders-claude-plugins` and update CLAUDE.md files in both existing repos to reference it as the active enforcement mechanism.

**Components:**
- `lowlanders-claude-plugins`: add `lowlanders-plugin-dev-kit` as a second git submodule at `plugins/lowlanders-plugin-dev-kit/`; update `marketplace.json` to include the new plugin entry
- `lowlanders-claude-plugins/CLAUDE.md` — new root CLAUDE.md: brief description of the marketplace repo, reference to `lowlanders-plugin-dev-kit` as the active plugin-dev enforcement mechanism, and the `ed3d-extending-claude:maintaining-a-marketplace` skill note
- `schema-doc-generator/CLAUDE.md` — add a note that `lowlanders-plugin-dev-kit` is the active enforcement mechanism for plugin-dev skills (replacing any skills registry section)

**Dependencies:** Phases 1–6 (all skills and agent authored; plugin is in a releasable state)

**Done when:** Submodule appears in `lowlanders-claude-plugins` pointing to correct commit; `marketplace.json` passes validation; both CLAUDE.md files reference the monoplugin; all changes committed and pushed
<!-- END_PHASE_7 -->

## Additional Considerations

**Build process is meta:** Each adapted SKILL.md is authored using `ed3d-extending-claude:writing-skills` and hardened with `ed3d-extending-claude:testing-skills-with-subagents`. The monoplugin is its own first customer — the skills it bundles are used to build it.

**Maintenance burden:** Adapted copies will drift from ed3d originals over time. Each skill's `references/` directory should include a one-line attribution comment noting the source material and version consulted, to make future comparison straightforward.

**Skill description precision:** Descriptions must be narrow enough to not fire on general coding tasks but broad enough to catch all plugin-dev work. The RED-GREEN-REFACTOR testing in Phases 3–4 will surface rationalization gaps in the descriptions before the plugin ships.
