MERGE MEDIBIS_FACT_CE_temp AS T
USING (
  -- This CTE pre-aggregates the source data efficiently.
  SELECT
    B.source_system_id,
    B.case_num,
    MIN(C.quick_code) AS quick_code
  FROM ar_billtrans_charge_ce_temp AS B
  INNER JOIN `uspidnaproddata.advantx_ods.ut_dx` AS C
    ON B.source_system_id = C.source_system_id
   AND B.dx1_num = C.num
  -- Filter is applied early to reduce data volume immediately.
  WHERE B.source_system_id = V_source_system
  GROUP BY
    B.source_system_id,
    B.case_num
) AS S
ON T.source_system_id = S.source_system_id
   AND T.case_num = S.case_num
   -- This filter on the TARGET table is preserved from the original query.
   AND T.source_system_id = V_source_system
WHEN MATCHED THEN
  UPDATE SET icd9_code = S.quick_code;
