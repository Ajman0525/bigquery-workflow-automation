CREATE TABLE IF NOT EXISTS thcdnaproddata.aci.t_ade_report2 AS
WITH
  med_admin_base AS (
    SELECT
      CAST(regexp_extract(unique_id, '[0-9]+', 1, 1) AS INT64) AS hss_id,
      CAST(regexp_extract(unique_id, '[0-9]+', 1, 2) AS INT64) AS event_id,
      CAST(regexp_extract(unique_id, '[0-9]+', 1, 3) AS INT64) AS clinical_event_id,
      fact_medications_administration_sk,
      dim_facility_sk,
      dim_patient_sk,
      dim_dosage_measuring_units_sk,
      dim_administering_personnel_sk,
      dim_administering_location_sk,
      fact_order_sk,
      begin_bag_flg,
      dosage_quantity,
      administer_ts
    FROM `thcdnaproddata.aci.ade_med_admin_tmp`
  ),
  order_base AS (
    SELECT
      CAST(regexp_extract(unique_id, '[0-9]+', 1, 1) AS INT64) AS hss_id,
      CAST(regexp_extract(unique_id, '[0-9]+', 1, 2) AS INT64) AS order_id,
      fact_order_sk,
      dim_order_sk,
      dim_order_location_sk,
      facility_cd,
      patient_account_nbr,
      template_order_flg,
      order_action_ts
    FROM `thcdnaproddata.idm.fact_order`
  )
SELECT
  med2.ADE_TYPE_SK,
  med2.ADE_NAME AS ADE_NAME,
  med2.DRUG_NAME AS DRUG_NAME,
  med2.EVENT_NAME AS EVENT_NAME,
  med2.EVENT_TYPE AS EVENT_TYPE,
  f.FACILITY_CD AS FACILITY_DISP,
  f.FACILITY_NM_AND_CD AS FACILITY_DESC,
  f.MRKT_ID AS MRKT_ID,
  f.MRKT_NM AS MRKT_NM,
  f.REGN_ID AS REGN_ID,
  f.REGN_NM AS REGN_NM,
  CAST(NULL AS STRING) AS DC_DATE_DK,
  e.DISCHARGE_DT || ' ' || DISCHARGE_TM AS DC_DT_TM,
  e.DIM_ENCOUNTER_TYPE_SK AS ENCOUNTER_SK,
  e.PATIENT_ACCOUNT_NBR AS FIN_NBR,
  p.MEDICAL_RECORD_NBR AS MRN,
  e.ADMISSION_DT || ' ' || e.ADMISSION_TM AS ADMIT_DT_TM,
  CAST(NULL AS STRING) AS EVENT_TAG,
  (
    CASE
      WHEN staging.age_formatter(datetime(md.ADMINISTER_TS), datetime(p.DATE_OF_BIRTH), 'Y') < 3
      THEN staging.age_formatter(datetime(md.ADMINISTER_TS), datetime(p.DATE_OF_BIRTH), 'M') || ' Months'
      ELSE staging.age_formatter(datetime(md.ADMINISTER_TS), datetime(p.DATE_OF_BIRTH), 'Y') || ' Years'
    END
  ) AS EVENT_AGE,
  pa.FIRST_NM || IFNULL(pa.MIDDLE_NM, ' ') || pa.LAST_NM AS attending_physician,
  FACT_MEDICATIONS_ADMINISTRATION_SK AS DRUG_ADMIN_SK,
  md.ADMINISTER_TS AS DRUG_ADMIN_DT_TM,
  FORMAT('%.*f', 2, CAST(round(md.DOSAGE_QUANTITY, 2) AS FLOAT64)) || ' ' || mu.MEASURING_UNITS AS DRUG_EVENT_TAG,
  md.DIM_ADMINISTERING_LOCATION_SK AS DRUG_ADMIN_UNIT_SK,
  (
    CASE
      WHEN (d.LOCATION_CD IS NULL OR d.LOCATION_CD = 'N/A')
      THEN stg2.NURSING_UNIT_LOCATION
      ELSE f.FACILITY_CD || '-' || d.LOCATION_CD
    END
  ) AS DRUG_ADMIN_UNIT,
  (CASE WHEN o.TEMPLATE_ORDER_FLG = 0 OR o.TEMPLATE_ORDER_FLG IS NULL THEN o.fact_order_sk END) AS PARENT_ORDER_SK,
  o.ORDER_ACTION_TS AS DRUG_ORDER_DT_TM,
  stg1.ordered_as_mnemonic AS DRUG_MNEMONIC,
  stg1.CLINICAL_DISPLAY_LINE AS DRUG_ORDER_DETAIL,
  stg.ordering_physician AS DRUG_ORDERING_MD,
  pa2.DIM_PERSONNEL_SK AS DRUG_PERSONNEL_SK,
  (
    CASE
      WHEN pa2.PERSONNEL_FULL_NAME IS NULL OR pa2.PERSONNEL_FULL_NAME = 'N/A'
      THEN stg3.PERSONNEL_FULL_NAME
      ELSE pa2.PERSONNEL_FULL_NAME
    END
  ) AS DRUG_ADMINISTRATING_RN,
  -99 AS EVENT_ADMIN_SK,
  CAST(NULL AS STRING) AS EVENT_ADMIN_DT_TM,
  CAST(NULL AS STRING) AS EVENT_EVENT_TAG,
  CAST(NULL AS STRING) AS EVENT_ADMIN_UNIT_DK,
  CAST(NULL AS STRING) AS EVENT_ADMIN_UNIT,
  CAST(NULL AS STRING) AS EVENT_PARENT_ORDER_DK,
  CAST(NULL AS STRING) AS EVENT_ORDER_DT_TM,
  CAST(NULL AS STRING) AS EVENT_MNEMONIC,
  CAST(NULL AS STRING) AS EVENT_ORDER_DETAIL,
  CAST(NULL AS STRING) AS EVENT_RESULT_DK,
  CAST(NULL AS STRING) AS EVENT_TEST_RESULT,
  CAST(NULL AS STRING) AS RESULT_VALUE,
  CAST(NULL AS STRING) AS RESULT_VALUE_IND,
  CAST(NULL AS STRING) AS EVENT_PERFORMED_DT_TM,
  CAST(NULL AS STRING) AS EVENT_PHYSICIAN_DK,
  CAST(NULL AS STRING) AS EVENT_ORDERING_MD,
  CAST(NULL AS STRING) AS EVENT_PERSONNEL_DK,
  CAST(NULL AS STRING) AS EVENT_ADMINISTRATING_RN_2, -- Renamed to avoid alias collision
  1 AS ADE_IND,
  (CASE WHEN DATE_DIFF(md.ADMINISTER_TS, p.DATE_OF_BIRTH, SECOND) / 31536000 < 18 THEN 1 ELSE 0 END) AS PEDIATRIC_PATIENT,
  md.BEGIN_BAG_FLG AS BEGIN_BAG_FLG,
  CURRENT_DATETIME('America/Chicago') AS DM_CREATE_DT_TM
