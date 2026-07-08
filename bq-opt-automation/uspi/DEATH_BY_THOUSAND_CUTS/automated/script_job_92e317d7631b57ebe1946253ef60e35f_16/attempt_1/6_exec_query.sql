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

DECLARE
  V_source_system string default 'vhhc';

DECLARE
  V_SQL STRING;
  
CREATE TEMP TABLE ar_billtrans_charge_ce_temp (
        source_system_id string,
        bill_trans_num numeric,
        charge_amount numeric,
        paid_amount numeric,
        writtenoff_amount numeric,
        pat_part numeric,
        ps_num numeric,
        procfee_num numeric,
        units numeric,
        facility_num numeric,
        case_num numeric,
        visit_num numeric,
        dx1_num numeric,
        refer_phys_num numeric,
        dx1_num_10 numeric
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
    SELECT
      A.source_system_id,
      B.case_num,
      B.procfee_num,
      E.quick_code AS procedure_code,
      I.num AS visittype_num,
      I.quick_code AS visit_type_code,
      MIN(A.bill_period_num) AS bill_period_num
    FROM temp_ar_billtrans AS A
    INNER JOIN ar_billtrans_charge_ce_temp AS B
      ON A.source_system_id = B.source_system_id AND A.bill_trans_num = B.bill_trans_num
    INNER JOIN `uspidnaproddata.advantx_ods.ar_billing_period` AS C FOR SYSTEM_TIME AS OF freeze_time
      ON A.source_system_id = C.source_system_id AND A.bill_period_num = C.num
    INNER JOIN `uspidnaproddata.advantx_ods.ut_proc_fee` AS D FOR SYSTEM_TIME AS OF freeze_time
      ON B.source_system_id = D.source_system_id AND B.procfee_num = D.num
    INNER JOIN `uspidnaproddata.advantx_ods.ut_proc` AS E FOR SYSTEM_TIME AS OF freeze_time
      ON D.source_system_id = E.source_system_id AND D.proc_num = E.num
    INNER JOIN `uspidnaproddata.advantx_ods.ca_case` AS F FOR SYSTEM_TIME AS OF freeze_time
      ON B.source_system_id = F.source_system_id AND B.case_num = F.case_num
    INNER JOIN temp_ca_visit_visitdept_proc_hist AS G
      ON B.source_system_id = G.source_system_id
      AND B.case_num = G.case_num
      AND E.num = G.proc_num
      AND G.order_key = 1
    INNER JOIN `uspidnaproddata.advantx_ods.ca_visit` AS H FOR SYSTEM_TIME AS OF freeze_time
      ON G.source_system_id = H.source_system_id AND G.visit_num = H.visit_num
    INNER JOIN `uspidnaproddata.advantx_ods.ut_visittypes` AS I FOR SYSTEM_TIME AS OF freeze_time
      ON H.source_system_id = I.source_system_id AND H.visittype_num = I.num
    WHERE
      A.active = 1
      AND F.key_dos >= (
        SELECT
          DATE_TRUNC(DATE_SUB(CURRENT_DATE, INTERVAL '3' YEAR), YEAR) AS datetime_three_years_ago
      )
    GROUP BY
      A.source_system_id,
      B.case_num,
      B.procfee_num,
      E.quick_code,
      I.num,
      I.quick_code
  ) AS A
) AS A
WHERE
  rownumber = 1 AND A.source_system_id = V_source_system;

/* ================================================================================================= */
/* 3. Create the Optimized Temporary Table (V_TEMP_TABLE_OPT) */
/* ================================================================================================= */
CREATE OR REPLACE TEMPORARY TABLE V_TEMP_TABLE_OPT AS
WITH AggregatedData AS (
  /* This CTE performs all joins, filtering, and aggregation. */
  /* By applying the V_source_system filter here, we ensure all subsequent operations */
  /* are performed on the smallest possible dataset. */
  SELECT
    A.source_system_id,
    B.case_num,
    B.procfee_num,
    E.quick_code AS procedure_code,
    I.num AS visittype_num,
    I.quick_code AS visit_type_code,
    MIN(A.bill_period_num) AS bill_period_num
  FROM temp_ar_billtrans AS A
  INNER JOIN ar_billtrans_charge_ce_temp AS B
    ON A.source_system_id = B.source_system_id AND A.bill_trans_num = B.bill_trans_num
  INNER JOIN `uspidnaproddata.advantx_ods.ar_billing_period` AS C FOR SYSTEM_TIME AS OF freeze_time
    ON A.source_system_id = C.source_system_id AND A.bill_period_num = C.num
  INNER JOIN `uspidnaproddata.advantx_ods.ut_proc_fee` AS D FOR SYSTEM_TIME AS OF freeze_time
    ON B.source_system_id = D.source_system_id AND B.procfee_num = D.num
  INNER JOIN `uspidnaproddata.advantx_ods.ut_proc` AS E FOR SYSTEM_TIME AS OF freeze_time
    ON D.source_system_id = E.source_system_id AND D.proc_num = E.num
  INNER JOIN `uspidnaproddata.advantx_ods.ca_case` AS F FOR SYSTEM_TIME AS OF freeze_time
    ON B.source_system_id = F.source_system_id AND B.case_num = F.case_num
  INNER JOIN temp_ca_visit_visitdept_proc_hist AS G
    ON B.source_system_id = G.source_system_id
    AND B.case_num = G.case_num
    AND E.num = G.proc_num
  INNER JOIN `uspidnaproddata.advantx_ods.ca_visit` AS H FOR SYSTEM_TIME AS OF freeze_time
    ON G.source_system_id = H.source_system_id AND G.visit_num = H.visit_num
  INNER JOIN `uspidnaproddata.advantx_ods.ut_visittypes` AS I FOR SYSTEM_TIME AS OF freeze_time
    ON H.source_system_id = I.source_system_id AND H.visittype_num = I.num
  WHERE
    A.source_system_id /* Applying filters as early as possible is critical for performance. */ = V_source_system /* Assuming V_source_system is a variable/placeholder */
    AND A.active = 1
    AND F.key_dos >= DATE_TRUNC(DATE_SUB(CURRENT_DATE, INTERVAL '3' YEAR), YEAR)
    AND G.order_key = 1
  GROUP BY
    A.source_system_id,
    B.case_num,
    B.procfee_num,
    E.quick_code,
    I.num,
    I.quick_code
), RankedProcedures AS (
  /* This CTE applies the ROW_NUMBER() to select a single primary procedure per case. */
  SELECT
    source_system_id,
    case_num,
    procfee_num,
    procedure_code,
    visittype_num,
    visit_type_code,
    bill_period_num,
    ROW_NUMBER() OVER (PARTITION BY source_system_id, case_num ORDER BY procedure_code) AS rn
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
FROM RankedProcedures
WHERE
  rn = 1;

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