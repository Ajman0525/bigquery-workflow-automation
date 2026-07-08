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
DECLARE   facility_id STRING DEFAULT 'sops';
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
    CAST(IFNULL(C.pers_org_num, -1) AS STRING) AS pers_org_num,
    ROW_NUMBER() OVER (PARTITION BY A.source_system_id, A.case_num ORDER BY IFNULL(C.pers_org_num, -1)) AS row_num
  FROM MEDIBIS_FACT_CE_temp AS A
  LEFT OUTER JOIN `uspidnaproddata.advantx_ods.ad_case_ps_ins` AS B FOR SYSTEM_TIME AS OF freeze_time
    ON A.case_num = B.case_num AND A.source_system_id = B.source_system_id
  INNER JOIN `uspidnaproddata.advantx_ods.ad_ps_rolehist_ins` AS C FOR SYSTEM_TIME AS OF freeze_time
    ON B.pers_org_num_pt = C.pers_org_num_pers_ins
    AND A.source_system_id = B.source_system_id
    AND C.role_num = 6
) AS SRC
ON SRC.source_system_id = A.source_system_id
AND A.source_system_id = V_source_system
AND SRC.case_num = A.case_num
AND SRC.row_num = 1
WHEN MATCHED THEN UPDATE SET
  payor_code = SRC.pers_org_num;

/* ================================================================================================= */
/* 3. Create the Optimized Temporary Table (V_TEMP_TABLE_OPT) */
/* ================================================================================================= */
CREATE OR REPLACE TEMPORARY TABLE V_TEMP_TABLE_OPT AS
SELECT
  *
FROM `MEDIBIS_FACT_CE_temp`;

MERGE INTO V_TEMP_TABLE_OPT AS T
USING (
  WITH all_case_payors /* Join to find all possible payors for each case, filtered by the relevant source system. */ /* The original's LEFT JOIN followed by an INNER JOIN is semantically equivalent to two INNER JOINs. */ /* This step can produce multiple `pers_org_num` rows for each case, causing the join amplification seen in the execution graph. */ AS (
    SELECT
      A.source_system_id,
      A.case_num,
      C.pers_org_num
    FROM MEDIBIS_FACT_CE_temp AS A
    INNER JOIN `uspidnaproddata.advantx_ods.ad_case_ps_ins` AS B FOR SYSTEM_TIME AS OF freeze_time
      ON A.case_num = B.case_num AND A.source_system_id = B.source_system_id
    INNER JOIN `uspidnaproddata.advantx_ods.ad_ps_rolehist_ins` AS C FOR SYSTEM_TIME AS OF freeze_time
      ON B.pers_org_num_pt = C.pers_org_num_pers_ins
    WHERE
      A.source_system_id = V_source_system /* Predicate from the original MERGE ON clause applied early to the source scan. */
      AND C.role_num = 6
  )
  /* For each case, find the single payor that matches the original ROW_NUMBER() logic. */
  /* ARRAY_AGG with ORDER BY and LIMIT 1 is an efficient way to perform a top-1-per-group selection. */
  /* This avoids shuffling all the amplified rows from the join above, drastically reducing shuffle bytes and compute. */
  SELECT
    source_system_id,
    case_num,
    (
      ARRAY_AGG(
        CAST(IFNULL(pers_org_num, -1) AS STRING) ORDER BY IFNULL(pers_org_num, -1) ASC
        LIMIT 1
      )[OFFSET(0)]
    ) AS pers_org_num
  FROM all_case_payors
  GROUP BY
    source_system_id,
    case_num
) AS S
ON T.source_system_id = S.source_system_id
AND T.case_num = S.case_num
AND T.source_system_id = V_source_system /* This predicate on the target table is essential for the MERGE operation's performance and correctness. */
WHEN MATCHED THEN UPDATE SET
  payor_code = S.pers_org_num;

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