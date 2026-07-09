INSERT INTO PRIMARY_PROCEDURE_ce_temp (
    source_system_id,
    case_num,
    procfee_num,
    procedure_code,
    visittype_num,
    visit_type_code,
    bill_period_num
)
WITH BaseData AS (
  SELECT
    A.source_system_id,
    B.case_num,
    B.procfee_num,
    D.quick_code AS procedure_code,
    G.num AS visittype_num,
    G.quick_code AS visit_type_code,
    A.bill_period_num
  FROM temp_ar_billtrans AS A
  INNER JOIN ar_billtrans_charge_ce_temp AS B
    ON A.source_system_id = B.source_system_id
    AND A.bill_trans_num = B.bill_trans_num
  INNER JOIN `uspidnaproddata.advantx_ods.ut_proc_fee` AS C
    ON B.source_system_id = C.source_system_id
    AND B.procfee_num = C.num
  INNER JOIN `uspidnaproddata.advantx_ods.ut_proc` AS D
    ON C.source_system_id = D.source_system_id
    AND C.proc_num = D.num
  INNER JOIN ar_billtrans_charge_rank_ce_temp AS E
    ON B.source_system_id = E.source_system_id
    AND B.case_num = E.case_num
    AND B.bill_trans_num = E.bill_trans_num
    AND B.charge_amount = E.charge_amount
  LEFT JOIN `uspidnaproddata.advantx_ods.ca_visit` AS F
    ON B.source_system_id = F.source_system_id
    AND B.visit_num = F.visit_num
  LEFT JOIN `uspidnaproddata.advantx_ods.ut_visittypes` AS G
    ON F.source_system_id = G.source_system_id
    AND F.visittype_num = G.num
  WHERE
    -- CRITICAL: Filter pushed down to the earliest point.
    A.source_system_id = V_source_system
    AND A.active = 1
    AND D.quick_code = 'ERROR'
),
AggregatedData AS (
  SELECT
    source_system_id,
    case_num,
    procfee_num,
    procedure_code,
    visittype_num,
    visit_type_code,
    MIN(bill_period_num) AS bill_period_num
  FROM BaseData
  -- Anti-join to exclude cases that already exist in the target table.
  -- This logic is applied BEFORE aggregation, preserving original semantics.
  WHERE
    NOT EXISTS (
      SELECT
        1
      FROM PRIMARY_PROCEDURE_ce_temp AS H
      WHERE
        H.source_system_id = BaseData.source_system_id
        AND H.case_num = BaseData.case_num
    )
  GROUP BY
    1,
    2,
    3,
    4,
    5,
    6
),
RankedProcedures AS (
  SELECT
    source_system_id,
    case_num,
    procfee_num,
    procedure_code,
    visittype_num,
    visit_type_code,
    bill_period_num,
    ROW_NUMBER() OVER (
      PARTITION BY
        source_system_id,
        case_num
      ORDER BY
        procedure_code
    ) AS rn
  FROM AggregatedData
)
SELECT
  source_system_id,
  case_num,
  procfee_num,
  procedure_code,
  visittype_num,
  visit_type_code,
  bill_period_num
FROM RankedProcedures
WHERE
  rn = 1;
