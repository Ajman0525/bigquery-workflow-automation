MERGE dim_fact_sd_temp AS a
USING (
  SELECT
    A.source_system_id,
    A.prim_sched_num,
    A.appointment_num,
    A.appt_date,
    appt_grid.num AS grid_num,
    ROW_NUMBER() OVER (
      PARTITION BY A.source_system_id, A.prim_sched_num, A.appointment_num, A.appt_date
      ORDER BY
        grid.sched_begin_time -- Adjust this to your preferred ordering column
    ) AS row_num
  FROM dim_fact_sd_temp A
  INNER JOIN advantx_ods.as_grid appt_grid
    ON CAST(A.block_code AS STRING) IS NULL
    AND A.source_system_id = appt_grid.source_system_id
    AND A.prim_sched_num = appt_grid.sched_num
    AND A.appointment_num = appt_grid.appointment_num
    AND A.appt_date = appt_grid.sched_date
  INNER JOIN advantx_ods.as_grid grid
    ON appt_grid.source_system_id = grid.source_system_id
    AND appt_grid.sched_num = grid.sched_num
    AND appt_grid.sched_date = grid.sched_date
    AND grid.blocktype_num = 2
    AND FORMAT_TIMESTAMP('%H:%M', appt_grid.sched_end_time) = FORMAT_TIMESTAMP('%H:%M', appt_grid.sched_begin_time)
  INNER JOIN advantx_ods.ut_sched sched
    ON grid.source_system_id = sched.source_system_id
    AND grid.block_phys_sched_num = sched.num
    AND A.source_system_id = sched.source_system_id
    AND A.phys_pers_org_num = sched.pers_org_num
) AS sub
ON a.source_system_id = sub.source_system_id
   AND a.prim_sched_num = sub.prim_sched_num
   AND a.appointment_num = sub.appointment_num
   AND a.appt_date = sub.appt_date
   AND sub.row_num = 1
   AND a.source_system_id = V_source_system
WHEN MATCHED THEN
  UPDATE SET
    a.block_code = CAST(sub.grid_num AS STRING)
