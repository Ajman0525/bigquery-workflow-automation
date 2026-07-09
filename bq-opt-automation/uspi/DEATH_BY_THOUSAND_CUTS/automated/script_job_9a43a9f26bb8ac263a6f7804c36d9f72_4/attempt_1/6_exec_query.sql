-- =================================================================================================
-- Script to create and validate two temporary tables.
-- Expected Outcome: The discrepancy and duplicate detail SELECTs should return zero rows.
-- The final SELECT statement should return two summary rows with row_count = 0, confirming that
-- V_TEMP_TABLE_ORIG and V_TEMP_TABLE_OPT produce identical distinct results and V_TEMP_TABLE_OPT
-- has no duplicate rows.
-- =================================================================================================
-- 1. Stored Procedure Context
-- =================================================================================================
-- START STORED PROCEDURE CONTEXT
-- Auto-generated from 2_sp_details.sql and 3_orig_sp.sql.
-- WARNING: Review the TODO items before relying on this validation script.
-- TODO: Could not locate the original query inside 3_orig_sp.sql; stored procedure context could not be inferred.
-- TODO: Verify variable V_source_system; no prior DECLARE was found in the SP.
-- TODO: Verify temp table dim_fact_sd_temp; no prior temp-table creation was found.
-- No stored procedure context dependencies were detected.
-- END STORED PROCEDURE CONTEXT

-- =================================================================================================
-- 2. Create the Original Temporary Table (V_TEMP_TABLE_ORIG)
-- =================================================================================================
CREATE OR REPLACE TEMP TABLE V_TEMP_TABLE_ORIG AS SELECT * FROM `dim_fact_sd_temp`;
MERGE V_TEMP_TABLE_ORIG AS a
USING (
  SELECT
    a.source_system_id,
    a.appointment_num,
    pr.quick_code AS procedure_code,
    UPPER(stat.description) AS appt_status,
    ROW_NUMBER() OVER (
      PARTITION BY a.source_system_id, a.appointment_num
      ORDER BY pr.quick_code, UPPER(stat.description)
    ) AS row_num
  FROM dim_fact_sd_temp a
  INNER JOIN `advantx_ods.as_appointment_procs` app_pr
    ON a.source_system_id = app_pr.source_system_id
    AND a.appointment_num = app_pr.appointment_num
    AND app_pr.order_num = 1
  INNER JOIN `advantx_ods.ut_proc` pr
    ON app_pr.source_system_id = pr.source_system_id
    AND app_pr.proc_num = pr.num
  INNER JOIN `advantx_ods.it_appointstat` stat
    ON pr.source_system_id = stat.source_system_id
    AND a.appointstat_num = stat.num
) AS src
ON a.source_system_id = src.source_system_id
AND a.appointment_num = src.appointment_num
AND src.row_num = 1
AND src.source_system_id = V_source_system
WHEN MATCHED THEN
  UPDATE SET
    a.procedure_code = src.procedure_code,
    a.appt_status = src.appt_status;

-- =================================================================================================
-- 3. Create the Optimized Temporary Table (V_TEMP_TABLE_OPT)
-- =================================================================================================
CREATE OR REPLACE TEMP TABLE V_TEMP_TABLE_OPT AS SELECT * FROM `dim_fact_sd_temp`;
MERGE V_TEMP_TABLE_OPT AS target
USING (
  WITH
    -- Pre-join appointment procedures and procedure codes, filtering early
    Procedures AS (
      SELECT
        app_pr.source_system_id,
        app_pr.appointment_num,
        pr.quick_code
      FROM `advantx_ods.as_appointment_procs` AS app_pr
      INNER JOIN `advantx_ods.ut_proc` AS pr
        ON app_pr.source_system_id = pr.source_system_id
        AND app_pr.proc_num = pr.num
      WHERE app_pr.source_system_id = V_source_system
        AND app_pr.order_num = 1
    ),
    -- Pre-filter and prepare status descriptions
    Statuses AS (
      SELECT
        source_system_id,
        num,
        UPPER(description) AS appt_status
      FROM `advantx_ods.it_appointstat`
      WHERE source_system_id = V_source_system
    ),
    -- Combine the data, joining back to the target table to get necessary fields
    CombinedSource AS (
      SELECT
        t.source_system_id,
        t.appointment_num,
        p.quick_code AS procedure_code,
        s.appt_status,
        ROW_NUMBER() OVER (
          PARTITION BY t.source_system_id, t.appointment_num
          ORDER BY p.quick_code, s.appt_status
        ) AS row_num
      FROM `dim_fact_sd_temp` AS t
      INNER JOIN Procedures AS p
        ON t.source_system_id = p.source_system_id
        AND t.appointment_num = p.appointment_num
      INNER JOIN Statuses AS s
        ON t.source_system_id = s.source_system_id
        AND t.appointstat_num = s.num
      -- Filter is applied within the target table scan
      WHERE t.source_system_id = V_source_system
    )
  -- Select the single record per appointment to be used for the update
  SELECT
    source_system_id,
    appointment_num,
    procedure_code,
    appt_status
  FROM CombinedSource
  WHERE row_num = 1
) AS source
ON target.source_system_id = source.source_system_id
  AND target.appointment_num = source.appointment_num
WHEN MATCHED THEN
  UPDATE SET
    procedure_code = source.procedure_code,
    appt_status = source.appt_status;

-- =================================================================================================
-- 4. Validation Step: Compare the two tables and check optimized duplicates.
-- DISCREPANCY counts distinct rows that appear in one table but not the other.
-- DUPLICATE ROWS counts extra copies of duplicate rows in V_TEMP_TABLE_OPT.
-- The first two SELECT statements show the actual rows when discrepancies or duplicates exist.
-- The final SELECT statement shows only the summary counts.
-- =================================================================================================
CREATE OR REPLACE TEMP TABLE V_VALIDATION_DISCREPANCIES AS
(SELECT 'ONLY IN ORIGINAL' AS validation_diff_type, *
 FROM V_TEMP_TABLE_ORIG
 EXCEPT DISTINCT
 SELECT 'ONLY IN ORIGINAL' AS validation_diff_type, *
 FROM V_TEMP_TABLE_OPT
)
UNION ALL
(SELECT 'ONLY IN OPTIMIZED' AS validation_diff_type, *
 FROM V_TEMP_TABLE_OPT
 EXCEPT DISTINCT
 SELECT 'ONLY IN OPTIMIZED' AS validation_diff_type, *
 FROM V_TEMP_TABLE_ORIG
);

CREATE OR REPLACE TEMP TABLE V_VALIDATION_OPT_DUPLICATES AS
SELECT duplicate_row.*
FROM (
  SELECT ANY_VALUE(opt) AS duplicate_row
  FROM V_TEMP_TABLE_OPT AS opt
  GROUP BY TO_JSON_STRING(opt)
  HAVING COUNT(*) > 1
);

-- View discrepancy rows.
SELECT *
FROM V_VALIDATION_DISCREPANCIES;

-- View duplicate rows from the optimized query.
SELECT *
FROM V_VALIDATION_OPT_DUPLICATES;

-- View summary counts.
SELECT 'DISCREPANCY' AS validation_check, COUNT(*) AS row_count
FROM V_VALIDATION_DISCREPANCIES
UNION ALL
SELECT 'DUPLICATE ROWS' AS validation_check, COALESCE(SUM(row_count - 1), 0) AS row_count
FROM (
  SELECT COUNT(*) AS row_count
  FROM V_TEMP_TABLE_OPT AS opt
  GROUP BY TO_JSON_STRING(opt)
  HAVING COUNT(*) > 1
);
