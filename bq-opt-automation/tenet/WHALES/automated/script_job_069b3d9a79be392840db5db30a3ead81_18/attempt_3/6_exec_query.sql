/* ================================================================================================= */
/* Script to create and validate two temporary tables. */
/* Expected Outcome: The discrepancy and duplicate detail SELECTs should return zero rows. */
/* The final SELECT statement should return two summary rows with row_count = 0, confirming that */
/* V_TEMP_TABLE_ORIG and V_TEMP_TABLE_OPT produce identical distinct results and V_TEMP_TABLE_OPT */
/* has no duplicate rows. */
/* ================================================================================================= */
/* 1. Stored Procedure Context */
/* ================================================================================================= */
/* START STORED PROCEDURE CONTEXT */
/* Auto-generated from 2_sp_details.sql and 3_orig_sp.sql. */

DECLARE freeze_time TIMESTAMP DEFAULT TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 24 HOUR);

CREATE TEMPORARY TABLE all_hs_fn_temp1
CLUSTER BY HEALTH_SYSTEM_SOURCE_ID, encntr_id AS
SELECT
  *
FROM (
  SELECT
    ENC.*,
    TRIM(substr(loc_nurse_unit_cd.DISPLAY, INSTR(loc_nurse_unit_cd.DISPLAY, '-') + 1)) AS ADMIT_NURSING_STN,
    row_number() OVER (
      PARTITION BY ENC.encntr_id, ENC.HEALTH_SYSTEM_SOURCE_ID, ENC.fac_cd
      ORDER BY ENCNTR_LOC_HIST_ID ASC, BEG_EFFECTIVE_DT_TM ASC NULLS LAST
    ) AS enc_loc_hist_wagg
  FROM (
    SELECT DISTINCT
      encntr_alias.alias AS mrn,
      encntr_alias2.alias AS pan,
      encounter.encntr_id,
      encounter.updt_dt_tm AS encounter_updt_dt_tm,
      substr(code_value.display, 1, 3) AS fac_cd,
      encounter.person_id,
      encounter.HEALTH_SYSTEM_SOURCE_ID,
      encounter.REASON_FOR_VISIT AS REASON_FOR_VISIT,
      person.NAME_FULL_FORMATTED AS patient_name,
      person.BIRTH_DT_TM AS patient_dob
    FROM thcdnaproddata.cerner_ods.cerner_encounter_hist AS encounter FOR SYSTEM_TIME AS OF freeze_time
    LEFT OUTER JOIN thcdnaproddata.cerner_ods.cerner_encntr_alias_hist AS encntr_alias FOR SYSTEM_TIME AS OF freeze_time
      ON encounter.HEALTH_SYSTEM_SOURCE_ID = encntr_alias.HEALTH_SYSTEM_SOURCE_ID
      AND encounter.ENCNTR_ID = encntr_alias.ENCNTR_ID
      AND encounter.ACTIVE_IND = 1
      AND encntr_alias.ENCNTR_ALIAS_TYPE_CD = 1079
      AND encntr_alias.ACTIVE_IND = 1
    LEFT OUTER JOIN thcdnaproddata.cerner_ods.cerner_encntr_alias_hist AS encntr_alias2 FOR SYSTEM_TIME AS OF freeze_time
      ON encounter.HEALTH_SYSTEM_SOURCE_ID = encntr_alias2.HEALTH_SYSTEM_SOURCE_ID
      AND encounter.ENCNTR_ID = encntr_alias2.ENCNTR_ID
      AND encntr_alias2.ENCNTR_ALIAS_TYPE_CD = 1077
      AND encntr_alias2.ACTIVE_IND = 1
    INNER JOIN thcdnaproddata.cerner_ods.cerner_encntr_loc_hist_hist AS encntr_loc_hist FOR SYSTEM_TIME AS OF freeze_time
      ON encounter.HEALTH_SYSTEM_SOURCE_ID = encntr_loc_hist.HEALTH_SYSTEM_SOURCE_ID
      AND encounter.ENCNTR_ID = encntr_loc_hist.ENCNTR_ID
      AND encntr_loc_hist.encntr_type_cd = 309310
    INNER JOIN thcdnaproddata.cerner_ods.cerner_code_value_hist AS code_value FOR SYSTEM_TIME AS OF freeze_time
      ON encounter.HEALTH_SYSTEM_SOURCE_ID = code_value.HEALTH_SYSTEM_SOURCE_ID
      AND encounter.LOC_FACILITY_CD = code_value.CODE_VALUE
      AND substr(code_value.display, 1, 3) IN (
        'BMC',
        'HNM',
        'VBA',
        'VBC',
        'MOD',
        'DES',
        'IND',
        'CYF',
        'HHH',
        'NFR',
        'PMC',
        'SRE',
        'SYL',
        'SRM',
        'NMC',
        'NM1',
        'DHF',
        'AHH',
        'PVA',
        'AHD',
        'MHH',
        'WVH',
        'PBA',
        'SFH',
        'BAR',
        'SCH',
        'FRM',
        'HAH',
        'LOM',
        'PLA',
        'LAK',
        'FVR',
        'MAN',
        'SVM',
        'TWI',
        'ECH',
        'CCD',
        'SIE',
        'PRV',
        'NBH',
        'NCA',
        'SLH',
        'MTB',
        'BMA',
        'DHW',
        'SPW',
        'SES',
        'NOS',
        'SMH',
        'CGH',
        'DEL',
        'WBO',
        'PBG',
        'FLO',
        'HIA',
        'GSM',
        'PGH',
        'HMD',
        'EMC',
        'FMM',
        'RHB',
        'SVH',
        'FUH',
        'WHF',
        'TES'
      )
    INNER JOIN thcdnaproddata.cerner_ods.cerner_person_hist AS person FOR SYSTEM_TIME AS OF freeze_time
      ON encounter.health_system_source_id = person.HEALTH_SYSTEM_SOURCE_ID
      AND encounter.person_id = person.PERSON_ID
      AND person.ACTIVE_IND = 1
    WHERE
      encounter.ACTIVE_IND = 1
  ) AS ENC
  LEFT JOIN thcdnaproddata.cerner_ods.cerner_encntr_loc_hist_hist AS encntr_loc_hist FOR SYSTEM_TIME AS OF freeze_time
    ON ENC.HEALTH_SYSTEM_SOURCE_ID = encntr_loc_hist.HEALTH_SYSTEM_SOURCE_ID
    AND ENC.ENCNTR_ID = encntr_loc_hist.ENCNTR_ID
    AND encntr_loc_hist.encntr_type_cd <> 309310
  LEFT JOIN thcdnaproddata.cerner_ods.cerner_code_value_hist AS loc_nurse_unit_cd FOR SYSTEM_TIME AS OF freeze_time
    ON loc_nurse_unit_cd.HEALTH_SYSTEM_SOURCE_ID = encntr_loc_hist.HEALTH_SYSTEM_SOURCE_ID
    AND loc_nurse_unit_cd.CODE_VALUE = encntr_loc_hist.LOC_NURSE_UNIT_CD
    AND loc_nurse_unit_cd.CODE_SET = 220
) AS ENC_LOC
WHERE
  ENC_LOC.enc_loc_hist_wagg = 1;

