-- =============================================================================
-- MSSQL Schema Extraction Queries
-- For use with the defect tracking reference documentation framework.
-- Compatible with SQL Server 2008+ (compatibility level 100)
-- =============================================================================
-- Run each section against your target MSSQL database (the backend of the
-- Microsoft Access defect tracking application). Export results as pipe-
-- delimited text and place each section's output in the corresponding numbered
-- file under databases/{DATABASE_NAME}/.
--
-- Recommended: run via sqlcmd or SSMS "Results to Text/File"
--   sqlcmd -S <server> -d <database> -i schema_extraction.sql -o output.txt -s"|" -W
--
-- Note: Uses FOR XML PATH for column aggregation instead of STRING_AGG
-- (which requires SQL Server 2017+). All syntax is valid for compat level 100.
-- =============================================================================


-- =============================================================================
-- 1. DATABASE METADATA
-- =============================================================================
-- Run this first to capture the database name, collation, and compatibility level.

SELECT
    DB_NAME()                           AS database_name,
    DATABASEPROPERTYEX(DB_NAME(), 'Collation') AS collation,
    d.compatibility_level,
    d.recovery_model_desc,
    d.create_date
FROM sys.databases d
WHERE d.name = DB_NAME();


-- =============================================================================
-- 2. SCHEMAS
-- =============================================================================

SELECT
    s.schema_id,
    s.name              AS schema_name,
    p.name              AS schema_owner
FROM sys.schemas s
INNER JOIN sys.database_principals p ON s.principal_id = p.principal_id
WHERE s.schema_id < 16384
  AND s.name NOT IN ('sys', 'INFORMATION_SCHEMA', 'guest')
ORDER BY s.name;


-- =============================================================================
-- 3. TABLES AND COLUMNS
-- =============================================================================
-- Core table/column listing with types, nullability, defaults, and identity info.

SELECT
    s.name                              AS schema_name,
    t.name                              AS table_name,
    c.column_id,
    c.name                              AS column_name,
    tp.name                             AS data_type,
    CASE
        WHEN tp.name IN ('nvarchar','nchar','varchar','char','varbinary','binary')
            THEN CASE c.max_length WHEN -1 THEN 'MAX' ELSE CAST(
                CASE WHEN tp.name IN ('nvarchar','nchar')
                     THEN c.max_length / 2
                     ELSE c.max_length
                END AS VARCHAR(10))
            END
        WHEN tp.name IN ('decimal','numeric')
            THEN CAST(c.precision AS VARCHAR) + ',' + CAST(c.scale AS VARCHAR)
        ELSE NULL
    END                                 AS type_detail,
    c.is_nullable,
    c.is_identity,
    CASE WHEN ic.column_id IS NOT NULL
         THEN CAST(ic.seed_value AS VARCHAR) + '/' + CAST(ic.increment_value AS VARCHAR)
         ELSE NULL
    END                                 AS identity_seed_increment,
    dc.definition                       AS default_value,
    c.is_computed,
    cc.definition                       AS computed_definition,
    ep.value                            AS column_description
FROM sys.tables t
INNER JOIN sys.schemas s            ON t.schema_id = s.schema_id
INNER JOIN sys.columns c            ON t.object_id = c.object_id
INNER JOIN sys.types tp             ON c.user_type_id = tp.user_type_id
LEFT JOIN sys.default_constraints dc ON c.default_object_id = dc.object_id
LEFT JOIN sys.computed_columns cc   ON c.object_id = cc.object_id AND c.column_id = cc.column_id
LEFT JOIN sys.identity_columns ic   ON c.object_id = ic.object_id AND c.column_id = ic.column_id
LEFT JOIN sys.extended_properties ep ON ep.major_id = t.object_id
                                    AND ep.minor_id = c.column_id
                                    AND ep.name = 'MS_Description'
WHERE t.is_ms_shipped = 0
ORDER BY s.name, t.name, c.column_id;


-- =============================================================================
-- 4. PRIMARY KEYS
-- =============================================================================

SELECT
    s.name                              AS schema_name,
    t.name                              AS table_name,
    kc.name                             AS pk_name,
    STUFF((
        SELECT ', ' + c2.name
        FROM sys.index_columns ic2
        INNER JOIN sys.columns c2   ON ic2.object_id = c2.object_id
                                    AND ic2.column_id = c2.column_id
        WHERE ic2.object_id = i.object_id
          AND ic2.index_id = i.index_id
        ORDER BY ic2.key_ordinal
        FOR XML PATH(''), TYPE
    ).value('.', 'NVARCHAR(MAX)'), 1, 2, '')
                                        AS pk_columns,
    i.type_desc                         AS index_type
