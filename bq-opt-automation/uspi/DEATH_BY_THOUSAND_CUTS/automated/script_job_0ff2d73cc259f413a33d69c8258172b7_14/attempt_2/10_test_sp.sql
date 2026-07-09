-- Job ID: script_job_0ff2d73cc259f413a33d69c8258172b7_14

-- ---------------------------------------------------------------------------
-- Test stored procedure script.
-- Creates scratch objects in thcdnadevdata.staging,
-- invokes the optimized test SP, and drops those objects at the end.
-- ---------------------------------------------------------------------------

-- ---------------------------------------------------------------------------
-- 1. Create scratch tables and optimized test stored procedure.
-- ---------------------------------------------------------------------------

-- ---------------------------------------------------------------------------
-- Test scaffolding only.
-- The tables below are created in thcdnadevdata.staging
-- as prerequisites for manually testing the optimized SP.
-- They are not part of the stored procedure definition and are dropped in
-- the cleanup block at the end of the combined test script.
-- ---------------------------------------------------------------------------

-- No prod DML targets were detected.

CREATE OR REPLACE PROCEDURE thcdnadevdata.staging.opt_csp_odsadvantxdw_fact_sd_update(IN facility_id STRING, OUT OUT_PARAM INT64)
BEGIN
--++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
-- Application:   ODS
--
-- Name:          csp_ODSAdvantxDW_FACT_SD_Update
--
-- Description:   Export medibis_fact_sd
--                                       
--  
-- Parameters:
--      TABLE_NAME  - Source table name
--      OUT_PARAM   - Out Parameter used for process Orchestration.
--
-- Invoked by:    - To be detemined.
--                
-- Copyright:     ISI
--    
-- Rev History:
--          07/31/2024 - Sripal - Created
--          07/31/2024 - Mohamed - Modified
--          06/20/2025 - Kimberly - Added UPDATE statement for procedure_combination
--          06/23/2025 - Sadichhya - Added facility_id param and SQL for dynamic table.
--          09/25/2025 - Dushyanth - Added retry logic for concurrent Issue
--          06/08/2026 - AI optimization - Modified - Added optimized queries
--++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

DECLARE
  V_PROC_NAME STRING;
DECLARE
  V_LOG_MESSAGE STRING;
DECLARE
  V_TABLE_NAME STRING;
DECLARE
  V_CURRENT_TS DATETIME;
DECLARE
  V_SQL STRING;
DECLARE
  V_source_system STRING;
 
--Retry logic variables---------
DECLARE V_LAST_EXTRACT_DT DATE;
DECLARE V_ERRORMESSAGE STRING;
DECLARE V_MYERRORMESSAGE STRING;
DECLARE V_RESULT STRING; 
declare complex_dml string;
declare complex_dml1 string;
declare complex_dml2 string;
-------------------------------
BEGIN

	SET
		V_PROC_NAME = 'csp_odsadvantxdw_fact_sd_update';
	SET
		V_LOG_MESSAGE = 'Starting Procedure - ' || V_PROC_NAME || ' - ' || CURRENT_DATETIME("America/Chicago");
	SET
		V_TABLE_NAME = 'medibis_fact_sd';
	SET
		V_CURRENT_TS = DATETIME(TIMESTAMP (CURRENT_DATETIME), "America/Chicago");
  SET
    V_source_system = facility_id;


SET V_SQL = FORMAT("""
  CREATE TEMP TABLE temp_ca_visit_visitdept AS
  SELECT * FROM uspidnaproddata.advantx_ods.ca_visit_visitdept_%s
""", V_source_system);

