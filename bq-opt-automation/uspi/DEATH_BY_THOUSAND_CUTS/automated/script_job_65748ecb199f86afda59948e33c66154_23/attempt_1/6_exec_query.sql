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


DECLARE
  V_source_system string default 'rswl';

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

CREATE TEMP TABLE expected_collection_pct_fc_ce_temp ( 
                source_system_id string,  
                fc_code  numeric,
                expected_collection_pct numeric);

-- END STORED PROCEDURE CONTEXT

-- =================================================================================================
-- 2. Create the Original Temporary Table (V_TEMP_TABLE_ORIG)
-- =================================================================================================
CREATE OR REPLACE TEMP TABLE V_TEMP_TABLE_ORIG AS
SELECT          source_system_id, fc_code,
            CASE WHEN SUM(charge_amount) = 0.0 THEN 0.0 ELSE SUM(paid_amount)/SUM(charge_amount) END as expected_collection_pct
            FROM
            (
            SELECT  a.source_system_id,i.num as fc_code,
                a.case_num,
                SUM(b.charge_amount) as charge_amount,
                SUM(b.paid_amount) as paid_amount,
                SUM(b.writtenoff_amount) as writtenoff_amount                           
            FROM    `uspidnaproddata.advantx_ods.ca_case` a
            INNER JOIN  (SELECT * FROM ar_billtrans_charge_ce_temp) b
            on  a.source_system_id = b.source_system_id and
                a.case_num = b.case_num
            INNER JOIN `uspidnaproddata.advantx_ods.ut_proc_fee` d
            on  b.source_system_id = d.source_system_id and
                b.procfee_num = d.num
            INNER JOIN `uspidnaproddata.advantx_ods.ut_proc` e
            on  d.source_system_id = e.source_system_id and
                d.proc_num = e.num
            INNER JOIN (SELECT 
                ROW_NUMBER() OVER(PARTITION BY a_s.source_system_id, a_s.case_num ORDER BY policy_effective_date DESC) AS RowNum, 
                a_s.source_system_id, 
                a_s.case_num, 
                b_s.pers_org_num as payor_code, 
                IFNULL(copay_amt,0.00) as copay_amt
                FROM `uspidnaproddata.advantx_ods.ad_case_ps_ins` a_s  INNER JOIN             
                     `uspidnaproddata.advantx_ods.ad_ps_rolehist_ins` b_s  ON a_s.role_num = 6 AND
                a_s.source_system_id = b_s.source_system_id AND
                a_s.pers_org_num_pt = b_s.pers_org_num_pt AND 
                a_s.ps_num = b_s.ps_num and 
                a_s.role_num = b_s.role_num AND
                b_s.pers_org_num IS NOT NULL
                ) G ON g.RowNum = 1 AND
                    a.source_system_id = g.source_system_id AND
                    a.case_num = g.case_num 
            INNER JOIN `uspidnaproddata.advantx_ods.ut_insurcarrier`  h
            ON  g.source_system_id = h.source_system_id and
                g.payor_code = h.pers_org_num
            INNER JOIN `uspidnaproddata.advantx_ods.ut_insurcarrier_tisclient`    J
            ON  h.source_system_id = j.source_system_id and
                h.num = j.inscarr_num and
                a.tisclient_num = j.tisclient_num
            INNER JOIN `uspidnaproddata.advantx_ods.ut_insurtype`    I
            ON  j.source_system_id = i.source_system_id and
                j.insurtype_num = i.num
            WHERE   CAST(key_dos as DATE) BETWEEN DATE_TRUNC(DATE_SUB(CURRENT_DATE(), INTERVAL 3 YEAR), YEAR) and  CURRENT_DATE 
                and e.quick_code NOT IN ('ERROR','DUMMY')
        and a.source_system_id=V_source_system
            GROUP BY  a.source_system_id, i.num, a.case_num
                        HAVING          charge_amount - paid_amount - writtenoff_amount <= 10.00
            --HAVING    SUM(charge_amount) - SUM(paid_amount) - SUM(writtenoff_amount) <= 10.00
            ) cases
            GROUP BY source_system_id,fc_code;

