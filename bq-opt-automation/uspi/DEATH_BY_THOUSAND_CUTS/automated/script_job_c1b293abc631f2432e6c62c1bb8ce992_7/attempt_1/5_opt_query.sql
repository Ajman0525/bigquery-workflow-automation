WITH source_for_update AS (
  SELECT
    A.source_system_id,
    A.case_number,
    A.appointment_num,
    D.begin_time,
    D.end_time,
    ROW_NUMBER() OVER(
      PARTITION BY A.source_system_id, A.case_number, A.appointment_num
      ORDER BY D.begin_time, D.end_time
    ) AS row_num
  FROM dim_fact_sd_temp AS A
  INNER JOIN `advantx_ods.as_appointment` AS B
    ON A.source_system_id = B.source_system_id
    AND A.case_number = B.case_num
    AND A.appointment_num = B.num
  INNER JOIN `advantx_ods.ca_visit` AS C
    ON B.source_system_id = C.source_system_id
    AND B.case_num = C.case_num
  INNER JOIN `temp_ca_visit_visitdept` AS D
    ON C.source_system_id = D.source_system_id
    AND C.case_num = D.case_num
    AND C.visit_num = D.visit_num
  WHERE A.source_system_id = V_source_system
    AND D.visitdept_num = 3
)
MERGE dim_fact_sd_temp AS target
USING (
  SELECT
    source_system_id,
    case_number,
    appointment_num,
    begin_time,
    end_time
  FROM source_for_update
  WHERE row_num = 1
) AS source
ON target.source_system_id = source.source_system_id
  AND target.case_number = source.case_number
  AND target.appointment_num = source.appointment_num
WHEN MATCHED
  THEN
    UPDATE
    SET
      target.begin_time = source.begin_time,
      target.end_time = source.end_time;
