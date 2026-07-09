/*
 The script variable V_source_system must be declared prior to this statement.
 Example: DECLARE V_source_system STRING DEFAULT 'rssc';
*/
MERGE `MEDIBIS_FACT_CE_temp` AS T
USING (
  SELECT
    source_system_id,
    case_num,
    new_case_status
  FROM (
    SELECT
      B.source_system_id,
      B.case_num,
      COALESCE(UPPER(C.quick_code), 'UNKNOWN') AS new_case_status,
      ROW_NUMBER() OVER (
        PARTITION BY B.source_system_id, B.case_num
        ORDER BY COALESCE(UPPER(C.quick_code), 'UNKNOWN') ASC
      ) AS rn
    FROM
      `uspidnaproddata.advantx_ods.ca_case` AS B
    INNER JOIN
      `uspidnaproddata.advantx_ods.ods_case_status` AS C
      ON B.source_system_id = C.source_system_id
      AND B.case_status = C.case_status
    WHERE
      -- Pre-filter source data to only what is relevant for the update.
      -- This is valid because the MERGE's ON clause filters the target by the same value.
      B.source_system_id = V_source_system
  )
  WHERE rn = 1
) AS S
ON T.source_system_id = S.source_system_id
   AND T.case_num = S.case_num
   -- This filter on the target table is preserved from the original ON clause for correctness.
   AND T.source_system_id = V_source_system
WHEN MATCHED THEN
  UPDATE SET T.case_status = S.new_case_status;