EXECUTE IMMEDIATE V_SQL;


   CREATE TEMP TABLE dim_fact_sd_temp (
    source_system_id string,
      company_code string,
      facility_code numeric, --changed
      patient_code numeric, ---changed
      case_number numeric,  --changed
      physician_code string,
      physician_group_code string,
      refer_physician_code string DEFAULT '-1',
      procedure_code string,
      scheduled_room string,
      anesthesia_type string,
      case_id string,
      appt_code string,
      appt_status string,
      appt_create_date datetime,
      appt_type_code string,
      appt_cancel_reason string DEFAULT 'NO REASON',
      appt_date datetime,
      prim_sched_begin_time datetime,
      prim_sched_end_time datetime,
      begin_time datetime,
      end_time datetime,
      day_of_week string,
      appt_start_time string,
      appt_end_time string,
      appt_duration int64,
      appt_sched_lag int64,
      appt_count int64 DEFAULT 1,
      appt_cancel_reason_quick_code string DEFAULT 'NO REASON',
      or_time int64,
      or_duration_diff_bucket_mins int64,
      or_duration_diff_bucket_desc string DEFAULT 'NA',
      or_duration_diff_bucket_group string DEFAULT 'NA',
      surgery_duration int64,
      duration_diff_bucket_mins int64,
      duration_diff_bucket_desc string DEFAULT 'NA',
      duration_diff_bucket_group string DEFAULT 'NA',
      account_number string,
      admission_time_lag int64 DEFAULT 0,
      dismissal_time_lag int64 DEFAULT 0,
      delayed_start_time int64 DEFAULT 0,
      block_code string,
      procedure_combination string,
      procedure_type string,
      prim_sched_num numeric,
      appointment_num numeric,
      appointstat_num numeric,
      reason_num numeric,
      primary_phys_num numeric,
      refer_phys_num numeric,
      phys_pers_org_num numeric,
      pers_org_num_pt numeric,
      tisclient_num numeric);

-- Optimized Version Job ID = script_job_0bb1f453228b4dfedd1fa2554f71e494_2 --



INSERT INTO dim_fact_sd_temp (
    source_system_id, company_code, facility_code, case_number, anesthesia_type, case_id, appt_code, appt_create_date, 
    appt_type_code, appt_date, prim_sched_begin_time, prim_sched_end_time, day_of_week, appt_start_time, appt_end_time, 
    appt_duration, appt_sched_lag, prim_sched_num, appointment_num, appointstat_num, reason_num, primary_phys_num, 
    refer_phys_num, pers_org_num_pt, tisclient_num
)
WITH prefiltered_appointments AS (
    -- Step 1: Filter ca_case and join to as_appointment first. This drastically reduces the number of rows
    -- flowing into the main join with the complex view.
    SELECT
        ca.case_num,
        ca.pers_org_num_pt,
        ca.tisclient_num,
        ca.primary_phys_num,
        ca.refer_phys_num,
        ca.source_system_id,
        app.num,
        app.enter_date,
        app.visittype_num,
        app.prim_sched_date,
        app.prim_sched_begin_time,
        app.prim_sched_end_time,
        app.prim_sched_num,
        app.appointstat_num,
        app.reason_num,
        app.anestype_num
    FROM advantx_ods.ca_case AS ca
    INNER JOIN advantx_ods.as_appointment AS app 
        ON ca.source_system_id = app.source_system_id
        AND ca.case_num = app.case_num
    WHERE ca.source_system_id = V_source_system
      AND ca.key_dos >= (
          -- This subquery is constant-folded by BigQuery but isolating it makes the logic clearer.
          SELECT DATETIME(CONCAT(CAST(EXTRACT(YEAR FROM DATE_SUB(CURRENT_DATE(), INTERVAL 365 DAY)) AS STRING), '-01-01 00:00:00'))
      )
)
SELECT
    A.source_system_id,
    A.company_code,
    A.pers_org_num_org AS facility_code,
    pa.case_num AS case_number,
    CAST(COALESCE(pa.anestype_num, 0) AS STRING) AS anesthesia_type,

    -- Step 2: Optimized complex column derivations.
    -- Replaced concatenation and RIGHT() with the more efficient and readable LPAD().
    -- Simplified redundant CAST/COALESCE patterns.
    CONCAT(
        LPAD(COALESCE(TRIM(CAST(pa.tisclient_num AS STRING)), ''), 4, '0'),
        LPAD(COALESCE(TRIM(CAST(pa.pers_org_num_pt AS STRING)), ''), 8, '0'),
        LPAD(COALESCE(TRIM(CAST(pa.case_num AS STRING)), ''), 8, '0')
    ) AS case_id,

    CAST(pa.num AS STRING) AS appt_code,
    pa.enter_date AS appt_create_date,
    CAST(pa.visittype_num AS STRING) AS appt_type_code,
    pa.prim_sched_date AS appt_date,
    pa.prim_sched_begin_time,
    pa.prim_sched_end_time,
    FORMAT_TIMESTAMP('%A', pa.prim_sched_date) AS day_of_week,
    FORMAT_TIMESTAMP('%H:%M:00', pa.prim_sched_begin_time) AS appt_start_time,
    FORMAT_TIMESTAMP('%H:%M:00', pa.prim_sched_end_time) AS appt_end_time,

    -- Replaced expensive FORMAT_TIMESTAMP and string comparison with efficient numeric extraction.
    CASE
        WHEN EXTRACT(HOUR FROM pa.prim_sched_begin_time) >= 1
             AND EXTRACT(HOUR FROM pa.prim_sched_end_time) >= 1
        THEN TIMESTAMP_DIFF(pa.prim_sched_end_time, pa.prim_sched_begin_time, MINUTE)
        ELSE 0
    END AS appt_duration,

    -- Preserved original lag calculation logic.
    DATE_DIFF(DATE(pa.prim_sched_date), DATE(pa.enter_date), DAY) + 
    CASE WHEN TIME(pa.enter_date) > TIME '12:00:00' THEN -1 ELSE 0 END AS appt_sched_lag,

    pa.prim_sched_num,
    pa.num AS appointment_num,
    pa.appointstat_num,
    pa.reason_num,
    pa.primary_phys_num,
    pa.refer_phys_num,
    pa.pers_org_num_pt,
    pa.tisclient_num
