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
      -- Optimized: Replaced subquery and string manipulation with a direct DATETIME constructor for clarity and robustness.
      AND ca.key_dos >= DATETIME(EXTRACT(YEAR FROM DATE_SUB(CURRENT_DATE(), INTERVAL 365 DAY)), 1, 1, 0, 0, 0)
)
SELECT
    A.source_system_id,
    A.company_code,
    A.pers_org_num_org AS facility_code,
    pa.case_num AS case_number,
    CAST(COALESCE(pa.anestype_num, 0) AS STRING) AS anesthesia_type,

    -- Preserved optimized complex column derivations.
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

    -- Preserved efficient numeric extraction for duration calculation.
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
-- Join the view to the small, pre-filtered result set.
INNER JOIN prefiltered_appointments AS pa
    -- Optimized: Applying LOWER to both sides makes the join case-insensitive and robust.
    -- The optimizer can treat LOWER(pa.source_system_id) as a constant, allowing for predicate pushdown into the view's scan.
    ON LOWER(A.source_system_id) = LOWER(pa.source_system_id) 
    AND A.pers_org_num_org = pa.tisclient_num
