/*
 BQ Auditor: Optimized MERGE Statement
 Original query read the target table MEDIBIS_FACT_CE_temp twice: once in the 
 source subquery and once as the MERGE target. This rewrite eliminates the 
 redundant read and join within the source subquery, as the MERGE's ON clause 
 inherently performs the necessary filtering. This reduces I/O and compute.

 NOTE: The variable `V_source_system` is assumed from the original query context.
 Replace it with the correct variable or literal value as needed.
*/
MERGE MEDIBIS_FACT_CE_temp AS TGT
USING (
  WITH RankedCodes AS (
    SELECT
      B.source_system_id,
      B.case_num,
      C.quick_code,
      ROW_NUMBER() OVER (
        PARTITION BY
          B.source_system_id,
          B.case_num
        ORDER BY
          C.quick_code ASC
      ) AS rn
    FROM
      ar_billtrans_charge_ce_temp AS B
      INNER JOIN `uspidnaproddata.advantx_ods.ut_dx` AS C ON B.source_system_id = C.source_system_id
      AND B.dx1_num_10 = C.num
    WHERE
      -- Filter early on the driving table to reduce data processed downstream.
      B.source_system_id = V_source_system
  )
  SELECT
    source_system_id,
    case_num,
    quick_code
  FROM
    RankedCodes
  WHERE
    rn = 1
) AS SRC ON TGT.source_system_id = SRC.source_system_id
AND TGT.case_num = SRC.case_num
-- The filter on the target table is still required to scope the MERGE operation.
AND TGT.source_system_id = V_source_system
WHEN MATCHED THEN
UPDATE
SET
  icd10_code = SRC.quick_code;
