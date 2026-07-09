MERGE dim_fact_sd_temp AS a
USING (
  SELECT
    a.source_system_id,
    a.appointment_num,
    pr.quick_code AS procedure_code,
    UPPER(stat.description) AS appt_status,
    ROW_NUMBER() OVER (
      PARTITION BY a.source_system_id, a.appointment_num
      ORDER BY pr.quick_code, UPPER(stat.description)
    ) AS row_num
  FROM dim_fact_sd_temp a
  INNER JOIN `advantx_ods.as_appointment_procs` app_pr
    ON a.source_system_id = app_pr.source_system_id
    AND a.appointment_num = app_pr.appointment_num
    AND app_pr.order_num = 1
  INNER JOIN `advantx_ods.ut_proc` pr
    ON app_pr.source_system_id = pr.source_system_id
    AND app_pr.proc_num = pr.num
  INNER JOIN `advantx_ods.it_appointstat` stat
    ON pr.source_system_id = stat.source_system_id
    AND a.appointstat_num = stat.num
) AS src
ON a.source_system_id = src.source_system_id
AND a.appointment_num = src.appointment_num
AND src.row_num = 1
AND src.source_system_id = V_source_system
WHEN MATCHED THEN
  UPDATE SET
    a.procedure_code = src.procedure_code,
    a.appt_status = src.appt_status
