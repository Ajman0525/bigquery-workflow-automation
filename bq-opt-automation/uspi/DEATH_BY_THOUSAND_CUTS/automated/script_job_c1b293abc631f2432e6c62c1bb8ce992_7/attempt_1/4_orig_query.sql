MERGE dim_fact_sd_temp AS target
USING (
  SELECT
    A.source_system_id,
    A.case_number,
    A.appointment_num,
    -- Select and rank rows to handle duplicates
    D.begin_time,
    D.end_time,
    ROW_NUMBER() OVER (
      PARTITION BY A.source_system_id, A.case_number, A.appointment_num
      ORDER BY D.begin_time, D.end_time
    ) AS row_num
  FROM dim_fact_sd_temp A
  INNER JOIN `advantx_ods.as_appointment` B
    ON A.source_system_id = B.source_system_id
    AND A.case_number = B.case_num
    AND A.appointment_num = B.num
  INNER JOIN `advantx_ods.ca_visit` C
    ON B.source_system_id = C.source_system_id
    AND B.case_num = C.case_num
  INNER JOIN `temp_ca_visit_visitdept` D
    ON C.source_system_id = D.source_system_id
    AND C.case_num = D.case_num
    AND C.visit_num = D.visit_num
    AND D.visitdept_num = 3
) AS source
ON target.source_system_id = source.source_system_id
AND target.case_number = source.case_number
AND target.appointment_num = source.appointment_num
AND source.row_num = 1  -- Ensure only the top-ranked row is used
AND source.source_system_id = V_source_system
WHEN MATCHED THEN
  UPDATE SET
    target.begin_time = source.begin_time,
    target.end_time = source.end_time
