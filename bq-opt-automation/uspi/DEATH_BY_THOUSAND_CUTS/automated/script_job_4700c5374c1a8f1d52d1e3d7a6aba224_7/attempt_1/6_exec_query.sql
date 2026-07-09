/* ================================================================================================= */ 
/* Script to create and validate two temporary tables. */ /* Expected Outcome: The discrepancy and duplicate detail SELECTs should return zero rows. */ 
/* The final SELECT statement should return two summary rows with row_count = 0, confirming that */ 
/* V_TEMP_TABLE_ORIG and V_TEMP_TABLE_OPT produce identical distinct results and V_TEMP_TABLE_OPT */ 
/* has no duplicate rows. */ 
/* ================================================================================================= */ 
/* 1. Stored Procedure Context */ 
/* ================================================================================================= */ 
/* START STORED PROCEDURE CONTEXT */ 

DECLARE freeze_time TIMESTAMP DEFAULT TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 24 HOUR);
DECLARE   facility_id STRING DEFAULT 'sjos' ;
DECLARE   V_source_system STRING;
DECLARE   V_SQL STRING;

SET V_source_system = facility_id;

SET V_SQL = FORMAT(""" 
CREATE TEMP TABLE temp_ca_visit_visitdept AS 
SELECT * FROM uspidnaproddata.advantx_ods.ca_visit_visitdept_%s 
""", V_source_system); 
       EXECUTE IMMEDIATE V_SQL; 

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
WITH cteSource_for_update AS (
  SELECT
    A.source_system_id,
    A.case_number,
    A.appointment_num,
    D.begin_time,
    D.end_time,
    ROW_NUMBER() OVER (
      PARTITION BY A.source_system_id, A.case_number, A.appointment_num
      ORDER BY D.begin_time, D.end_time
    ) AS row_num
  FROM dim_fact_sd_temp AS A
  INNER JOIN `advantx_ods.as_appointment` AS B FOR SYSTEM_TIME AS OF freeze_time
    ON A.source_system_id = B.source_system_id
    AND A.case_number = B.case_num
    AND A.appointment_num = B.num
  INNER JOIN `advantx_ods.ca_visit` AS C FOR SYSTEM_TIME AS OF freeze_time
    ON B.source_system_id = C.source_system_id AND B.case_num = C.case_num
  INNER JOIN `temp_ca_visit_visitdept` AS D
    ON C.source_system_id = D.source_system_id
    AND C.case_num = D.case_num
    AND C.visit_num = D.visit_num
  WHERE
    A.source_system_id = V_source_system AND D.visitdept_num = 3
)
SELECT
  *
FROM cteSource_for_update;

/* ================================================================================================= */
/* 3. Create the Optimized Temporary Table (V_TEMP_TABLE_OPT) */
/* ================================================================================================= */
CREATE OR REPLACE TEMPORARY TABLE V_TEMP_TABLE_OPT AS
WITH dim_fact_filtered AS (
  SELECT
    source_system_id,
    case_number,
    appointment_num
  FROM `dim_fact_sd_temp`
  WHERE
    source_system_id = V_source_system
), visit_dept_filtered AS (
  SELECT
    source_system_id,
    case_num,
    visit_num,
    begin_time,
    end_time
  FROM `temp_ca_visit_visitdept`
  WHERE
    visitdept_num = 3
    AND source_system_id = V_source_system /* Propagated filter for early pruning */
), appointments AS (
  SELECT
    source_system_id,
    case_num,
    num
  FROM `advantx_ods.as_appointment` FOR SYSTEM_TIME AS OF freeze_time
  WHERE
    source_system_id = V_source_system /* Propagated filter for early pruning */
), visits AS (
  SELECT
    source_system_id,
    case_num,
    visit_num
  FROM `advantx_ods.ca_visit` FOR SYSTEM_TIME AS OF freeze_time
  WHERE
    source_system_id = V_source_system /* Propagated filter for early pruning */
)
SELECT
  A.source_system_id,
  A.case_number,
  A.appointment_num,
  D.begin_time,
  D.end_time,
  ROW_NUMBER() OVER (
    PARTITION BY A.source_system_id, A.case_number, A.appointment_num
    ORDER BY D.begin_time, D.end_time
  ) AS row_num
FROM dim_fact_filtered AS A
INNER JOIN appointments AS B
  ON A.source_system_id = B.source_system_id
  AND A.case_number = B.case_num
  AND A.appointment_num = B.num
INNER JOIN visits AS C
  ON B.source_system_id = C.source_system_id AND B.case_num = C.case_num
INNER JOIN visit_dept_filtered AS D
  ON C.source_system_id = D.source_system_id
  AND C.case_num = D.case_num
  AND C.visit_num = D.visit_num;

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