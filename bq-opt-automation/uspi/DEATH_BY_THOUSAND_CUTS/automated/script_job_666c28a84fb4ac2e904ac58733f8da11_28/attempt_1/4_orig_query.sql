MERGE MEDIBIS_FACT_CE_temp A
USING (SELECT  
                A.source_system_id
                ,A.case_num
                ,B.quick_code
                ,ROW_NUMBER() OVER(PARTITION BY A.source_system_id, A.case_num ORDER BY B.quick_code) AS row_num
FROM MEDIBIS_FACT_CE_temp A INNER JOIN
        (SELECT 
                A.source_system_id
                ,A.case_num
                ,A.quick_code
                FROM (SELECT
                A.source_system_id
                ,A.case_num
                ,B.quick_code
                ,ROW_NUMBER() OVER(PARTITION BY A.source_system_id, A.case_num ORDER BY A.source_system_id, A.case_num, B.num) AS RowNumber
        FROM `uspidnaproddata.advantx_ods.as_appointment` A INNER JOIN
         `uspidnaproddata.advantx_ods.ut_visittypes` B ON 
                                A.source_system_id = B.source_system_id AND
                A.visittype_num = B.num
                                    WHERE B.active = 1) A
        WHERE A.RowNumber = 1) B ON 
        A.source_system_id = B.source_system_id AND
        A.case_num = B.case_num) SRC ON
        SRC.source_system_id = A.source_system_id AND
        SRC.case_num = A.case_num  AND
        A.source_system_id = V_source_system AND
        SRC.row_num = 1
        WHEN MATCHED THEN 
        UPDATE SET visit_type_code = quick_code;