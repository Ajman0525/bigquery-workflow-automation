CREATE PROCEDURE thcdnaproddata.idm.sp_fact_encounter_guarantor(IN inparam_facility_cd STRING, OUT OUT_PARAM INT64)
BEGIN
  /* ------------------------------------------------------------------------------------------------------------------------------------------------------- */
  -- Proc name    : sp_fact_encounter_guarantor
  -- Database     : idm
  -- Author       : Shiva Arun Reddy
  -- Project      : Tenet 2.0 Conversion
  -- Proc Desc    : Stored procedure to load fact_encounter.
  -- Revision History:
  -- When 	  Version 	Modified by 					        Change description
  -- --------	  -------	-----------------------		-----------------------------------------------------------------------------------------------------
  -- 20250917  1.0 		Shiva Arun Reddy		                Created!
  /* ---------------------------------------------------------------------------------------------------------------------------------------------------------- */

  DECLARE V_LAST_EXTRACT_DT DATE;
  DECLARE V_PROC_NAME STRING DEFAULT 'sp_fact_encounter_guarantor';
  DECLARE V_LOG_MESSAGE STRING;
  DECLARE V_FACILITY_CD STRING DEFAULT inparam_facility_cd;
  DECLARE V_ERRORMESSAGE STRING;
  DECLARE V_MYERRORMESSAGE STRING;
  DECLARE min_of_max_dates DATE;
  DECLARE V_RESULT_1,V_RESULT_2 STRING;
  DECLARE DML_1, DML_2 STRING;

  SET V_LAST_EXTRACT_DT = ( SELECT CAST(last_extract_ts AS DATE) FROM
  `thcdnaproddata.idm.data_control_v2` WHERE LOWER(target_table_nm) = 'pre_fact_encounter_guarantor' AND process_nm = 'sp_fact_encounter_guarantor'
  AND LOWER (TRIM(fac_cd)) = LOWER (TRIM(V_FACILITY_CD)) ORDER BY load_ts DESC LIMIT 1);

  BEGIN

  CREATE TEMP TABLE fact_encounter_temp
  PARTITION BY DATE_TRUNC(DISCHARGE_DT, MONTH)
  CLUSTER BY FACILITY_CD, PATIENT_ACCOUNT_NBR AS
  select * from idm.pre_fact_encounter_guarantor limit 0;

	-- CTE: Combine DAAC and NM visit data
	-- START OPTIMIZED QUERY
