UPDATE `thcdnadevdata.staging.query_ai_optimization_results`
SET
  optimized_sql = """WITH PatientMinDOB AS (
  SELECT
    B.source_system_id,
    CAST(B.pers_org_num_pers AS STRING) AS patient_code,
    MIN(C.dob) AS min_dob
  FROM
    `uspidnaproddata.advantx_ods.ad_pt` AS B
    INNER JOIN `uspidnaproddata.advantx_ods.co_pers` AS C ON B.source_system_id = C.source_system_id
    AND B.pers_org_num_pers = C.pers_org_num
  WHERE
    B.source_system_id = V_source_system
  GROUP BY
    1,
    2
)
MERGE MEDIBIS_FACT_CE_temp AS A
USING
  PatientMinDOB AS SRC
ON
  A.source_system_id = SRC.source_system_id
  AND A.patient_code = SRC.patient_code
  AND A.source_system_id = V_source_system
WHEN MATCHED THEN
  UPDATE
SET
  patient_age = FLOOR(DATE_DIFF(A.date_of_service, SRC.min_dob, DAY) / 365.25);""",
  updated_at = CURRENT_DATETIME("America/Chicago")
WHERE job_id = 'script_job_265e586b3ed5115f618f9e12adb3405c_35'
  AND created_at = "2026-06-02T11:41:48.802564";
