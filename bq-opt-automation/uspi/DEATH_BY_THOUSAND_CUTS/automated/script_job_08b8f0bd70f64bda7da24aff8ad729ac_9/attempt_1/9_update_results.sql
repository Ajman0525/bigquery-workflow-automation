UPDATE `thcdnadevdata.staging.query_ai_optimization_results`
SET
  optimized_sql = """MERGE dim_fact_sd_temp AS a
USING (
  SELECT
    * EXCEPT(rn)
  FROM (
    SELECT
      A.source_system_id,
      A.prim_sched_num,
      A.appointment_num,
      A.appt_date,
      appt_grid.num AS grid_num,
      ROW_NUMBER() OVER (
        PARTITION BY A.source_system_id, A.prim_sched_num, A.appointment_num, A.appt_date
        ORDER BY grid.sched_begin_time ASC
      ) AS rn
    FROM dim_fact_sd_temp AS A
    INNER JOIN advantx_ods.as_grid AS appt_grid
      ON A.source_system_id = appt_grid.source_system_id
      AND A.prim_sched_num = appt_grid.sched_num
      AND A.appointment_num = appt_grid.appointment_num
      AND A.appt_date = appt_grid.sched_date
    INNER JOIN advantx_ods.as_grid AS grid
      ON appt_grid.source_system_id = grid.source_system_id
      AND appt_grid.sched_num = grid.sched_num
      AND appt_grid.sched_date = grid.sched_date
    INNER JOIN advantx_ods.ut_sched AS sched
      ON grid.source_system_id = sched.source_system_id
      AND grid.block_phys_sched_num = sched.num
      AND A.source_system_id = sched.source_system_id
      AND A.phys_pers_org_num = sched.pers_org_num
    WHERE
      A.block_code IS NULL
      AND grid.blocktype_num = 2
      AND TIMESTAMP_TRUNC(appt_grid.sched_end_time, MINUTE) = TIMESTAMP_TRUNC(appt_grid.sched_begin_time, MINUTE)
  )
  WHERE rn = 1
) AS sub
ON a.source_system_id = sub.source_system_id
   AND a.prim_sched_num = sub.prim_sched_num
   AND a.appointment_num = sub.appointment_num
   AND a.appt_date = sub.appt_date
   AND a.source_system_id = V_source_system
WHEN MATCHED THEN
  UPDATE SET
    a.block_code = CAST(sub.grid_num AS STRING)""",
  updated_at = CURRENT_DATETIME("America/Chicago")
WHERE job_id = 'script_job_08b8f0bd70f64bda7da24aff8ad729ac_9'
  AND created_at = "2026-05-14T17:35:16.538089";
