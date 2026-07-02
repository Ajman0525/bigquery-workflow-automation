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

DECLARE inparam_facility_cd STRING DEFAULT 'NCA';

DECLARE V_FACILITY_CD STRING;
DECLARE V_METRIC_NAME STRING;
DECLARE V_TARGET_TBL_NM STRING;
DECLARE V_LAST_EXTRACT_DT DATETIME;

SET V_FACILITY_CD = UPPER(inparam_facility_cd);
SET V_METRIC_NAME   = 'pos_goal';
SET V_TARGET_TBL_NM = 'fact_cash_summary';
SET V_LAST_EXTRACT_DT = (SELECT MAX(last_extract_ts) FROM `rcm_mart.mart_data_control` 
										             WHERE source_system = 'daac'
													       AND target_table_nm = V_TARGET_TBL_NM
                                 AND metric_nm = V_METRIC_NAME
																 AND fac_cd = V_FACILITY_CD
                                 AND active_flg = 'Y');
-- END STORED PROCEDURE CONTEXT

-- =================================================================================================
-- 2. Create the Original Temporary Table (V_TEMP_TABLE_ORIG)
-- =================================================================================================
CREATE OR REPLACE TEMP TABLE V_TEMP_TABLE_ORIG AS
SELECT
          framework_metadata.createhashkey(vw.client_id, vw.source_system, vw.facility_cd, CAST(vw.posting_me AS STRING), V_METRIC_NAME, null, null, null, null, null, null, null, null, null, null, null, null, null, null, null) AS ar_rev_adj_hk,
          vw.dim_facility_hk,
          vw.client_id,
          vw.source_system,
          vw.facility_cd,
          vw.posting_me,
          vw.max_posting_date,
          vw.prior_max_posting_me,
          vw.fiscal_year,
          vw.prior_fiscal_year,
          vw.current_max_year,
          vw.prior_max_year,
          vw.prior_year_max_posting_date,
          vw.posting_month_name,
          vw.current_mtd_posting_days,
          vw.current_fytd_posting_days,
          vw.current_me_posting_days,
          vw.me_fytd_posting_days,
          vw.fytd_posting_days_total,
          vw.max_posting_year,
          vw.max_posting_me,
          vw.quarter,
          vw.quarter_year,
          vw.prior_year_posting_date,
          vw.display,
          vw.tenet_novant,
          V_METRIC_NAME AS metric_key,
          vw.pos_goal AS metric_value
        FROM `cfrdnaproddata3.rcm_mart.vw_detail_consolidated_fact_cash_summary` vw
        WHERE vw.facility_cd = V_FACILITY_CD
          AND vw.posting_me >= V_LAST_EXTRACT_DT;

-- =================================================================================================
-- 3. Create the Optimized Temporary Table (V_TEMP_TABLE_OPT)
-- =================================================================================================
CREATE OR REPLACE TEMP TABLE V_TEMP_TABLE_OPT AS
WITH vw_filtered AS (
  SELECT
    dim_facility_hk,
    client_id,
    source_system,
    facility_cd,
    posting_me,
    max_posting_date,
    prior_max_posting_me,
    fiscal_year,
    prior_fiscal_year,
    current_max_year,
    prior_max_year,
    prior_year_max_posting_date,
    posting_month_name,
    current_mtd_posting_days,
    current_fytd_posting_days,
    current_me_posting_days,
    me_fytd_posting_days,
    fytd_posting_days_total,
    max_posting_year,
    max_posting_me,
    quarter,
    quarter_year,
    prior_year_posting_date,
    display,
    tenet_novant,
    pos_goal
  FROM `cfrdnaproddata3.rcm_mart.vw_detail_consolidated_fact_cash_summary`
  WHERE facility_cd = V_FACILITY_CD
    AND posting_me >= V_LAST_EXTRACT_DT
)
SELECT
  framework_metadata.createhashkey(vw.client_id, vw.source_system, vw.facility_cd, CAST(vw.posting_me AS STRING), V_METRIC_NAME, null, null, null, null, null, null, null, null, null, null, null, null, null, null, null) AS ar_rev_adj_hk,
  vw.dim_facility_hk,
  vw.client_id,
  vw.source_system,
  vw.facility_cd,
  vw.posting_me,
  vw.max_posting_date,
  vw.prior_max_posting_me,
  vw.fiscal_year,
  vw.prior_fiscal_year,
  vw.current_max_year,
  vw.prior_max_year,
  vw.prior_year_max_posting_date,
  vw.posting_month_name,
  vw.current_mtd_posting_days,
  vw.current_fytd_posting_days,
  vw.current_me_posting_days,
  vw.me_fytd_posting_days,
  vw.fytd_posting_days_total,
  vw.max_posting_year,
  vw.max_posting_me,
  vw.quarter,
  vw.quarter_year,
  vw.prior_year_posting_date,
  vw.display,
  vw.tenet_novant,
  V_METRIC_NAME AS metric_key,
  vw.pos_goal AS metric_value
FROM vw_filtered AS vw;

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
