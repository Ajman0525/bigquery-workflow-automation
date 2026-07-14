-- Declare script variables to pre-calculate filter values.
-- This avoids repeated calculations inside the query and helps the optimizer.
-- Assumption: V7LCHD column is of type INT64/NUMERIC and stores dates as YYYYMMDD.
DECLARE V_LAST_EXTRACT_DT_INT INT64 DEFAULT CAST(FORMAT_DATE('%Y%m%d', V_LAST_EXTRACT_DT) AS INT64);
DECLARE V_FACILITY_CD_LOWER_TRIM STRING DEFAULT LOWER(TRIM(V_FACILITY_CD));

CREATE TEMP TABLE SRC_STAGING_VISIT AS
WITH
  branch_1_daac AS (
    -- Block 1: Data from daac_ods.daac_visit_hist joined with daac_guar_hist
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
        WHEN G.G1CELLPH = '0' OR G.G1CELLPH = '' OR G.G1CELLPH IS NULL OR LENGTH(TRIM(G.G1CELLPH)) < 10
        THEN G.G1GRPH
        ELSE G.G1CELLPH
      END AS GUARANTORCELLPHONE,
      G.G1GREM,
      V.V7HOSP_THC_SRC,
      V.V7LCHD,
      'DAAC' AS SOURCE_SYSTEM
    FROM
      `thcdnaproddata.daac_ods.daac_visit_hist` AS V
    LEFT JOIN
      `thcdnaproddata.daac_ods.daac_guar_hist` AS G
      ON V.V7HOSP = G.G1HOSP AND V.V7PAT = G.G1PATN
    WHERE
      -- Optimized date filter enables partition/cluster pruning if V7LCHD is a partitioning/clustering key.
      V.V7LCHD >= V_LAST_EXTRACT_DT_INT
      AND (
        LOWER(TRIM(V.v7hosp_thc_src)) = V_FACILITY_CD_LOWER_TRIM
        OR (LOWER(TRIM(V.v7hosp)) = V_FACILITY_CD_LOWER_TRIM AND V.v7hosp_thc_src IS NULL)
      )
  ),
  branch_2_nm AS (
    -- Block 2: Data from staging.nm_visit
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
      `thcdnaproddata.staging.nm_visit` AS V
    WHERE
      -- Optimized date filter enables partition/cluster pruning.
      V.V7LCHD >= V_LAST_EXTRACT_DT_INT
      AND (
        LOWER(TRIM(V.v7hosp_thc_src)) = V_FACILITY_CD_LOWER_TRIM
        OR (LOWER(TRIM(V.v7hosp)) = V_FACILITY_CD_LOWER_TRIM AND V.v7hosp_thc_src IS NULL)
      )
      AND V.V7PAT IS NOT NULL
      AND (
        (V.V7ADMD >= 20130101 AND V.V7ADMD <> 99999999)
        OR (V.V7DISD >= 20130101 AND V.V7DISD <> 99999999)
        OR (V.V7DISD IS NULL AND V.V7ADMD IS NULL)
      )
  )
SELECT * FROM branch_1_daac
UNION ALL
SELECT * FROM branch_2_nm;
