INSERT INTO expected_collection_pct_payors_ce_temp (source_system_id, payor_code, expected_collection_pct)
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
