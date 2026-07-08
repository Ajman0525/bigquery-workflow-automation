MERGE MEDIBIS_FACT_CE_temp A
USING (SELECT   
        A.source_system_id,
        A.case_num,
        CAST(IFNULL(C.pers_org_num,-1) AS STRING) AS pers_org_num,
        ROW_NUMBER() OVER (PARTITION BY A.source_system_id, A.case_num ORDER BY IFNULL(C.pers_org_num,-1)) AS row_num
        FROM MEDIBIS_FACT_CE_temp A LEFT OUTER JOIN
        `uspidnaproddata.advantx_ods.ad_case_ps_ins`  B on 
                        A.case_num = B.case_num AND
                        A.source_system_id = B.source_system_id INNER JOIN
        `uspidnaproddata.advantx_ods.ad_ps_rolehist_ins` C ON 
                        B.pers_org_num_pt = C.pers_org_num_pers_ins AND 
                        A.source_system_id = B.source_system_id AND
                        C.role_num = 6) SRC ON
                SRC.source_system_id = A.source_system_id AND
                A.source_system_id = V_source_system AND
                SRC.case_num = A.case_num AND
                SRC.row_num =1 
        WHEN MATCHED THEN 
        UPDATE SET payor_code = SRC.pers_org_num
