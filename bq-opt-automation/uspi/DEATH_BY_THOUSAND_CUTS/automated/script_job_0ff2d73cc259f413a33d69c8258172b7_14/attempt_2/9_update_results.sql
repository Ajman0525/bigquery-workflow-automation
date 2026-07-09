UPDATE `thcdnadevdata.staging.query_ai_optimization_results`
SET
  optimized_sql = """MERGE dim_fact_sd_temp AS target
USING (
  -- Pre-calculate the aggregated procedure codes for relevant appointments
  SELECT
    a.source_system_id,
    a.appointment_num,
    STRING_AGG(DISTINCT pr.quick_code, '/') AS procedure_combination
  FROM
    dim_fact_sd_temp AS a
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
    ON a.source_system_id = stat.source_system_id
    AND a.appointstat_num = stat.num
  WHERE
    a.source_system_id = V_source_system -- Filter applied early
    AND pr.quick_code IS NOT NULL
  GROUP BY
    a.source_system_id,
    a.appointment_num
) AS source
ON
  target.source_system_id = source.source_system_id
  AND target.appointment_num = source.appointment_num
WHEN MATCHED THEN
  UPDATE SET procedure_combination = source.procedure_combination;""",
  updated_at = CURRENT_DATETIME("America/Chicago")
WHERE job_id = 'script_job_0ff2d73cc259f413a33d69c8258172b7_14'
  AND created_at = "2026-07-09T08:17:28.436648";
