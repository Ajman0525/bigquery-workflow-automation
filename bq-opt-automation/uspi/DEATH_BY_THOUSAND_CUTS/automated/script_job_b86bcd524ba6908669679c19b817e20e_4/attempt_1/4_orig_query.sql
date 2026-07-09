MERGE `dim_fact_sd_temp` AS target
USING (
  WITH
    -- Pre-join appointment procedures and procedure codes, filtering early
    Procedures AS (
      SELECT
        app_pr.source_system_id,
        app_pr.appointment_num,
        pr.quick_code
      FROM `advantx_ods.as_appointment_procs` AS app_pr
      INNER JOIN `advantx_ods.ut_proc` AS pr
        ON app_pr.source_system_id = pr.source_system_id
        AND app_pr.proc_num = pr.num
      WHERE app_pr.source_system_id = V_source_system
        AND app_pr.order_num = 1
    ),
    -- Pre-filter and prepare status descriptions
    Statuses AS (
      SELECT
        source_system_id,
        num,
        UPPER(description) AS appt_status
      FROM `advantx_ods.it_appointstat`
      WHERE source_system_id = V_source_system
    ),
    -- Combine the data, joining back to the target table to get necessary fields
    CombinedSource AS (
      SELECT
        t.source_system_id,
        t.appointment_num,
        p.quick_code AS procedure_code,
        s.appt_status,
        ROW_NUMBER() OVER (
          PARTITION BY t.source_system_id, t.appointment_num
          ORDER BY p.quick_code, s.appt_status
        ) AS row_num
      FROM `dim_fact_sd_temp` AS t
      INNER JOIN Procedures AS p
        ON t.source_system_id = p.source_system_id
        AND t.appointment_num = p.appointment_num
      INNER JOIN Statuses AS s
        ON t.source_system_id = s.source_system_id
        AND t.appointstat_num = s.num
      -- Filter is applied within the target table scan
      WHERE t.source_system_id = V_source_system
    )
  -- Select the single record per appointment to be used for the update
  SELECT
    source_system_id,
    appointment_num,
    procedure_code,
    appt_status
  FROM CombinedSource
  WHERE row_num = 1
) AS source
ON target.source_system_id = source.source_system_id
  AND target.appointment_num = source.appointment_num
WHEN MATCHED THEN
  UPDATE SET
    procedure_code = source.procedure_code,
    appt_status = source.appt_status
