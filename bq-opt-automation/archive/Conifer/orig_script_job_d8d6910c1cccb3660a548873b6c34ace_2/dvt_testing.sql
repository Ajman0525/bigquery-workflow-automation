-- =================================================================================================

-- Script to create and validate two temporary tables.

-- Expected Outcome: The final SELECT statement should return zero rows, confirming that

-- V_TEMP_TABLE_ORIG and V_TEMP_TABLE_OPT produce identical results.

-- =================================================================================================

-- 1. Declare and set the facility code variable used in both queries.

-- =================================================================================================

-- 2. Create the Original Temporary Table (V_TEMP_TABLE_ORIG)

-- =================================================================================================

--CREATE OR REPLACE TEMP TABLE V_TEMP_TABLE_ORIG AS --select * from [ung table name]

-- INSERT YOUR ORIGINAL SCRIPT HERE

-- =================================================================================================

-- 3. Create the Optimized Temporary Table (V_TEMP_TABLE_OPT)

-- =================================================================================================

--CREATE OR REPLACE TEMP TABLE V_TEMP_TABLE_OPT AS --select * from [ung table name]

-- INSERT YOUR OPTIMIZED SCRIPT HERE

-- =================================================================================================

-- 4. Validation Step: Compare the two tables.

-- This query returns rows that are in V_TEMP_TABLE_ORIG but not in V_TEMP_TABLE_OPT.

-- Because the logic is identical, this should produce an empty result set.

-- =================================================================================================

-- To show rows that are only in the original table

(SELECT 'ONLY IN ORIGINAL' AS diff_type, *

FROM V_TEMP_TABLE_ORIG

EXCEPT DISTINCT

SELECT 'ONLY IN ORIGINAL' AS diff_type, *

FROM V_TEMP_TABLE_OPT

)

UNION ALL

-- To show rows that are only in the optimized table

(SELECT 'ONLY IN OPTIMIZED' AS diff_type, *

FROM V_TEMP_TABLE_OPT

EXCEPT DISTINCT

SELECT 'ONLY IN OPTIMIZED' AS diff_type, *

FROM V_TEMP_TABLE_ORIG

);
 