CREATE TEMP TABLE SRC_STAGING_VISIT AS (
  WITH daac_visits_filtered AS (
    SELECT
      V.V7HOSP,
      V.V7PAT,
      V.V7PATT,
      V.V7ADMD,
      V.V7DISD,
      V.V7PATC,
      V.V7HOSP_THC_SRC,
      V.V7LCHD
    FROM
      `thcdnaproddata.daac_ods.daac_visit_hist` AS V
    WHERE
      -- This predicate is now SARGable, allowing for partition pruning if V7LCHD is a partitioning key.
      V.V7LCHD >= CAST(FORMAT_DATE('%Y%m%d', V_LAST_EXTRACT_DT) AS INT64)
      AND (
        LOWER(TRIM(v.v7hosp_thc_src)) = LOWER(TRIM(V_FACILITY_CD))
        OR (LOWER(TRIM(v.v7hosp)) = LOWER(TRIM(V_FACILITY_CD)) AND v.v7hosp_thc_src IS NULL)
      )
  ),
  nm_visits_filtered AS (
    SELECT
      V.V7HOSP,
      V.V7PAT,
      V.V7PATT,
      V.V7ADMD,
      V.V7DISD,
      V.V7PATC,
      V.G1NAME,
      V.G1GRPH,
      V.G1GREM,
      V.V7HOSP_THC_SRC,
      V.V7LCHD,
      V.SOURCE_SYSTEM
    FROM
      `thcdnaproddata.staging.nm_visit` AS V
    WHERE
      -- This predicate is now SARGable, allowing for partition pruning if V7LCHD is a partitioning key.
      V.V7LCHD >= CAST(FORMAT_DATE('%Y%m%d', V_LAST_EXTRACT_DT) AS INT64)
      AND (
        LOWER(TRIM(v.v7hosp_thc_src)) = LOWER(TRIM(V_FACILITY_CD))
        OR (LOWER(TRIM(v.v7hosp)) = LOWER(TRIM(V_FACILITY_CD)) AND v.v7hosp_thc_src IS NULL)
      )
      AND V.V7PAT IS NOT NULL
      AND (
        (V.V7ADMD >= 20130101 AND V.V7ADMD <> 99999999)
        OR (V.V7DISD >= 20130101 AND V.V7DISD <> 99999999)
        OR (V.V7DISD IS NULL AND V.V7ADMD IS NULL)
      )
  )
  SELECT
    V.V7HOSP AS HOSP_CD,
    CAST(V.V7PAT AS STRING) AS PATNO,
    TRIM(V.V7PATT) AS V7PATT,
    V.V7ADMD,
    V.V7DISD,
    REGEXP_REPLACE(TRIM(V.V7PATC), '[ ]+', ' ') AS PATIENT_CLASS_CD,
    REGEXP_REPLACE(TRIM(V.V7PATT), '[ ]+', ' ') AS patient_class_type,
    G.G1LNAM,
    G.G1FNAM,
    CASE
      WHEN G.G1CELLPH = '0'
      OR G.G1CELLPH = ''
      OR G.G1CELLPH IS NULL
      OR LENGTH(TRIM(G.G1CELLPH)) < 10
      THEN G.G1GRPH
      ELSE G.G1CELLPH
    END AS GUARANTORCELLPHONE,
    G.G1GREM,
    V.V7HOSP_THC_SRC,
    V.V7LCHD,
    'DAAC' AS SOURCE_SYSTEM
  FROM
    daac_visits_filtered AS V
  LEFT JOIN
    `thcdnaproddata.daac_ods.daac_guar_hist` AS G
    ON V.V7HOSP = G.G1HOSP AND V.V7PAT = G.G1PATN
  UNION ALL
  SELECT
    V.V7HOSP AS HOSP_CD,
    TRIM(V.V7PAT) AS PATNO,
    TRIM(V.V7PATT) AS V7PATT,
    V.V7ADMD,
    V.V7DISD,
    REGEXP_REPLACE(TRIM(V.V7PATC), '[ ]+', ' ') AS PATIENT_CLASS_CD,
    REGEXP_REPLACE(TRIM(V.V7PATT), '[ ]+', ' ') AS patient_class_type,
    V.G1NAME AS G1LNAM,
    ' ' AS G1FNAM,
    V.G1GRPH AS GUARANTORCELLPHONE,
    V.G1GREM,
    V.V7HOSP_THC_SRC,
    V.V7LCHD,
    V.SOURCE_SYSTEM
  FROM
    nm_visits_filtered AS V
);
-- END OPTIMIZED QUERY;


CREATE TEMP TABLE XFM_KEYS AS (

WITH stg_visit_cleaned AS (
  SELECT
    REGEXP_REPLACE(TRIM(HOSP_CD), '[ ]+', ' ') AS HOSP_CODE,
    CASE WHEN REGEXP_REPLACE(TRIM(UPPER(HOSP_CD)), '[ ]+', ' ') = 'TRA' THEN 'DAAC_TRA' ELSE SOURCE_SYSTEM END AS SOURCE_SYSTEM,
    PATNO, V7ADMD, V7DISD,
    REGEXP_REPLACE(TRIM(G1LNAM), '[ ]+', ' ') AS G1LNAM,
    REGEXP_REPLACE(TRIM(G1FNAM), '[ ]+', ' ') AS G1FNAM,
    REGEXP_REPLACE(TRIM(GUARANTORCELLPHONE), '[ ]+', ' ') AS GUARANTORCELLPHONE,
    REGEXP_REPLACE(TRIM(G1GREM), '[ ]+', ' ') AS G1GREM,
    V7HOSP_THC_SRC, V7LCHD,
    PATIENT_CLASS_CD

  FROM SRC_STAGING_VISIT
)

SELECT
  t1.*,
FROM stg_visit_cleaned AS t1
);




	-- CTE: Prepare the data for the final insert format
	CREATE TEMP TABLE PREP_FINAL_INSERT AS (
		SELECT
    CAST(t6.PATNO AS STRING) AS PATIENT_ACCOUNT_NBR,t6.HOSP_CODE AS FACILITY_CD,
    CAST(CASE WHEN t6.SOURCE_SYSTEM = 'DAAC' THEN CONCAT(t6.G1LNAM, ',', t6.G1FNAM) ELSE CAST(t6.G1LNAM AS STRING) END AS STRING) AS GUARANTOR_NM,
    t6.GUARANTORCELLPHONE AS GUARANTOR_PHONE_NBR,
    t6.G1GREM AS GUARANTOR_EMPLOYER_NM,
    t6.V7HOSP_THC_SRC as FACILITY_CD_THC_SRC, SOURCE_SYSTEM,
    SAFE.PARSE_DATE('%Y%m%d', CAST(t6.V7LCHD AS STRING)) AS LAST_CHANGE_DATE,
    FROM XFM_KEYS AS t6
	);


