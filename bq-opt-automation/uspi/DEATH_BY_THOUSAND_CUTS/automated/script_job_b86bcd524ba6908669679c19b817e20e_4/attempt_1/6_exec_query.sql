/* ================================================================================================= */ 
/* Script to create and validate two temporary tables. */ 
/* Expected Outcome: The discrepancy and duplicate detail SELECTs should return zero rows. */ 
/* The final SELECT statement should return two summary rows with row_count = 0, confirming that */ 
/* V_TEMP_TABLE_ORIG and V_TEMP_TABLE_OPT produce identical distinct results and V_TEMP_TABLE_OPT */ 
/* has no duplicate rows. */ 
/* ================================================================================================= */ 
/* 1. Stored Procedure Context */ 
/* ================================================================================================= */ 
/* START STORED PROCEDURE CONTEXT */ 
/* Auto-generated from 2_sp_details.sql and 3_orig_sp.sql. */
DECLARE freeze_time TIMESTAMP DEFAULT TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 24 HOUR);
DECLARE   facility_id STRING DEFAULT 'sjos' ;
DECLARE   V_source_system STRING;

SET V_source_system = facility_id;

CREATE TEMPORARY TABLE dim_fact_sd_temp (
  source_system_id STRING,
  company_code STRING,
  facility_code NUMERIC, /* changed */
  patient_code NUMERIC, /* -changed */
  case_number NUMERIC, /* changed */
  physician_code STRING,
  physician_group_code STRING,
  refer_physician_code STRING DEFAULT '-1',
  procedure_code STRING,
  scheduled_room STRING,
  anesthesia_type STRING,
  case_id STRING,
  appt_code STRING,
  appt_status STRING,
  appt_create_date DATETIME,
  appt_type_code STRING,
  appt_cancel_reason STRING DEFAULT 'NO REASON',
  appt_date DATETIME,
  prim_sched_begin_time DATETIME,
  prim_sched_end_time DATETIME,
  begin_time DATETIME,
  end_time DATETIME,
  day_of_week STRING,
  appt_start_time STRING,
  appt_end_time STRING,
  appt_duration INT64,
  appt_sched_lag INT64,
  appt_count INT64 DEFAULT 1,
  appt_cancel_reason_quick_code STRING DEFAULT 'NO REASON',
  or_time INT64,
  or_duration_diff_bucket_mins INT64,
  or_duration_diff_bucket_desc STRING DEFAULT 'NA',
  or_duration_diff_bucket_group STRING DEFAULT 'NA',
  surgery_duration INT64,
  duration_diff_bucket_mins INT64,
  duration_diff_bucket_desc STRING DEFAULT 'NA',
  duration_diff_bucket_group STRING DEFAULT 'NA',
  account_number STRING,
  admission_time_lag INT64 DEFAULT 0,
  dismissal_time_lag INT64 DEFAULT 0,
  delayed_start_time INT64 DEFAULT 0,
  block_code STRING,
  procedure_combination STRING,
  procedure_type STRING,
  prim_sched_num NUMERIC,
  appointment_num NUMERIC,
  appointstat_num NUMERIC,
  reason_num NUMERIC,
  primary_phys_num NUMERIC,
  refer_phys_num NUMERIC,
  phys_pers_org_num NUMERIC,
  pers_org_num_pt NUMERIC,
  tisclient_num NUMERIC
);

/* END STORED PROCEDURE CONTEXT */
/* ================================================================================================= */
/* 2. Create the Original Temporary Table (V_TEMP_TABLE_ORIG) */
/* ================================================================================================= */
CREATE OR REPLACE TEMPORARY TABLE V_TEMP_TABLE_ORIG AS
SELECT
  *
FROM `dim_fact_sd_temp`;

MERGE INTO V_TEMP_TABLE_ORIG AS target
USING (
  WITH Procedures /* Pre-join appointment procedures and procedure codes, filtering early */ AS (
    SELECT
      app_pr.source_system_id,
      app_pr.appointment_num,
      pr.quick_code
    FROM `advantx_ods.as_appointment_procs` AS app_pr FOR SYSTEM_TIME AS OF freeze_time
    INNER JOIN `advantx_ods.ut_proc` AS pr FOR SYSTEM_TIME AS OF freeze_time
      ON app_pr.source_system_id = pr.source_system_id AND app_pr.proc_num = pr.num
    WHERE
      app_pr.source_system_id = V_source_system AND app_pr.order_num = 1
  ), Statuses /* Pre-filter and prepare status descriptions */ AS (
    SELECT
      source_system_id,
      num,
      UPPER(description) AS appt_status
    FROM `advantx_ods.it_appointstat` FOR SYSTEM_TIME AS OF freeze_time
    WHERE
      source_system_id = V_source_system
  ), CombinedSource /* Combine the data, joining back to the target table to get necessary fields */ AS (
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
      ON t.source_system_id = p.source_system_id AND t.appointment_num = p.appointment_num
    INNER JOIN Statuses AS s
      ON t.source_system_id = s.source_system_id AND t.appointstat_num = s.num
    /* Filter is applied within the target table scan */
    WHERE
      t.source_system_id = V_source_system
  )
  /* Select the single record per appointment to be used for the update */
  SELECT
    source_system_id,
    appointment_num,
    procedure_code,
    appt_status
  FROM CombinedSource
  WHERE
    row_num = 1
) AS source
ON target.source_system_id = source.source_system_id
AND target.appointment_num = source.appointment_num
WHEN MATCHED THEN UPDATE SET
  procedure_code = source.procedure_code,
  appt_status = source.appt_status;

