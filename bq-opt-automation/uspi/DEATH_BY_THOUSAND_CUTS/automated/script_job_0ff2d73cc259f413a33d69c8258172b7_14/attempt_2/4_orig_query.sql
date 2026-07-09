UPDATE dim_fact_sd_temp a
SET a.procedure_combination = src.procedure_combination
FROM
(SELECT 
    a.source_system_id,
    a.appointment_num,
    STRING_AGG(DISTINCT procedure_code,'/') AS procedure_combination
FROM (
SELECT 
    a.source_system_id,
    a.appointment_num, app_pr.order_num,
    pr.quick_code AS procedure_code,
    UPPER(stat.description) AS appt_status
  FROM dim_fact_sd_temp a
  INNER JOIN `uspidnaproddata.advantx_ods.as_appointment_procs` app_pr
    ON a.source_system_id = app_pr.source_system_id
    AND a.appointment_num = app_pr.appointment_num
    --AND app_pr.order_num = 1 --get all procedure code
  INNER JOIN `uspidnaproddata.advantx_ods.ut_proc` pr
    ON app_pr.source_system_id = pr.source_system_id
    AND app_pr.proc_num = pr.num
  INNER JOIN `uspidnaproddata.advantx_ods.it_appointstat` stat
    ON pr.source_system_id = stat.source_system_id
    AND a.appointstat_num = stat.num
) a where procedure_code IS NOT NULL
GROUP BY 1,2
) src
WHERE a.source_system_id = src.source_system_id
AND a.appointment_num = src.appointment_num
AND src.source_system_id = V_source_system