FROM sys.key_constraints kc
INNER JOIN sys.tables t             ON kc.parent_object_id = t.object_id
INNER JOIN sys.schemas s            ON t.schema_id = s.schema_id
INNER JOIN sys.indexes i            ON kc.parent_object_id = i.object_id
                                    AND kc.unique_index_id = i.index_id
WHERE kc.type = 'PK'
  AND t.is_ms_shipped = 0
ORDER BY s.name, t.name;


-- =============================================================================
-- 5. FOREIGN KEYS
-- =============================================================================

SELECT
    s.name                              AS schema_name,
    tp.name                             AS parent_table,
    fk.name                             AS fk_name,
    STUFF((
        SELECT ', ' + cp2.name
        FROM sys.foreign_key_columns fkc2
        INNER JOIN sys.columns cp2  ON fkc2.parent_object_id = cp2.object_id
                                    AND fkc2.parent_column_id = cp2.column_id
        WHERE fkc2.constraint_object_id = fk.object_id
        ORDER BY fkc2.constraint_column_id
        FOR XML PATH(''), TYPE
    ).value('.', 'NVARCHAR(MAX)'), 1, 2, '')
                                        AS parent_columns,
    sr.name                             AS referenced_schema,
    tr.name                             AS referenced_table,
    STUFF((
        SELECT ', ' + cr2.name
        FROM sys.foreign_key_columns fkc2
        INNER JOIN sys.columns cr2  ON fkc2.referenced_object_id = cr2.object_id
                                    AND fkc2.referenced_column_id = cr2.column_id
        WHERE fkc2.constraint_object_id = fk.object_id
        ORDER BY fkc2.constraint_column_id
        FOR XML PATH(''), TYPE
    ).value('.', 'NVARCHAR(MAX)'), 1, 2, '')
                                        AS referenced_columns,
    fk.delete_referential_action_desc   AS on_delete,
    fk.update_referential_action_desc   AS on_update,
    fk.is_disabled
FROM sys.foreign_keys fk
INNER JOIN sys.tables tp            ON fk.parent_object_id = tp.object_id
INNER JOIN sys.schemas s            ON tp.schema_id = s.schema_id
INNER JOIN sys.tables tr            ON fk.referenced_object_id = tr.object_id
INNER JOIN sys.schemas sr           ON tr.schema_id = sr.schema_id
WHERE tp.is_ms_shipped = 0
ORDER BY s.name, tp.name, fk.name;


-- =============================================================================
-- 6. INDEXES (non-PK)
-- =============================================================================

SELECT
    s.name                              AS schema_name,
    t.name                              AS table_name,
    i.name                              AS index_name,
    i.type_desc                         AS index_type,
    i.is_unique,
    i.is_primary_key,
    i.has_filter,
    i.filter_definition,
    STUFF((
        SELECT ', ' + c2.name
        FROM sys.index_columns ic2
        INNER JOIN sys.columns c2   ON ic2.object_id = c2.object_id
                                    AND ic2.column_id = c2.column_id
        WHERE ic2.object_id = i.object_id
          AND ic2.index_id = i.index_id
          AND ic2.is_included_column = 0
        ORDER BY ic2.key_ordinal
        FOR XML PATH(''), TYPE
    ).value('.', 'NVARCHAR(MAX)'), 1, 2, '')
                                        AS key_columns,
    STUFF((
        SELECT ', ' + c2.name
        FROM sys.index_columns ic2
        INNER JOIN sys.columns c2   ON ic2.object_id = c2.object_id
                                    AND ic2.column_id = c2.column_id
        WHERE ic2.object_id = i.object_id
          AND ic2.index_id = i.index_id
          AND ic2.is_included_column = 1
        ORDER BY ic2.index_column_id
        FOR XML PATH(''), TYPE
    ).value('.', 'NVARCHAR(MAX)'), 1, 2, '')
                                        AS included_columns
FROM sys.indexes i
INNER JOIN sys.tables t             ON i.object_id = t.object_id
INNER JOIN sys.schemas s            ON t.schema_id = s.schema_id
WHERE i.is_primary_key = 0
  AND i.type > 0  -- exclude heaps
  AND t.is_ms_shipped = 0
ORDER BY s.name, t.name, i.name;


-- =============================================================================
-- 7. UNIQUE CONSTRAINTS
-- =============================================================================

SELECT
    s.name                              AS schema_name,
    t.name                              AS table_name,
    kc.name                             AS constraint_name,
    STUFF((
        SELECT ', ' + c2.name
        FROM sys.index_columns ic2
        INNER JOIN sys.columns c2   ON ic2.object_id = c2.object_id
                                    AND ic2.column_id = c2.column_id
        WHERE ic2.object_id = i.object_id
          AND ic2.index_id = i.index_id
        ORDER BY ic2.key_ordinal
        FOR XML PATH(''), TYPE
    ).value('.', 'NVARCHAR(MAX)'), 1, 2, '')
                                        AS columns
