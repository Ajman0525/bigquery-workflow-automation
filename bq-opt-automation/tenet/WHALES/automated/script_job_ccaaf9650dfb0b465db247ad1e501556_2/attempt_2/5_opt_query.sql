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
)