FROM med_admin_base AS md
INNER JOIN order_base AS o
  ON o.fact_order_sk = md.fact_order_sk
INNER JOIN `thcdnaproddata.aci.t_ade_fact_med2` AS med2
  ON med2.DIM_ORDER_SK = o.dim_order_sk
INNER JOIN `thcdnaproddata.idm.dim_patient` AS p
  ON p.dim_patient_sk = md.dim_patient_sk
INNER JOIN `thcdnaproddata.idm.fact_encounter` AS e
  ON e.patient_account_nbr = o.patient_account_nbr
  AND e.facility_cd = o.facility_cd
INNER JOIN `thcdnaproddata.idm.dim_facility` AS f
  ON f.dim_facility_sk = md.dim_facility_sk
LEFT JOIN `thcdnaproddata.idm.dim_physician` AS pa
  ON pa.DIM_PHYSICIAN_SK = e.DIM_ATTENDING_PHYSICIAN_SK
LEFT JOIN `thcdnaproddata.idm.dim_location` AS d
  ON d.DIM_LOCATION_SK = md.DIM_ADMINISTERING_LOCATION_SK
LEFT JOIN `thcdnaproddata.idm.dim_location` AS d1
  ON d1.DIM_LOCATION_SK = o.DIM_ORDER_LOCATION_SK
LEFT JOIN `thcdnaproddata.aci.ordering_physician_stg` AS stg
  ON stg.hss_id = o.hss_id
  AND stg.order_id = o.order_id
LEFT JOIN `thcdnaproddata.idm.dim_personnel` AS pa2
  ON pa2.DIM_PERSONNEL_SK = md.DIM_ADMINISTERING_PERSONNEL_SK
LEFT JOIN `thcdnaproddata.idm.dim_measuring_units` AS mu
  ON md.DIM_DOSAGE_MEASURING_UNITS_SK = mu.DIM_MEASURING_UNITS_SK
LEFT JOIN `thcdnaproddata.aci.oredr_mnemonic_stg2` AS stg1
  ON stg1.order_hss_id = o.hss_id
  AND stg1.order_id = o.order_id
LEFT JOIN `thcdnaproddata.aci.ade_admin_nurse_unit_location` AS stg2
  ON stg2.hss_id = md.hss_id
  AND stg2.event_id = md.event_id
  AND stg2.clinical_event_id = md.clinical_event_id
LEFT JOIN `thcdnaproddata.aci.ade_admin_administering_rn` AS stg3
  ON stg3.hss_id = md.hss_id
  AND stg3.event_id = md.event_id
  AND stg3.clinical_event_id = md.clinical_event_id;
