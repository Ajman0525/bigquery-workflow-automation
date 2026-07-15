DECLARE freeze_time TIMESTAMP DEFAULT TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 24 HOUR);


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

DECLARE V_LAST_EXTRACT_DT DATE;
DECLARE V_FACILITY_CD STRING DEFAULT 'SMQ';

SET V_LAST_EXTRACT_DT = ( SELECT CAST(last_extract_ts AS DATE) FROM
  `thcdnaproddata.idm.data_control_v2` WHERE LOWER(target_table_nm) = 'pre_fact_encounter_guarantor' AND process_nm = 'sp_fact_encounter_guarantor'
  AND LOWER (TRIM(fac_cd)) = LOWER (TRIM(V_FACILITY_CD)) ORDER BY load_ts DESC LIMIT 1);

/* END STORED PROCEDURE CONTEXT */
/* ================================================================================================= */
/* 2. Create the Original Temporary Table (V_TEMP_TABLE_ORIG) */
/* ================================================================================================= */
CREATE OR REPLACE TEMPORARY TABLE V_TEMP_TABLE_ORIG AS
(
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
  FROM thcdnaproddata.daac_ods.daac_visit_hist AS V FOR SYSTEM_TIME AS OF freeze_time
  LEFT JOIN thcdnaproddata.daac_ods.daac_guar_hist AS G FOR SYSTEM_TIME AS OF freeze_time
    ON V.V7HOSP = G.G1HOSP AND V.V7PAT = G.G1PATN
  WHERE
    PARSE_DATE('%Y%m%d', CAST(V7LCHD AS STRING)) >= V_LAST_EXTRACT_DT
    AND (
      LOWER(TRIM(v7hosp_thc_src)) = LOWER(TRIM(V_FACILITY_CD))
      OR (
        LOWER(TRIM(v7hosp)) = LOWER(TRIM(V_FACILITY_CD)) AND v7hosp_thc_src IS NULL
      )
    ) /* AND (V.V7ADMD <> 99999999 OR V.V7DISD <> 99999999) */
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
  FROM thcdnaproddata.staging.nm_visit AS V FOR SYSTEM_TIME AS OF freeze_time
  WHERE
    PARSE_DATE('%Y%m%d', CAST(V7LCHD AS STRING)) >= V_LAST_EXTRACT_DT
    AND (
      LOWER(TRIM(v7hosp_thc_src)) = LOWER(TRIM(V_FACILITY_CD))
      OR (
        LOWER(TRIM(v7hosp)) = LOWER(TRIM(V_FACILITY_CD)) AND v7hosp_thc_src IS NULL
      )
    )
    AND NOT V.V7PAT IS NULL
    AND (
      (
        V.V7ADMD >= 20130101 AND V.V7ADMD <> 99999999
      )
      OR (
        V.V7DISD >= 20130101 AND V.V7DISD <> 99999999
      )
      OR (
        V.V7DISD IS NULL AND V.V7ADMD IS NULL
      )
    )
);

/* ================================================================================================= */
/* 3. Create the Optimized Temporary Table (V_TEMP_TABLE_OPT) */
/* ================================================================================================= */
CREATE OR REPLACE TEMPORARY TABLE V_TEMP_TABLE_OPT AS
(
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
    FROM `thcdnaproddata.daac_ods.daac_visit_hist` AS V FOR SYSTEM_TIME AS OF freeze_time
    WHERE
      V.V7LCHD /* This predicate is now SARGable, allowing for partition pruning if V7LCHD is a partitioning key. */ >= CAST(FORMAT_DATE('%Y%m%d', V_LAST_EXTRACT_DT) AS INT64)
      AND (
        LOWER(TRIM(v.v7hosp_thc_src)) = LOWER(TRIM(V_FACILITY_CD))
        OR (
          LOWER(TRIM(v.v7hosp)) = LOWER(TRIM(V_FACILITY_CD)) AND v.v7hosp_thc_src IS NULL
        )
      )
  ), nm_visits_filtered AS (
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
    FROM `thcdnaproddata.staging.nm_visit` AS V FOR SYSTEM_TIME AS OF freeze_time
    WHERE
      V.V7LCHD /* This predicate is now SARGable, allowing for partition pruning if V7LCHD is a partitioning key. */ >= CAST(FORMAT_DATE('%Y%m%d', V_LAST_EXTRACT_DT) AS INT64)
      AND (
        LOWER(TRIM(v.v7hosp_thc_src)) = LOWER(TRIM(V_FACILITY_CD))
        OR (
          LOWER(TRIM(v.v7hosp)) = LOWER(TRIM(V_FACILITY_CD)) AND v.v7hosp_thc_src IS NULL
        )
      )
      AND NOT V.V7PAT IS NULL
      AND (
        (
          V.V7ADMD >= 20130101 AND V.V7ADMD <> 99999999
        )
        OR (
          V.V7DISD >= 20130101 AND V.V7DISD <> 99999999
        )
        OR (
          V.V7DISD IS NULL AND V.V7ADMD IS NULL
        )
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
  FROM daac_visits_filtered AS V
  LEFT JOIN `thcdnaproddata.daac_ods.daac_guar_hist` AS G FOR SYSTEM_TIME AS OF freeze_time
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
  FROM nm_visits_filtered AS V
);

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