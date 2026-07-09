MERGE MEDIBIS_FACT_CE_temp A
USING (SELECT   
        A.source_system_id,
        A.case_num,
        CASE WHEN C.quick_code IS NULL THEN 'UNKNOWN' ELSE UPPER(C.quick_code) END  AS case_status1,
        ROW_NUMBER() OVER (PARTITION BY A.source_system_id, A.case_num ORDER BY CASE WHEN C.quick_code IS NULL THEN 'UNKNOWN' ELSE UPPER(C.quick_code) END ) AS row_num
        FROM MEDIBIS_FACT_CE_temp A INNER JOIN 
         `uspidnaproddata.advantx_ods.ca_case`  B  ON 
                        A.source_system_id = B.source_system_id AND
                        A.case_num = B.case_num LEFT OUTER JOIN
        `uspidnaproddata.advantx_ods.ods_case_status`  C  ON 
                        B.source_system_id = C.source_system_id 
                        WHERE B.case_status = C.case_status ) SRC ON 
                SRC.source_system_id = A.source_system_id and
                SRC.case_num = A.case_num AND
                 A.source_system_id = V_source_system AND
                SRC.row_num =1
        WHEN MATCHED THEN 
        UPDATE SET case_status = SRC.case_status1
