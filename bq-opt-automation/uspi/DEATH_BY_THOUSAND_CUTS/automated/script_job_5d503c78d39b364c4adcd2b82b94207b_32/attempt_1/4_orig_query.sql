MERGE MEDIBIS_FACT_CE_temp A
USING (SELECT   
        A.source_system_id,
        A.case_num,
        C.quick_code,
        ROW_NUMBER() OVER (PARTITION BY A.source_system_id, A.case_num ORDER BY C.quick_code ) AS row_num
        FROM MEDIBIS_FACT_CE_temp A INNER JOIN 
        ar_billtrans_charge_ce_temp B ON
                A.source_system_id = B.source_system_id and
                A.case_num = B.case_num   INNER JOIN 
        `uspidnaproddata.advantx_ods.ut_dx` C ON 
                        B.source_system_id = C.source_system_id AND
            B.dx1_num_10 = C.num) SRC ON 
                SRC.source_system_id = A.source_system_id and
                SRC.case_num = A.case_num AND
                A.source_system_id = V_source_system AND
                SRC.row_num =1
        WHEN MATCHED THEN 
        UPDATE SET icd10_code = SRC.quick_code ;    