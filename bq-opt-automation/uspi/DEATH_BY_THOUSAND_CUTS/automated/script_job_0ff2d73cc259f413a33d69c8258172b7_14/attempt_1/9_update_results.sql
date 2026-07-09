UPDATE `thcdnadevdata.staging.query_ai_optimization_results`
SET
  optimized_sql = """WITH src_procedures AS (
  SELECT
    a.source_system_id,
    a.appointment_num,
    STRING_AGG(DISTINCT pr.quick_code, '/') AS procedure_combination
  FROM
    `uspidnaproddata.advantx_ods.dim_fact_sd_temp` AS a
  INNER JOIN
    `uspidnaproddata.advantx_ods.as_appointment_procs` AS app_pr
    ON a.source_system_id = app_pr.source_system_id
    AND a.appointment_num = app_pr.appointment_num
  INNER JOIN
    `uspidnaproddata.advantx_ods.ut_proc` AS pr
    ON app_pr.source_system_id = pr.source_system_id
    AND app_pr.proc_num = pr.num
  INNER JOIN
    `uspidnaproddata.advantx_ods.it_appointstat` AS stat
    ON pr.source_system_id = stat.source_system_id
    AND a.appointstat_num = stat.num
  WHERE
    a.source_system_id = V_source_system
    AND pr.quick_code IS NOT NULL
  GROUP BY
    1,
    2
)
UPDATE
  dim_fact_sd_temp a
SET
  a.procedure_combination = src.procedure_combination
FROM
  src_procedures AS src
WHERE
  a.source_system_id = src.source_system_id
  AND a.appointment_num = src.appointment_num;""",
  updated_at = CURRENT_DATETIME("America/Chicago")
WHERE job_id = 'script_job_0ff2d73cc259f413a33d69c8258172b7_14'
  AND created_at = "2026-06-05T06:56:18.880657";