/* ================================================================================================= */
/* 3. Create the Optimized Temporary Table (V_TEMP_TABLE_OPT) */
/* ================================================================================================= */
CREATE OR REPLACE TEMPORARY TABLE V_TEMP_TABLE_OPT AS
SELECT
  *
FROM `dim_fact_sd_temp`;

MERGE INTO V_TEMP_TABLE_OPT AS target
USING (
  WITH Procedures /* Pre-join appointment procedures and procedure codes, filtering early */ AS (
    SELECT
      app_pr.source_system_id,
      app_pr.appointment_num,
      pr.quick_code
    FROM `advantx_ods.as_appointment_procs` AS app_pr FOR SYSTEM_TIME AS OF freeze_time
    INNER JOIN `advantx_ods.ut_proc` AS pr FOR SYSTEM_TIME AS OF freeze_time
      ON app_pr.source_system_id = pr.source_system_id AND app_pr.proc_num = pr.num
    WHERE
      app_pr.source_system_id = V_source_system AND app_pr.order_num = 1
  ), Statuses /* Pre-filter and prepare status descriptions */ AS (
    SELECT
      source_system_id,
      num,
      UPPER(description) AS appt_status
    FROM `advantx_ods.it_appointstat` FOR SYSTEM_TIME AS OF freeze_time
    WHERE
      source_system_id = V_source_system
  ), CombinedSource /* Combine data to create the source for the MERGE. */ /* This CTE reads the target table to link procedures and statuses, causing the first scan. */ AS (
    SELECT
      t.source_system_id,
      t.appointment_num,
      p.quick_code AS procedure_code,
      s.appt_status,
      ROW_NUMBER() OVER (
        PARTITION BY t.source_system_id, t.appointment_num
        ORDER BY p.quick_code ASC, s.appt_status ASC
      ) AS row_num /* This window function is critical for correctness. It ensures one update */ /* per appointment, resolving potential duplicates with a deterministic order. */
    FROM `dim_fact_sd_temp` AS t
    INNER JOIN Procedures AS p
      ON t.source_system_id = p.source_system_id AND t.appointment_num = p.appointment_num
    INNER JOIN Statuses AS s
      ON t.source_system_id = s.source_system_id AND t.appointstat_num = s.num
    WHERE
      t.source_system_id = V_source_system
  )
  /* Select the single record per appointment to be used for the update. */
  SELECT
    source_system_id,
    appointment_num,
    procedure_code,
    appt_status
  FROM CombinedSource
  WHERE
    row_num = 1
) AS source
ON target.source_system_id = source.source_system_id
AND target.appointment_num = source.appointment_num
WHEN MATCHED THEN UPDATE SET
  procedure_code = source.procedure_code,
  appt_status = source.appt_status;

/* ================================================================================================= */
/* 4. Validation Step: Compare the two tables and check optimized duplicates. */
/* DISCREPANCY counts distinct rows that appear in one table but not the other. */
/* DUPLICATE ROWS counts extra copies of duplicate rows in V_TEMP_TABLE_OPT. */
/* The first two SELECT statements show the actual rows when discrepancies or duplicates exist. */
/* The final SELECT statement shows only the summary counts. */
/* ================================================================================================= */
CREATE OR REPLACE TEMPORARY TABLE V_VALIDATION_DISCREPANCIES AS
(
  SELECT
    'ONLY IN ORIGINAL' AS validation_diff_type,
    *
  FROM V_TEMP_TABLE_ORIG
  EXCEPT DISTINCT
  SELECT
    'ONLY IN ORIGINAL' AS validation_diff_type,
    *
  FROM V_TEMP_TABLE_OPT
)
UNION ALL
(
  SELECT
    'ONLY IN OPTIMIZED' AS validation_diff_type,
    *
  FROM V_TEMP_TABLE_OPT
  EXCEPT DISTINCT
  SELECT
    'ONLY IN OPTIMIZED' AS validation_diff_type,
    *
  FROM V_TEMP_TABLE_ORIG
);

CREATE OR REPLACE TEMPORARY TABLE V_VALIDATION_OPT_DUPLICATES AS
SELECT
  duplicate_row.*
FROM (
  SELECT
    ANY_VALUE(opt) AS duplicate_row
  FROM V_TEMP_TABLE_OPT AS opt
  GROUP BY
    TO_JSON_STRING(opt)
  HAVING
    COUNT(*) > 1
);

/* View discrepancy rows. */
SELECT
  *
FROM V_VALIDATION_DISCREPANCIES;

/* View duplicate rows from the optimized query. */
SELECT
  *
FROM V_VALIDATION_OPT_DUPLICATES;

/* View summary counts. */
SELECT
  'DISCREPANCY' AS validation_check,
  COUNT(*) AS row_count
FROM V_VALIDATION_DISCREPANCIES
UNION ALL
SELECT
  'DUPLICATE ROWS' AS validation_check,
  COALESCE(SUM(row_count - 1), 0) AS row_count
FROM (
  SELECT
    COUNT(*) AS row_count
  FROM V_TEMP_TABLE_OPT AS opt
  GROUP BY
    TO_JSON_STRING(opt)
  HAVING
    COUNT(*) > 1
);