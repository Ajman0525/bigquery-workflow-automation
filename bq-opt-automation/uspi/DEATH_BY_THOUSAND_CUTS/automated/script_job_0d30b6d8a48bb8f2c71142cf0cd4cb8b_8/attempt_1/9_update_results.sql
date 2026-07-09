UPDATE `thcdnadevdata.staging.query_ai_optimization_results`
SET
  optimized_sql = """MERGE dim_fact_sd_temp AS target
USING (
  WITH
  dim_fact_sd_temp_w_minutes AS (
    SELECT
      source_system_id,
      prim_sched_num,
      appt_date,
      prim_sched_begin_time,
      prim_sched_end_time,
      phys_pers_org_num,
      TIME_DIFF(prim_sched_begin_time, TIME'00:00:00', MINUTE) AS start_minute,
      TIME_DIFF(prim_sched_end_time, TIME'00:00:00', MINUTE) AS end_minute
    FROM dim_fact_sd_temp
    WHERE source_system_id = V_source_system
  ),
  as_grid_w_minutes AS (
    SELECT
      source_system_id,
      sched_num,
      sched_date,
      num,
      block_phys_sched_num,
      TIME_DIFF(sched_begin_time, TIME'00:00:00', MINUTE) AS start_minute,
      TIME_DIFF(sched_end_time, TIME'00:00:00', MINUTE) AS end_minute
    FROM `advantx_ods.as_grid`
    WHERE blocktype_num = 2
      AND source_system_id = V_source_system
  )
  SELECT
    A.source_system_id,
    A.prim_sched_num,
    A.appt_date,
    A.prim_sched_begin_time,
    A.prim_sched_end_time,
    B.num AS block_code,
    ROW_NUMBER() OVER (
      PARTITION BY A.source_system_id, A.prim_sched_num, A.appt_date, A.prim_sched_begin_time, A.prim_sched_end_time
      ORDER BY B.num ASC
    ) AS row_num
  FROM dim_fact_sd_temp_w_minutes AS A
  INNER JOIN as_grid_w_minutes AS B
    ON A.source_system_id = B.source_system_id
    AND A.prim_sched_num = B.sched_num
    AND A.appt_date = B.sched_date
    AND (
      A.start_minute BETWEEN B.start_minute AND (B.end_minute - 1)
      OR A.end_minute BETWEEN B.start_minute AND (B.end_minute - 1)
    )
  INNER JOIN `advantx_ods.ut_sched` AS C
    ON A.source_system_id = C.source_system_id
    AND A.phys_pers_org_num = C.pers_org_num
    AND B.block_phys_sched_num = C.num
  WHERE C.source_system_id = V_source_system
) AS source
ON target.source_system_id = source.source_system_id
AND target.prim_sched_num = source.prim_sched_num
AND target.appt_date = source.appt_date
AND target.prim_sched_begin_time = source.prim_sched_begin_time
AND target.prim_sched_end_time = source.prim_sched_end_time
AND source.row_num = 1
AND source.source_system_id = V_source_system
WHEN MATCHED THEN
  UPDATE SET
    target.block_code = CAST(source.block_code AS STRING)""",
  updated_at = CURRENT_DATETIME("America/Chicago")
WHERE job_id = 'script_job_0d30b6d8a48bb8f2c71142cf0cd4cb8b_8'
  AND created_at = "2026-06-08T13:24:20.150601";
