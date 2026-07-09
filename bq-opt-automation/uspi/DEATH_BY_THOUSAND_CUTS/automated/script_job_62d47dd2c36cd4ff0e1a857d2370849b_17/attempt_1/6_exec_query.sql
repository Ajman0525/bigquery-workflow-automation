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
DECLARE V_source_system STRING DEFAULT 'vhhc' ;
DECLARE V_SQL STRING;

CREATE TEMPORARY TABLE PRIMARY_PROCEDURE_ce_temp (
  source_system_id STRING,
  case_num NUMERIC DEFAULT 0,
  procfee_num NUMERIC DEFAULT 0,
  procedure_code STRING DEFAULT NULL,
  facility_num NUMERIC DEFAULT NULL,
  visittype_num NUMERIC DEFAULT NULL,
  visit_type_code STRING DEFAULT NULL,
  bill_period_num NUMERIC DEFAULT NULL
);

CREATE TEMPORARY TABLE ar_billtrans_charge_ce_temp (
  source_system_id STRING,
  bill_trans_num NUMERIC,
  charge_amount NUMERIC,
  paid_amount NUMERIC,
  writtenoff_amount NUMERIC,
  pat_part NUMERIC,
  ps_num NUMERIC,
  procfee_num NUMERIC,
  units NUMERIC,
  facility_num NUMERIC,
  case_num NUMERIC,
  visit_num NUMERIC,
  dx1_num NUMERIC,
  refer_phys_num NUMERIC,
  dx1_num_10 NUMERIC
);

CREATE TEMPORARY TABLE ar_billtrans_charge_rank_ce_temp (
  source_system_id STRING,
  case_num NUMERIC,
  bill_trans_num NUMERIC,
  charge_amount NUMERIC
);

SET V_SQL = FORMAT("""
      CREATE TEMP TABLE temp_ar_billtrans AS
      SELECT * FROM `uspidnaproddata.advantx_ods.ar_billtrans_%s`
      """, V_source_system);

      EXECUTE IMMEDIATE V_SQL;

/* END STORED PROCEDURE CONTEXT */
/* ================================================================================================= */
/* 2. Create the Original Temporary Table (V_TEMP_TABLE_ORIG) */
/* ================================================================================================= */
CREATE OR REPLACE TEMPORARY TABLE V_TEMP_TABLE_ORIG AS 
SELECT
  source_system_id,
  case_num,
  procfee_num,
  procedure_code,
  visittype_num,
  visit_type_code,
  bill_period_num
FROM (
  SELECT
    source_system_id,
    case_num,
    procfee_num,
    procedure_code,
    visittype_num,
    visit_type_code,
    bill_period_num,
    ROW_NUMBER() OVER (
      PARTITION BY source_system_id, case_num
      ORDER BY source_system_id, case_num, procedure_code
    ) AS rownumber
  FROM (
    SELECT DISTINCT
      A.source_system_id,
      B.case_num,
      B.procfee_num,
      D.quick_code AS procedure_code,
      G.num AS visittype_num,
      G.quick_code AS visit_type_code,
      MIN(A.bill_period_num) AS bill_period_num
    FROM temp_ar_billtrans AS A
    INNER JOIN ar_billtrans_charge_ce_temp AS B
      ON A.source_system_id = B.source_system_id AND A.bill_trans_num = B.bill_trans_num
    INNER JOIN `uspidnaproddata.advantx_ods.ut_proc_fee` AS C FOR SYSTEM_TIME AS OF freeze_time
      ON B.source_system_id = C.source_system_id AND B.procfee_num = C.num
    INNER JOIN `uspidnaproddata.advantx_ods.ut_proc` AS D FOR SYSTEM_TIME AS OF freeze_time
      ON C.source_system_id = D.source_system_id AND C.proc_num = D.num
    INNER JOIN (
      SELECT
        source_system_id,
        case_num,
        bill_trans_num,
        charge_amount
      FROM ar_billtrans_charge_rank_ce_temp
    ) AS E
      ON B.source_system_id = E.source_system_id
      AND B.case_num = E.case_num
      AND B.bill_trans_num = E.bill_trans_num
      AND B.charge_amount = E.charge_amount
    LEFT OUTER JOIN `uspidnaproddata.advantx_ods.ca_visit` AS F FOR SYSTEM_TIME AS OF freeze_time
      ON B.source_system_id = F.source_system_id AND B.visit_num = F.visit_num
    LEFT OUTER JOIN `uspidnaproddata.advantx_ods.ut_visittypes` AS G FOR SYSTEM_TIME AS OF freeze_time
      ON F.source_system_id = G.source_system_id AND F.visittype_num = G.num
    LEFT OUTER JOIN PRIMARY_PROCEDURE_ce_temp AS H
      ON B.source_system_id = H.source_system_id AND B.case_num = H.case_num
    WHERE
      A.active = 1 AND D.quick_code <> 'ERROR' AND H.source_system_id IS NULL
    GROUP BY
      A.source_system_id,
      B.case_num,
      B.procfee_num,
      D.quick_code,
      G.num,
      G.quick_code
  ) AS A
) AS A
WHERE
  rownumber = 1 AND A.source_system_id = V_source_system;
