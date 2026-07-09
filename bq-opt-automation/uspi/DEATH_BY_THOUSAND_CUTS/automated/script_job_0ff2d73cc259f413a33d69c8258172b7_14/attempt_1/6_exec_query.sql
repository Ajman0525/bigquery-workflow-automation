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

DECLARE facility_id STRING DEFAULT 'scjb';

DECLARE
  V_source_system STRING;

SET
    V_source_system = facility_id;

CREATE TEMP TABLE dim_fact_sd_temp (
    source_system_id string,
      company_code string,
      facility_code numeric, --changed
      patient_code numeric, ---changed
      case_number numeric,  --changed
      physician_code string,
      physician_group_code string,
      refer_physician_code string DEFAULT '-1',
      procedure_code string,
      scheduled_room string,
      anesthesia_type string,
      case_id string,
      appt_code string,
      appt_status string,
      appt_create_date datetime,
      appt_type_code string,
      appt_cancel_reason string DEFAULT 'NO REASON',
      appt_date datetime,
      prim_sched_begin_time datetime,
      prim_sched_end_time datetime,
      begin_time datetime,
      end_time datetime,
      day_of_week string,
      appt_start_time string,
      appt_end_time string,
      appt_duration int64,
      appt_sched_lag int64,
      appt_count int64 DEFAULT 1,
      appt_cancel_reason_quick_code string DEFAULT 'NO REASON',
      or_time int64,
      or_duration_diff_bucket_mins int64,
      or_duration_diff_bucket_desc string DEFAULT 'NA',
      or_duration_diff_bucket_group string DEFAULT 'NA',
      surgery_duration int64,
      duration_diff_bucket_mins int64,
      duration_diff_bucket_desc string DEFAULT 'NA',
      duration_diff_bucket_group string DEFAULT 'NA',
      account_number string,
      admission_time_lag int64 DEFAULT 0,
      dismissal_time_lag int64 DEFAULT 0,
      delayed_start_time int64 DEFAULT 0,
      block_code string,
      procedure_combination string,
      procedure_type string,
      prim_sched_num numeric,
      appointment_num numeric,
      appointstat_num numeric,
      reason_num numeric,
      primary_phys_num numeric,
      refer_phys_num numeric,
      phys_pers_org_num numeric,
      pers_org_num_pt numeric,
      tisclient_num numeric);
-- END STORED PROCEDURE CONTEXT

-- =================================================================================================
-- 2. Create the Original Temporary Table (V_TEMP_TABLE_ORIG)
-- =================================================================================================
CREATE OR REPLACE TEMP TABLE V_TEMP_TABLE_ORIG AS
UPDATE dim_fact_sd_temp a
SET a.procedure_combination = src.procedure_combination
FROM
(SELECT 
    a.source_system_id,
    a.appointment_num,
    STRING_AGG(DISTINCT procedure_code,'/') AS procedure_combination
FROM (
SELECT 
    a.source_system_id,
    a.appointment_num, app_pr.order_num,
    pr.quick_code AS procedure_code,
    UPPER(stat.description) AS appt_status
  FROM dim_fact_sd_temp a
  INNER JOIN `uspidnaproddata.advantx_ods.as_appointment_procs` app_pr
    ON a.source_system_id = app_pr.source_system_id
    AND a.appointment_num = app_pr.appointment_num
    --AND app_pr.order_num = 1 --get all procedure code
  INNER JOIN `uspidnaproddata.advantx_ods.ut_proc` pr
    ON app_pr.source_system_id = pr.source_system_id
    AND app_pr.proc_num = pr.num
  INNER JOIN `uspidnaproddata.advantx_ods.it_appointstat` stat
    ON pr.source_system_id = stat.source_system_id
    AND a.appointstat_num = stat.num
) a where procedure_code IS NOT NULL
GROUP BY 1,2
) src
WHERE a.source_system_id = src.source_system_id
AND a.appointment_num = src.appointment_num
AND src.source_system_id = V_source_system;

-- =================================================================================================
-- 3. Create the Optimized Temporary Table (V_TEMP_TABLE_OPT)
-- =================================================================================================
CREATE OR REPLACE TEMP TABLE V_TEMP_TABLE_OPT AS
WITH src_procedures AS (
  SELECT
    a.source_system_id,
    a.appointment_num,
    STRING_AGG(DISTINCT pr.quick_code, '/') AS procedure_combination
  FROM
    `uspidnaproddata.advantx_ods.dim_fact_sd_temp` AS a
  INNER JOIN
    `uspidnaproddata.advantx_ods.as_appointment_procs` AS app_pr
    ON a.source_system_id = app_pr.source_system_id
    AND a.appointment_num = app_pr.appointment_num
  INNER JOIN
    `uspidnaproddata.advantx_ods.ut_proc` AS pr
    ON app_pr.source_system_id = pr.source_system_id
    AND app_pr.proc_num = pr.num
  INNER JOIN
    `uspidnaproddata.advantx_ods.it_appointstat` AS stat
    ON pr.source_system_id = stat.source_system_id
    AND a.appointstat_num = stat.num
  WHERE
    a.source_system_id = V_source_system
    AND pr.quick_code IS NOT NULL
  GROUP BY
    1,
    2
)
UPDATE
  dim_fact_sd_temp a
SET
  a.procedure_combination = src.procedure_combination
FROM
  src_procedures AS src
WHERE
  a.source_system_id = src.source_system_id
  AND a.appointment_num = src.appointment_num;

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
