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
DECLARE   facility_id STRING DEFAULT 'rssc';
DECLARE   V_source_system STRING;

SET V_source_system = facility_id;

CREATE TEMPORARY TABLE MEDIBIS_FACT_CE_temp (
  source_system_id STRING,
  company_code STRING,
  facility_code STRING,
  physician_code STRING,
  procedure_code STRING,
  payor_code STRING DEFAULT '-1',
  patient_code STRING,
  date_of_service DATETIME,
  case_num NUMERIC DEFAULT 0,
  tisclient_num NUMERIC DEFAULT 0,
  case_id STRING,
  patient_type_code STRING,
  visit_type_code STRING,
  case_count INT64 DEFAULT 0,
  case_charge_amount NUMERIC DEFAULT 0.0, /* changed -- sad */
  case_primary_payment_amount NUMERIC DEFAULT 0.0, /* changed  --sad */
  case_copay_payment_amount NUMERIC DEFAULT 0.0, /* changed  --sad */
  case_writeoff_amount NUMERIC DEFAULT 0.0, /* changed  --sad */
  case_bad_debt_amount NUMERIC DEFAULT 0.0, /* changed  --sad */
  procedure_count INT64 DEFAULT 0,
  financial_year INT64,
  financial_period INT64,
  icd9_code STRING DEFAULT 'UNK',
  service_code STRING DEFAULT '0',
  or_minutes INT64 DEFAULT 0,
  supply_cost FLOAT64 DEFAULT 0.0,
  staff_cost FLOAT64 DEFAULT 0.0,
  implant_cost FLOAT64 DEFAULT 0.0,
  case_refund_amount NUMERIC DEFAULT 0.0, /* changed  --sad */
  case_misc_charge_amount NUMERIC DEFAULT 0.0, /* changed  --sad */
  cpt_charge_amount NUMERIC DEFAULT 0.0, /* changed  --sad */
  cpt_procedure_code STRING,
  net_rev_pct_rankbkt NUMERIC DEFAULT 0.0,
  net_rev_dlr_rankbkt NUMERIC DEFAULT 0.0,
  supply_cost_rankbkt NUMERIC DEFAULT 0.0,
  sup_cost_pct_netrev_rankbkt NUMERIC DEFAULT 0.0,
  net_rev_pct_rankdesc STRING,
  net_rev_dlr_rankdesc STRING,
  supply_cost_rankdesc STRING,
  sup_cost_pct_netrev_rankdesc STRING,
  account_name STRING,
  balance_category STRING,
  drg_code STRING,
  inpatient_days INT64 DEFAULT 0,
  billing_period INT64,
  case_unapplied_payment_amount NUMERIC DEFAULT 0.0, /* changed  --sad */
  case_procedure_count INT64 DEFAULT 0,
  patient_age FLOAT64,
  entity_code STRING,
  case_outstanding_bal_amount NUMERIC DEFAULT 0.0, /* changed  --sad */
  case_status STRING,
  case_tob_writeoff_amount NUMERIC DEFAULT 0.0, /* changed  --sad */
  case_top_writeoff_amount NUMERIC DEFAULT 0.0, /* changed  --sad */
  patient_class_code STRING,
  expected_collections FLOAT64 DEFAULT 0.0,
  expected_collections_est_ind INT64,
  case_error_paid_amount NUMERIC DEFAULT 0.0,
  billing_period_start_date DATETIME,
  procedure_combination STRING,
  case_payor_status STRING,
  or_room STRING,
  total_asc_time INT64 DEFAULT 0,
  refer_physician_code STRING,
  fixed_cost FLOAT64 DEFAULT 0.0,
  icd10_code STRING DEFAULT 'UNK',
  acuity_flag INT64,
  units NUMERIC
);

/* END STORED PROCEDURE CONTEXT */
/* ================================================================================================= */
/* 2. Create the Original Temporary Table (V_TEMP_TABLE_ORIG) */
/* ================================================================================================= */
CREATE OR REPLACE TEMPORARY TABLE V_TEMP_TABLE_ORIG AS
SELECT
  *
FROM `MEDIBIS_FACT_CE_temp`;

MERGE INTO V_TEMP_TABLE_ORIG AS A
USING (
  SELECT
    A.source_system_id,
    A.case_num,
    CASE WHEN C.quick_code IS NULL THEN 'UNKNOWN' ELSE UPPER(C.quick_code) END AS case_status1,
    ROW_NUMBER() OVER (
      PARTITION BY A.source_system_id, A.case_num
      ORDER BY CASE WHEN C.quick_code IS NULL THEN 'UNKNOWN' ELSE UPPER(C.quick_code) END
    ) AS row_num
  FROM MEDIBIS_FACT_CE_temp AS A
  INNER JOIN `uspidnaproddata.advantx_ods.ca_case` AS B FOR SYSTEM_TIME AS OF freeze_time
    ON A.source_system_id = B.source_system_id AND A.case_num = B.case_num
  LEFT OUTER JOIN `uspidnaproddata.advantx_ods.ods_case_status` AS C FOR SYSTEM_TIME AS OF freeze_time
    ON B.source_system_id = C.source_system_id
  WHERE
    B.case_status = C.case_status
) AS SRC
ON SRC.source_system_id = A.source_system_id
AND SRC.case_num = A.case_num
AND A.source_system_id = V_source_system
AND SRC.row_num = 1
WHEN MATCHED THEN UPDATE SET
  case_status = SRC.case_status1;

/* ================================================================================================= */
/* 3. Create the Optimized Temporary Table (V_TEMP_TABLE_OPT) */
/* ================================================================================================= */
CREATE OR REPLACE TEMPORARY TABLE V_TEMP_TABLE_OPT AS
SELECT
  *
FROM `MEDIBIS_FACT_CE_temp`;

MERGE INTO V_TEMP_TABLE_OPT AS T
USING (
  SELECT
    source_system_id,
    case_num,
    new_case_status
  FROM (
    SELECT
      B.source_system_id,
      B.case_num,
      COALESCE(UPPER(C.quick_code), 'UNKNOWN') AS new_case_status,
      ROW_NUMBER() OVER (
        PARTITION BY B.source_system_id, B.case_num
        ORDER BY COALESCE(UPPER(C.quick_code), 'UNKNOWN') ASC
      ) AS rn
    FROM `uspidnaproddata.advantx_ods.ca_case` AS B FOR SYSTEM_TIME AS OF freeze_time
    INNER JOIN `uspidnaproddata.advantx_ods.ods_case_status` AS C FOR SYSTEM_TIME AS OF freeze_time
      ON B.source_system_id = C.source_system_id AND B.case_status = C.case_status
    WHERE
      B.source_system_id /* Pre-filter source data to only what is relevant for the update. */ /* This is valid because the MERGE's ON clause filters the target by the same value. */ = V_source_system
  )
  WHERE
    rn = 1
) AS S
ON T.source_system_id = S.source_system_id
AND T.case_num = S.case_num
AND /* This filter on the target table is preserved from the original ON clause for correctness. */ T.source_system_id = V_source_system
WHEN MATCHED THEN UPDATE SET
  T.case_status = S.new_case_status /*
 The script variable V_source_system must be declared prior to this statement.
 Example: DECLARE V_source_system STRING DEFAULT 'rssc';
*/;

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