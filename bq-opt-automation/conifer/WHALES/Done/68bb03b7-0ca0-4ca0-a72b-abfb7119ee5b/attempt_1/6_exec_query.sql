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
-- No stored procedure context dependencies were detected.
-- END STORED PROCEDURE CONTEXT

-- =================================================================================================

-- 2. Create the Original Temporary Table (V_TEMP_TABLE_ORIG)

-- =================================================================================================

CREATE OR REPLACE TEMP TABLE V_TEMP_TABLE_ORIG AS
SELECT *
FROM cfrdnaproddata3.ace_ods.rpadta_ptmdesk RPA
WHERE EXISTS (
    SELECT 1
    FROM cfrdnaproddata3.ace_staging.ptmdesk_dlta d
    WHERE d.DTDBID = RPA.DTDBID
      AND d.DTTRGTS = RPA.DTTRGTS
      AND INDICATOR IN ('A','C','D','P')
);


-- =================================================================================================

-- 3. Create the Optimized Temporary Table (V_TEMP_TABLE_OPT)

-- =================================================================================================

CREATE OR REPLACE TEMP TABLE V_TEMP_TABLE_OPT AS
SELECT T.*
FROM `cfrdnaproddata3.ace_ods.rpadta_ptmdesk` T
INNER JOIN (
    SELECT DISTINCT
        DTDBID,
        DTTRGTS
    FROM `cfrdnaproddata3.ace_staging.ptmdesk_dlta`
    WHERE INDICATOR IN ('A', 'C', 'D', 'P')
) S
ON T.DTDBID = S.DTDBID
AND T.DTTRGTS = S.DTTRGTS;
 
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

