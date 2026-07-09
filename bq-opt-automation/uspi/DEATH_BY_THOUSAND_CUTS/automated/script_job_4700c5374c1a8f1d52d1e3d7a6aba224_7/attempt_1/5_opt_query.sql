CREATE TEMP TABLE source_for_update AS
WITH
  dim_fact_filtered AS (
    SELECT
      source_system_id,
      case_number,
      appointment_num
    FROM `dim_fact_sd_temp`
    WHERE source_system_id = V_source_system
  ),
  visit_dept_filtered AS (
    SELECT
      source_system_id,
      case_num,
      visit_num,
      begin_time,
      end_time
    FROM `temp_ca_visit_visitdept`
    WHERE visitdept_num = 3
      AND source_system_id = V_source_system -- Propagated filter for early pruning
  ),
  appointments AS (
    SELECT
      source_system_id,
      case_num,
      num
    FROM `advantx_ods.as_appointment`
    WHERE source_system_id = V_source_system -- Propagated filter for early pruning
  ),
  visits AS (
    SELECT
      source_system_id,
      case_num,
      visit_num
    FROM `advantx_ods.ca_visit`
    WHERE source_system_id = V_source_system -- Propagated filter for early pruning
  )
SELECT
  A.source_system_id,
  A.case_number,
  A.appointment_num,
  D.begin_time,
  D.end_time,
  ROW_NUMBER() OVER (
    PARTITION BY
      A.source_system_id,
      A.case_number,
      A.appointment_num
    ORDER BY
      D.begin_time,
      D.end_time
  ) AS row_num
FROM dim_fact_filtered AS A
INNER JOIN appointments AS B
  ON A.source_system_id = B.source_system_id
  AND A.case_number = B.case_num
  AND A.appointment_num = B.num
INNER JOIN visits AS C
  ON B.source_system_id = C.source_system_id
  AND B.case_num = C.case_num
INNER JOIN visit_dept_filtered AS D
  ON C.source_system_id = D.source_system_id
  AND C.case_num = D.case_num
  AND C.visit_num = D.visit_num;