/* END STORED PROCEDURE CONTEXT */
/* ================================================================================================= */
/* 2. Create the Original Temporary Table (V_TEMP_TABLE_ORIG) */
/* ================================================================================================= */
CREATE OR REPLACE TEMPORARY TABLE V_TEMP_TABLE_ORIG AS
WITH code_value_with_groups AS (
  SELECT
    code_value.HEALTH_SYSTEM_SOURCE_ID,
    code_value.CODE_VALUE,
    code_value.display_key,
    CASE
      WHEN code_value.display_key LIKE 'DATETIMEPHYSICIANRETURNEDCALL'
      THEN 'PERFORMED_DT_TM'
      WHEN code_value.display_key IN ('MODEOFARRIVALONUNIT', 'MODEOFARRIVAL')
      THEN 'ARR_METHOD_CE'
      WHEN (
        code_value.display_key LIKE 'EDDISPOSITION'
        OR code_value.display_key LIKE '%DISPOSITIONDED'
        OR code_value.display_key LIKE '%DISPOSITIONTYPEED'
      )
      THEN 'OUTCOME_CE'
      WHEN code_value.display_key IN (
        'EDBMCDISCHARGELOCATIONS',
        'EDHNMDISCHARGELOCATIONS',
        'EDVBADISCHARGELOCATIONS',
        'EDVBCDISCHARGELOCATIONS',
        'EDMODDISCHARGELOCATIONS',
        'EDSYLDISCHARGELOCATIONS',
        'EDCYFDISCHARGELOCATIONS',
        'EDNFRDISCHARGELOCATIONS',
        'EDPMCDISCHARGELOCATIONS',
        'EDSRMDISCHARGELOCATIONS',
        'EDAHHDISCHARGELOCATIONS',
        'EDPVADISCHARGELOCATIONS',
        'EDAHDDISCHARGELOCATIONS',
        'EDMHHDISCHARGELOCATIONS',
        'EDWVHDISCHARGELOCATIONS',
        'EDPBADISCHARGELOCATIONS',
        'EDBARDISCHARGELOCATIONS',
        'EDSFHDISCHARGELOCATIONS',
        'ESCHMDISCHARGELOCATIONS',
        'EDFRMDISCHARGELOCATIONS',
        'EDHAHDISCHARGELOCATIONS',
        'EDDISCHARGED',
        'EDADMITTOBMC',
        'EDADMITTOHNM',
        'EDADMITTOVBA',
        'EDADMITTOVBC',
        'EDADMITTOMOD',
        'EDADMITTOSRE',
        'EDADMITTOCYF',
        'EDADMITTONFR',
        'EDADMITTOPMC',
        'EDADMITTOAHH',
        'EDADMITTOPVA',
        'EDADMITTOAHD',
        'EDADMITTOMHH',
        'EDADMITTOWVH',
        'EDADMITTOPBA',
        'EDADMITTOBAR',
        'EDADMITTOSFH',
        'EDADMITTOSCH',
        'EDADMITTOFRM',
        'EDADMITTOHAH',
        'EDADMITTO',
        'EDBMCEXTENDEDCARE',
        'EDHNMEXTENDEDCARE',
        'EDVBAEXTENDEDCARE',
        'EDVBCEXTENDEDCARE',
        'EDMODEXTENDEDCARE',
        'EDSREEXTENDEDCARE',
        'EDCYFEXTENDEDCARE',
        'EDNFREXTENDEDCARE',
        'EDPMCEXTENDEDCARE',
        'EDSRMEXTENDEDCARE',
        'EDAHHEXTENDEDCARE',
        'EDPVAEXTENDEDCARE',
        'EDAHDEXTENDEDCARE',
        'EDMHHEXTENDEDCARE',
        'EDWVHEXTENDEDCARE',
        'EDPBAEXTENDEDCARE',
        'EDBAREXTENDEDCARE',
        'EDSFHEXTENDEDCARE',
        'EDSCHEXTENDEDCARE',
        'EDFRMEXTENDEDCARE',
        'EDHAHEXTENDEDCARE',
        'EDBMCNURSINGHOMES',
        'EDHNMNURSINGHOMES',
        'EDVBANURSINGHOMES',
        'EDVBCNURSINGHOMES',
        'EDMODNURSINGHOMES',
        'EDSRENURSINGHOMES',
        'EDCYFNURSINGHOMES',
        'EDNFRNURSINGHOMES',
        'EDPMCNURSINGHOMES',
        'EDSRMNURSINGHOMES',
        'EDAHHNURSINGHOMES',
        'EDPVANURSINGHOMES',
        'EDAHDNURSINGHOMES',
        'EDMHHNURSINGHOMES',
        'EDWVHNURSINGHOMES',
        'EDPBANURSINGHOMES',
        'EDBARNURSINGHOMES',
        'EDSFHNURSINGHOMES',
        'EDSCHNURSINGHOMES',
        'EDFRMNURSINGHOMES',
        'EDHAHNURSINGHOMES',
        'EDBMCTRANSFER',
        'EDHNMTRANSFER',
        'EDVBATRANSFER',
        'EDVBCTRANSFER',
        'EDMODTRANSFER',
        'EDSRETRANSFER',
        'EDCYFTRANSFER',
        'EDNFRTRANSFER',
        'EDPMCTRANSFER',
        'EDSRMTRANSFER',
        'EDAHHTRANSFER',
        'EDPVATRANSFER',
        'EDAHDTRANSFER',
        'EDMHHTRANSFER',
        'EDWVHTRANSFER',
        'EDPBATRANSFER',
        'EDBARTRANSFER',
        'EDSFHTRANSFER',
        'EDSCHTRANSFER',
        'EDFRMTRANSFER',
        'EDHAHTRANSFER',
        'EDBMCNURSINGHOME',
        'EDHNMNURSINGHOME',
        'EDVBANURSINGHOME',
        'EDVBCNURSINGHOME',
        'EDMODNURSINGHOME',
        'EDSYLNURSINGHOME',
        'EDCYFNURSINGHOME',
        'EDNFRNURSINGHOME',
        'EDPMCNURSINGHOME',
        'EDSRMNURSINGHOME',
        'EDAHHNURSINGHOME',
        'EDPVANURSINGHOME',
        'EDAHDNURSINGHOME',
        'EDMHHNURSINGHOME',
        'EDWVHNURSINGHOME',
        'EDPBANURSINGHOME',
        'EDBARNURSINGHOME',
        'EDSFHNURSINGHOME',
        'EDSCHNURSINGHOME',
        'EDFRMNURSINGHOME',
        'EDHAHNURSINGHOME',
        'EDBMCTRANSFERLOCATIONS',
        'EDHNMTRANSFERLOCATIONS',
        'EDVBATRANSFERLOCATIONS',
        'EDVBCTRANSFERLOCATIONS',
        'EDMODTRANSFERLOCATIONS',
        'EDSYLTRANSFERLOCATIONS',
        'EDCYFTRANSFERLOCATIONS',
        'EDNFRTRANSFERLOCATIONS',
        'EDPMCTRANSFERLOCATIONS',
        'EDSRMTRANSFERLOCATIONS',
        'EDAHHTRANSFERLOCATIONS',
        'EDPVATRANSFERLOCATIONS',
        'EDAHDTRANSFERLOCATIONS',
        'EDMHHTRANSFERLOCATIONS',
        'EDWVHTRANSFERLOCATIONS',
        'EDPBATRANSFERLOCATIONS',
        'EDBARTRANSFERLOCATIONS',
        'EDSFHTRANSFERLOCATIONS',
        'EDSCHTRANSFERLOCATIONS',
        'EDFRMTRANSFERLOCATIONS',
        'EDHAHTRANSFERLOCATIONS',
        'EDCYFADMITTO',
        'EDCYFTRANSFERTO',
        'EDSRMADMITTO',
        'EDSRMTRANSFERTO',
        'EDMODADMITTO',
        'EDMODTRANSFERTO'
      )
      OR code_value.display_key LIKE '%ADMITTODED'
      OR code_value.display_key LIKE '%EXTENDEDCAREDED'
      OR code_value.display_key LIKE '%NURSINGHOMEDED'
      OR code_value.display_key LIKE '%TRANSFERLOCATIONSDED'
      THEN 'OUTCOME_LOC_CE'
      ELSE 'OTHER'
    END AS display_group
  FROM thcdnaproddata.cerner_ods.cerner_code_value_hist AS code_value FOR SYSTEM_TIME AS OF freeze_time
  WHERE
    code_value.CODE_SET = 72
    AND code_value.ACTIVE_IND = 1
    AND (
      code_value.display_key IN (
        'DATETIMEPHYSICIANRETURNEDCALL',
        'MODEOFARRIVALONUNIT',
        'MODEOFARRIVAL',
        'EDDISPOSITION',
        'EDBMCDISCHARGELOCATIONS',
        'EDHNMDISCHARGELOCATIONS',
        'EDVBADISCHARGELOCATIONS',
        'EDVBCDISCHARGELOCATIONS',
        'EDMODDISCHARGELOCATIONS',
        'EDSYLDISCHARGELOCATIONS',
        'EDCYFDISCHARGELOCATIONS',
        'EDNFRDISCHARGELOCATIONS',
        'EDPMCDISCHARGELOCATIONS',
        'EDSRMDISCHARGELOCATIONS',
        'EDAHHDISCHARGELOCATIONS',
        'EDPVADISCHARGELOCATIONS',
        'EDAHDDISCHARGELOCATIONS',
        'EDMHHDISCHARGELOCATIONS',
        'EDWVHDISCHARGELOCATIONS',
        'EDPBADISCHARGELOCATIONS',
        'EDBARDISCHARGELOCATIONS',
        'EDSFHDISCHARGELOCATIONS',
        'ESCHMDISCHARGELOCATIONS',
        'EDFRMDISCHARGELOCATIONS',
        'EDHAHDISCHARGELOCATIONS',
        'EDDISCHARGED',
        'EDADMITTOBMC',
        'EDADMITTOHNM',
        'EDADMITTOVBA',
        'EDADMITTOVBC',
        'EDADMITTOMOD',
        'EDADMITTOSRE',
        'EDADMITTOCYF',
        'EDADMITTONFR',
        'EDADMITTOPMC',
        'EDADMITTOAHH',
        'EDADMITTOPVA',
        'EDADMITTOAHD',
        'EDADMITTOMHH',
        'EDADMITTOWVH',
        'EDADMITTOPBA',
        'EDADMITTOBAR',
        'EDADMITTOSFH',
        'EDADMITTOSCH',
        'EDADMITTOFRM',
        'EDADMITTOHAH',
        'EDADMITTO',
        'EDBMCEXTENDEDCARE',
        'EDHNMEXTENDEDCARE',
        'EDVBAEXTENDEDCARE',
        'EDVBCEXTENDEDCARE',
        'EDMODEXTENDEDCARE',
        'EDSREEXTENDEDCARE',
        'EDCYFEXTENDEDCARE',
        'EDNFREXTENDEDCARE',
        'EDPMCEXTENDEDCARE',
        'EDSRMEXTENDEDCARE',
        'EDAHHEXTENDEDCARE',
        'EDPVAEXTENDEDCARE',
        'EDAHDEXTENDEDCARE',
        'EDMHHEXTENDEDCARE',
        'EDWVHEXTENDEDCARE',
        'EDPBAEXTENDEDCARE',
        'EDBAREXTENDEDCARE',
        'EDSFHEXTENDEDCARE',
        'EDSCHEXTENDEDCARE',
        'EDFRMEXTENDEDCARE',
        'EDHAHEXTENDEDCARE',
        'EDBMCNURSINGHOMES',
        'EDHNMNURSINGHOMES',
        'EDVBANURSINGHOMES',
        'EDVBCNURSINGHOMES',
        'EDMODNURSINGHOMES',
        'EDSRENURSINGHOMES',
        'EDCYFNURSINGHOMES',
        'EDNFRNURSINGHOMES',
        'EDPMCNURSINGHOMES',
        'EDSRMNURSINGHOMES',
        'EDAHHNURSINGHOMES',
        'EDPVANURSINGHOMES',
        'EDAHDNURSINGHOMES',
        'EDMHHNURSINGHOMES',
        'EDWVHNURSINGHOMES',
        'EDPBANURSINGHOMES',
        'EDBARNURSINGHOMES',
        'EDSFHNURSINGHOMES',
        'EDSCHNURSINGHOMES',
        'EDFRMNURSINGHOMES',
        'EDHAHNURSINGHOMES',
        'EDBMCTRANSFER',
        'EDHNMTRANSFER',
        'EDVBATRANSFER',
        'EDVBCTRANSFER',
        'EDMODTRANSFER',
        'EDSRETRANSFER',
        'EDCYFTRANSFER',
        'EDNFRTRANSFER',
        'EDPMCTRANSFER',
        'EDSRMTRANSFER',
        'EDAHHTRANSFER',
        'EDPVATRANSFER',
        'EDAHDTRANSFER',
        'EDMHHTRANSFER',
        'EDWVHTRANSFER',
        'EDPBATRANSFER',
        'EDBARTRANSFER',
        'EDSFHTRANSFER',
        'EDSCHTRANSFER',
        'EDFRMTRANSFER',
        'EDHAHTRANSFER',
        'EDBMCNURSINGHOME',
        'EDHNMNURSINGHOME',
        'EDVBANURSINGHOME',
        'EDVBCNURSINGHOME',
        'EDMODNURSINGHOME',
        'EDSYLNURSINGHOME',
        'EDCYFNURSINGHOME',
        'EDNFRNURSINGHOME',
        'EDPMCNURSINGHOME',
        'EDSRMNURSINGHOME',
        'EDAHHNURSINGHOME',
        'EDPVANURSINGHOME',
        'EDAHDNURSINGHOME',
        'EDMHHNURSINGHOME',
        'EDWVHNURSINGHOME',
        'EDPBANURSINGHOME',
        'EDBARNURSINGHOME',
        'EDSFHNURSINGHOME',
        'EDSCHNURSINGHOME',
        'EDFRMNURSINGHOME',
        'EDHAHNURSINGHOME',
        'EDBMCTRANSFERLOCATIONS',
        'EDHNMTRANSFERLOCATIONS',
        'EDVBATRANSFERLOCATIONS',
        'EDVBCTRANSFERLOCATIONS',
        'EDMODTRANSFERLOCATIONS',
        'EDSYLTRANSFERLOCATIONS',
        'EDCYFTRANSFERLOCATIONS',
        'EDNFRTRANSFERLOCATIONS',
        'EDPMCTRANSFERLOCATIONS',
        'EDSRMTRANSFERLOCATIONS',
        'EDAHHTRANSFERLOCATIONS',
        'EDPVATRANSFERLOCATIONS',
        'EDAHDTRANSFERLOCATIONS',
        'EDMHHTRANSFERLOCATIONS',
        'EDWVHTRANSFERLOCATIONS',
        'EDPBATRANSFERLOCATIONS',
        'EDBARTRANSFERLOCATIONS',
        'EDSFHTRANSFERLOCATIONS',
        'EDSCHTRANSFERLOCATIONS',
        'EDFRMTRANSFERLOCATIONS',
        'EDHAHTRANSFERLOCATIONS',
        'EDCYFADMITTO',
        'EDCYFTRANSFERTO',
        'EDSRMADMITTO',
        'EDSRMTRANSFERTO',
        'EDMODADMITTO',
        'EDMODTRANSFERTO'
      )
      OR code_value.display_key LIKE '%ADMITTODED'
      OR code_value.display_key LIKE '%EXTENDEDCAREDED'
      OR code_value.display_key LIKE '%NURSINGHOMEDED'
      OR code_value.display_key LIKE '%TRANSFERLOCATIONSDED'
      OR code_value.display_key LIKE '%DISPOSITIONDED'
      OR code_value.display_key LIKE '%DISPOSITIONTYPEED'
    )
), filtered_events AS (
  SELECT
    ce.HEALTH_SYSTEM_SOURCE_ID,
    ce.ENCNTR_ID,
    ce.PERFORMED_DT_TM,
    ce.PERFORMED_PRSNL_ID,
    ce.RESULT_VAL,
    cvg.display_group,
    ROW_NUMBER() OVER (
      PARTITION BY ce.ENCNTR_ID, ce.HEALTH_SYSTEM_SOURCE_ID, cvg.display_group
      ORDER BY ce.event_id ASC NULLS LAST, ce.clinical_event_id DESC
    ) AS rn
  FROM thcdnaproddata.cerner_ods.cerner_clinical_event_hist AS ce FOR SYSTEM_TIME AS OF freeze_time
  LEFT JOIN code_value_with_groups AS cvg
    ON ce.EVENT_CD = cvg.CODE_VALUE
    AND ce.HEALTH_SYSTEM_SOURCE_ID = cvg.HEALTH_SYSTEM_SOURCE_ID
), final_events AS (
  SELECT
    *
  FROM filtered_events
  WHERE
    rn = 1
)
SELECT
  foo.health_system_source_id,
  foo.mrn,
  foo.pan,
  foo.encntr_id,
  foo.fac_cd,
  foo.person_id,
  foo.patient_name,
  foo.patient_dob,
  foo.encounter_updt_dt_tm,
  foo.ADMIT_NURSING_STN,
  foo.REASON_FOR_VISIT,
  MAX(
    CASE WHEN fe.display_group = 'PERFORMED_DT_TM' THEN fe.PERFORMED_DT_TM ELSE NULL END
  ) AS PERFORMED_DT_TM,
  MAX(
    CASE
      WHEN fe.display_group = 'PERFORMED_DT_TM'
      THEN p1.NAME_FULL_FORMATTED
      ELSE NULL
    END
  ) AS CHARTED_PHYS_ON_CALL_NM,
  MAX(CASE WHEN fe.display_group = 'ARR_METHOD_CE' THEN fe.result_val ELSE NULL END) AS ARR_METHOD,
  MAX(CASE WHEN fe.display_group = 'OUTCOME_CE' THEN fe.result_val ELSE NULL END) AS OUTCOME,
  MAX(CASE WHEN fe.display_group = 'OUTCOME_LOC_CE' THEN fe.result_val ELSE NULL END) AS OUTCOME_LOCATION
