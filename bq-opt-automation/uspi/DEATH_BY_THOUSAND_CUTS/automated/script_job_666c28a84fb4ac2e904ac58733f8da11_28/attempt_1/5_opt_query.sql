WITH source_visit_types AS (
  SELECT
    source_system_id,
    case_num,
    quick_code
  FROM (
    SELECT
      apt.source_system_id,
      apt.case_num,
      vt.quick_code,
      ROW_NUMBER() OVER(PARTITION BY apt.source_system_id, apt.case_num ORDER BY vt.num ASC) as rn
    FROM
      `uspidnaproddata.advantx_ods.as_appointment` AS apt
    INNER JOIN
      `uspidnaproddata.advantx_ods.ut_visittypes` AS vt
      ON apt.source_system_id = vt.source_system_id AND apt.visittype_num = vt.num
    WHERE
      vt.active = 1
      AND apt.source_system_id = 'rswl' -- Inferred from execution graph variable V_source_system
  )
  WHERE rn = 1
)
MERGE `MEDIBIS_FACT_CE_temp` AS TGT
USING source_visit_types AS SRC
  ON TGT.source_system_id = SRC.source_system_id
 AND TGT.case_num = SRC.case_num
WHEN MATCHED AND TGT.source_system_id = 'rswl' -- Preserves original ON clause logic for the target table
THEN
  UPDATE SET TGT.visit_type_code = SRC.quick_code;
