MERGE MEDIBIS_FACT_CE_temp A
USING (
    SELECT  
        A.source_system_id,
        A.patient_code,
        A.date_of_service,
        A.case_id,
        CAST(B.pers_org_num_pers AS STRING) AS pers_org_num_pers,
        FLOOR(DATE_DIFF(A.date_of_service, C.dob, DAY) / 365.25) AS PATIENT_AGE,
        ROW_NUMBER() OVER (PARTITION BY
            A.source_system_id, A.patient_code, A.date_of_service, A.case_id
            ORDER BY C.dob, A.case_id
        ) AS row_num
    FROM MEDIBIS_FACT_CE_temp A
    INNER JOIN `uspidnaproddata.advantx_ods.ad_pt`  B
        ON A.source_system_id = B.source_system_id
        AND A.patient_code = CAST(B.pers_org_num_pers AS STRING)
    INNER JOIN `uspidnaproddata.advantx_ods.co_pers`  C
        ON B.source_system_id = C.source_system_id  
    WHERE B.pers_org_num_pers = C.pers_org_num
) SRC
ON SRC.source_system_id = A.source_system_id
AND SRC.pers_org_num_pers = A.patient_code
AND SRC.date_of_service = A.date_of_service
AND SRC.case_id = A.case_id
AND SRC.row_num = 1
AND A.source_system_id = V_source_system
WHEN MATCHED THEN
    UPDATE SET patient_age = SRC.PATIENT_AGE
