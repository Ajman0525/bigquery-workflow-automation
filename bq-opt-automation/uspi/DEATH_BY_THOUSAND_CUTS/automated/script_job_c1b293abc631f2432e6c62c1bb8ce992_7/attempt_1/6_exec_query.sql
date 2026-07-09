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
-- TODO: Verify temp table temp_ca_visit_visitdept; no prior temp-table creation was found.
-- No stored procedure context dependencies were detected.
-- END STORED PROCEDURE CONTEXT

-- =================================================================================================
-- 2. Create the Original Temporary Table (V_TEMP_TABLE_ORIG)
-- =================================================================================================
CREATE OR REPLACE TEMP TABLE V_TEMP_TABLE_ORIG AS
MERGE dim_fact_sd_temp AS target
USING (
  SELECT
    A.source_system_id,
    A.case_number,
    A.appointment_num,
    -- Select and rank rows to handle duplicates
    D.begin_time,
    D.end_time,
    ROW_NUMBER() OVER (
      PARTITION BY A.source_system_id, A.case_number, A.appointment_num
      ORDER BY D.begin_time, D.end_time
    ) AS row_num
  FROM dim_fact_sd_temp A
  INNER JOIN `advantx_ods.as_appointment` B
    ON A.source_system_id = B.source_system_id
    AND A.case_number = B.case_num
    AND A.appointment_num = B.num
  INNER JOIN `advantx_ods.ca_visit` C
    ON B.source_system_id = C.source_system_id
    AND B.case_num = C.case_num
  INNER JOIN `temp_ca_visit_visitdept` D
    ON C.source_system_id = D.source_system_id
    AND C.case_num = D.case_num
    AND C.visit_num = D.visit_num
    AND D.visitdept_num = 3
) AS source
ON target.source_system_id = source.source_system_id
AND target.case_number = source.case_number
AND target.appointment_num = source.appointment_num
AND source.row_num = 1  -- Ensure only the top-ranked row is used
AND source.source_system_id = V_source_system
WHEN MATCHED THEN
  UPDATE SET
    target.begin_time = source.begin_time,
    target.end_time = source.end_time;

-- =================================================================================================
-- 3. Create the Optimized Temporary Table (V_TEMP_TABLE_OPT)
-- =================================================================================================
CREATE OR REPLACE TEMP TABLE V_TEMP_TABLE_OPT AS
WITH source_for_update AS (
  SELECT
    A.source_system_id,
    A.case_number,
    A.appointment_num,
    D.begin_time,
    D.end_time,
    ROW_NUMBER() OVER(
      PARTITION BY A.source_system_id, A.case_number, A.appointment_num
      ORDER BY D.begin_time, D.end_time
    ) AS row_num
  FROM dim_fact_sd_temp AS A
  INNER JOIN `advantx_ods.as_appointment` AS B
    ON A.source_system_id = B.source_system_id
    AND A.case_number = B.case_num
    AND A.appointment_num = B.num
  INNER JOIN `advantx_ods.ca_visit` AS C
    ON B.source_system_id = C.source_system_id
    AND B.case_num = C.case_num
  INNER JOIN `temp_ca_visit_visitdept` AS D
    ON C.source_system_id = D.source_system_id
    AND C.case_num = D.case_num
    AND C.visit_num = D.visit_num
  WHERE A.source_system_id = V_source_system
    AND D.visitdept_num = 3
)
MERGE dim_fact_sd_temp AS target
USING (
  SELECT
    source_system_id,
    case_number,
    appointment_num,
    begin_time,
    end_time
  FROM source_for_update
  WHERE row_num = 1
) AS source
ON target.source_system_id = source.source_system_id
  AND target.case_number = source.case_number
  AND target.appointment_num = source.appointment_num
WHEN MATCHED
  THEN
    UPDATE
    SET
      target.begin_time = source.begin_time,
      target.end_time = source.end_time;

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
