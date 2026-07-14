INSERT INTO `thcdnaproddata.idm.fact_encounter_modified_anr` (
    PATIENT_ACCOUNT_NBR,
    FACILITY_CD,
    MODIFIED_ANR
)
SELECT
    FE.PATIENT_ACCOUNT_NBR,
    FE.FACILITY_CD,
    FE.PA_TOTAL_PAYMENTS AS MODIFIED_ANR
FROM
    `idm.fact_encounter` AS FE
WHERE
    -- Condition 1: Apply the variable-based filter. Placing this first may help reduce rows early.
    LOWER(TRIM(FE.FACILITY_CD)) = LOWER(TRIM(V_FACILITY_CD))
    -- Condition 2: Ensure the encounter belongs to a valid facility using a NULL-safe semi-join.
    AND EXISTS (
        SELECT 1
        FROM `thcdnaproddata.idm.dim_facility` AS DF
        WHERE
            FE.DIM_FACILITY_SK = DF.DIM_FACILITY_SK
            AND (
                (DF.MRKT_ID IN ('M16') AND DF.FACILITY_CD NOT IN ('BMC'))
                OR DF.FACILITY_CD IN ('HMD', 'EMC')
            )
    )
    -- Condition 3: Ensure the record does not already exist in the target table using a NULL-safe anti-join.
    AND NOT EXISTS (
        SELECT 1
        FROM `thcdnaproddata.idm.fact_encounter_modified_anr` AS TGT
        WHERE
            TGT.PATIENT_ACCOUNT_NBR = FE.PATIENT_ACCOUNT_NBR
            AND TGT.FACILITY_CD = FE.FACILITY_CD
    );