FROM uspidnaproddata.edw_advantx.vw_ad_tisclient AS A
-- Step 3: Join the view to the small, pre-filtered result set.
INNER JOIN prefiltered_appointments AS pa
    -- Preserved original join logic. The function remains but now operates on a much smaller dataset.
    ON LOWER(A.source_system_id) = pa.source_system_id 
    AND A.pers_org_num_org = pa.tisclient_num;



-- End of Optimized Version --

  MERGE dim_fact_sd_temp AS a
USING (
  SELECT
    a.source_system_id,
    a.pers_org_num_pt,
    COALESCE(pt.pers_org_num_pers, -1) AS patient_code,
    pt.account_num
  FROM dim_fact_sd_temp a
  LEFT JOIN `advantx_ods.ad_pt` pt
    ON a.source_system_id = pt.source_system_id
    AND a.pers_org_num_pt = pt.pers_org_num_pers
  -- Handling duplicates using ROW_NUMBER to pick the first occurrence
  QUALIFY ROW_NUMBER() OVER (PARTITION BY a.source_system_id, a.pers_org_num_pt ORDER BY pt.account_num) = 1
) AS src
ON a.source_system_id = src.source_system_id
AND a.pers_org_num_pt = src.pers_org_num_pt
and src.source_system_id = V_source_system
WHEN MATCHED THEN
  UPDATE SET
    a.patient_code = src.patient_code,
    a.account_number = src.account_num;

                
-- optimized query: script_job_9a43a9f26bb8ac263a6f7804c36d9f72_4                         

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
    appt_status = source.appt_status;

--end of opti for script_job_9a43a9f26bb8ac263a6f7804c36d9f72_4--


--     UPDATE dim_fact_sd_temp
-- SET    appt_cancel_reason = Upper(rsn.description),
--        appt_cancel_reason_quick_code = Upper(rsn.quick_code)
-- FROM   dim_fact_sd_temp a
--        INNER JOIN advantx_ods.ut_reason rsn
--                ON a.source_system_id = rsn.source_system_id
--                   AND a.reason_num = rsn.num;	  
MERGE dim_fact_sd_temp AS target
USING (
  SELECT
    a.source_system_id,
    a.reason_num,
    UPPER(rsn.description) AS appt_cancel_reason,
    UPPER(rsn.quick_code) AS appt_cancel_reason_quick_code,
    ROW_NUMBER() OVER (
      PARTITION BY a.source_system_id, a.reason_num
      ORDER BY rsn.description, rsn.quick_code
    ) AS row_num
  FROM dim_fact_sd_temp a
  INNER JOIN `advantx_ods.ut_reason` rsn
    ON a.source_system_id = rsn.source_system_id
    AND a.reason_num = rsn.num
) AS source
ON target.source_system_id = source.source_system_id
AND target.reason_num = source.reason_num
AND source.row_num = 1  -- Ensure only the top-ranked row is used
AND source.source_system_id = V_source_system
WHEN MATCHED THEN
  UPDATE SET
    target.appt_cancel_reason = source.appt_cancel_reason,
    target.appt_cancel_reason_quick_code = source.appt_cancel_reason_quick_code;

/*
    UPDATE dim_fact_sd_temp
SET    physician_code = phys.pers_org_num,
       phys_pers_org_num = phys.pers_org_num,
       physician_group_code = phys.pers_org_num
FROM   dim_fact_sd_temp a
       INNER JOIN advantx_ods.ut_phys phys
               ON a.source_system_id = phys.source_system_id
                  AND a.primary_phys_num = phys.num;
				  */

