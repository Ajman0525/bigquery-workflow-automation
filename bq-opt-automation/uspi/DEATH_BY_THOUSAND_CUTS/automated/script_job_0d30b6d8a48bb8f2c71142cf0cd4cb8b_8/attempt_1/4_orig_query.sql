MERGE dim_fact_sd_temp AS target
USING (
  SELECT
    A.source_system_id,
    A.prim_sched_num,
    A.appt_date,
    A.prim_sched_begin_time,
    A.prim_sched_end_time,
    B.num AS block_code,
    ROW_NUMBER() OVER (
      PARTITION BY A.source_system_id, A.prim_sched_num, A.appt_date, A.prim_sched_begin_time, A.prim_sched_end_time
      ORDER BY B.num
    ) AS row_num
  FROM dim_fact_sd_temp AS A
  INNER JOIN `advantx_ods.as_grid` AS B
    ON A.source_system_id = B.source_system_id
    AND A.prim_sched_num = B.sched_num
    AND B.blocktype_num = 2
    AND A.appt_date = B.sched_date
    AND (
      (
        (EXTRACT(HOUR FROM A.prim_sched_begin_time) * 60) + EXTRACT(MINUTE FROM A.prim_sched_begin_time)
      ) BETWEEN (
        (EXTRACT(HOUR FROM B.sched_begin_time) * 60) + EXTRACT(MINUTE FROM B.sched_begin_time)
      ) AND (
        (EXTRACT(HOUR FROM B.sched_end_time) * 60) + EXTRACT(MINUTE FROM B.sched_end_time) - 1
      ) 
      OR (
        (EXTRACT(HOUR FROM A.prim_sched_end_time) * 60) + EXTRACT(MINUTE FROM A.prim_sched_end_time)
      ) BETWEEN (
        (EXTRACT(HOUR FROM B.sched_begin_time) * 60) + EXTRACT(MINUTE FROM B.sched_begin_time)
      ) AND (
        (EXTRACT(HOUR FROM B.sched_end_time) * 60) + EXTRACT(MINUTE FROM B.sched_end_time) - 1
      )
    )
  INNER JOIN `advantx_ods.ut_sched` AS C
    ON A.source_system_id = C.source_system_id
    AND A.phys_pers_org_num = C.pers_org_num
    AND B.source_system_id = C.source_system_id
    AND B.block_phys_sched_num = C.num
) AS source
ON target.source_system_id = source.source_system_id
AND target.prim_sched_num = source.prim_sched_num
AND target.appt_date = source.appt_date
AND target.prim_sched_begin_time = source.prim_sched_begin_time
AND target.prim_sched_end_time = source.prim_sched_end_time
AND source.row_num = 1  -- Ensure only the top-ranked row is used
AND source.source_system_id = V_source_system
WHEN MATCHED THEN
  UPDATE SET
    target.block_code = CAST(source.block_code as STRING)