-- =================================================================================================
-- 3. Create the Optimized Temporary Table (V_TEMP_TABLE_OPT)
-- =================================================================================================
CREATE OR REPLACE TEMP TABLE V_TEMP_TABLE_OPT AS
/*
 Correctness & Performance Rewrite

 1.  MODIFIED: The `CAST(key_dos AS DATE)` filter is rewritten as a direct range comparison on the `key_dos` column to enable partition pruning, significantly reducing bytes scanned.
 2.  REFACTORED: The query is restructured into Common Table Expressions (CTEs) to improve readability and logical separation.
 3.  IMPROVED: The `SELECT *` is replaced with an explicit list of necessary columns.
 4.  IMPROVED: Unused columns (`copay_amt`) are removed from subqueries to reduce data movement.
 5.  UNCHANGED: All join logic, aggregation levels, and the `HAVING` clause are preserved to guarantee identical results.
*/

WITH
latest_insurance AS (
  -- This CTE finds the most recent insurance payor for each case, replacing the inline derived table 'G'.
  -- The unused `copay_amt` column has been removed.
  SELECT
    a_s.source_system_id,
    a_s.case_num,
    b_s.pers_org_num AS payor_code,
    ROW_NUMBER() OVER (PARTITION BY a_s.source_system_id, a_s.case_num ORDER BY policy_effective_date DESC) AS RowNum
  FROM `uspidnaproddata.advantx_ods.ad_case_ps_ins` AS a_s
  INNER JOIN `uspidnaproddata.advantx_ods.ad_ps_rolehist_ins` AS b_s
    ON a_s.source_system_id = b_s.source_system_id
    AND a_s.pers_org_num_pt = b_s.pers_org_num_pt
    AND a_s.ps_num = b_s.ps_num
    AND a_s.role_num = b_s.role_num
  WHERE a_s.role_num = 6 AND b_s.pers_org_num IS NOT NULL
),
case_financials AS (
  -- This CTE performs the first level of aggregation (by case) and applies the balance filter.
  SELECT
    a.source_system_id,
    i.num AS fc_code,
    SUM(b.charge_amount) AS charge_amount,
    SUM(b.paid_amount) AS paid_amount
  FROM `uspidnaproddata.advantx_ods.ca_case` AS a
  -- Replaced SELECT * with explicit columns
  INNER JOIN (
    SELECT source_system_id, case_num, charge_amount, paid_amount, writtenoff_amount, procfee_num
    FROM ar_billtrans_charge_ce_temp
  ) AS b ON a.source_system_id = b.source_system_id AND a.case_num = b.case_num
  INNER JOIN `uspidnaproddata.advantx_ods.ut_proc_fee` AS d ON b.source_system_id = d.source_system_id AND b.procfee_num = d.num
  INNER JOIN `uspidnaproddata.advantx_ods.ut_proc` AS e ON d.source_system_id = e.source_system_id AND d.proc_num = e.num
  INNER JOIN latest_insurance AS g ON g.RowNum = 1 AND a.source_system_id = g.source_system_id AND a.case_num = g.case_num
  INNER JOIN `uspidnaproddata.advantx_ods.ut_insurcarrier` AS h ON g.source_system_id = h.source_system_id AND g.payor_code = h.pers_org_num
  INNER JOIN `uspidnaproddata.advantx_ods.ut_insurcarrier_tisclient` AS j ON h.source_system_id = j.source_system_id AND h.num = j.inscarr_num AND a.tisclient_num = j.tisclient_num
  INNER JOIN `uspidnaproddata.advantx_ods.ut_insurtype` AS i ON j.source_system_id = i.source_system_id AND j.insurtype_num = i.num
  WHERE
    -- PERFORMANCE: This predicate enables partition pruning, assuming key_dos is a DATETIME/DATETIME partition column.
    a.key_dos >= DATETIME(DATE_TRUNC(DATE_SUB(CURRENT_DATE(), INTERVAL 3 YEAR), YEAR))
    AND a.key_dos < DATETIME(DATE_ADD(CURRENT_DATE(), INTERVAL 1 DAY))
    AND e.quick_code NOT IN ('ERROR', 'DUMMY')
    AND a.source_system_id = V_source_system
  GROUP BY
    a.source_system_id,
    i.num,
    a.case_num
  HAVING
    SUM(b.charge_amount) - SUM(b.paid_amount) - SUM(b.writtenoff_amount) <= 10.00
)
-- Final aggregation to calculate the collection percentage.
SELECT
  source_system_id,
  fc_code,
  CASE
    WHEN SUM(charge_amount) = 0.0 THEN 0.0
    ELSE SUM(paid_amount) / SUM(charge_amount)
  END AS expected_collection_pct
FROM case_financials
GROUP BY
  source_system_id,
  fc_code;

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
