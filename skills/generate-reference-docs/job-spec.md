# Schema Reference Document Generator

## Purpose

You are being given the raw output of database catalog extraction queries run against a database. Your job is to parse these results and produce a set of structured reference documents that will be used to interact with, query, and modify the database.

The reference documents must be accurate, complete, and organized so that a reader can write correct SQL, understand the relationships and business logic encoded in the schema, and make informed decisions about data extraction and modification.

---

## Input Format

You will receive one directory per database. Each directory contains text files with pipe-delimited (`|`) or tab-delimited extraction output, one file per extraction section. The sections are numbered to match the extraction script:

| File | Contents |
|------|----------|
| `01_database_metadata.txt` | Database name, collation, compat level |
| `02_schemas.txt` | Schema names and owners |
| `03_tables_columns.txt` | Every table and column with types, nullability, defaults, identity, computed columns, descriptions |
| `04_primary_keys.txt` | PK constraint names and their columns |
| `05_foreign_keys.txt` | FK relationships with cascade rules and disabled state |
| `06_indexes.txt` | Non-PK indexes with key and included columns, filters |
| `07_unique_constraints.txt` | Unique constraints |
| `08_check_constraints.txt` | Check constraints with definitions |
| `09_views.txt` | View definitions |
| `10_stored_procedures.txt` | Stored procedure bodies |
| `11_procedure_parameters.txt` | Procedure parameter signatures |
| `12_functions.txt` | Scalar and table-valued function definitions |
| `13_triggers.txt` | Trigger definitions and events |
| `14_user_defined_types.txt` | Custom types |
| `15_extended_properties.txt` | Table-level descriptions and metadata |
| `16_row_counts.txt` | Row counts per table |
| `17_lookup_data.txt` | Actual row data from tables with <100 rows (lookup/enum tables). Format: `--- TABLE: schema.table ---` delimiter between tables, followed by pipe-delimited rows. May be empty if no lookup tables exist or extraction did not include this step. |

If the user provides the data in a different format (single file, JSON, pasted text), adapt accordingly. The section numbers and headers in the SQL script are sufficient to identify which data is which.

---

## Output: Reference Document Structure

Generate the following files in the output directory:

### 1. `00_overview.md` — Database Overview

This document provides a high-level map of the database. It should contain:

- **Database metadata**: name, collation, compatibility level, recovery model.
- **Schema inventory**: list each schema with a one-line description of its apparent purpose (inferred from table names within it).
- **Entity-relationship summary**: a written description of the major entity groups and how they relate. Do not generate a diagram; describe the relationships in prose. For example: "The `Defects` table references `WorkOrders` via `WorkOrderID`, and each defect is linked to one or more `DefectDetails` rows by `DefectID`."
- **Table classification**: categorize every table into one of these buckets based on its structure, row count, and relationships:
  - **Transactional** — tables that store event-driven or time-stamped records (defect entries, inspection logs, rework records).
  - **Master/Reference** — tables that store relatively stable entities (parts, suppliers, employees, work centers).
  - **Lookup/Enum** — small tables (typically <100 rows) that map codes to descriptions (defect codes, failure categories, disposition types).
  - **Junction/Bridge** — tables that exist solely to implement many-to-many relationships.
  - **Configuration** — tables storing application settings or feature flags.
  - **Staging/Temp** — tables that appear to be used for ETL or batch processing.
  - **Unknown** — tables whose purpose is unclear; flag these for human annotation.

### 2. `01_type_reference.md` — Data Type Reference

A reference table covering every data type encountered in the schema. Include:

- The SQL type as declared (e.g., `nvarchar(50)`, `decimal(18,4)`, `uniqueidentifier`).
- Behavioral notes relevant to querying and filtering (e.g., collation sensitivity for `nvarchar`, precision loss risks for `float`, whether `bit` columns are used as tri-state with NULLs).
- Any edge cases specific to this schema (e.g., date columns stored as `varchar`, numeric codes stored in string columns).

### 3. `02_tables/` — Per-Domain Table Reference (directory of files)

Group tables by logical domain. Each file covers one domain and contains, for each table in that domain:

- **Table purpose**: one or two sentences describing what this table stores, inferred from its name, columns, relationships, extended properties, and row count.
- **Columns**: for each column, list the name, SQL type, nullability, default, and a one-sentence semantic description. If the column participates in a FK, note the target. If it has a check constraint, note the allowed values. If it is computed, include the formula.
- **Primary key**: the PK column(s) and type (clustered/nonclustered).
- **Foreign keys**: each FK with parent columns, referenced table and columns, cascade rules, and whether it is disabled.
- **Indexes**: each non-PK index with its columns, included columns, uniqueness, and filter condition.
- **Unique constraints**: if any.
- **Triggers**: if any, with a brief summary of what they do.
- **Access patterns** (inferred): based on the indexes and foreign keys, describe the likely query patterns (e.g., "This table is almost certainly queried by `PartNumber` and `InspectionDate` given the composite index on those columns").

File naming convention: `02_tables/{nn}_{domain_name}.md` where `nn` is a zero-padded sequence number and `domain_name` is a lowercase slug. Examples: `02_tables/01_defects.md`, `02_tables/02_work_orders.md`, `02_tables/03_lookup_codes.md`.

