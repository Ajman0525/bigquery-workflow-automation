/*
 Assume 'V_source_system' is a pre-declared scripting variable.
 Example: DECLARE V_source_system STRING;
 SET V_source_system = 'some_value';
*/
INSERT INTO PRIMARY_PROCEDURE_ce_temp (
  source_system_id,
  case_num,
  procfee_num,
  procedure_code,
  visittype_num,
  visit_type_code,
  bill_period_num
)
WITH
  -- Step 1: Pre-filter all source tables by the target source_system_id to reduce data volume early.
  -- This is the most critical optimization.
  filtered_billtrans_charge AS (
    SELECT case_num, procfee_num, bill_trans_num, charge_amount, visit_num, source_system_id
    FROM ar_billtrans_charge_ce_temp
    WHERE source_system_id = V_source_system
  ),
  filtered_ar_billtrans AS (
    SELECT bill_trans_num, bill_period_num, source_system_id
    FROM temp_ar_billtrans
    WHERE source_system_id = V_source_system AND active = 1
  ),
  filtered_proc AS (
    SELECT num, source_system_id, quick_code
    FROM `uspidnaproddata.advantx_ods.ut_proc`
    WHERE source_system_id = V_source_system AND quick_code = 'ERROR'
  ),
  filtered_proc_fee AS (
    SELECT num, proc_num, source_system_id
    FROM `uspidnaproddata.advantx_ods.ut_proc_fee`
    WHERE source_system_id = V_source_system
  ),
  -- Step 2: Combine the core data sources.
  base_data AS (
    SELECT
      A.bill_period_num,
      B.case_num,
      B.procfee_num,
      B.bill_trans_num,
      B.charge_amount,
      B.visit_num,
      B.source_system_id,
      D.quick_code AS procedure_code
    FROM filtered_ar_billtrans AS A
    INNER JOIN filtered_billtrans_charge AS B
      ON A.bill_trans_num = B.bill_trans_num AND A.source_system_id = B.source_system_id
    INNER JOIN filtered_proc_fee AS C
      ON B.procfee_num = C.num AND B.source_system_id = C.source_system_id
    INNER JOIN filtered_proc AS D
      ON C.proc_num = D.num AND C.source_system_id = D.source_system_id
  ),
  -- Step 3: Perform joins, apply anti-join filters, and aggregate.
  -- The redundant DISTINCT is removed as GROUP BY already ensures uniqueness of grouped fields.
  aggregated_procedures AS (
    SELECT
      S.source_system_id,
      S.case_num,
      S.procfee_num,
      S.procedure_code,
      G.num AS visittype_num,
      G.quick_code AS visit_type_code,
      MIN(S.bill_period_num) AS bill_period_num
    FROM base_data AS S
    LEFT JOIN ar_billtrans_charge_rank_ce_temp AS E
      ON S.source_system_id = E.source_system_id
      AND S.case_num = E.case_num
      AND S.bill_trans_num = E.bill_trans_num
      AND S.charge_amount = E.charge_amount
    LEFT JOIN `uspidnaproddata.advantx_ods.ca_visit` AS F
      ON S.source_system_id = F.source_system_id AND S.visit_num = F.visit_num
    LEFT JOIN `uspidnaproddata.advantx_ods.ut_visittypes` AS G
      ON F.source_system_id = G.source_system_id AND F.visittype_num = G.num
    LEFT JOIN PRIMARY_PROCEDURE_ce_temp AS H
      ON S.source_system_id = H.source_system_id AND S.case_num = H.case_num
    WHERE
      E.source_system_id IS NULL -- Anti-join condition
      AND H.source_system_id IS NULL -- Idempotency check
    GROUP BY 1, 2, 3, 4, 5, 6
  ),
  -- Step 4: Apply window function to select one procedure per case.
  ranked_procedures AS (
    SELECT
      source_system_id,
      case_num,
      procfee_num,
      procedure_code,
      visittype_num,
      visit_type_code,
      bill_period_num,
      ROW_NUMBER() OVER (PARTITION BY source_system_id, case_num ORDER BY procedure_code) AS rownumber
    FROM aggregated_procedures
  )
-- Step 5: Final selection and insertion.
SELECT
  source_system_id,
  case_num,
  procfee_num,
  procedure_code,
  visittype_num,
  visit_type_code,
  bill_period_num
FROM ranked_procedures
WHERE rownumber = 1;
