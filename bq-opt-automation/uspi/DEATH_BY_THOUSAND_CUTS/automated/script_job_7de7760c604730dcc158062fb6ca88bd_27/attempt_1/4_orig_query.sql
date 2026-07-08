INSERT INTO MEDIBIS_FACT_CE_temp
                (company_code
                ,facility_code
                ,physician_code
                ,procedure_code
                ,patient_code
                ,date_of_service
                ,case_id
                ,patient_type_code
                ,visit_type_code
                ,case_count
                ,procedure_count
                ,financial_year
                ,financial_period
                ,billing_period
                ,billing_period_start_date
                ,service_code
                ,case_num
            ,tisclient_num                
                ,cpt_procedure_code
                ,account_name
                ,case_charge_amount
                ,case_primary_payment_amount
                ,case_copay_payment_amount
                ,case_writeoff_amount
                ,cpt_charge_amount
                ,entity_code
                ,refer_physician_code
                ,units
                ,source_system_id)
                SELECT
                    DISTINCT A.company_code
                    ,cast(A.pers_org_num_org as string) AS faclity_code
                    ,cast(G.pers_org_num as string) AS physician_code
                    ,I.procedure_code
                    ,cast(B.pers_org_num_pers as string) AS patient_code
                    ,CAST(CAST(C.key_dos AS DATE) AS DATETIME) AS date_of_service
                    ,
                   --  CAST(CONCAT(CONCAT(RIGHT(CONCAT( '0000' ,  LTRIM(RTRIM(IFNULL(CAST(C.tisclient_num AS STRING),'')))),4) ,
                   --  RIGHT(CONCAT( '00000000' ,  LTRIM(RTRIM(IFNULL(CAST(C.pers_org_num_pt AS STRING),'')))),8)),
                   --  CASE WHEN C.case_num IS NULL THEN '00000000' ELSE 
                   --  RIGHT(CONCAT( '00000000' ,  LTRIM(RTRIM(IFNULL(CAST(C.case_num AS STRING),'')))),8)    END)
                   -- AS STRING) AS case_id
                   CONCAT(
                        LPAD(TRIM(COALESCE(CAST(C.tisclient_num AS STRING), '')), 4, '0'),
                        LPAD(TRIM(COALESCE(CAST(B.pers_org_num_pers AS STRING), '')), 8, '0'),
                        LPAD(TRIM(COALESCE(CAST(C.case_num AS STRING), '')), 8, '0')
                    ) AS case_id
                    ,'O' AS patient_type_code
                    ,'U' AS visit_type_code
                    ,0 AS case_count
                    ,cast(f.units as integer) AS procedure_count
                    ,NULL AS financial_year
                    ,NULL AS financial_period
                    ,NULL AS bill_period_num
                    ,CAST(NULL AS DATETIME) AS billing_period_start_date
                    ,F.service_code
                    ,C.case_num
                    ,C.tisclient_num
                    ,L.cpt_procedure_code
                    ,b.account_num AS account_name,

                     --changed  --sad
                    CAST(0.00 AS NUMERIC) AS case_charge_amount
                    ,CAST(0.00 AS NUMERIC) AS case_primary_payment_amount
                    ,CAST(0.00 AS NUMERIC) AS case_copay_payment_amount
                    ,CAST(0.00 AS NUMERIC) AS case_writeoff_amount

                --     ,0.00 AS case_charge_amount
                --     ,0.00 AS case_primary_payment_amount
                --     ,0.00 AS case_copay_payment_amount
                --     ,0.00 AS case_writeoff_amount
                    ,F.charge_amount
                    ,cast(I.entity_code as string)
                    ,cast(CASE WHEN C.refer_phys_num is null THEN -1 ELSE C.refer_phys_num END as string)AS refer_physician_code 
                    ,f.units
                    ,A.source_system_id
                FROM `uspidnaproddata.edw_advantx.vw_ad_tisclient`  A INNER JOIN
                        `uspidnaproddata.advantx_ods.ad_pt` B ON 
                                A.source_system_id = B.source_system_id INNER JOIN
                        `uspidnaproddata.advantx_ods.ca_case` C ON 
                                B.source_system_id = C.source_system_id AND
                                B.pers_org_num_pers = C.pers_org_num_pt  LEFT OUTER JOIN
                        `uspidnaproddata.advantx_ods.ca_visit` D ON 
                                C.source_system_id = D.source_system_id AND
                                C.case_num = D.case_num LEFT OUTER JOIN
                        temp_ca_visit_visitdept_proc_hist E ON 
                                D.source_system_id = E.source_system_id AND
                                D.case_num = E.case_num AND
                                D.visit_num = E.visit_num AND
                                E.order_key = 1 INNER JOIN
                (SELECT A.source_system_id
                                 ,A.case_num
                                 ,A.visit_num
                                 ,A.procfee_num
                                 ,A.charge_amount
                                 ,A.paid_amount
                                 ,A.pat_part
                                 ,A.writtenoff_amount
                                 ,C.tis_client_num
                                 ,CASE WHEN E.quick_code IS NULL THEN '0' ELSE E.quick_code END AS service_code
                                 ,A.units
                FROM ar_billtrans_charge_ce_temp A INNER JOIN
                        temp_ar_billtrans B ON 
                                                A.source_system_id = B.source_system_id AND
                                                A.bill_trans_num = B.bill_trans_num INNER JOIN
                        `uspidnaproddata.advantx_ods.ar_billing_period` C ON 
                                                B.source_system_id = C.source_system_id AND
                                                B.bill_period_num = C.num INNER JOIN
                        `uspidnaproddata.advantx_ods.ut_proc_fee` D ON 
                                                A.source_system_id = D.source_system_id AND
                                                A.procfee_num = D.num LEFT OUTER JOIN
                        `uspidnaproddata.advantx_ods.ut_servicetypes` E ON 
                                                D.source_system_id = E.source_system_id AND
                                                D.service_type_num = E.num 
                WHERE  b.active = 1) F ON C.source_system_id = F.source_system_id AND
                                                             C.case_num = F.case_num AND
                                                             CASE WHEN D.visit_num IS NULL THEN -1 ELSE D.visit_num END = CASE WHEN F.visit_num IS NULL THEN -1 ELSE F.visit_num END AND
                                                             A.pers_org_num_org = F.tis_client_num LEFT OUTER JOIN
                        `uspidnaproddata.advantx_ods.ut_phys`  G ON 
                                                C.source_system_id = G.source_system_id AND
                                                C.primary_phys_num = G.num LEFT OUTER JOIN
                (SELECT 
                            A.source_system_id
                            ,A.case_num
                            ,A.procedure_code
                            ,B.tis_client_num
                            ,A.facility_num AS entity_code,
                            ROW_NUMBER() OVER (PARTITION BY A.source_system_id, A.case_num, A.bill_period_num ORDER BY A.procedure_code,A.facility_num ) AS row_num
                        FROM PRIMARY_PROCEDURE_ce_temp A INNER JOIN
                        `uspidnaproddata.advantx_ods.ar_billing_period` B ON 
                                        A.source_system_id = B.source_system_id AND
                                        A.bill_period_num = B.num) I ON 
                                        F.source_system_id = I.source_system_id AND
                                        F.case_num = I.case_num  
                                        and row_num=1
                                    LEFT OUTER JOIN
                        `uspidnaproddata.advantx_ods.ut_visittypes`  K ON 
                                        D.source_system_id = K.source_system_id AND
                                        D.visittype_num = K.num LEFT OUTER JOIN
                (SELECT 
                            A.source_system_id
                            ,A.num AS procfee_num
                            ,B.quick_code AS cpt_procedure_code
                        FROM `uspidnaproddata.advantx_ods.ut_proc_fee` A INNER JOIN
                        `uspidnaproddata.advantx_ods.ut_proc` B ON 
                                A.source_system_id = B.source_system_id AND
                                A.proc_num = b.num) L ON 
                                F.source_system_id = L.source_system_id AND
                                F.procfee_num = L.procfee_num 
                             WHERE F.charge_amount IS NOT NULL    and  C.key_dos >=  
        (SELECT DATE_TRUNC(DATE_SUB(CURRENT_DATE(), INTERVAL 3 YEAR), YEAR) 
    AS datetime_three_years_ago) AND A.source_system_id=V_source_system;