/* ================================================================================================= */
/* 3. Create the Optimized Temporary Table (V_TEMP_TABLE_OPT) */
/* ================================================================================================= */
CREATE OR REPLACE TEMPORARY TABLE V_TEMP_TABLE_OPT AS
WITH JoinedData AS (
  SELECT
    A.bill_period_num,
    B.case_num,
    B.procfee_num,
    D.quick_code AS procedure_code,
    G.num AS visittype_num,
    G.quick_code AS visit_type_code,
    A.source_system_id
  FROM temp_ar_billtrans AS A
  INNER JOIN ar_billtrans_charge_ce_temp AS B
    ON A.source_system_id = B.source_system_id AND A.bill_trans_num = B.bill_trans_num
  INNER JOIN `uspidnaproddata.advantx_ods.ut_proc_fee` AS C FOR SYSTEM_TIME AS OF freeze_time
    ON B.source_system_id = C.source_system_id AND B.procfee_num = C.num
  INNER JOIN `uspidnaproddata.advantx_ods.ut_proc` AS D FOR SYSTEM_TIME AS OF freeze_time
    ON C.source_system_id = D.source_system_id AND C.proc_num = D.num
  INNER JOIN ar_billtrans_charge_rank_ce_temp AS E
    ON B.source_system_id = E.source_system_id
    AND B.case_num = E.case_num
    AND B.bill_trans_num = E.bill_trans_num
    AND B.charge_amount = E.charge_amount
  LEFT JOIN `uspidnaproddata.advantx_ods.ca_visit` AS F FOR SYSTEM_TIME AS OF freeze_time
    ON B.source_system_id = F.source_system_id AND B.visit_num = F.visit_num
  LEFT JOIN `uspidnaproddata.advantx_ods.ut_visittypes` AS G FOR SYSTEM_TIME AS OF freeze_time
    ON F.source_system_id = G.source_system_id AND F.visittype_num = G.num
  LEFT JOIN PRIMARY_PROCEDURE_ce_temp AS H
    ON B.source_system_id = H.source_system_id AND B.case_num = H.case_num
  WHERE
    A.source_system_id = V_source_system
    AND A.active = 1
    AND D.quick_code <> 'ERROR'
    AND H.source_system_id IS NULL
), AggregatedData AS (
  SELECT
    source_system_id,
    case_num,
    procfee_num,
    procedure_code,
    visittype_num,
    visit_type_code,
    MIN(bill_period_num) AS bill_period_num
  FROM JoinedData
  GROUP BY
    source_system_id,
    case_num,
    procfee_num,
    procedure_code,
    visittype_num,
    visit_type_code
), RankedData AS (
  SELECT
    source_system_id,
    case_num,
    procfee_num,
    procedure_code,
    visittype_num,
    visit_type_code,
    bill_period_num,
    ROW_NUMBER() OVER (PARTITION BY source_system_id, case_num ORDER BY procedure_code) AS rownumber
  FROM AggregatedData
)
SELECT
  source_system_id,
  case_num,
  procfee_num,
  procedure_code,
  visittype_num,
  visit_type_code,
  bill_period_num
FROM RankedData
WHERE
  rownumber = 1;

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