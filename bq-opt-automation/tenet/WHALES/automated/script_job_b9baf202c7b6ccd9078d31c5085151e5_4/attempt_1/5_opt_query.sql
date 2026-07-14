INSERT INTO thcdnaproddata.idm.fact_encounter_modified_anr (
  PATIENT_ACCOUNT_NBR,
  FACILITY_CD,
  MODIFIED_ANR
)
SELECT
  fe.PATIENT_ACCOUNT_NBR,
  fe.FACILITY_CD,
  fe.PA_TOTAL_PAYMENTS AS MODIFIED_ANR
FROM
  `idm.fact_encounter` AS fe
JOIN
  `idm.dim_facility` AS df
  ON fe.DIM_FACILITY_SK = df.DIM_FACILITY_SK
LEFT JOIN
  `thcdnaproddata.idm.fact_encounter_modified_anr` AS existing
  ON fe.PATIENT_ACCOUNT_NBR = existing.PATIENT_ACCOUNT_NBR
  AND fe.FACILITY_CD = existing.FACILITY_CD
WHERE
  -- Filter to include only new records not present in the target table
  existing.PATIENT_ACCOUNT_NBR IS NULL
  -- Merged facility filter criteria from original JOIN and IN subquery
  AND (
    (df.MRKT_ID = 'M16' AND df.FACILITY_CD != 'BMC')
    OR df.FACILITY_CD IN ('HMD', 'EMC')
  )
  -- This function-wrapped predicate remains a major performance bottleneck.
  -- It forces a full scan and should be addressed via ETL or data cleaning.
  AND LOWER(TRIM(fe.FACILITY_CD)) = LOWER(TRIM(V_FACILITY_CD));
