DECLARE freeze_time TIMESTAMP DEFAULT TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 24 HOUR);


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
/* No stored procedure context dependencies were detected. */
/* END STORED PROCEDURE CONTEXT */
/* ================================================================================================= */
/* 2. Create the Original Temporary Table (V_TEMP_TABLE_ORIG) */
/* ================================================================================================= */
CREATE OR REPLACE TEMPORARY TABLE V_TEMP_TABLE_ORIG AS
SELECT
  *
FROM (
  SELECT
    s_o.HEALTH_SYSTEM_SOURCE_ID AS order_hss_id,
    s_o.ORDER_ID AS ORDER_ID,
    s_o.ENCNTR_ID AS ENCNTR_ID,
    s_o.PERSON_ID AS PERSON_ID,
    s_o.ordered_as_mnemonic AS ordered_as_mnemonic,
    s_o.ORDER_MNEMONIC AS PRIMARY_MNEMONIC,
    s_o.CLINICAL_DISPLAY_LINE,
    s_o.ORDER_DETAIL_DISPLAY_LINE
  FROM thcdnaproddata.aci.oredr_mnemonic_stg1 AS stg1 FOR SYSTEM_TIME AS OF freeze_time
  INNER JOIN thcdnaproddata.cerner_ods.cerner_orders_hist AS s_o FOR SYSTEM_TIME AS OF freeze_time
    ON s_o.HEALTH_SYSTEM_SOURCE_ID = stg1.order_hss_id AND s_o.ORDER_ID = stg1.ORDER_id
  UNION ALL
  SELECT
    s_o.HEALTH_SYSTEM_SOURCE_ID AS order_hss_id,
    s_o.ORDER_ID AS ORDER_ID,
    s_o.ENCNTR_ID AS ENCNTR_ID,
    s_o.PERSON_ID AS PERSON_ID,
    s_o.ordered_as_mnemonic AS ordered_as_mnemonic,
    s_o.ORDER_MNEMONIC AS PRIMARY_MNEMONIC,
    s_o.CLINICAL_DISPLAY_LINE,
    s_o.ORDER_DETAIL_DISPLAY_LINE
  FROM thcdnaproddata.aci.oredr_mnemonic_stg1 AS stg1 FOR SYSTEM_TIME AS OF freeze_time
  INNER JOIN thcdnaproddata.cerner_ods.dmc_orders_hist AS s_o FOR SYSTEM_TIME AS OF freeze_time
    ON s_o.HEALTH_SYSTEM_SOURCE_ID = stg1.order_hss_id AND s_o.ORDER_ID = stg1.ORDER_id
) AS foo;

/* ================================================================================================= */
/* 3. Create the Optimized Temporary Table (V_TEMP_TABLE_OPT) */
/* ================================================================================================= */
CREATE OR REPLACE TEMPORARY TABLE V_TEMP_TABLE_OPT AS
WITH stg1_keys AS (
  SELECT
    order_hss_id,
    ORDER_id
  FROM thcdnaproddata.aci.oredr_mnemonic_stg1 FOR SYSTEM_TIME AS OF freeze_time
)
SELECT
  s_o.HEALTH_SYSTEM_SOURCE_ID AS order_hss_id,
  s_o.ORDER_ID AS ORDER_ID,
  s_o.ENCNTR_ID AS ENCNTR_ID,
  s_o.PERSON_ID AS PERSON_ID,
  s_o.ordered_as_mnemonic AS ordered_as_mnemonic,
  s_o.ORDER_MNEMONIC AS PRIMARY_MNEMONIC,
  s_o.CLINICAL_DISPLAY_LINE,
  s_o.ORDER_DETAIL_DISPLAY_LINE
FROM stg1_keys
INNER JOIN thcdnaproddata.cerner_ods.cerner_orders_hist AS s_o FOR SYSTEM_TIME AS OF freeze_time
  ON s_o.HEALTH_SYSTEM_SOURCE_ID = stg1_keys.order_hss_id
  AND s_o.ORDER_ID = stg1_keys.ORDER_id
UNION ALL
SELECT
  s_o.HEALTH_SYSTEM_SOURCE_ID AS order_hss_id,
  s_o.ORDER_ID AS ORDER_ID,
  s_o.ENCNTR_ID AS ENCNTR_ID,
  s_o.PERSON_ID AS PERSON_ID,
  s_o.ordered_as_mnemonic AS ordered_as_mnemonic,
  s_o.ORDER_MNEMONIC AS PRIMARY_MNEMONIC,
  s_o.CLINICAL_DISPLAY_LINE,
  s_o.ORDER_DETAIL_DISPLAY_LINE
FROM stg1_keys
INNER JOIN thcdnaproddata.cerner_ods.dmc_orders_hist AS s_o FOR SYSTEM_TIME AS OF freeze_time
  ON s_o.HEALTH_SYSTEM_SOURCE_ID = stg1_keys.order_hss_id
  AND s_o.ORDER_ID = stg1_keys.ORDER_id;

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