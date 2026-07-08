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
DECLARE V_source_system string;
DECLARE facility_id STRING DEFAULT 'sops';
SET
    V_source_system = facility_id;

CREATE TEMP TABLE MEDIBIS_FACT_CE_temp (
    source_system_id string,
    company_code string,
    facility_code string,
    physician_code string,
    procedure_code string,
    payor_code string  DEFAULT '-1',
    patient_code string,
    date_of_service datetime,
    case_num numeric  DEFAULT 0,
    tisclient_num numeric  DEFAULT 0,
    case_id string,
    patient_type_code string,
    visit_type_code string,
    case_count integer  DEFAULT 0,
        case_charge_amount NUMERIC DEFAULT 0.0,  --changed -- sad
    case_primary_payment_amount NUMERIC DEFAULT 0.0,  --changed  --sad
    case_copay_payment_amount NUMERIC DEFAULT 0.0,  --changed  --sad
    case_writeoff_amount NUMERIC DEFAULT 0.0,   --changed  --sad
    case_bad_debt_amount NUMERIC DEFAULT 0.0,   --changed  --sad
    procedure_count integer  DEFAULT 0,
    financial_year integer ,
    financial_period integer ,
    icd9_code string  DEFAULT 'UNK',
    service_code string  DEFAULT '0',
    or_minutes integer  DEFAULT 0,
    supply_cost float64  DEFAULT 0.0,
    staff_cost float64  DEFAULT 0.0,
    implant_cost float64  DEFAULT 0.0,
    case_refund_amount NUMERIC DEFAULT 0.0,  --changed  --sad
    case_misc_charge_amount NUMERIC DEFAULT 0.0,  --changed  --sad
    cpt_charge_amount NUMERIC DEFAULT 0.0,  --changed  --sad
    cpt_procedure_code string,
    net_rev_pct_rankbkt numeric DEFAULT 0.0,
    net_rev_dlr_rankbkt numeric DEFAULT 0.0,
    supply_cost_rankbkt numeric DEFAULT 0.0,
    sup_cost_pct_netrev_rankbkt numeric  DEFAULT 0.0,
    net_rev_pct_rankdesc string,
    net_rev_dlr_rankdesc string,
    supply_cost_rankdesc string,
    sup_cost_pct_netrev_rankdesc string,
    account_name string,
    balance_category string,
    drg_code string,
    inpatient_days integer  DEFAULT 0,
    billing_period integer ,
    case_unapplied_payment_amount NUMERIC DEFAULT 0.0,   --changed  --sad
    case_procedure_count integer  DEFAULT 0,
    patient_age float64,
    entity_code string,
    case_outstanding_bal_amount NUMERIC DEFAULT 0.0,   --changed  --sad
        case_status string,
    case_tob_writeoff_amount NUMERIC DEFAULT 0.0,   --changed  --sad
    case_top_writeoff_amount NUMERIC DEFAULT 0.0,   --changed  --sad
    patient_class_code string,
    expected_collections float64  DEFAULT 0.0,
    expected_collections_est_ind integer,
    case_error_paid_amount numeric  DEFAULT 0.0,
    billing_period_start_date datetime,
    procedure_combination string,
    case_payor_status string,
    or_room string,
    total_asc_time integer  default 0,
    refer_physician_code string,
    fixed_cost float64  DEFAULT 0.0,
    icd10_code string  DEFAULT 'UNK',
        acuity_flag int64,
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
    b.case_id,
    b.total_asc_time,
    b.case_primary_payment_amount,
    b.case_unapplied_payment_amount,
    b.case_copay_payment_amount,
    b.case_outstanding_bal_amount,
    b.case_writeoff_amount,
    b.case_tob_writeoff_amount,
    b.case_top_writeoff_amount,
    b.balance_category,
    b.case_bad_debt_amount,
    b.implant_cost,
    b.expected_collections,
    b.expected_collections_est_ind,
    ROW_NUMBER() OVER (
      PARTITION BY A.source_system_id, A.case_id
      ORDER BY b.total_asc_time, b.case_primary_payment_amount, b.case_unapplied_payment_amount, b.case_copay_payment_amount, b.case_outstanding_bal_amount, b.case_writeoff_amount, b.case_tob_writeoff_amount, b.case_top_writeoff_amount, b.balance_category, b.case_bad_debt_amount, b.implant_cost, b.expected_collections, b.expected_collections_est_ind
    ) AS row_num
  FROM MEDIBIS_FACT_CE_temp AS A
  INNER JOIN (
    SELECT
      source_system_id,
      case_id,
      total_asc_time,
      case_primary_payment_amount,
      case_unapplied_payment_amount,
      case_copay_payment_amount,
      case_outstanding_bal_amount,
      case_writeoff_amount,
      case_tob_writeoff_amount,
      case_top_writeoff_amount,
      balance_category,
      case_bad_debt_amount,
      implant_cost,
      expected_collections,
      expected_collections_est_ind
    FROM `uspidnaproddata.edw_advantx.medibis_dim_case` FOR SYSTEM_TIME AS OF freeze_time
  ) AS B
    ON A.source_system_id = B.source_system_id
  WHERE
    A.case_id = B.case_id
) AS src
ON SRC.source_system_id = A.source_system_id
AND SRC.case_id = A.case_id
AND A.source_system_id = V_source_system
AND SRC.row_num = 1
WHEN MATCHED THEN UPDATE SET
  total_asc_time = src.total_asc_time,
  case_primary_payment_amount = src.case_primary_payment_amount,
  case_unapplied_payment_amount = src.case_unapplied_payment_amount,
  case_copay_payment_amount = src.case_copay_payment_amount,
  case_outstanding_bal_amount = src.case_outstanding_bal_amount,
  case_writeoff_amount = src.case_writeoff_amount,
  case_tob_writeoff_amount = src.case_tob_writeoff_amount,
  case_top_writeoff_amount = src.case_top_writeoff_amount,
  balance_category = src.balance_category,
  case_bad_debt_amount = src.case_bad_debt_amount,
  implant_cost = src.implant_cost,
  expected_collections = src.expected_collections,
  expected_collections_est_ind = src.expected_collections_est_ind;

