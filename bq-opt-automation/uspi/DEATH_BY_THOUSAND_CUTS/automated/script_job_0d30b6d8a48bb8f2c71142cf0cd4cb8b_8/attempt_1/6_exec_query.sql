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
-- TODO: Verify temp table dim_fact_sd_temp_w_minutes; no prior temp-table creation was found. It may be created by dynamic SQL.

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
MERGE dim_fact_sd_temp AS target
USING (
  SELECT
    A.source_system_id,
    A.prim_sched_num,
    A.appt_date,
    A.prim_sched_begin_time,
    A.prim_sched_end_time,
    B.num AS block_code,
    ROW_NUMBER() OVER (
      PARTITION BY A.source_system_id, A.prim_sched_num, A.appt_date, A.prim_sched_begin_time, A.prim_sched_end_time
      ORDER BY B.num
    ) AS row_num
  FROM dim_fact_sd_temp AS A
  INNER JOIN `advantx_ods.as_grid` AS B
    ON A.source_system_id = B.source_system_id
    AND A.prim_sched_num = B.sched_num
    AND B.blocktype_num = 2
    AND A.appt_date = B.sched_date
    AND (
      (
        (EXTRACT(HOUR FROM A.prim_sched_begin_time) * 60) + EXTRACT(MINUTE FROM A.prim_sched_begin_time)
      ) BETWEEN (
        (EXTRACT(HOUR FROM B.sched_begin_time) * 60) + EXTRACT(MINUTE FROM B.sched_begin_time)
      ) AND (
        (EXTRACT(HOUR FROM B.sched_end_time) * 60) + EXTRACT(MINUTE FROM B.sched_end_time) - 1
      ) 
      OR (
        (EXTRACT(HOUR FROM A.prim_sched_end_time) * 60) + EXTRACT(MINUTE FROM A.prim_sched_end_time)
      ) BETWEEN (
        (EXTRACT(HOUR FROM B.sched_begin_time) * 60) + EXTRACT(MINUTE FROM B.sched_begin_time)
      ) AND (
        (EXTRACT(HOUR FROM B.sched_end_time) * 60) + EXTRACT(MINUTE FROM B.sched_end_time) - 1
      )
    )
  INNER JOIN `advantx_ods.ut_sched` AS C
    ON A.source_system_id = C.source_system_id
    AND A.phys_pers_org_num = C.pers_org_num
    AND B.source_system_id = C.source_system_id
    AND B.block_phys_sched_num = C.num
) AS source
ON target.source_system_id = source.source_system_id
AND target.prim_sched_num = source.prim_sched_num
AND target.appt_date = source.appt_date
AND target.prim_sched_begin_time = source.prim_sched_begin_time
AND target.prim_sched_end_time = source.prim_sched_end_time
AND source.row_num = 1  -- Ensure only the top-ranked row is used
AND source.source_system_id = V_source_system
WHEN MATCHED THEN
  UPDATE SET
    target.block_code = CAST(source.block_code as STRING);

-- =================================================================================================
-- 3. Create the Optimized Temporary Table (V_TEMP_TABLE_OPT)
-- =================================================================================================
CREATE OR REPLACE TEMP TABLE V_TEMP_TABLE_OPT AS
MERGE dim_fact_sd_temp AS target
USING (
  WITH
  dim_fact_sd_temp_w_minutes AS (
    SELECT
      source_system_id,
      prim_sched_num,
      appt_date,
      prim_sched_begin_time,
      prim_sched_end_time,
      phys_pers_org_num,
      TIME_DIFF(prim_sched_begin_time, TIME'00:00:00', MINUTE) AS start_minute,
      TIME_DIFF(prim_sched_end_time, TIME'00:00:00', MINUTE) AS end_minute
    FROM dim_fact_sd_temp
    WHERE source_system_id = V_source_system
  ),
  as_grid_w_minutes AS (
    SELECT
      source_system_id,
      sched_num,
      sched_date,
      num,
      block_phys_sched_num,
      TIME_DIFF(sched_begin_time, TIME'00:00:00', MINUTE) AS start_minute,
      TIME_DIFF(sched_end_time, TIME'00:00:00', MINUTE) AS end_minute
    FROM `advantx_ods.as_grid`
    WHERE blocktype_num = 2
      AND source_system_id = V_source_system
  )
  SELECT
    A.source_system_id,
    A.prim_sched_num,
    A.appt_date,
    A.prim_sched_begin_time,
    A.prim_sched_end_time,
    B.num AS block_code,
    ROW_NUMBER() OVER (
      PARTITION BY A.source_system_id, A.prim_sched_num, A.appt_date, A.prim_sched_begin_time, A.prim_sched_end_time
      ORDER BY B.num ASC
    ) AS row_num
  FROM dim_fact_sd_temp_w_minutes AS A
  INNER JOIN as_grid_w_minutes AS B
    ON A.source_system_id = B.source_system_id
    AND A.prim_sched_num = B.sched_num
    AND A.appt_date = B.sched_date
    AND (
      A.start_minute BETWEEN B.start_minute AND (B.end_minute - 1)
      OR A.end_minute BETWEEN B.start_minute AND (B.end_minute - 1)
    )
  INNER JOIN `advantx_ods.ut_sched` AS C
    ON A.source_system_id = C.source_system_id
    AND A.phys_pers_org_num = C.pers_org_num
    AND B.block_phys_sched_num = C.num
  WHERE C.source_system_id = V_source_system
) AS source
ON target.source_system_id = source.source_system_id
AND target.prim_sched_num = source.prim_sched_num
AND target.appt_date = source.appt_date
AND target.prim_sched_begin_time = source.prim_sched_begin_time
AND target.prim_sched_end_time = source.prim_sched_end_time
AND source.row_num = 1
AND source.source_system_id = V_source_system
WHEN MATCHED THEN
  UPDATE SET
    target.block_code = CAST(source.block_code AS STRING);

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