INSERT INTO fact_encounter_temp (
    PATIENT_ACCOUNT_NBR, FACILITY_CD,GUARANTOR_NM, GUARANTOR_PHONE_NBR, GUARANTOR_EMPLOYER_NM,
    FACILITY_CD_THC_SRC,LAST_CHANGE_DATE
	)
	select * except(row_no) from(
	SELECT
  TRIM(src.PATIENT_ACCOUNT_NBR) PATIENT_ACCOUNT_NBR,
  TRIM(src.FACILITY_CD) FACILITY_CD,
  src.GUARANTOR_NM,
	src.GUARANTOR_PHONE_NBR,
  REGEXP_REPLACE(TRIM(src.GUARANTOR_EMPLOYER_NM), '[ ]+', ' ') AS GUARANTOR_EMPLOYER_NM,
  src.FACILITY_CD_THC_SRC,
  src.LAST_CHANGE_DATE,
	ROW_NUMBER () OVER (PARTITION BY FACILITY_CD,PATIENT_ACCOUNT_NBR,SOURCE_SYSTEM) row_no
	FROM PREP_FINAL_INSERT AS src
	) where row_no =1;


CREATE TEMP TABLE tmp_guarantor_fix AS
  SELECT
    F.FACILITY_CD, F.PATIENT_ACCOUNT_NBR,
    CASE
      WHEN SUBSTRING(F.GUARANTOR_NM, LENGTH(F.GUARANTOR_NM), 1) = ',' THEN SUBSTRING(F.GUARANTOR_NM, 1, LENGTH(F.GUARANTOR_NM) - 1)
      ELSE NULL
    END AS GUARANTOR_NM_CLEAN
  FROM fact_encounter_temp F
  WHERE (LOWER(TRIM(F.FACILITY_CD_THC_SRC)) = LOWER(TRIM(V_FACILITY_CD))
         OR (LOWER(TRIM(F.FACILITY_CD)) = LOWER(TRIM(V_FACILITY_CD)) AND F.FACILITY_CD_THC_SRC IS NULL))
    AND F.GUARANTOR_NM IS NOT NULL;


  UPDATE fact_encounter_temp T
  SET T.GUARANTOR_NM = S.GUARANTOR_NM_CLEAN
      -- T.UPDATE_TS = CURRENT_DATETIME("America/Chicago"),
      -- T.UPDATE_UID = 'GUARANTOR_FIX'
  FROM tmp_guarantor_fix S
  WHERE TRIM(T.FACILITY_CD) = TRIM(S.FACILITY_CD)
    AND TRIM(T.PATIENT_ACCOUNT_NBR) = TRIM(S.PATIENT_ACCOUNT_NBR)
    AND S.GUARANTOR_NM_CLEAN IS NOT NULL
    AND (
      LOWER(TRIM(T.FACILITY_CD_THC_SRC)) = LOWER(TRIM(V_FACILITY_CD))
      OR (LOWER(TRIM(T.FACILITY_CD)) = LOWER(TRIM(V_FACILITY_CD)) AND T.FACILITY_CD_THC_SRC IS NULL)
    );

