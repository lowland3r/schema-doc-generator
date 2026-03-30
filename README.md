# schema-doc-generator

A Claude Code plugin that automates database schema extraction and reference documentation generation for MSSQL databases.

## Commands

| Command | Description |
|---------|-------------|
| `/extract-schema` | Generate a database schema extraction script (PowerShell or sqlcmd) |
| `/generate-docs` | Generate reference documentation from existing extraction files |
| `/schema-docs` | Full pipeline: extraction script generation, human execution gate, then reference doc generation |

## Installation

```bash
claude plugin install https://github.com/lowland3r/schema-doc-generator
```

Requires the `ed3d-basic-agents` plugin for large-corpus (>=50KB) documentation generation:

```bash
claude plugin install https://github.com/lowland3r/ed3d-basic-agents
```

## How It Works

1. Run `/extract-schema` (or `/schema-docs` for the full pipeline) and provide your SQL Server instance, database name, and preferred script format (PowerShell/dbatools or sqlcmd).
2. The plugin generates an extraction script. **You run it** — the plugin never connects to your database.
3. Run `/generate-docs` to transform the 17 extraction files into structured reference documentation.

## Output

- Extraction files: `references/databases/{DB_NAME}/` (17 pipe-delimited `.txt` files)
- Reference docs: `docs/database_reference/{DB_NAME}/` (8 output files including per-domain table docs)
