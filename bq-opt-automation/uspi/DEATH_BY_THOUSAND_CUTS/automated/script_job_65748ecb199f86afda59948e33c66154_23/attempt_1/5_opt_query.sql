/*
 Correctness & Performance Rewrite

 1.  MODIFIED: The `CAST(key_dos AS DATE)` filter is rewritten as a direct range comparison on the `key_dos` column to enable partition pruning, significantly reducing bytes scanned.
 2.  REFACTORED: The query is restructured into Common Table Expressions (CTEs) to improve readability and logical separation.
 3.  IMPROVED: The `SELECT *` is replaced with an explicit list of necessary columns.
 4.  IMPROVED: Unused columns (`copay_amt`) are removed from subqueries to reduce data movement.
 5.  UNCHANGED: All join logic, aggregation levels, and the `HAVING` clause are preserved to guarantee identical results.
*/
INSERT INTO expected_collection_pct_fc_ce_temp (source_system_id, fc_code, expected_collection_pct)
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
    -- PERFORMANCE: This predicate enables partition pruning, assuming key_dos is a TIMESTAMP/DATETIME partition column.
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