MERGE dim_fact_sd_temp AS target
USING (
  SELECT
    a.source_system_id,
    a.primary_phys_num,
    phys.pers_org_num,
    ROW_NUMBER() OVER (
      PARTITION BY a.source_system_id, a.primary_phys_num
      ORDER BY phys.pers_org_num
    ) AS row_num
  FROM dim_fact_sd_temp a
  INNER JOIN `advantx_ods.ut_phys` phys
    ON a.source_system_id = phys.source_system_id
    AND a.primary_phys_num = phys.num
) AS source
ON target.source_system_id = source.source_system_id
AND target.primary_phys_num = source.primary_phys_num
AND source.row_num = 1  -- Ensure only the top-ranked row is used
AND source.source_system_id = V_source_system
WHEN MATCHED THEN
  UPDATE SET
    target.physician_code = CAST(source.pers_org_num as STRING),
    target.phys_pers_org_num = source.pers_org_num ,
    target.physician_group_code = CAST(source.pers_org_num as STRING);

/*

    UPDATE dim_fact_sd_temp
SET    begin_time = D.begin_time,
       end_time = D.end_time
FROM   dim_fact_sd_temp A
       INNER JOIN advantx_ods.as_appointment B
               ON A.source_system_id = B.source_system_id
                  AND A.case_number = B.case_num
                  AND A.appointment_num = B.num
       INNER JOIN advantx_ods.ca_visit C
               ON B.source_system_id = C.source_system_id
                  AND B.case_num = C.case_num
       INNER JOIN temp_ca_visit_visitdept D
               ON C.source_system_id = D.source_system_id
                  AND C.case_num = D.case_num
                  AND C.visit_num = D.visit_num
                  AND D.visitdept_num = 3;
*/

-- Optimized Version Job ID = script_job_c1b293abc631f2432e6c62c1bb8ce992_7

