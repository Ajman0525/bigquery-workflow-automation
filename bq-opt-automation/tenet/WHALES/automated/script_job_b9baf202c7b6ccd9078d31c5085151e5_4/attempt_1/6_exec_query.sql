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
-- WARNING: Review the TODO items before relying on this validation script.
-- TODO: Could not locate the original query inside 3_orig_sp.sql; stored procedure context could not be inferred.
-- TODO: Verify variable V_FACILITY_CD; no prior DECLARE was found in the SP.
-- No stored procedure context dependencies were detected.
-- END STORED PROCEDURE CONTEXT

-- =================================================================================================
-- 2. Create the Original Temporary Table (V_TEMP_TABLE_ORIG)
-- =================================================================================================
CREATE OR REPLACE TEMP TABLE V_TEMP_TABLE_ORIG AS
select PATIENT_ACCOUNT_NBR, FE.FACILITY_CD,PA_TOTAL_PAYMENTS as MODIFIED_ANR 
  from idm.fact_encounter FE join idm.dim_facility DF
  on FE.DIM_FACILITY_SK=DF.DIM_FACILITY_SK

	WHERE FE.DIM_FACILITY_SK IN 
	(
		SELECT DIM_FACILITY_SK FROM thcdnaproddata.idm.dim_facility DF
		WHERE ( (DF.MRKT_ID IN ('M16') AND DF.FACILITY_CD NOT IN ('BMC')) OR DF.FACILITY_CD IN ('HMD','EMC'))

	)
	AND (FE.FACILITY_CD, PATIENT_ACCOUNT_NBR) NOT IN (SELECT (FACILITY_CD, PATIENT_ACCOUNT_NBR) FROM thcdnaproddata.idm.fact_encounter_modified_anr)
  and (LOWER(TRIM(FE.FACILITY_CD)) = LOWER(TRIM(V_FACILITY_CD)));

-- =================================================================================================
-- 3. Create the Optimized Temporary Table (V_TEMP_TABLE_OPT)
-- =================================================================================================
CREATE OR REPLACE TEMP TABLE V_TEMP_TABLE_OPT AS
SELECT
  fe.PATIENT_ACCOUNT_NBR,
  fe.FACILITY_CD,
  fe.PA_TOTAL_PAYMENTS AS MODIFIED_ANR
FROM
  `idm.fact_encounter` AS fe
JOIN
  `idm.dim_facility` AS df
  ON fe.DIM_FACILITY_SK = df.DIM_FACILITY_SK
LEFT JOIN
  `thcdnaproddata.idm.fact_encounter_modified_anr` AS existing
  ON fe.PATIENT_ACCOUNT_NBR = existing.PATIENT_ACCOUNT_NBR
  AND fe.FACILITY_CD = existing.FACILITY_CD
WHERE
  -- Filter to include only new records not present in the target table
  existing.PATIENT_ACCOUNT_NBR IS NULL
  -- Merged facility filter criteria from original JOIN and IN subquery
  AND (
    (df.MRKT_ID = 'M16' AND df.FACILITY_CD != 'BMC')
    OR df.FACILITY_CD IN ('HMD', 'EMC')
  )
  -- This function-wrapped predicate remains a major performance bottleneck.
  -- It forces a full scan and should be addressed via ETL or data cleaning.
  AND LOWER(TRIM(fe.FACILITY_CD)) = LOWER(TRIM(V_FACILITY_CD));

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
