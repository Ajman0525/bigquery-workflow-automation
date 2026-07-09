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
-- No stored procedure context dependencies were detected.
-- END STORED PROCEDURE CONTEXT

-- =================================================================================================
-- 2. Create the Original Temporary Table (V_TEMP_TABLE_ORIG)
-- =================================================================================================
CREATE OR REPLACE TEMP TABLE V_TEMP_TABLE_ORIG AS
SELECT A.source_system_id,
       A.company_code,
       A.pers_org_num_org,
       ca.case_num,
       CAST(COALESCE(app.anestype_num, 0) AS STRING) AS anesthesia_type,
      CAST(CONCAT(
           RIGHT('0000' || TRIM(CAST(COALESCE(CAST(ca.tisclient_num AS STRING), '') AS STRING)), 4),
           RIGHT('00000000' || TRIM(CAST(COALESCE(CAST(ca.pers_org_num_pt AS STRING), '') AS STRING)), 8),
           RIGHT('00000000' || TRIM(CAST(COALESCE(CAST(ca.case_num AS STRING), '') AS STRING)), 8)
       ) AS STRING) AS case_id,
        -- COALESCE(CAST(ca.case_num AS STRING),'000000') AS case_id ,     
        CAST(app.num AS STRING) AS appt_code,
       app.enter_date AS appt_create_date,
       CAST(app.visittype_num as STRING) AS appt_type_code,
       app.prim_sched_date AS appt_date,
       app.prim_sched_begin_time,
       app.prim_sched_end_time,
       FORMAT_TIMESTAMP('%A', app.prim_sched_date) AS day_of_week,
       FORMAT_TIMESTAMP('%H:%M:00', app.prim_sched_begin_time) AS appt_start_time,
       FORMAT_TIMESTAMP('%H:%M:00', app.prim_sched_end_time) AS appt_end_time,
       CASE
           WHEN FORMAT_TIMESTAMP('%H:%M', app.prim_sched_begin_time) >= '01:00'
                AND FORMAT_TIMESTAMP('%H:%M', app.prim_sched_end_time) >= '01:00'
           THEN TIMESTAMP_DIFF(app.prim_sched_end_time, app.prim_sched_begin_time, MINUTE)
           ELSE 0
       END AS appt_duration,
       DATE_DIFF(
           DATE(app.prim_sched_date), 
           DATE(app.enter_date), 
           DAY
       ) + CASE
           WHEN TIME(app.enter_date) > TIME '12:00:00' THEN -1
           ELSE 0
       END AS appt_sched_lag,
       app.prim_sched_num,
       app.num,
       app.appointstat_num,
       app.reason_num,
       ca.primary_phys_num,
       ca.refer_phys_num,
       ca.pers_org_num_pt,
       ca.tisclient_num
FROM uspidnaproddata.edw_advantx.vw_ad_tisclient A
INNER JOIN advantx_ods.ca_case ca
    ON LOWER(A.source_system_id) = ca.source_system_id
    AND A.pers_org_num_org = ca.tisclient_num
INNER JOIN advantx_ods.as_appointment app
    ON ca.source_system_id = app.source_system_id
    AND ca.case_num = app.case_num
    where ca.source_system_id = V_source_system AND CA.key_dos >= 
    (SELECT DATETIME(CONCAT(CAST(EXTRACT(YEAR FROM DATE_SUB(CURRENT_DATE(), INTERVAL 365 DAY)) AS STRING), '-01-01 00:00:00')) 
    AS datetime_three_years_ago);

