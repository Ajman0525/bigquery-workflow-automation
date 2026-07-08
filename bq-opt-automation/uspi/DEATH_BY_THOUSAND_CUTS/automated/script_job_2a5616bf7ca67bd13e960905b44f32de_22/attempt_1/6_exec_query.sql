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
-- TODO: Verify variable V_source_system; no prior DECLARE was found in the SP.
-- TODO: Verify temp table ar_billtrans_charge_ce_temp; no prior temp-table creation was found.
-- No stored procedure context dependencies were detected.
-- END STORED PROCEDURE CONTEXT

-- =================================================================================================
-- 2. Create the Original Temporary Table (V_TEMP_TABLE_ORIG)
-- =================================================================================================
CREATE OR REPLACE TEMP TABLE V_TEMP_TABLE_ORIG AS
SELECT		source_system_id, payor_code,
			CASE WHEN SUM(charge_amount) = 0.0 then 0.0 ELSE SUM(paid_amount)/SUM(charge_amount) END AS expected_collection_pct
			FROM
			(
			SELECT			        a.source_system_id ,g.payor_code,
							a.case_num,
							SUM(b.charge_amount) as charge_amount,
							SUM(b.paid_amount) as paid_amount,
							SUM(b.writtenoff_amount) as writtenoff_amount
                                                        --SUM(charge_amount) - SUM(paid_amount) - SUM(writtenoff_amount) as sum_amount							
		FROM	`uspidnaproddata.advantx_ods.ca_case` a
		INNER JOIN  (SELECT * FROM ar_billtrans_charge_ce_temp) b
			        on      a.source_system_id = b.source_system_id and
					a.case_num = b.case_num
		INNER JOIN `uspidnaproddata.advantx_ods.ut_proc_fee` d
			on		b.source_system_id = d.source_system_id and
					b.procfee_num = d.num
		INNER JOIN `uspidnaproddata.advantx_ods.ut_proc` e
			on		d.source_system_id = e.source_system_id and
					d.proc_num = e.num
		INNER JOIN (SELECT 
						ROW_NUMBER() OVER(PARTITION BY a_s.source_system_id, a_s.case_num ORDER BY policy_effective_date DESC) AS RowNum, 
						a_s.source_system_id, 
						a_s.case_num, 
						b_s.pers_org_num as payor_code, 
						IFNULL(copay_amt,0.00) as copay_amt
		FROM `uspidnaproddata.advantx_ods.ad_case_ps_ins`  a_s  INNER JOIN		     
		`uspidnaproddata.advantx_ods.ad_ps_rolehist_ins`  b_s 
                                                ON a_s.role_num = 6 AND
					        a_s.source_system_id = b_s.source_system_id AND
						a_s.ps_num = b_s.ps_num and 
						a_s.role_num = b_s.role_num AND
						b_s.pers_org_num IS NOT NULL ) G ON g.RowNum = 1 AND
								    a.source_system_id = g.source_system_id AND
								    a.case_num = g.case_num 
		WHERE	CAST(key_dos as DATE) BETWEEN DATE_TRUNC(DATE_SUB(CURRENT_DATE(), INTERVAL 3 YEAR), YEAR) and  CURRENT_DATE
				and e.quick_code NOT IN ('ERROR','DUMMY')
        and a.source_system_id = V_source_system
                        GROUP BY 		a.source_system_id, payor_code, a.case_num
                        HAVING			charge_amount - paid_amount - writtenoff_amount <= 10.00
			--HAVING			SUM(charge_amount) - SUM(paid_amount) - SUM(writtenoff_amount) <= 10.00
			) cases
			GROUP BY source_system_id,payor_code;

-- =================================================================================================
-- 3. Create the Optimized Temporary Table (V_TEMP_TABLE_OPT)
-- =================================================================================================
CREATE OR REPLACE TEMP TABLE V_TEMP_TABLE_OPT AS
WITH
  -- CTE to determine the most recent payor for each case, improving readability.
  PrimaryPayor AS (
    SELECT
      source_system_id,
      case_num,
      payor_code
    FROM (
      SELECT
        a_s.source_system_id,
        a_s.case_num,
        b_s.pers_org_num AS payor_code,
        ROW_NUMBER() OVER (PARTITION BY a_s.source_system_id, a_s.case_num ORDER BY a_s.policy_effective_date DESC) AS RowNum
      FROM
        `uspidnaproddata.advantx_ods.ad_case_ps_ins` AS a_s
      INNER JOIN
        `uspidnaproddata.advantx_ods.ad_ps_rolehist_ins` AS b_s
        ON a_s.source_system_id = b_s.source_system_id
        AND a_s.ps_num = b_s.ps_num
        AND a_s.role_num = b_s.role_num
      WHERE
        a_s.role_num = 6
        AND b_s.pers_org_num IS NOT NULL
    )
    WHERE
      RowNum = 1
  ),
  -- CTE for first-level aggregation. This isolates the main join and aggregation logic.
  CaseFinancials AS (
    SELECT
      a.source_system_id,
      g.payor_code,
      SUM(b.charge_amount) AS charge_amount,
      SUM(b.paid_amount) AS paid_amount
    FROM
      `uspidnaproddata.advantx_ods.ca_case` AS a
    INNER JOIN
      -- PERFORMANCE: Replaced `SELECT *` with explicit columns to reduce bytes scanned.
      (SELECT source_system_id, case_num, procfee_num, charge_amount, paid_amount, writtenoff_amount FROM ar_billtrans_charge_ce_temp) AS b
      ON a.source_system_id = b.source_system_id
      AND a.case_num = b.case_num
    INNER JOIN
      `uspidnaproddata.advantx_ods.ut_proc_fee` AS d
      ON b.source_system_id = d.source_system_id
      AND b.procfee_num = d.num
    INNER JOIN
      `uspidnaproddata.advantx_ods.ut_proc` AS e
      ON d.source_system_id = e.source_system_id
      AND d.proc_num = e.num
    INNER JOIN
      PrimaryPayor AS g
      ON a.source_system_id = g.source_system_id
      AND a.case_num = g.case_num
    WHERE
      -- RECOMMENDATION: If 'key_dos' is a TIMESTAMP/DATETIME partition key, rewrite this filter
      -- to be of the form `a.key_dos >= ... AND a.key_dos < ...` to enable partition pruning.
      CAST(a.key_dos AS DATE) BETWEEN DATE_TRUNC(DATE_SUB(CURRENT_DATE(), INTERVAL 3 YEAR), YEAR) AND CURRENT_DATE()
      AND e.quick_code NOT IN ('ERROR', 'DUMMY')
      AND a.source_system_id = V_source_system
    GROUP BY
      a.source_system_id,
      g.payor_code,
      a.case_num
    HAVING
      -- This logic is equivalent to the original query's HAVING clause.
      SUM(b.charge_amount) - SUM(b.paid_amount) - SUM(b.writtenoff_amount) <= 10.00
  )
-- Final insertion takes aggregated data and computes the collection percentage.
SELECT
  source_system_id,
  payor_code,
  CASE
    WHEN SUM(charge_amount) = 0.0 THEN 0.0
    ELSE SUM(paid_amount) / SUM(charge_amount)
  END AS expected_collection_pct
FROM
  CaseFinancials
GROUP BY
  source_system_id,
  payor_code;

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