FROM sys.key_constraints kc
INNER JOIN sys.tables t             ON kc.parent_object_id = t.object_id
INNER JOIN sys.schemas s            ON t.schema_id = s.schema_id
INNER JOIN sys.indexes i            ON kc.parent_object_id = i.object_id
                                    AND kc.unique_index_id = i.index_id
WHERE kc.type = 'UQ'
  AND t.is_ms_shipped = 0
ORDER BY s.name, t.name;


-- =============================================================================
-- 8. CHECK CONSTRAINTS
-- =============================================================================

SELECT
    s.name                              AS schema_name,
    t.name                              AS table_name,
    cc.name                             AS constraint_name,
    cc.definition,
    cc.is_disabled
FROM sys.check_constraints cc
INNER JOIN sys.tables t             ON cc.parent_object_id = t.object_id
INNER JOIN sys.schemas s            ON t.schema_id = s.schema_id
WHERE t.is_ms_shipped = 0
ORDER BY s.name, t.name, cc.name;


-- =============================================================================
-- 9. VIEWS
-- =============================================================================

SELECT
    s.name                              AS schema_name,
    v.name                              AS view_name,
    m.definition                        AS view_definition,
    ep.value                            AS view_description
FROM sys.views v
INNER JOIN sys.schemas s            ON v.schema_id = s.schema_id
INNER JOIN sys.sql_modules m        ON v.object_id = m.object_id
LEFT JOIN sys.extended_properties ep ON ep.major_id = v.object_id
                                    AND ep.minor_id = 0
                                    AND ep.name = 'MS_Description'
WHERE v.is_ms_shipped = 0
ORDER BY s.name, v.name;


-- =============================================================================
-- 10. STORED PROCEDURES
-- =============================================================================

SELECT
    s.name                              AS schema_name,
    p.name                              AS procedure_name,
    m.definition                        AS procedure_definition,
    p.create_date,
    p.modify_date,
    ep.value                            AS procedure_description
FROM sys.procedures p
INNER JOIN sys.schemas s            ON p.schema_id = s.schema_id
INNER JOIN sys.sql_modules m        ON p.object_id = m.object_id
LEFT JOIN sys.extended_properties ep ON ep.major_id = p.object_id
                                    AND ep.minor_id = 0
                                    AND ep.name = 'MS_Description'
WHERE p.is_ms_shipped = 0
ORDER BY s.name, p.name;


-- =============================================================================
-- 11. STORED PROCEDURE PARAMETERS
-- =============================================================================

SELECT
    s.name                              AS schema_name,
    o.name                              AS procedure_name,
    par.parameter_id,
    par.name                            AS parameter_name,
    tp.name                             AS data_type,
    CASE
        WHEN tp.name IN ('nvarchar','nchar','varchar','char','varbinary','binary')
            THEN CASE par.max_length WHEN -1 THEN 'MAX' ELSE CAST(
                CASE WHEN tp.name IN ('nvarchar','nchar')
                     THEN par.max_length / 2
                     ELSE par.max_length
                END AS VARCHAR(10))
            END
        WHEN tp.name IN ('decimal','numeric')
            THEN CAST(par.precision AS VARCHAR) + ',' + CAST(par.scale AS VARCHAR)
        ELSE NULL
    END                                 AS type_detail,
    par.is_output,
    par.has_default_value,
    par.default_value
FROM sys.parameters par
INNER JOIN sys.objects o            ON par.object_id = o.object_id
INNER JOIN sys.schemas s            ON o.schema_id = s.schema_id
INNER JOIN sys.types tp             ON par.user_type_id = tp.user_type_id
WHERE o.type = 'P'
  AND o.is_ms_shipped = 0
ORDER BY s.name, o.name, par.parameter_id;


-- =============================================================================
-- 12. SCALAR AND TABLE-VALUED FUNCTIONS
-- =============================================================================

SELECT
    s.name                              AS schema_name,
    o.name                              AS function_name,
    o.type_desc                         AS function_type,
    m.definition                        AS function_definition,
    o.create_date,
    o.modify_date
FROM sys.objects o
INNER JOIN sys.schemas s            ON o.schema_id = s.schema_id
INNER JOIN sys.sql_modules m        ON o.object_id = m.object_id
WHERE o.type IN ('FN', 'IF', 'TF')  -- scalar, inline table, multi-statement table
  AND o.is_ms_shipped = 0