/* ================================================================================================= */
/* 3. Create the Optimized Temporary Table (V_TEMP_TABLE_OPT) */
/* ================================================================================================= */
CREATE OR REPLACE TEMPORARY TABLE V_TEMP_TABLE_OPT AS
SELECT
  *
FROM `MEDIBIS_FACT_CE_temp`;

MERGE INTO V_TEMP_TABLE_OPT AS T
USING (
  /* Step 1: Pre-filter and de-duplicate the source data in a single pass. */
  /* This avoids joining the entire medibis_dim_case table. */
  SELECT
    source_system_id,
    case_id,
    total_asc_time,
    case_primary_payment_amount,
    case_unapplied_payment_amount,
    case_copay_payment_amount,
    case_outstanding_bal_amount,
    case_writeoff_amount,
    case_tob_writeoff_amount,
    case_top_writeoff_amount,
    balance_category,
    case_bad_debt_amount,
    implant_cost,
    expected_collections,
    expected_collections_est_ind
  FROM (
    SELECT
      source_system_id,
      case_id,
      total_asc_time,
      case_primary_payment_amount,
      case_unapplied_payment_amount,
      case_copay_payment_amount,
      case_outstanding_bal_amount,
      case_writeoff_amount,
      case_tob_writeoff_amount,
      case_top_writeoff_amount,
      balance_category,
      case_bad_debt_amount,
      implant_cost,
      expected_collections,
      expected_collections_est_ind,
      ROW_NUMBER() OVER (
        PARTITION BY source_system_id, case_id
        ORDER BY total_asc_time, case_primary_payment_amount, case_unapplied_payment_amount, case_copay_payment_amount, case_outstanding_bal_amount, case_writeoff_amount, case_tob_writeoff_amount, case_top_writeoff_amount, balance_category, case_bad_debt_amount, implant_cost, expected_collections, expected_collections_est_ind
      ) AS row_num
    FROM `uspidnaproddata.edw_advantx.medibis_dim_case` FOR SYSTEM_TIME AS OF freeze_time
    /* Step 2: Push the filter down to the source scan for maximum efficiency. */
    WHERE
      source_system_id = V_source_system
  )
  WHERE
    row_num = 1
) AS S
ON T.source_system_id = S.source_system_id
AND T.case_id = S.case_id
AND /* Step 3: Keep the original filter on the target table, as required by the MERGE logic. */ T.source_system_id = V_source_system
WHEN MATCHED THEN UPDATE SET
  total_asc_time = S.total_asc_time,
  case_primary_payment_amount = S.case_primary_payment_amount,
  case_unapplied_payment_amount = S.case_unapplied_payment_amount,
  case_copay_payment_amount = S.case_copay_payment_amount,
  case_outstanding_bal_amount = S.case_outstanding_bal_amount,
  case_writeoff_amount = S.case_writeoff_amount,
  case_tob_writeoff_amount = S.case_tob_writeoff_amount,
  case_top_writeoff_amount = S.case_top_writeoff_amount,
  balance_category = S.balance_category,
  case_bad_debt_amount = S.case_bad_debt_amount,
  implant_cost = S.implant_cost,
  expected_collections = S.expected_collections,
  expected_collections_est_ind = S.expected_collections_est_ind;

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