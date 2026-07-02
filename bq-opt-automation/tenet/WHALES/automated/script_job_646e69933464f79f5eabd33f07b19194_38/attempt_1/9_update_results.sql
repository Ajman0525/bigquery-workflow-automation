UPDATE `thcdnadevdata.staging.query_ai_optimization_results`
SET
  optimized_sql = """CREATE TABLE IF NOT EXISTS thcdnaproddata.aci.t_ade_report2
AS
WITH
  md_base AS (
    SELECT
      regexp_extract(unique_id, '[0-9]+', 1, 1) AS hss_id,
      regexp_extract(unique_id, '[0-9]+', 1, 2) AS event_id,
      regexp_extract(unique_id, '[0-9]+', 1, 3) AS clinical_event_id,
      fact_order_sk,
      dim_patient_sk,
      dim_facility_sk,
      ADMINISTER_TS,
      DIM_ADMINISTERING_LOCATION_SK,
      DIM_ADMINISTERING_PERSONNEL_SK,
      DIM_DOSAGE_MEASURING_UNITS_SK,
      DOSAGE_QUANTITY,
      BEGIN_BAG_FLG,
      FACT_MEDICATIONS_ADMINISTRATION_SK
    FROM
      `thcdnaproddata.aci.ade_med_admin_tmp`
  ),
  o_base AS (
    SELECT
      regexp_extract(unique_id, '[0-9]+', 1, 2) AS order_id,
      regexp_extract(unique_id, '[0-9]+', 1, 1) AS hss_id,
      fact_order_sk,
      dim_order_sk,
      patient_account_nbr,
      facility_cd,
      TEMPLATE_ORDER_FLG,
      ORDER_ACTION_TS
    FROM
      `thcdnaproddata.idm.fact_order`
  ),
  stg_ordering_physician AS (
    SELECT
      CAST(hss_id AS STRING) AS hss_id,
      CAST(order_id AS STRING) AS order_id,
      ordering_physician
    FROM
      `thcdnaproddata.aci.ordering_physician_stg`
  ),
  stg1_order_mnemonic AS (
    SELECT
      CAST(order_hss_id AS STRING) AS order_hss_id,
      CAST(order_id AS STRING) AS order_id,
      ordered_as_mnemonic,
      CLINICAL_DISPLAY_LINE
    FROM
      `thcdnaproddata.aci.oredr_mnemonic_stg2`
  ),
  stg2_nurse_unit AS (
    SELECT
      CAST(hss_id AS STRING) AS hss_id,
      CAST(event_id AS STRING) AS event_id,
      CAST(clinical_event_id AS STRING) AS clinical_event_id,
      NURSING_UNIT_LOCATION
    FROM
      `thcdnaproddata.aci.ade_admin_nurse_unit_location`
  ),
  stg3_admin_rn AS (
    SELECT
      CAST(hss_id AS STRING) AS hss_id,
      CAST(event_id AS STRING) AS event_id,
      CAST(clinical_event_id AS STRING) AS clinical_event_id,
      PERSONNEL_FULL_NAME
    FROM
      `thcdnaproddata.aci.ade_admin_administering_rn`
  ),
  base_joined AS (
    SELECT
      md.ADE_TYPE_SK,
      md.ADE_NAME,
      md.DRUG_NAME,
      md.EVENT_NAME,
      md.EVENT_TYPE,
      f.FACILITY_CD AS FACILITY_DISP,
      f.FACILITY_NM_AND_CD AS FACILITY_DESC,
      f.MRKT_ID,
      f.MRKT_NM,
      f.REGN_ID,
      f.REGN_NM,
      e.DISCHARGE_DT || ' ' || e.DISCHARGE_TM AS DC_DT_TM,
      e.DIM_ENCOUNTER_TYPE_SK AS ENCOUNTER_SK,
      o.patient_account_nbr AS FIN_NBR,
      p.MEDICAL_RECORD_NBR AS MRN,
      e.ADMISSION_DT || ' ' || e.ADMISSION_TM AS ADMIT_DT_TM,
      pa.FIRST_NM || IFNULL(pa.MIDDLE_NM, ' ') || pa.LAST_NM AS attending_physician,
      mda.FACT_MEDICATIONS_ADMINISTRATION_SK AS DRUG_ADMIN_SK,
      mda.ADMINISTER_TS AS DRUG_ADMIN_DT_TM,
      FORMAT('%.*f', 2, CAST(ROUND(mda.DOSAGE_QUANTITY, 2) AS FLOAT64)) || ' ' || mu.MEASURING_UNITS AS DRUG_EVENT_TAG,
      mda.DIM_ADMINISTERING_LOCATION_SK AS DRUG_ADMIN_UNIT_SK,
      (CASE WHEN (d.LOCATION_CD IS NULL OR d.LOCATION_CD = 'N/A') THEN stg2.NURSING_UNIT_LOCATION ELSE f.FACILITY_CD || '-' || d.LOCATION_CD END) AS DRUG_ADMIN_UNIT,
      (CASE WHEN o.TEMPLATE_ORDER_FLG = 0 OR o.TEMPLATE_ORDER_FLG IS NULL THEN o.fact_order_sk END) AS PARENT_ORDER_SK,
      o.ORDER_ACTION_TS AS DRUG_ORDER_DT_TM,
      stg1.ordered_as_mnemonic AS DRUG_MNEMONIC,
      stg1.CLINICAL_DISPLAY_LINE AS DRUG_ORDER_DETAIL,
      stg.ordering_physician AS DRUG_ORDERING_MD,
      pa2.DIM_PERSONNEL_SK AS DRUG_PERSONNEL_SK,
      (CASE WHEN pa2.PERSONNEL_FULL_NAME IS NULL OR pa2.PERSONNEL_FULL_NAME = 'N/A' THEN stg3.PERSONNEL_FULL_NAME ELSE pa2.PERSONNEL_FULL_NAME END) AS DRUG_ADMINISTRATING_RN,
      (CASE WHEN DATE_DIFF(mda.ADMINISTER_TS, p.DATE_OF_BIRTH, SECOND) / 31536000 < 18 THEN 1 ELSE 0 END) AS PEDIATRIC_PATIENT,
      mda.BEGIN_BAG_FLG AS BEGIN_BAG_FLG,
      mda.ADMINISTER_TS,
      p.DATE_OF_BIRTH
    FROM md_base AS mda
    INNER JOIN o_base AS o ON o.fact_order_sk = mda.fact_order_sk
    INNER JOIN `thcdnaproddata.aci.t_ade_fact_med2` AS md ON md.DIM_ORDER_SK = o.dim_order_sk
    INNER JOIN `thcdnaproddata.idm.dim_patient` AS p ON p.dim_patient_sk = mda.dim_patient_sk
    INNER JOIN `thcdnaproddata.idm.fact_encounter` AS e ON e.patient_account_nbr = o.patient_account_nbr AND e.facility_cd = o.facility_cd
    INNER JOIN `thcdnaproddata.idm.dim_facility` AS f ON f.dim_facility_sk = mda.dim_facility_sk
    LEFT JOIN `thcdnaproddata.idm.dim_physician` AS pa ON pa.DIM_PHYSICIAN_SK = e.DIM_ATTENDING_PHYSICIAN_SK
    LEFT JOIN `thcdnaproddata.idm.dim_location` AS d ON d.DIM_LOCATION_SK = mda.DIM_ADMINISTERING_LOCATION_SK
    LEFT JOIN stg_ordering_physician AS stg ON stg.hss_id = o.hss_id AND stg.order_id = o.order_id
    LEFT JOIN `thcdnaproddata.idm.dim_personnel` AS pa2 ON pa2.DIM_PERSONNEL_SK = mda.DIM_ADMINISTERING_PERSONNEL_SK
    LEFT JOIN `thcdnaproddata.idm.dim_measuring_units` AS mu ON mda.DIM_DOSAGE_MEASURING_UNITS_SK = mu.DIM_MEASURING_UNITS_SK
    LEFT JOIN stg1_order_mnemonic AS stg1 ON stg1.order_hss_id = o.hss_id AND stg1.order_id = o.order_id
    LEFT JOIN stg2_nurse_unit AS stg2 ON stg2.hss_id = mda.hss_id AND stg2.event_id = mda.event_id AND stg2.clinical_event_id = mda.clinical_event_id
    LEFT JOIN stg3_admin_rn AS stg3 ON stg3.hss_id = mda.hss_id AND stg3.event_id = mda.event_id AND stg3.clinical_event_id = mda.clinical_event_id
  )
SELECT
  ADE_TYPE_SK,
  ADE_NAME,
  DRUG_NAME,
  EVENT_NAME,
  EVENT_TYPE,
  FACILITY_DISP,
  FACILITY_DESC,
  MRKT_ID,
  MRKT_NM,
  REGN_ID,
  REGN_NM,
  CAST(NULL AS STRING) AS DC_DATE_DK,
  DC_DT_TM,
  ENCOUNTER_SK,
  FIN_NBR,
  MRN,
  ADMIT_DT_TM,
  CAST(NULL AS STRING) AS EVENT_TAG,
  (
    CASE
      WHEN staging.age_formatter(datetime(ADMINISTER_TS), datetime(DATE_OF_BIRTH), 'Y') < 3
      THEN staging.age_formatter(datetime(ADMINISTER_TS), datetime(DATE_OF_BIRTH), 'M') || ' Months'
      ELSE staging.age_formatter(datetime(ADMINISTER_TS), datetime(DATE_OF_BIRTH), 'Y') || ' Years'
    END
  ) AS EVENT_AGE,
  attending_physician,
  DRUG_ADMIN_SK,
  DRUG_ADMIN_DT_TM,
  DRUG_EVENT_TAG,
  DRUG_ADMIN_UNIT_SK,
  DRUG_ADMIN_UNIT,
  PARENT_ORDER_SK,
  DRUG_ORDER_DT_TM,
  DRUG_MNEMONIC,
  DRUG_ORDER_DETAIL,
  DRUG_ORDERING_MD,
  DRUG_PERSONNEL_SK,
  DRUG_ADMINISTRATING_RN,
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
  CAST(NULL AS STRING) AS EVENT_ADMINISTRATING_RN,
  1 AS ADE_IND,
  PEDIATRIC_PATIENT,
  BEGIN_BAG_FLG,
  CURRENT_DATETIME('America/Chicago') AS DM_CREATE_DT_TM
FROM base_joined;""",
  updated_at = CURRENT_DATETIME("America/Chicago")
WHERE job_id = 'script_job_646e69933464f79f5eabd33f07b19194_38'
  AND created_at = "2026-06-22T05:34:11.981682";
