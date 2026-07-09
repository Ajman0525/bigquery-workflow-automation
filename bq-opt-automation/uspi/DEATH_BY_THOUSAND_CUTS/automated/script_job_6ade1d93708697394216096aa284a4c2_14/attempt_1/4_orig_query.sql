 INSERT INTO ar_billtrans_charge_rank_ce_temp
                (source_system_id
                ,case_num
                ,bill_trans_num
                ,charge_amount)
                SELECT 
                A.source_system_id
                ,A.case_num
                ,A.bill_trans_num
                ,A.charge_amount
                FROM (SELECT 
                        A.source_system_id
                        ,B.case_num
                        ,B.bill_trans_num
                        ,B.charge_amount
                        ,ROW_NUMBER() OVER
                        (PARTITION BY A.source_system_id, b.case_num ORDER BY
                        A.source_system_id, b.case_num, b.charge_amount DESC, b.bill_trans_num) AS RowNumber 
                        FROM  temp_ar_billtrans A INNER JOIN
                        ar_billtrans_charge_ce_temp B ON 
                                A.source_system_id = B.source_system_id AND
                                A.bill_trans_num = B.bill_trans_num INNER JOIN
                        `uspidnaproddata.advantx_ods.ar_billing_period`  C ON 
                                A.source_system_id = C.source_system_id  AND
                                A.bill_period_num = C.num INNER JOIN
                        `uspidnaproddata.advantx_ods.ut_proc_fee`  D ON 
                                A.source_system_id = D.source_system_id  and
                                B.procfee_num = D.num INNER JOIN
                        `uspidnaproddata.advantx_ods.ut_proc` E ON 
                                A.source_system_id = E.source_system_id  and
                                D.proc_num = E.num INNER JOIN
                        `uspidnaproddata.advantx_ods.ca_case`  F ON 
                                A.source_system_id = F.source_system_id  AND
                                B.case_num = F.case_num LEFT OUTER JOIN
                        temp_ca_visit_visitdept_proc_hist  G ON 
                                A.source_system_id = G.source_system_id  AND
                                B.case_num = G.case_num AND
                                E.num = G.proc_num AND
                                G.order_key = 1
                                WHERE  A.active = 1   AND 
                                 F.key_dos >= 
                     (SELECT DATE_TRUNC(DATE_SUB(CURRENT_DATE(), INTERVAL 3 YEAR), YEAR)
    AS datetime_three_years_ago)  
                                ) A
                            WHERE A.RowNumber = 1  AND A.source_system_id=V_source_system;