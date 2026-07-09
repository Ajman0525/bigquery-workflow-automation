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
DECLARE freeze_time TIMESTAMP DEFAULT TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 24 HOUR);
DECLARE V_source_system STRING DEFAULT 'vhhc'; 
DECLARE V_SQL STRING;

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

SET V_SQL = FORMAT("""
      CREATE TEMP TABLE temp_ar_billtrans AS
      SELECT * FROM `uspidnaproddata.advantx_ods.ar_billtrans_%s`
      """, V_source_system);

    EXECUTE IMMEDIATE V_SQL;

SET V_SQL = FORMAT("""
        CREATE TEMP TABLE temp_ca_visit_visitdept_proc_hist AS
        SELECT * FROM uspidnaproddata.advantx_ods.ca_visit_visitdept_proc_hist_%s
        """, V_source_system);

    EXECUTE IMMEDIATE V_SQL;
/* END STORED PROCEDURE CONTEXT */
/* ================================================================================================= */
/* 2. Create the Original Temporary Table (V_TEMP_TABLE_ORIG) */
/* ================================================================================================= */
CREATE OR REPLACE TEMPORARY TABLE V_TEMP_TABLE_ORIG AS
SELECT
  A.source_system_id,
  A.case_num,
  A.bill_trans_num,
  A.charge_amount
FROM (
  SELECT
    A.source_system_id,
    B.case_num,
    B.bill_trans_num,
    B.charge_amount,
    ROW_NUMBER() OVER (
      PARTITION BY A.source_system_id, b.case_num
      ORDER BY A.source_system_id, b.case_num, b.charge_amount DESC, b.bill_trans_num
    ) AS RowNumber
  FROM temp_ar_billtrans AS A
  INNER JOIN ar_billtrans_charge_ce_temp AS B
    ON A.source_system_id = B.source_system_id AND A.bill_trans_num = B.bill_trans_num
  INNER JOIN `uspidnaproddata.advantx_ods.ar_billing_period` AS C FOR SYSTEM_TIME AS OF freeze_time
    ON A.source_system_id = C.source_system_id AND A.bill_period_num = C.num
  INNER JOIN `uspidnaproddata.advantx_ods.ut_proc_fee` AS D FOR SYSTEM_TIME AS OF freeze_time
    ON A.source_system_id = D.source_system_id AND B.procfee_num = D.num
  INNER JOIN `uspidnaproddata.advantx_ods.ut_proc` AS E FOR SYSTEM_TIME AS OF freeze_time
    ON A.source_system_id = E.source_system_id AND D.proc_num = E.num
  INNER JOIN `uspidnaproddata.advantx_ods.ca_case` AS F FOR SYSTEM_TIME AS OF freeze_time
    ON A.source_system_id = F.source_system_id AND B.case_num = F.case_num
  LEFT OUTER JOIN temp_ca_visit_visitdept_proc_hist AS G
    ON A.source_system_id = G.source_system_id
    AND B.case_num = G.case_num
    AND E.num = G.proc_num
    AND G.order_key = 1
  WHERE
    A.active = 1
    AND F.key_dos >= (
      SELECT
        DATE_TRUNC(DATE_SUB(CURRENT_DATE, INTERVAL '3' YEAR), YEAR) AS datetime_three_years_ago
    )
) AS A
WHERE
  A.RowNumber = 1 AND A.source_system_id = V_source_system;

/* ================================================================================================= */
/* 3. Create the Optimized Temporary Table (V_TEMP_TABLE_OPT) */
/* ================================================================================================= */
CREATE OR REPLACE TEMPORARY TABLE V_TEMP_TABLE_OPT AS
WITH FilteredData AS (
  SELECT
    A.source_system_id,
    B.case_num,
    B.bill_trans_num,
    B.charge_amount,
    ROW_NUMBER() OVER (
      PARTITION BY A.source_system_id, B.case_num
      ORDER BY B.charge_amount DESC, B.bill_trans_num ASC
    ) AS RowNumber
  FROM temp_ar_billtrans AS A
  INNER JOIN ar_billtrans_charge_ce_temp AS B
    ON A.source_system_id = B.source_system_id AND A.bill_trans_num = B.bill_trans_num
  INNER JOIN `uspidnaproddata.advantx_ods.ar_billing_period` AS C FOR SYSTEM_TIME AS OF freeze_time
    ON A.source_system_id = C.source_system_id AND A.bill_period_num = C.num
  INNER JOIN `uspidnaproddata.advantx_ods.ut_proc_fee` AS D FOR SYSTEM_TIME AS OF freeze_time
    ON A.source_system_id = D.source_system_id AND B.procfee_num = D.num
  INNER JOIN `uspidnaproddata.advantx_ods.ut_proc` AS E FOR SYSTEM_TIME AS OF freeze_time
    ON A.source_system_id = E.source_system_id AND D.proc_num = E.num
  INNER JOIN `uspidnaproddata.advantx_ods.ca_case` AS F FOR SYSTEM_TIME AS OF freeze_time
    ON A.source_system_id = F.source_system_id AND B.case_num = F.case_num
  LEFT OUTER JOIN temp_ca_visit_visitdept_proc_hist AS G
    ON A.source_system_id = G.source_system_id
    AND B.case_num = G.case_num
    AND E.num = G.proc_num
    AND G.order_key = 1
  WHERE
    A.active = 1
    AND F.key_dos >= DATE_TRUNC(DATE_SUB(CURRENT_DATE, INTERVAL '3' YEAR), YEAR)
    AND A.source_system_id = V_source_system
)
SELECT
  source_system_id,
  case_num,
  bill_trans_num,
  charge_amount
FROM FilteredData
WHERE
  RowNumber = 1;

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