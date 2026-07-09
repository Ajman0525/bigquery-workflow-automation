INSERT INTO dim_fact_sd_temp
            ( source_system_id,
            company_code,
             facility_code,
             case_number,
             anesthesia_type,
             case_id,
             appt_code,
             appt_create_date,
             appt_type_code,
             appt_date,
             prim_sched_begin_time,
             prim_sched_end_time,
             day_of_week,
             appt_start_time,
             appt_end_time,
             appt_duration,
             appt_sched_lag,
             prim_sched_num,
             appointment_num,
             appointstat_num,
             reason_num,
             primary_phys_num,
             refer_phys_num,
             pers_org_num_pt,
             tisclient_num)
SELECT A.source_system_id,
       A.company_code,
       A.pers_org_num_org,
       ca.case_num,
       CAST(COALESCE(app.anestype_num, 0) AS STRING) AS anesthesia_type,
      CAST(CONCAT(
           RIGHT('0000' || TRIM(CAST(COALESCE(CAST(ca.tisclient_num AS STRING), '') AS STRING)), 4),
           RIGHT('00000000' || TRIM(CAST(COALESCE(CAST(ca.pers_org_num_pt AS STRING), '') AS STRING)), 8),
           RIGHT('00000000' || TRIM(CAST(COALESCE(CAST(ca.case_num AS STRING), '') AS STRING)), 8)
       ) AS STRING) AS case_id,
        -- COALESCE(CAST(ca.case_num AS STRING),'000000') AS case_id ,     
        CAST(app.num AS STRING) AS appt_code,
       app.enter_date AS appt_create_date,
       CAST(app.visittype_num as STRING) AS appt_type_code,
       app.prim_sched_date AS appt_date,
       app.prim_sched_begin_time,
       app.prim_sched_end_time,
       FORMAT_TIMESTAMP('%A', app.prim_sched_date) AS day_of_week,
       FORMAT_TIMESTAMP('%H:%M:00', app.prim_sched_begin_time) AS appt_start_time,
       FORMAT_TIMESTAMP('%H:%M:00', app.prim_sched_end_time) AS appt_end_time,
       CASE
           WHEN FORMAT_TIMESTAMP('%H:%M', app.prim_sched_begin_time) >= '01:00'
                AND FORMAT_TIMESTAMP('%H:%M', app.prim_sched_end_time) >= '01:00'
           THEN TIMESTAMP_DIFF(app.prim_sched_end_time, app.prim_sched_begin_time, MINUTE)
           ELSE 0
       END AS appt_duration,
       DATE_DIFF(
           DATE(app.prim_sched_date), 
           DATE(app.enter_date), 
           DAY
       ) + CASE
           WHEN TIME(app.enter_date) > TIME '12:00:00' THEN -1
           ELSE 0
       END AS appt_sched_lag,
       app.prim_sched_num,
       app.num,
       app.appointstat_num,
       app.reason_num,
       ca.primary_phys_num,
       ca.refer_phys_num,
       ca.pers_org_num_pt,
       ca.tisclient_num
FROM uspidnaproddata.edw_advantx.vw_ad_tisclient A
INNER JOIN advantx_ods.ca_case ca
    ON LOWER(A.source_system_id) = ca.source_system_id
    AND A.pers_org_num_org = ca.tisclient_num
INNER JOIN advantx_ods.as_appointment app
    ON ca.source_system_id = app.source_system_id
    AND ca.case_num = app.case_num
    where ca.source_system_id = V_source_system AND CA.key_dos >= 
    (SELECT DATETIME(CONCAT(CAST(EXTRACT(YEAR FROM DATE_SUB(CURRENT_DATE(), INTERVAL 365 DAY)) AS STRING), '-01-01 00:00:00')) 
    AS datetime_three_years_ago)
