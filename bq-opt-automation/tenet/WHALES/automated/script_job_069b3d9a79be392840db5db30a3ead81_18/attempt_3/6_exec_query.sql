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
CREATE TABLE IF NOT EXISTS thcdnaproddata.aci.ordering_physician_stg CLUSTER BY hss_id,order_id AS
select * FROM (
--CERNER
select distinct o.order_id
,o.health_system_source_id as hss_id
, p.name_full_formatted as ordering_physician
FROM thcdnaproddata.cerner_ods.cerner_orders_hist o
inner JOIN thcdnaproddata.cerner_ods.cerner_order_action_hist oa
on oa.order_id = o.order_id
and oa.health_system_source_id = o.health_system_source_id
and oa.order_provider_id > 0
and oa.action_sequence = 1    
inner JOIN thcdnaproddata.cerner_ods.cerner_code_value_hist cv
on oa.action_type_cd = cv.code_value
and cv.display = 'Order'
and oa.health_system_source_id = cv.health_system_source_id
inner JOIN thcdnaproddata.cerner_ods.cerner_prsnl_hist p
on p.person_id = oa.order_provider_id
inner JOIN thcdnaproddata.cerner_ods.cerner_code_value_hist f 
on p.health_system_source_id = f.health_system_source_id 
and f.code_value = p.position_cd

UNION ALL
---DMC
select distinct o.order_id
,o.health_system_source_id as hss_id
, p.name_full_formatted as ordering_physician
FROM thcdnaproddata.cerner_ods.dmc_orders_hist o
inner JOIN thcdnaproddata.cerner_ods.dmc_order_action_hist oa
on oa.order_id = o.order_id
and oa.health_system_source_id = o.health_system_source_id
and oa.order_provider_id > 0
and oa.action_sequence = 1    
inner JOIN thcdnaproddata.cerner_ods.dmc_code_value_hist cv
on oa.action_type_cd = cv.code_value
and cv.display = 'Order'
and oa.health_system_source_id = cv.health_system_source_id
inner JOIN thcdnaproddata.cerner_ods.dmc_prsnl_hist p
on p.person_id = oa.order_provider_id
inner JOIN thcdnaproddata.cerner_ods.dmc_code_value_hist f 
on p.health_system_source_id = f.health_system_source_id 
and f.code_value = p.position_cd
) as foo;

-- =================================================================================================
-- 3. Create the Optimized Temporary Table (V_TEMP_TABLE_OPT)
-- =================================================================================================
CREATE OR REPLACE TEMP TABLE V_TEMP_TABLE_OPT AS
CREATE TABLE IF NOT EXISTS thcdnaproddata.aci.ordering_physician_stg
CLUSTER BY hss_id, order_id AS
WITH cerner_data AS (
  SELECT DISTINCT
    o.order_id,
    o.health_system_source_id AS hss_id,
    p.name_full_formatted AS ordering_physician
  FROM
    `thcdnaproddata.cerner_ods.cerner_orders_hist` AS o
  INNER JOIN
    `thcdnaproddata.cerner_ods.cerner_order_action_hist` AS oa
    ON o.order_id = oa.order_id AND o.health_system_source_id = oa.health_system_source_id
  INNER JOIN
    `thcdnaproddata.cerner_ods.cerner_prsnl_hist` AS p
    ON oa.order_provider_id = p.person_id
  WHERE
    oa.action_sequence = 1
    AND oa.order_provider_id > 0
    -- Replaced INNER JOIN to 'cv' with a more efficient EXISTS subquery to act as a filter
    AND EXISTS (
      SELECT 1
      FROM `thcdnaproddata.cerner_ods.cerner_code_value_hist` AS cv
      WHERE
        cv.code_value = oa.action_type_cd
        AND cv.health_system_source_id = oa.health_system_source_id
        AND cv.display = 'Order'
    )
    -- Replaced filtering INNER JOIN to 'f' with a more efficient EXISTS subquery
    AND EXISTS (
      SELECT 1
      FROM `thcdnaproddata.cerner_ods.cerner_code_value_hist` AS f
      WHERE
        f.code_value = p.position_cd
        AND f.health_system_source_id = p.health_system_source_id
    )
),
dmc_data AS (
  SELECT DISTINCT
    o.order_id,
    o.health_system_source_id AS hss_id,
    p.name_full_formatted AS ordering_physician
  FROM
    `thcdnaproddata.cerner_ods.dmc_orders_hist` AS o
  INNER JOIN
    `thcdnaproddata.cerner_ods.dmc_order_action_hist` AS oa
    ON o.order_id = oa.order_id AND o.health_system_source_id = oa.health_system_source_id
  INNER JOIN
    `thcdnaproddata.cerner_ods.dmc_prsnl_hist` AS p
    ON oa.order_provider_id = p.person_id
  WHERE
    oa.action_sequence = 1
    AND oa.order_provider_id > 0
    -- Replaced INNER JOIN to 'cv' with a more efficient EXISTS subquery to act as a filter
    AND EXISTS (
      SELECT 1
      FROM `thcdnaproddata.cerner_ods.dmc_code_value_hist` AS cv
      WHERE
        cv.code_value = oa.action_type_cd
        AND cv.health_system_source_id = oa.health_system_source_id
        AND cv.display = 'Order'
    )
    -- Replaced filtering INNER JOIN to 'f' with a more efficient EXISTS subquery
    AND EXISTS (
      SELECT 1
      FROM `thcdnaproddata.cerner_ods.dmc_code_value_hist` AS f
      WHERE
        f.code_value = p.position_cd
        AND f.health_system_source_id = p.health_system_source_id
    )
)
SELECT order_id, hss_id, ordering_physician FROM cerner_data
UNION ALL
SELECT order_id, hss_id, ordering_physician FROM dmc_data;

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