### 4. `03_stored_procedures.md` — Stored Procedure Reference

For each stored procedure:

- **Signature**: name, parameters with types and direction (input/output), default values.
- **Purpose**: a one to three sentence summary of what the procedure does, derived from reading its body.
- **Tables touched**: which tables it reads from and writes to.
- **Business logic notes**: any non-obvious logic encoded in the procedure (e.g., conditional branching, transaction handling, error codes, temp table usage).
- **Return behavior**: what result sets it returns, if any, and what output parameters it sets.

Group procedures by the domain they primarily operate on, matching the table groupings from section 3.

### 5. `04_views.md` — View Reference

For each view:

- **Definition summary**: what the view joins and exposes, described in prose rather than reproducing the SQL verbatim.
- **Source tables**: which tables it reads from.
- **Use case**: inferred purpose (reporting view, denormalized lookup, access control layer, etc.).

### 6. `05_functions.md` — Function Reference

For each function:

- **Signature**: name, parameters, return type.
- **Purpose**: what it computes or returns.
- **Usage context**: where it appears to be used (in computed columns, check constraints, other procedures, etc.).

### 7. `06_business_logic.md` — Inferred Business Rules

This is the most important interpretive document. Walk through the schema holistically and document every business rule you can infer from:

- Check constraints (allowed values imply domain rules).
- Foreign key cascade rules (cascade delete implies ownership; no action implies soft references).
- Trigger logic (side effects, audit logging, computed denormalization).
- Default values (especially `GETDATE()`, `NEWID()`, status defaults).
- Naming conventions (columns named `IsDeleted`, `IsActive`, `Status`, `CreatedDate`, `ModifiedDate` imply soft-delete, audit trail, or state machine patterns).
- Stored procedure logic (transaction boundaries, error handling patterns).
- Disabled foreign keys (these often indicate the application manages referential integrity itself).

For each inferred rule, note the confidence level: **High** (directly evidenced by constraints/triggers), **Medium** (strongly implied by naming and structure), or **Low** (speculative, needs human verification).

Also note implications for safe data modification — e.g., "Deleting from `Defects` without first removing `DefectDetails` rows will violate the FK constraint," or "The `IsDeleted` soft-delete pattern means rows should be flagged rather than physically removed."

### 8. `07_annotations_needed.md` — Questions for Human Review

List everything the schema alone cannot answer. This is a structured list of questions organized by table or domain, such as:

- "The `Status` column on `dbo.Defects` is `int` with no check constraint or lookup FK. What do the status codes mean?"
- "The `dbo.AuditLog` table has no foreign keys. Is it written to by triggers, application code, or both?"
- "Tables `dbo.TempImport_A` and `dbo.TempImport_B` appear to be staging tables. Can they be excluded from queries, or does the application read from them?"
- "The FK from `dbo.DefectItems` to `dbo.Parts` is disabled. Is referential integrity enforced at the application layer?"

---

## Processing Instructions

1. **Parse all input files first** before generating any output. You need the full picture to correctly classify tables and infer relationships.

2. **Cross-reference aggressively.** A column named `StatusID` with no FK might still reference a lookup table — check if a table named `Status` or `Statuses` exists. Similarly, naming patterns like `{TableName}ID` on other tables strongly suggest implicit FKs even if they are not declared.

3. **Do not fabricate information.** If a column's purpose is unclear, say so. Place it in the annotations file for human review rather than guessing.

4. **Preserve precision.** When documenting types, include the full type declaration (e.g., `decimal(18,4)`, not just `decimal`). When documenting defaults, include the exact expression.

5. **Single-database dispatch.** This plugin dispatches one database at a time. You will receive extraction files for exactly one database. Generate one set of reference documents in the output directory for that database.

6. **Row counts inform classification.** A table with 12 rows is almost certainly a lookup table. A table with 50 million rows is transactional or logging. Use row counts as a strong signal but not the only one.

7. **Be opinionated about safe modification.** In the business logic document, note things like: "The `IsDeleted` soft-delete pattern on multiple tables means UPDATE rather than DELETE should be used when retiring records" or "Cascade deletes on this FK mean removing a parent row will silently remove all child rows."

8. **Lookup table data enriches documentation.** If `17_lookup_data.txt` contains data, use it to document actual enum/code values in the type reference, table specs, and business logic documents. For example, if `tblDefectCodes` has 108 rows of defect code definitions, include those values (or a representative sample for large lookup tables) in the relevant table spec and cross-reference them in the business logic document.

---

## Style Requirements

- Write in plain, technical prose. No filler, no hedging beyond the confidence levels defined above.
- Use Markdown formatting consistently. Code-style backticks for all SQL identifiers, table names, and column names.
- Keep each document self-contained enough that a reader working on one domain does not need to constantly cross-reference other files, but do use explicit cross-references (e.g., "See `02_tables/01_defects.md` for the `Defects` table definition") when relationships span domains.
- Target audience is an analyst or AI model using these documents to write queries, understand data relationships, and make safe modifications. Be explicit about nullability, constraints, and edge cases.