FROM all_hs_fn_temp1 AS foo
INNER JOIN final_events AS fe
  ON foo.encntr_id = fe.ENCNTR_ID
  AND foo.HEALTH_SYSTEM_SOURCE_ID = fe.HEALTH_SYSTEM_SOURCE_ID
LEFT OUTER JOIN thcdnaproddata.cerner_ods.cerner_prsnl_hist AS p1 FOR SYSTEM_TIME AS OF freeze_time
  ON fe.PERFORMED_PRSNL_ID = p1.PERSON_ID
  AND fe.HEALTH_SYSTEM_SOURCE_ID = p1.HEALTH_SYSTEM_SOURCE_ID
GROUP BY
  1,
  2,
  3,
  4,
  5,
  6,
  7,
  8,
  9,
  10,
  11;

/* ================================================================================================= */
/* 3. Create the Optimized Temporary Table (V_TEMP_TABLE_OPT) */
/* ================================================================================================= */
CREATE OR REPLACE TEMPORARY TABLE V_TEMP_TABLE_OPT AS
WITH code_value_with_groups AS (
  /* This CTE is efficient, but the ELSE 'OTHER' is unreachable due to the WHERE clause. */
  /* Removing it for clarity; any row passing the WHERE clause must match a WHEN condition. */
  SELECT
    code_value.HEALTH_SYSTEM_SOURCE_ID,
    code_value.CODE_VALUE,
    code_value.display_key,
    CASE
      WHEN code_value.display_key LIKE 'DATETIMEPHYSICIANRETURNEDCALL'
      THEN 'PERFORMED_DT_TM'
      WHEN code_value.display_key IN ('MODEOFARRIVALONUNIT', 'MODEOFARRIVAL')
      THEN 'ARR_METHOD_CE'
      WHEN (
        code_value.display_key LIKE 'EDDISPOSITION'
        OR code_value.display_key LIKE '%DISPOSITIONDED'
        OR code_value.display_key LIKE '%DISPOSITIONTYPEED'
      )
      THEN 'OUTCOME_CE'
      WHEN code_value.display_key IN (
        'EDBMCDISCHARGELOCATIONS',
        'EDHNMDISCHARGELOCATIONS',
        'EDVBADISCHARGELOCATIONS',
        'EDVBCDISCHARGELOCATIONS',
        'EDMODDISCHARGELOCATIONS',
        'EDSYLDISCHARGELOCATIONS',
        'EDCYFDISCHARGELOCATIONS',
        'EDNFRDISCHARGELOCATIONS',
        'EDPMCDISCHARGELOCATIONS',
        'EDSRMDISCHARGELOCATIONS',
        'EDAHHDISCHARGELOCATIONS',
        'EDPVADISCHARGELOCATIONS',
        'EDAHDDISCHARGELOCATIONS',
        'EDMHHDISCHARGELOCATIONS',
        'EDWVHDISCHARGELOCATIONS',
        'EDPBADISCHARGELOCATIONS',
        'EDBARDISCHARGELOCATIONS',
        'EDSFHDISCHARGELOCATIONS',
        'ESCHMDISCHARGELOCATIONS',
        'EDFRMDISCHARGELOCATIONS',
        'EDHAHDISCHARGELOCATIONS',
        'EDDISCHARGED',
        'EDADMITTOBMC',
        'EDADMITTOHNM',
        'EDADMITTOVBA',
        'EDADMITTOVBC',
        'EDADMITTOMOD',
        'EDADMITTOSRE',
        'EDADMITTOCYF',
        'EDADMITTONFR',
        'EDADMITTOPMC',
        'EDADMITTOAHH',
        'EDADMITTOPVA',
        'EDADMITTOAHD',
        'EDADMITTOMHH',
        'EDADMITTOWVH',
        'EDADMITTOPBA',
        'EDADMITTOBAR',
        'EDADMITTOSFH',
        'EDADMITTOSCH',
        'EDADMITTOFRM',
        'EDADMITTOHAH',
        'EDADMITTO',
        'EDBMCEXTENDEDCARE',
        'EDHNMEXTENDEDCARE',
        'EDVBAEXTENDEDCARE',
        'EDVBCEXTENDEDCARE',
        'EDMODEXTENDEDCARE',
        'EDSREEXTENDEDCARE',
        'EDCYFEXTENDEDCARE',
        'EDNFREEXTENDEDCARE',
        'EDPMCEXTENDEDCARE',
        'EDSRMEXTENDEDCARE',
        'EDAHHEXTENDEDCARE',
        'EDPVAEXTENDEDCARE',
        'EDAHDEXTENDEDCARE',
        'EDMHHEXTENDEDCARE',
        'EDWVHEXTENDEDCARE',
        'EDPBAEXTENDEDCARE',
        'EDBAREXTENDEDCARE',
        'EDSFHEXTENDEDCARE',
        'EDSCHEXTENDEDCARE',
        'EDFRMEXTENDEDCARE',
        'EDHAHEXTENDEDCARE',
        'EDBMCNURSINGHOMES',
        'EDHNMNURSINGHOMES',
        'EDVBANURSINGHOMES',
        'EDVBCNURSINGHOMES',
        'EDMODNURSINGHOMES',
        'EDSRENURSINGHOMES',
        'EDCYFNURSINGHOMES',
        'EDNFRNURSINGHOMES',
        'EDPMCNURSINGHOMES',
        'EDSRMNURSINGHOMES',
        'EDAHHNURSINGHOMES',
        'EDPVANURSINGHOMES',
        'EDAHDNURSINGHOMES',
        'EDMHHNURSINGHOMES',
        'EDWVHNURSINGHOMES',
        'EDPBANURSINGHOMES',
        'EDBARNURSINGHOMES',
        'EDSFHNURSINGHOMES',
        'EDSCHNURSINGHOMES',
        'EDFRMNURSINGHOMES',
        'EDHAHNURSINGHOMES',
        'EDBMCTRANSFER',
        'EDHNMTRANSFER',
        'EDVBATRANSFER',
        'EDVBCTRANSFER',
        'EDMODTRANSFER',
        'EDSRETRANSFER',
        'EDCYFTRANSFER',
        'EDNFRTRANSFER',
        'EDPMCTRANSFER',
        'EDSRMTRANSFER',
        'EDAHHTRANSFER',
        'EDPVATRANSFER',
        'EDAHDTRANSFER',
        'EDMHHTRANSFER',
        'EDWVHTRANSFER',
        'EDPBATRANSFER',
        'EDBARTRANSFER',
        'EDSFHTRANSFER',
        'EDSCHTRANSFER',
        'EDFRMTRANSFER',
        'EDHAHTRANSFER',
        'EDBMCNURSINGHOME',
        'EDHNMNURSINGHOME',
        'EDVBANURSINGHOME',
        'EDVBCNURSINGHOME',
        'EDMODNURSINGHOME',
        'EDSYLNURSINGHOME',
        'EDCYFNURSINGHOME',
        'EDNFRNURSINGHOME',
        'EDPMCNURSINGHOME',
        'EDSRMNURSINGHOME',
        'EDAHHNURSINGHOME',
        'EDPVANURSINGHOME',
        'EDAHDNURSINGHOME',
        'EDMHHNURSINGHOME',
        'EDWVHNURSINGHOME',
        'EDPBANURSINGHOME',
        'EDBARNURSINGHOME',
        'EDSFHNURSINGHOME',
        'EDSCHNURSINGHOME',
        'EDFRMNURSINGHOME',
        'EDHAHNURSINGHOME',
        'EDBMCTRANSFERLOCATIONS',
        'EDHNMTRANSFERLOCATIONS',
        'EDVBATRANSFERLOCATIONS',
        'EDVBCTRANSFERLOCATIONS',
        'EDMODTRANSFERLOCATIONS',
        'EDSYLTRANSFERLOCATIONS',
        'EDCYFTRANSFERLOCATIONS',
        'EDNFRTRANSFERLOCATIONS',
        'EDPMCTRANSFERLOCATIONS',
        'EDSRMTRANSFERLOCATIONS',
        'EDAHHTRANSFERLOCATIONS',
        'EDPVATRANSFERLOCATIONS',
        'EDAHDTRANSFERLOCATIONS',
        'EDMHHTRANSFERLOCATIONS',
        'EDWVHTRANSFERLOCATIONS',
        'EDPBATRANSFERLOCATIONS',
        'EDBARTRANSFERLOCATIONS',
        'EDSFHTRANSFERLOCATIONS',
        'EDSCHTRANSFERLOCATIONS',
        'EDFRMTRANSFERLOCATIONS',
        'EDHAHTRANSFERLOCATIONS',
        'EDCYFADMITTO',
        'EDCYFTRANSFERTO',
        'EDSRMADMITTO',
        'EDSRMTRANSFERTO',
        'EDMODADMITTO',
        'EDMODTRANSFERTO'
      )
      OR code_value.display_key LIKE '%ADMITTODED'
      OR code_value.display_key LIKE '%EXTENDEDCAREDED'
      OR code_value.display_key LIKE '%NURSINGHOMEDED'
      OR code_value.display_key LIKE '%TRANSFERLOCATIONSDED'
      THEN 'OUTCOME_LOC_CE'
    END AS display_group
  FROM thcdnaproddata.cerner_ods.cerner_code_value_hist AS code_value FOR SYSTEM_TIME AS OF freeze_time
  WHERE
    code_value.CODE_SET = 72
    AND code_value.ACTIVE_IND = 1
    AND (
      code_value.display_key IN (
        'DATETIMEPHYSICIANRETURNEDCALL',
        'MODEOFARRIVALONUNIT',
        'MODEOFARRIVAL',
        'EDDISPOSITION',
        'EDBMCDISCHARGELOCATIONS',
        'EDHNMDISCHARGELOCATIONS',
        'EDVBADISCHARGELOCATIONS',
        'EDVBCDISCHARGELOCATIONS',
        'EDMODDISCHARGELOCATIONS',
        'EDSYLDISCHARGELOCATIONS',
        'EDCYFDISCHARGELOCATIONS',
        'EDNFRDISCHARGELOCATIONS',
        'EDPMCDISCHARGELOCATIONS',
        'EDSRMDISCHARGELOCATIONS',
        'EDAHHDISCHARGELOCATIONS',
        'EDPVADISCHARGELOCATIONS',
        'EDAHDDISCHARGELOCATIONS',
        'EDMHHDISCHARGELOCATIONS',
        'EDWVHDISCHARGELOCATIONS',
        'EDPBADISCHARGELOCATIONS',
        'EDBARDISCHARGELOCATIONS',
        'EDSFHDISCHARGELOCATIONS',
        'ESCHMDISCHARGELOCATIONS',
        'EDFRMDISCHARGELOCATIONS',
        'EDHAHDISCHARGELOCATIONS',
        'EDDISCHARGED',
        'EDADMITTOBMC',
        'EDADMITTOHNM',
        'EDADMITTOVBA',
        'EDADMITTOVBC',
        'EDADMITTOMOD',
        'EDADMITTOSRE',
        'EDADMITTOCYF',
        'EDADMITTONFR',
        'EDADMITTOPMC',
        'EDADMITTOAHH',
        'EDADMITTOPVA',
        'EDADMITTOAHD',
        'EDADMITTOMHH',
        'EDADMITTOWVH',
        'EDADMITTOPBA',
        'EDADMITTOBAR',
        'EDADMITTOSFH',
        'EDADMITTOSCH',
        'EDADMITTOFRM',
        'EDADMITTOHAH',
        'EDADmitto',
        'EDBMCEXTENDEDCARE',
        'EDHNMEXTENDEDCARE',
        'EDVBAEXTENDEDCARE',
        'EDVBCEXTENDEDCARE',
        'EDMODEXTENDEDCARE',
        'EDSREEXTENDEDCARE',
        'EDCYFEXTENDEDCARE',
        'EDNFREEXTENDEDCARE',
        'EDPMCEXTENDEDCARE',
        'EDSRMEXTENDEDCARE',
        'EDAHHEXTENDEDCARE',
        'EDPVAEXTENDEDCARE',
        'EDAHDEXTENDEDCARE',
        'EDMHHEXTENDEDCARE',
        'EDWVHEXTENDEDCARE',
        'EDPBAEXTENDEDCARE',
        'EDBAREXTENDEDCARE',
        'EDSFHEXTENDEDCARE',
        'EDSCHEXTENDEDCARE',
        'EDFRMEXTENDEDCARE',
        'EDHAHEXTENDEDCARE',
        'EDBMCNURSINGHOMES',
        'EDHNMNURSINGHOMES',
        'EDVBANURSINGHOMES',
        'EDVBCNURSINGHOMES',
        'EDMODNURSINGHOMES',
        'EDSRENURSINGHOMES',
        'EDCYFNURSINGHOMES',
        'EDNFRNURSINGHOMES',
        'EDPMCNURSINGHOMES',
        'EDSRMNURSINGHOMES',
        'EDAHHNURSINGHOMES',
        'EDPVANURSINGHOMES',
        'EDAHDNURSINGHOMES',
        'EDMHHNURSINGHOMES',
        'EDWVHNURSINGHOMES',
        'EDPBANURSINGHOMES',
        'EDBARNURSINGHOMES',
        'EDSFHNURSINGHOMES',
        'EDSCHNURSINGHOMES',
        'EDFRMNURSINGHOMES',
        'EDHAHNURSINGHOMES',
        'EDBMCTRANSFER',
        'EDHNMTRANSFER',
        'EDVBATRANSFER',
        'EDVBCTRANSFER',
        'EDMODTRANSFER',
        'EDSRETRANSFER',
        'EDCYFTRANSFER',
        'EDNFRTRANSFER',
        'EDPMCTRANSFER',
        'EDSRMTRANSFER',
        'EDAHHTRANSFER',
        'EDPVATRANSFER',
        'EDAHDTRANSFER',
        'EDMHHTRANSFER',
        'EDWVHTRANSFER',
        'EDPBATRANSFER',
        'EDBARTRANSFER',
        'EDSFHTRANSFER',
        'EDSCHTRANSFER',
        'EDFRMTRANSFER',
        'EDHAHTRANSFER',
        'EDBMCNURSINGHOME',
        'EDHNMNURSINGHOME',
        'EDVBANURSINGHOME',
        'EDVBCNURSINGHOME',
        'EDMODNURSINGHOME',
        'EDSYLNURSINGHOME',
        'EDCYFNURSINGHOME',
        'EDNFRNURSINGHOME',
        'EDPMCNURSINGHOME',
        'EDSRMNURSINGHOME',
        'EDAHHNURSINGHOME',
        'EDPVANURSINGHOME',
        'EDAHDNURSINGHOME',
        'EDMHHNURSINGHOME',
        'EDWVHNURSINGHOME',
        'EDPBANURSINGHOME',
        'EDBARNURSINGHOME',
        'EDSFHNURSINGHOME',
        'EDSCHNURSINGHOME',
        'EDFRMNURSINGHOME',
        'EDHAHNURSINGHOME',
        'EDBMCTRANSFERLOCATIONS',
        'EDHNMTRANSFERLOCATIONS',
        'EDVBATRANSFERLOCATIONS',
        'EDVBCTRANSFERLOCATIONS',
        'EDMODTRANSFERLOCATIONS',
        'EDSYLTRANSFERLOCATIONS',
        'EDCYFTRANSFERLOCATIONS',
        'EDNFRTRANSFERLOCATIONS',
        'EDPMCTRANSFERLOCATIONS',
        'EDSRMTRANSFERLOCATIONS',
        'EDAHHTRANSFERLOCATIONS',
        'EDPVATRANSFERLOCATIONS',
        'EDAHDTRANSFERLOCATIONS',
        'EDMHHTRANSFERLOCATIONS',
        'EDWVHTRANSFERLOCATIONS',
        'EDPBATRANSFERLOCATIONS',
        'EDBARTRANSFERLOCATIONS',
        'EDSFHTRANSFERLOCATIONS',
        'EDSCHTRANSFERLOCATIONS',
        'EDFRMTRANSFERLOCATIONS',
        'EDHAHTRANSFERLOCATIONS',
        'EDCYFADMITTO',
        'EDCYFTRANSFERTO',
        'EDSRMADMITTO',
        'EDSRMTRANSFERTO',
        'EDMODADMITTO',
        'EDMODTRANSFERTO'
      )
      OR code_value.display_key LIKE '%ADMITTODED'
      OR code_value.display_key LIKE '%EXTENDEDCAREDED'
      OR code_value.display_key LIKE '%NURSINGHOMEDED'
      OR code_value.display_key LIKE '%TRANSFERLOCATIONSDED'
      OR code_value.display_key LIKE '%DISPOSITIONDED'
      OR code_value.display_key LIKE '%DISPOSITIONTYPEED'
    )
), relevant_events /* OPTIMIZATION: Pre-filter clinical events to only those encounters present in the driving table `all_hs_fn_temp1`. */ /* This drastically reduces the number of rows processed by the expensive ROW_NUMBER() function. */ AS (
  SELECT
    ce.HEALTH_SYSTEM_SOURCE_ID,
    ce.ENCNTR_ID,
    ce.EVENT_CD,
    ce.PERFORMED_DT_TM,
    ce.PERFORMED_PRSNL_ID,
    ce.RESULT_VAL,
    ce.event_id,
    ce.clinical_event_id
  FROM thcdnaproddata.cerner_ods.cerner_clinical_event_hist AS ce FOR SYSTEM_TIME AS OF freeze_time
  INNER JOIN all_hs_fn_temp1 AS foo
    ON ce.ENCNTR_ID = foo.encntr_id
    AND ce.HEALTH_SYSTEM_SOURCE_ID = foo.HEALTH_SYSTEM_SOURCE_ID
), filtered_events AS (
  SELECT
    re.HEALTH_SYSTEM_SOURCE_ID,
    re.ENCNTR_ID,
    re.PERFORMED_DT_TM,
    re.PERFORMED_PRSNL_ID,
    re.RESULT_VAL,
    cvg.display_group,
    ROW_NUMBER() OVER (
      PARTITION BY re.ENCNTR_ID, re.HEALTH_SYSTEM_SOURCE_ID, cvg.display_group
      ORDER BY re.event_id ASC NULLS LAST, re.clinical_event_id DESC
    ) AS rn /* The ROW_NUMBER() logic is preserved exactly to guarantee correctness. */
  FROM relevant_events AS re /* Now joining from the pre-filtered set of events, not the entire history table. */
  LEFT JOIN code_value_with_groups AS cvg
    ON re.EVENT_CD = cvg.CODE_VALUE
    AND re.HEALTH_SYSTEM_SOURCE_ID = cvg.HEALTH_SYSTEM_SOURCE_ID
), final_events AS (
  /* Using explicit columns instead of SELECT * is a best practice. */
  SELECT
    HEALTH_SYSTEM_SOURCE_ID,
    ENCNTR_ID,
    PERFORMED_DT_TM,
    PERFORMED_PRSNL_ID,
    RESULT_VAL,
    display_group
  FROM filtered_events
  WHERE
    rn = 1
)
SELECT
  foo.health_system_source_id,
  foo.mrn,
  foo.pan,
  foo.encntr_id,
  foo.fac_cd,
  foo.person_id,
  foo.patient_name,
  foo.patient_dob,
  foo.encounter_updt_dt_tm,
  foo.ADMIT_NURSING_STN,
  foo.REASON_FOR_VISIT,
  MAX(
    CASE WHEN fe.display_group = 'PERFORMED_DT_TM' THEN fe.PERFORMED_DT_TM ELSE NULL END
  ) AS PERFORMED_DT_TM,
  MAX(
    CASE
      WHEN fe.display_group = 'PERFORMED_DT_TM'
      THEN p1.NAME_FULL_FORMATTED
      ELSE NULL
    END
  ) AS CHARTED_PHYS_ON_CALL_NM,
  MAX(CASE WHEN fe.display_group = 'ARR_METHOD_CE' THEN fe.result_val ELSE NULL END) AS ARR_METHOD,
  MAX(CASE WHEN fe.display_group = 'OUTCOME_CE' THEN fe.result_val ELSE NULL END) AS OUTCOME,
  MAX(CASE WHEN fe.display_group = 'OUTCOME_LOC_CE' THEN fe.result_val ELSE NULL END) AS OUTCOME_LOCATION
