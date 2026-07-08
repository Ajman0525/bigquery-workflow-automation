INSERT INTO PRIMARY_PROCEDURE_ce_temp
                (source_system_id
                ,case_num
                ,procfee_num
                ,procedure_code
                ,visittype_num
                ,visit_type_code
                ,bill_period_num)
                SELECT
                    source_system_id
                    ,case_num
                    ,procfee_num
                    ,procedure_code
                    ,visittype_num
                    ,visit_type_code
                    ,bill_period_num   
                FROM (SELECT source_system_id, case_num, procfee_num, procedure_code, visittype_num, visit_type_code, bill_period_num, 
                ROW_NUMBER() OVER (PARTITION BY source_system_id, case_num
                            ORDER BY source_system_id, case_num, procedure_code) AS rownumber
                FROM (SELECT
                                    A.source_system_id
                                    ,B.case_num
                                    ,B.procfee_num
                                    ,E.quick_code AS procedure_code
                                    ,I.num AS visittype_num
                                    ,I.quick_code AS visit_type_code
                                    ,MIN(A.bill_period_num) as bill_period_num
                        FROM temp_ar_billtrans A INNER JOIN
                        ar_billtrans_charge_ce_temp B ON 
                                        A.source_system_id = B.source_system_id AND
                                        A.bill_trans_num = B.bill_trans_num INNER JOIN
                        `uspidnaproddata.advantx_ods.ar_billing_period` C ON 
                                        A.source_system_id = C.source_system_id AND
                                        A.bill_period_num = C.num INNER JOIN
                        `uspidnaproddata.advantx_ods.ut_proc_fee` D ON 
                                        B.source_system_id = D.source_system_id AND
                                        B.procfee_num = D.num INNER JOIN
                        `uspidnaproddata.advantx_ods.ut_proc` E ON 
                                        D.source_system_id = E.source_system_id AND
                                        D.proc_num = E.num INNER JOIN
                        `uspidnaproddata.advantx_ods.ca_case` F ON 
                                        B.source_system_id = F.source_system_id AND
                                        B.case_num = F.case_num  INNER JOIN
                        temp_ca_visit_visitdept_proc_hist G ON 
                                        B.source_system_id = G.source_system_id AND
                                        B.case_num = G.case_num AND
                                        E.num = G.proc_num AND
                                        G.order_key = 1 INNER JOIN
                        `uspidnaproddata.advantx_ods.ca_visit` H ON 
                                        G.source_system_id = H.source_system_id AND
                                        G.visit_num = H.visit_num INNER JOIN
                        `uspidnaproddata.advantx_ods.ut_visittypes` I ON 
                                        H.source_system_id = I.source_system_id AND
                                        H.visittype_num = I.num           
                                        WHERE A.active = 1 AND 
                                          F.key_dos >=     (SELECT DATE_TRUNC(DATE_SUB(CURRENT_DATE(), INTERVAL 3 YEAR), YEAR) 
    AS datetime_three_years_ago)
                                        GROUP BY    A.source_system_id
                                                    ,B.case_num
                                                    ,B.procfee_num
                                                    ,E.quick_code
                                                    ,I.num
                                                    ,I.quick_code) A) A
                                    WHERE rownumber = 1 AND A.source_system_id=V_source_system;   --5,370,377