-- =================================================================================================
-- 3. Create the Optimized Temporary Table (V_TEMP_TABLE_OPT)
-- =================================================================================================
CREATE OR REPLACE TEMP TABLE V_TEMP_TABLE_OPT AS
WITH prefiltered_appointments AS (
    -- Step 1: Filter ca_case and join to as_appointment first. This drastically reduces the number of rows
    -- flowing into the main join with the complex view.
    SELECT
        ca.case_num,
        ca.pers_org_num_pt,
        ca.tisclient_num,
        ca.primary_phys_num,
        ca.refer_phys_num,
        ca.source_system_id,
        app.num,
        app.enter_date,
        app.visittype_num,
        app.prim_sched_date,
        app.prim_sched_begin_time,
        app.prim_sched_end_time,
        app.prim_sched_num,
        app.appointstat_num,
        app.reason_num,
        app.anestype_num
    FROM advantx_ods.ca_case AS ca
    INNER JOIN advantx_ods.as_appointment AS app 
        ON ca.source_system_id = app.source_system_id
        AND ca.case_num = app.case_num
    WHERE ca.source_system_id = V_source_system
      AND ca.key_dos >= (
          -- This subquery is constant-folded by BigQuery but isolating it makes the logic clearer.
          SELECT DATETIME(CONCAT(CAST(EXTRACT(YEAR FROM DATE_SUB(CURRENT_DATE(), INTERVAL 365 DAY)) AS STRING), '-01-01 00:00:00'))
      )
)
SELECT
    A.source_system_id,
    A.company_code,
    A.pers_org_num_org AS facility_code,
    pa.case_num AS case_number,
    CAST(COALESCE(pa.anestype_num, 0) AS STRING) AS anesthesia_type,

    -- Step 2: Optimized complex column derivations.
    -- Replaced concatenation and RIGHT() with the more efficient and readable LPAD().
    -- Simplified redundant CAST/COALESCE patterns.
    CONCAT(
        LPAD(COALESCE(TRIM(CAST(pa.tisclient_num AS STRING)), ''), 4, '0'),
        LPAD(COALESCE(TRIM(CAST(pa.pers_org_num_pt AS STRING)), ''), 8, '0'),
        LPAD(COALESCE(TRIM(CAST(pa.case_num AS STRING)), ''), 8, '0')
    ) AS case_id,

    CAST(pa.num AS STRING) AS appt_code,
    pa.enter_date AS appt_create_date,
    CAST(pa.visittype_num AS STRING) AS appt_type_code,
    pa.prim_sched_date AS appt_date,
    pa.prim_sched_begin_time,
    pa.prim_sched_end_time,
    FORMAT_TIMESTAMP('%A', pa.prim_sched_date) AS day_of_week,
    FORMAT_TIMESTAMP('%H:%M:00', pa.prim_sched_begin_time) AS appt_start_time,
    FORMAT_TIMESTAMP('%H:%M:00', pa.prim_sched_end_time) AS appt_end_time,

    -- Replaced expensive FORMAT_TIMESTAMP and string comparison with efficient numeric extraction.
    CASE
        WHEN EXTRACT(HOUR FROM pa.prim_sched_begin_time) >= 1
             AND EXTRACT(HOUR FROM pa.prim_sched_end_time) >= 1
        THEN TIMESTAMP_DIFF(pa.prim_sched_end_time, pa.prim_sched_begin_time, MINUTE)
        ELSE 0
    END AS appt_duration,

    -- Preserved original lag calculation logic.
    DATE_DIFF(DATE(pa.prim_sched_date), DATE(pa.enter_date), DAY) + 
    CASE WHEN TIME(pa.enter_date) > TIME '12:00:00' THEN -1 ELSE 0 END AS appt_sched_lag,

    pa.prim_sched_num,
    pa.num AS appointment_num,
    pa.appointstat_num,
    pa.reason_num,
    pa.primary_phys_num,
    pa.refer_phys_num,
    pa.pers_org_num_pt,
    pa.tisclient_num
FROM uspidnaproddata.edw_advantx.vw_ad_tisclient AS A
-- Step 3: Join the view to the small, pre-filtered result set.
INNER JOIN prefiltered_appointments AS pa
    -- Preserved original join logic. The function remains but now operates on a much smaller dataset.
    ON LOWER(A.source_system_id) = pa.source_system_id 
    AND A.pers_org_num_org = pa.tisclient_num;

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