CREATE TEMP TABLE source_for_update AS
WITH cteSource_for_update AS (
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
SELECT * FROM cteSource_for_update;

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
--end of optimized query
   /* 
                            
    UPDATE dim_fact_sd_temp
SET    block_code = B.num
FROM   dim_fact_sd_temp A
       INNER JOIN advantx_ods.as_grid B
               ON A.source_system_id = B.source_system_id
                  AND A.prim_sched_num = B.sched_num
                  AND B.blocktype_num = 2
                  AND A.appt_date = sched_date
                  AND ( ( Datepart(hh, A.prim_sched_begin_time) * 60 ) +
                              Datepart(mi, A.prim_sched_begin_time) BETWEEN (
                              Datepart(hh, B.sched_begin_time) * 60 ) +
                              Datepart(mi, B.sched_begin_time) AND
                                  (
                              Datepart(hh, B.sched_end_time) * 60 ) +
                              Datepart(mi, B.sched_end_time) - 1
                         OR ( Datepart(hh, A.prim_sched_end_time) * 60 ) +
                                Datepart(mi, A.prim_sched_end_time) BETWEEN (
                            Datepart(hh, B.sched_begin_time) * 60 ) +
                            Datepart(mi, B.sched_begin_time) AND
                                  (
                                Datepart(hh, B.sched_end_time) * 60 ) +
                                  Datepart(mi, B.sched_end_time)
                                  - 1 )
       INNER JOIN advantx_ods.ut_sched C
               ON A.source_system_id = C.source_system_id
                  AND A.phys_pers_org_num = C.pers_org_num
                  AND B.source_system_id = C.source_system_id
                  AND B.block_phys_sched_num = C.num; 
				  */
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
    target.block_code = CAST(source.block_code as STRING);

/*

    UPDATE dim_fact_sd_temp
SET    block_code = grid.num
FROM   dim_fact_sd_temp A
       INNER JOIN advantx_ods.as_grid appt_grid
               ON Isnumeric(a.block_code) = 0
                  AND
                  --only if the block record was not detected in the previous step
                  a.source_system_id = appt_grid.source_system_id
                  AND a.prim_sched_num = appt_grid.sched_num
                  AND a.appointment_num = appt_grid.appointment_num
                  AND appt_date = appt_grid.sched_date
       INNER JOIN advantx_ods.as_grid grid
               ON appt_grid.source_system_id = grid.source_system_id
                  AND appt_grid.sched_num = grid.sched_num
                  AND appt_grid.sched_date = grid.sched_date
                  AND grid.blocktype_num = 2
                  AND Cast(appt_grid.sched_end_time AS TIME) =
                      Cast(grid.sched_begin_time AS TIME)
       INNER JOIN advantx_ods.ut_sched sched
               ON grid.source_system_id = sched.source_system_id
                  AND grid.block_phys_sched_num = sched.num
                  AND a.source_system_id = sched.source_system_id
                  AND a.phys_pers_org_num = sched.pers_org_num; 
				  */
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
    a.block_code = CAST(sub.grid_num AS STRING);
               


/*
    UPDATE dim_fact_sd_temp
SET    block_code = CONCAT(
    '-3@',
    LPAD(CAST(tisclient_num AS STRING), 4, '0'),
    LPAD(CAST(pers_org_num_pt AS STRING), 8, '0'),
    LPAD(CAST(case_number AS STRING), 8, '0')
  ) 
WHERE  Isnumeric(block_code) = 0;
*/

UPDATE dim_fact_sd_temp
SET block_code = CONCAT(
    '-3@',
    LPAD(CAST(tisclient_num AS STRING), 4, '0'),
    LPAD(CAST(pers_org_num_pt AS STRING), 8, '0'),
    LPAD(CAST(case_number AS STRING), 8, '0')
)
WHERE NOT REGEXP_CONTAINS(block_code, r'^\d+$')
AND source_system_id = V_source_system;
/*
-- UPDATE Schedule Room
    UPDATE dim_fact_sd_temp
SET    scheduled_room = E.description
FROM   dim_fact_sd_temp a
       INNER JOIN advantx_ods.ut_sched sched
               ON a.source_system_id = sched.source_system_id
                  AND a.prim_sched_num = sched.num
       INNER JOIN advantx_ods.ut_room E
               ON sched.source_system_id = E.source_system_id
                  AND sched.room_num = E.num;
*/

MERGE dim_fact_sd_temp AS target
USING (
  SELECT
    a.source_system_id,
    sched.num AS prim_sched_num,
    E.num AS room_num,
    E.description AS scheduled_room,
    ROW_NUMBER() OVER (PARTITION BY a.source_system_id, sched.num ORDER BY E.num) AS row_num
  FROM
    dim_fact_sd_temp a
  INNER JOIN
    `advantx_ods.ut_sched` sched
  ON
    a.source_system_id = sched.source_system_id
    AND a.prim_sched_num = sched.num
  INNER JOIN
    `advantx_ods.ut_room` E
  ON
    sched.source_system_id = E.source_system_id
    AND sched.room_num = E.num
) AS source
ON
  target.source_system_id = source.source_system_id
  AND target.prim_sched_num = source.prim_sched_num
  AND source.row_num = 1
  AND source.source_system_id = V_source_system
WHEN MATCHED THEN
  UPDATE SET scheduled_room = source.scheduled_room;

        

     /*               -- Update Refer Physician Code

    UPDATE dim_fact_sd_temp
SET    refer_physician_code = refer_phys.pers_org_num
FROM   dim_fact_sd_temp a
       INNER JOIN advantx_ods.ut_phys refer_phys
               ON a.source_system_id = refer_phys.source_system_id
                  AND a.refer_phys_num = refer_phys.num;
*/


MERGE dim_fact_sd_temp AS target
USING (
  SELECT
    a.source_system_id,
    a.refer_phys_num,
    refer_phys.pers_org_num,
    ROW_NUMBER() OVER (PARTITION BY a.source_system_id, a.refer_phys_num ORDER BY refer_phys.pers_org_num) AS row_num
  FROM
    dim_fact_sd_temp a
  INNER JOIN
    `advantx_ods.ut_phys` refer_phys
  ON
    a.source_system_id = refer_phys.source_system_id
    AND a.refer_phys_num = refer_phys.num
) AS source
ON
  target.source_system_id = source.source_system_id
  AND target.refer_phys_num = source.refer_phys_num
  AND source.row_num = 1
  AND source.source_system_id = V_source_system
WHEN MATCHED THEN
  UPDATE SET target.refer_physician_code = CAST(source.pers_org_num as STRING);

        
                                                                                                                                                    
   MERGE dim_fact_sd_temp AS target
USING (
    -- Deduplicate or aggregate source data to ensure one-to-one mapping
    WITH aggregated_source AS (
        SELECT
            source_system_id,
            case_num,
            MAX(or_begin_time) AS or_begin_time,
            MAX(or_end_time) AS or_end_time,
            MAX(incision_begin_time) AS incision_begin_time,
            MAX(incision_end_time) AS incision_end_time,
            MAX(begin_date) AS begin_date,
            MAX(end_date) AS end_date,
            --MAX(appt_duration) AS appt_duration
            -- Add other columns as needed
        FROM `temp_ca_visit_visitdept`
        WHERE visitdept_num = 3
        GROUP BY source_system_id, case_num
    )
    SELECT * FROM aggregated_source
) AS source
ON target.source_system_id = source.source_system_id
   AND target.case_number = source.case_num
    AND source.source_system_id = V_source_system
WHEN MATCHED THEN
    UPDATE SET
        or_time = CASE 
            WHEN FORMAT_DATETIME('%H:%M', source.or_begin_time) >= '01:00' THEN 
                TIMESTAMP_DIFF(source.or_end_time, source.or_begin_time, MINUTE)
            ELSE 0 
        END,
        or_duration_diff_bucket_mins = CASE 
            WHEN FORMAT_DATETIME('%H:%M', source.or_begin_time) >= '01:00' 
                 AND FORMAT_DATETIME('%H:%M', source.or_end_time) >= '01:00' 
            THEN 
                target.appt_duration - TIME_DIFF(TIME(or_end_time), TIME(or_begin_time), MINUTE) 
            ELSE target.appt_duration 
            END,



        /*or_duration_diff_bucket_mins = CASE 
            WHEN FORMAT_DATETIME('%H:%M', source.or_begin_time) >= '01:00' 
                 AND FORMAT_DATETIME('%H:%M', source.or_end_time) >= '01:00' 
            THEN 
                target.appt_duration - TIMESTAMP_DIFF(
                    DATETIME_ADD(DATETIME(source.begin_date), INTERVAL EXTRACT(MINUTE FROM COALESCE(source.or_begin_time, source.or_begin_time)) MINUTE),
                    DATETIME_ADD(DATETIME(source.end_date), INTERVAL EXTRACT(MINUTE FROM COALESCE(source.or_end_time, source.or_end_time)) MINUTE),
                    MINUTE
                )
            ELSE target.appt_duration 
        END,*/

        surgery_duration = CASE 
            WHEN FORMAT_DATETIME('%H:%M', source.incision_begin_time) >= '01:00' 
                 AND FORMAT_DATETIME('%H:%M', source.incision_end_time) >= '01:00' 
                 AND FORMAT_DATETIME('%H:%M', source.or_begin_time) >= '01:00' 
                 AND FORMAT_DATETIME('%H:%M', source.or_end_time) >= '01:00'
            THEN TIME_DIFF(TIME(COALESCE(source.incision_end_time, source.or_end_time)), 
                          TIME(COALESCE(source.incision_begin_time, source.or_begin_time)), MINUTE) 
            ELSE 0 
            END,
            
        /*surgery_duration = CASE 
            WHEN FORMAT_DATETIME('%H:%M', source.incision_begin_time) >= '01:00' 
                 AND FORMAT_DATETIME('%H:%M', source.incision_end_time) >= '01:00' 
                 AND FORMAT_DATETIME('%H:%M', source.or_begin_time) >= '01:00' 
                 AND FORMAT_DATETIME('%H:%M', source.or_end_time) >= '01:00'
            THEN 
                TIMESTAMP_DIFF(
                    DATETIME_ADD(
                        DATETIME(source.begin_date), 
                        INTERVAL EXTRACT(MINUTE FROM COALESCE(source.incision_begin_time, source.or_begin_time)) MINUTE
                    ),
                    DATETIME_ADD(
                        DATETIME(source.end_date), 
                        INTERVAL EXTRACT(MINUTE FROM COALESCE(source.incision_end_time, source.or_end_time)) MINUTE
                    ),
                    MINUTE
                )
            ELSE 0 
        END,*/

        duration_diff_bucket_mins = CASE 
            WHEN FORMAT_DATETIME('%H:%M', PARSE_DATETIME('%H:%M:00', target.appt_start_time)) >= '01:00' 
                 AND FORMAT_DATETIME('%H:%M', PARSE_DATETIME('%H:%M:00', target.appt_end_time)) >= '01:00'
            THEN 
                TIMESTAMP_DIFF(
                    PARSE_DATETIME('%H:%M:00', target.appt_end_time),
                    PARSE_DATETIME('%H:%M:00', target.appt_start_time),
                    MINUTE
                ) - CASE 
                    WHEN FORMAT_DATETIME('%H:%M', source.incision_begin_time) >= '01:00' 
                         AND FORMAT_DATETIME('%H:%M', source.incision_end_time) >= '01:00' 
                         AND FORMAT_DATETIME('%H:%M', source.or_begin_time) >= '01:00' 
                         AND FORMAT_DATETIME('%H:%M', source.or_end_time) >= '01:00'
                    THEN 
                    TIME_DIFF(TIME(COALESCE(source.incision_end_time, source.or_end_time)), 
                          TIME(COALESCE(source.incision_begin_time, source.or_begin_time)), MINUTE) 
                        /*TIMESTAMP_DIFF(
                            DATETIME_ADD(
                                DATETIME(source.end_date),
                                INTERVAL EXTRACT(MINUTE FROM COALESCE(source.incision_end_time, source.or_end_time)) MINUTE
                            ),
                            DATETIME_ADD(
                                DATETIME(source.begin_date),
                                INTERVAL EXTRACT(MINUTE FROM COALESCE(source.incision_begin_time, source.or_begin_time)) MINUTE
                            ),
                            MINUTE
                        ) */
                    ELSE 0 
                END
            ELSE 0 
        END,

        delayed_start_time = CASE 
            WHEN FORMAT_DATETIME('%H:%M', source.or_begin_time) >= '01:00' 
                 AND FORMAT_DATETIME('%H:%M', PARSE_DATETIME('%H:%M:00', target.appt_start_time)) >= '01:00'
            THEN 
                COALESCE(
                    (
                        (EXTRACT(HOUR FROM source.or_begin_time) * 60) + EXTRACT(MINUTE FROM source.or_begin_time)
                    ) - (
                        (EXTRACT(HOUR FROM PARSE_DATETIME('%H:%M:00', target.appt_start_time)) * 60) + EXTRACT(MINUTE FROM PARSE_DATETIME('%H:%M:00', target.appt_start_time))
                    ),
                    0
                )
            ELSE 0 
        END;

-- MERGE dim_fact_sd_temp A
-- USING (SELECT   
--         A.source_system_id,
--         A.case_id,
--        B.procedure_combination,
--         ROW_NUMBER() OVER (PARTITION BY A.source_system_id,  A.case_id ORDER BY B.procedure_combination ) AS row_num
--         FROM dim_fact_sd_temp A INNER JOIN
--         `uspidnaproddata.edw_advantx.medibis_dim_case` B ON 
--                         A.source_system_id = B.source_system_id  
--                        WHERE A.case_id = B.case_id) SRC ON 
--                 SRC.source_system_id = A.source_system_id and
--                 SRC.case_id = A.case_id AND
--                 SRC.row_num =1
--                 AND SRC.source_system_id = V_source_system
--         WHEN MATCHED THEN 
--         UPDATE SET procedure_combination = SRC.procedure_combination ; 

-- START OPTIMIZED QUERY
MERGE dim_fact_sd_temp AS target
USING (
  -- Pre-calculate the aggregated procedure codes for relevant appointments
  SELECT
    a.source_system_id,
    a.appointment_num,
    STRING_AGG(DISTINCT pr.quick_code, '/') AS procedure_combination
  FROM
    dim_fact_sd_temp AS a
  INNER JOIN
    `uspidnaproddata.advantx_ods.as_appointment_procs` AS app_pr
    ON a.source_system_id = app_pr.source_system_id
    AND a.appointment_num = app_pr.appointment_num
  INNER JOIN
    `uspidnaproddata.advantx_ods.ut_proc` AS pr
    ON app_pr.source_system_id = pr.source_system_id
    AND app_pr.proc_num = pr.num
  INNER JOIN
    `uspidnaproddata.advantx_ods.it_appointstat` AS stat
    ON a.source_system_id = stat.source_system_id
    AND a.appointstat_num = stat.num
  WHERE
    a.source_system_id = V_source_system -- Filter applied early
    AND pr.quick_code IS NOT NULL
  GROUP BY
    a.source_system_id,
    a.appointment_num
) AS source
ON
  target.source_system_id = source.source_system_id
  AND target.appointment_num = source.appointment_num
WHEN MATCHED THEN
  UPDATE SET procedure_combination = source.procedure_combination;
-- END OPTIMIZED QUERY;



	/* =============================================================================================================================== */
    /* EXECUTING DELETE STATEMENT  */
    /* =============================================================================================================================== */
set complex_dml1 = FORMAT(""" DELETE FROM `uspidnaproddata.edw_advantx.medibis_fact_sd`  where source_system_id = '%s' and date(appt_date) >= DATETIME_SUB(CURRENT_DATE(), INTERVAL 365 DAY);""", V_source_system);  


set complex_dml2 = FORMAT("""INSERT into uspidnaproddata.edw_advantx.medibis_fact_sd   
     (select
	cast(b.oracleid as numeric) as oracleid,
  cast(a.company_code AS string)  AS company_code,
	cast(a.facility_code AS string) AS facility_code,
  cast(a.patient_code AS string)  AS patient_code,
  cast(a.case_number AS string)   AS case_number,
	a.physician_code,
	a.physician_group_code,
	a.refer_physician_code,
	a.procedure_code,
	a.scheduled_room,
	a.anesthesia_type,
	a.case_id,
	a.appt_code,
	a.appt_status,
	a.appt_create_date,
	a.appt_type_code,
	a.appt_cancel_reason,
	a.appt_date,
	a.day_of_week,
	a.appt_start_time,
	a.appt_end_time,
	a.appt_duration,
	a.appt_sched_lag,
	a.appt_count,
	a.appt_cancel_reason_quick_code,
	a.or_time,
	a.or_duration_diff_bucket_mins,
	a.or_duration_diff_bucket_desc,
	a.or_duration_diff_bucket_group,
	a.surgery_duration,
	a.duration_diff_bucket_mins,
	a.duration_diff_bucket_desc,
	a.duration_diff_bucket_group,
	a.account_number,
	a.admission_time_lag,
	a.dismissal_time_lag,
	a.delayed_start_time,
	a.block_code,
  null as row_sequence,
	a.procedure_combination,
	a.procedure_type,
  a.source_system_id,
  current_datetime("America/Chicago") as load_ts
from dim_fact_sd_temp a
left outer join uspidnaproddata.edw_advantx.company_code_xref b
on cast(a.company_code AS string) = b.company_code
and cast(a.facility_code AS string) = b.facility_code
where a.source_system_id = '%s' and date(appt_date) >= DATETIME_SUB(CURRENT_DATE(), INTERVAL 365 DAY));""", V_source_system); 

    select complex_dml1;
    select complex_dml2;

    
    CALL `uspidnaproddata.framework_metadata.execute_sql_dml` (complex_dml1, V_PROC_NAME,V_RESULT);

     if V_RESULT <> 'P' then 
      RAISE USING message = V_RESULT;
    end if;

    
    if V_RESULT <> 'P' then 
    SET V_ERRORMESSAGE = V_RESULT;
    else SET V_ERRORMESSAGE = @@error.message;
    end if;	

    CALL `uspidnaproddata.framework_metadata.execute_sql_dml` (complex_dml2, V_PROC_NAME,V_RESULT);


    if V_RESULT <> 'P' then 
      RAISE USING message = V_RESULT;
    end if;

    
    if V_RESULT <> 'P' then 
    SET V_ERRORMESSAGE = V_RESULT;
    else SET V_ERRORMESSAGE = @@error.message;
    end if;	

-----------------------------------------------------------------------------------

    SET out_param = 1;

    SELECT out_param; 

	/* =============================================================================================================================== */
	/* HANDLE EXCEPTIONS */
	/* =============================================================================================================================== */

	EXCEPTION
		WHEN ERROR THEN
			SET V_LOG_MESSAGE = 'FAILED - Procedure ' || V_PROC_NAME || ', Reason: TRANSACTION_ABORTED - ' || REPLACE(@@error.message,'\'\'','''''');
			SELECT  '%', V_LOG_MESSAGE;
			SET V_LOG_MESSAGE = 'FAILED - Procedure ' || V_PROC_NAME || ', ' || REPLACE(@@error.message,'\'\'','''''');
			SELECT  '%', V_LOG_MESSAGE;
			SET OUT_PARAM = 0;
			SELECT OUT_PARAM;
	END;
END;

-- ---------------------------------------------------------------------------
-- 2. Invoke optimized test stored procedure.
-- ---------------------------------------------------------------------------

BEGIN
  DECLARE OUT_PARAM INT64 DEFAULT NULL;
  CALL thcdnadevdata.staging.opt_csp_odsadvantxdw_fact_sd_update('scjb', OUT_PARAM);
  SELECT OUT_PARAM AS out_status;
END;

-- ---------------------------------------------------------------------------
-- 3. Cleanup scratch tables and optimized test stored procedure.
-- ---------------------------------------------------------------------------

DROP PROCEDURE IF EXISTS thcdnadevdata.staging.opt_csp_odsadvantxdw_fact_sd_update;