SET DML_1 = CONCAT(
  """
MERGE `thcdnaproddata.idm.pre_fact_encounter_guarantor` AS T
USING (
  SELECT * FROM `fact_encounter_temp`
  WHERE DATE(LAST_CHANGE_DATE) BETWEEN
    (SELECT MIN(DATE(LAST_CHANGE_DATE)) FROM `fact_encounter_temp`)
    AND
    (SELECT MAX(DATE(LAST_CHANGE_DATE)) FROM `fact_encounter_temp`)
) AS S
ON T.PATIENT_ACCOUNT_NBR = S.PATIENT_ACCOUNT_NBR AND T.FACILITY_CD = S.FACILITY_CD
WHEN MATCHED THEN
  UPDATE SET
    T.GUARANTOR_NM = S.GUARANTOR_NM,
    T.GUARANTOR_PHONE_NBR = S.GUARANTOR_PHONE_NBR,
    T.GUARANTOR_EMPLOYER_NM = S.GUARANTOR_EMPLOYER_NM,
    T.LAST_CHANGE_DATE = S.LAST_CHANGE_DATE
WHEN NOT MATCHED THEN
  INSERT (
    PATIENT_ACCOUNT_NBR, FACILITY_CD, GUARANTOR_NM, GUARANTOR_PHONE_NBR, GUARANTOR_EMPLOYER_NM,
		FACILITY_CD_THC_SRC,LAST_CHANGE_DATE
  )
  VALUES (
  S.PATIENT_ACCOUNT_NBR, S.FACILITY_CD, S.GUARANTOR_NM, S.GUARANTOR_PHONE_NBR, S.GUARANTOR_EMPLOYER_NM,
  S.FACILITY_CD_THC_SRC,S.LAST_CHANGE_DATE
  );
	""");

  CALL thcdnaproddata.framework_metadata.execute_sql_dml (DML_1,V_PROC_NAME,V_RESULT_1);

  if V_RESULT_1 <> 'P' then
    RAISE USING message = V_RESULT_1;
  end if;

  SET min_of_max_dates = (SELECT MIN(PARSE_DATE('%Y%m%d', CAST(max_dt AS STRING)))AS min_of_max_dates
FROM (
  SELECT MAX(v7lchd) AS max_dt
  FROM daac_ods.daac_visit_hist
  WHERE (
    LOWER(TRIM(v7hosp_thc_src)) = LOWER(TRIM(V_FACILITY_CD))
    OR (
      LOWER(TRIM(v7hosp)) = LOWER(TRIM(V_FACILITY_CD))
      AND v7hosp_thc_src IS NULL
    )
  )

  UNION ALL

  SELECT MAX(v7lchd) AS max_dt
  FROM staging.nm_visit
  WHERE (
    LOWER(TRIM(v7hosp_thc_src)) = LOWER(TRIM(V_FACILITY_CD))
    OR (
      LOWER(TRIM(v7hosp)) = LOWER(TRIM(V_FACILITY_CD))
      AND v7hosp_thc_src IS NULL
    )
  )

  UNION ALL

  SELECT MAX(g1lchd) AS max_dt
  FROM daac_ods.daac_guar_hist
  WHERE (
    LOWER(TRIM(g1hosp_thc_src)) = LOWER(TRIM(V_FACILITY_CD))
    OR (
      LOWER(TRIM(g1hosp)) = LOWER(TRIM(V_FACILITY_CD))
      AND g1hosp_thc_src IS NULL
    )
  )
));

  SET DML_2 = CONCAT(
  """
	INSERT INTO `thcdnaproddata.idm.data_control_v2` (source_system, target_table_nm, fac_cd, process_nm, last_extract_ts, load_ts)
  SELECT 'daac', 'pre_fact_encounter_guarantor', LOWER(TRIM('""",V_FACILITY_CD,"""')), '""",V_PROC_NAME,"""',
  (SELECT IFNULL(DATETIME('""",
IFNULL(CAST(min_of_max_dates AS STRING), CAST(V_LAST_EXTRACT_DT AS STRING)),
"""'),'""",CAST(V_LAST_EXTRACT_DT AS STRING),"""')),
  CURRENT_DATETIME("America/Chicago");
  """);

  CALL thcdnaproddata.framework_metadata.execute_sql_dml (DML_2,V_PROC_NAME,V_RESULT_2);

  if V_RESULT_2 <> 'P' then
    RAISE USING message = V_RESULT_2;
  end if;

  DROP TABLE IF EXISTS SRC_STAGING_VISIT;
  DROP TABLE IF EXISTS XFM_KEYS;
  DROP TABLE IF EXISTS PREP_FINAL_INSERT;
  DROP TABLE IF EXISTS fact_encounter_temp;


SET
  OUT_PARAM = 1;
SELECT
  OUT_PARAM; /* =============================================================================================================================== */ /* HANDLE EXCEPTIONS

  /* =============================================================================================================================== */ EXCEPTION
    WHEN ERROR THEN SET V_LOG_MESSAGE = 'FAILED - Procedure ' || V_PROC_NAME || ', Reason: TRANSACTION_ABORTED - ' || REPLACE(@@error.message,'\'','\'\''); SET V_LOG_MESSAGE = 'FAILED - Procedure ' || V_PROC_NAME || ', ' || REPLACE(@@error.message,'\'','\'\''); SELECT '%', V_LOG_MESSAGE; SET OUT_PARAM = 0; SELECT OUT_PARAM; RAISE USING message = SUBSTR(@@error.message,1,5000);
END;

END;