FROM all_hs_fn_temp1 AS foo
INNER JOIN final_events AS fe
  ON foo.encntr_id = fe.ENCNTR_ID
  AND foo.HEALTH_SYSTEM_SOURCE_ID = fe.HEALTH_SYSTEM_SOURCE_ID
LEFT OUTER JOIN thcdnaproddata.cerner_ods.cerner_prsnl_hist AS p1 FOR SYSTEM_TIME AS OF freeze_time
  ON fe.PERFORMED_PRSNL_ID = p1.PERSON_ID
  AND fe.HEALTH_SYSTEM_SOURCE_ID = p1.HEALTH_SYSTEM_SOURCE_ID
/* Using explicit column names in GROUP BY is safer and more readable than ordinals. */
GROUP BY
  foo.health_system_source_id,
  foo.mrn,
  foo.pan,
  foo.encntr_id,
  foo.fac_cd,
  foo.person_id,
  foo.patient_name,
  foo.patient_dob,
  foo.encounter_updt_dt_tm,
  foo.ADMIT_NURSING_STN,
  foo.REASON_FOR_VISIT;

/* ================================================================================================= */
/* 4. Validation Step: Compare the two tables and check optimized duplicates. */
/* DISCREPANCY counts distinct rows that appear in one table but not the other. */
/* DUPLICATE ROWS counts extra copies of duplicate rows in V_TEMP_TABLE_OPT. */
/* The first two SELECT statements show the actual rows when discrepancies or duplicates exist. */
/* The final SELECT statement shows only the summary counts. */
/* ================================================================================================= */
CREATE OR REPLACE TEMPORARY TABLE V_VALIDATION_DISCREPANCIES AS
(
  SELECT
    'ONLY IN ORIGINAL' AS validation_diff_type,
    *
  FROM V_TEMP_TABLE_ORIG
  EXCEPT DISTINCT
  SELECT
    'ONLY IN ORIGINAL' AS validation_diff_type,
    *
  FROM V_TEMP_TABLE_OPT
)
UNION ALL
(
  SELECT
    'ONLY IN OPTIMIZED' AS validation_diff_type,
    *
  FROM V_TEMP_TABLE_OPT
  EXCEPT DISTINCT
  SELECT
    'ONLY IN OPTIMIZED' AS validation_diff_type,
    *
  FROM V_TEMP_TABLE_ORIG
);

CREATE OR REPLACE TEMPORARY TABLE V_VALIDATION_OPT_DUPLICATES AS
SELECT
  duplicate_row.*
FROM (
  SELECT
    ANY_VALUE(opt) AS duplicate_row
  FROM V_TEMP_TABLE_OPT AS opt
  GROUP BY
    TO_JSON_STRING(opt)
  HAVING
    COUNT(*) > 1
);

/* View discrepancy rows. */
SELECT
  *
FROM V_VALIDATION_DISCREPANCIES;

/* View duplicate rows from the optimized query. */
SELECT
  *
FROM V_VALIDATION_OPT_DUPLICATES;

/* View summary counts. */
SELECT
  'DISCREPANCY' AS validation_check,
  COUNT(*) AS row_count
FROM V_VALIDATION_DISCREPANCIES
UNION ALL
SELECT
  'DUPLICATE ROWS' AS validation_check,
  COALESCE(SUM(row_count - 1), 0) AS row_count
FROM (
  SELECT
    COUNT(*) AS row_count
  FROM V_TEMP_TABLE_OPT AS opt
  GROUP BY
    TO_JSON_STRING(opt)
  HAVING
    COUNT(*) > 1
);