ORDER BY s.name, o.name;


-- =============================================================================
-- 13. TRIGGERS
-- =============================================================================

SELECT
    s.name                              AS schema_name,
    OBJECT_NAME(tr.parent_id)           AS table_name,
    tr.name                             AS trigger_name,
    tr.is_instead_of_trigger,
    m.definition                        AS trigger_definition,
    STUFF((
        SELECT ', ' + te2.type_desc
        FROM sys.trigger_events te2
        WHERE te2.object_id = tr.object_id
        FOR XML PATH(''), TYPE
    ).value('.', 'NVARCHAR(MAX)'), 1, 2, '')
                                        AS trigger_events,
    tr.is_disabled
FROM sys.triggers tr
INNER JOIN sys.sql_modules m        ON tr.object_id = m.object_id
INNER JOIN sys.tables t             ON tr.parent_id = t.object_id
INNER JOIN sys.schemas s            ON t.schema_id = s.schema_id
WHERE tr.parent_class = 1  -- object-level triggers only
ORDER BY s.name, OBJECT_NAME(tr.parent_id), tr.name;


-- =============================================================================
-- 14. USER-DEFINED TYPES
-- =============================================================================

SELECT
    s.name                              AS schema_name,
    t.name                              AS type_name,
    bt.name                             AS base_type,
    t.max_length,
    t.precision,
    t.scale,
    t.is_nullable,
    t.is_table_type
FROM sys.types t
INNER JOIN sys.schemas s            ON t.schema_id = s.schema_id
LEFT JOIN sys.types bt              ON t.system_type_id = bt.user_type_id
WHERE t.is_user_defined = 1
ORDER BY s.name, t.name;


-- =============================================================================
-- 15. TABLE-LEVEL EXTENDED PROPERTIES (descriptions)
-- =============================================================================

SELECT
    s.name                              AS schema_name,
    t.name                              AS table_name,
    ep.name                             AS property_name,
    ep.value                            AS property_value
FROM sys.extended_properties ep
INNER JOIN sys.tables t             ON ep.major_id = t.object_id
INNER JOIN sys.schemas s            ON t.schema_id = s.schema_id
WHERE ep.minor_id = 0
  AND ep.class = 1
  AND t.is_ms_shipped = 0
ORDER BY s.name, t.name, ep.name;


-- =============================================================================
-- 16. ROW COUNTS (for understanding table significance)
-- =============================================================================

SELECT
    s.name                              AS schema_name,
    t.name                              AS table_name,
    SUM(p.rows)                         AS row_count
FROM sys.tables t
INNER JOIN sys.schemas s            ON t.schema_id = s.schema_id
INNER JOIN sys.partitions p         ON t.object_id = p.object_id
WHERE p.index_id IN (0, 1)  -- heap or clustered index
  AND t.is_ms_shipped = 0
GROUP BY s.name, t.name
ORDER BY row_count DESC;

-- =============================================================================
-- 17. LOOKUP TABLE DATA
-- =============================================================================
-- Dynamically extracts all rows from tables with fewer than 100 rows.
-- Uses row counts from sys.partitions to identify candidates, then
-- builds and executes SELECT statements for each.
-- Output: one result set per lookup table, separated by a header row
-- containing the table name.

DECLARE @sql NVARCHAR(MAX) = N'';
DECLARE @schema NVARCHAR(128), @table NVARCHAR(128), @rows BIGINT;

DECLARE lookup_cursor CURSOR LOCAL FAST_FORWARD FOR
    SELECT s.name AS schema_name, t.name AS table_name, SUM(p.rows) AS row_count
    FROM sys.tables t
    INNER JOIN sys.schemas s ON t.schema_id = s.schema_id
    INNER JOIN sys.partitions p ON t.object_id = p.object_id
    WHERE p.index_id IN (0, 1)
      AND t.is_ms_shipped = 0
    GROUP BY s.name, t.name
    HAVING SUM(p.rows) > 0 AND SUM(p.rows) < 100
    ORDER BY s.name, t.name;

OPEN lookup_cursor;
FETCH NEXT FROM lookup_cursor INTO @schema, @table, @rows;

WHILE @@FETCH_STATUS = 0
BEGIN
    -- Print a delimiter line so the output can be split per-table
    SET @sql = N'PRINT ''--- TABLE: ' + @schema + N'.' + @table + N' ---'';'
             + N' SELECT * FROM ' + QUOTENAME(@schema) + N'.' + QUOTENAME(@table) + N';';
    EXEC sp_executesql @sql;
    FETCH NEXT FROM lookup_cursor INTO @schema, @table, @rows;
END

CLOSE lookup_cursor;
DEALLOCATE lookup_cursor;
