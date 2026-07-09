INSERT INTO ar_billtrans_charge_rank_ce_temp
                (source_system_id
                ,case_num
                ,bill_trans_num
                ,charge_amount)
WITH FilteredData AS (
    SELECT
        A.source_system_id,
        B.case_num,
        B.bill_trans_num,
        B.charge_amount,
        ROW_NUMBER() OVER(
            PARTITION BY A.source_system_id, B.case_num 
            ORDER BY B.charge_amount DESC, B.bill_trans_num ASC
        ) AS RowNumber
    FROM temp_ar_billtrans AS A
    INNER JOIN ar_billtrans_charge_ce_temp AS B 
        ON A.source_system_id = B.source_system_id 
        AND A.bill_trans_num = B.bill_trans_num
    INNER JOIN `uspidnaproddata.advantx_ods.ar_billing_period` AS C 
        ON A.source_system_id = C.source_system_id  
        AND A.bill_period_num = C.num
    INNER JOIN `uspidnaproddata.advantx_ods.ut_proc_fee` AS D 
        ON A.source_system_id = D.source_system_id  
        AND B.procfee_num = D.num
    INNER JOIN `uspidnaproddata.advantx_ods.ut_proc` AS E 
        ON A.source_system_id = E.source_system_id  
        AND D.proc_num = E.num
    INNER JOIN `uspidnaproddata.advantx_ods.ca_case` AS F 
        ON A.source_system_id = F.source_system_id  
        AND B.case_num = F.case_num
    LEFT OUTER JOIN temp_ca_visit_visitdept_proc_hist AS G 
        ON A.source_system_id = G.source_system_id  
        AND B.case_num = G.case_num 
        AND E.num = G.proc_num 
        AND G.order_key = 1
    WHERE A.active = 1
      AND F.key_dos >= DATE_TRUNC(DATE_SUB(CURRENT_DATE(), INTERVAL 3 YEAR), YEAR)
      AND A.source_system_id = V_source_system
)
SELECT
    source_system_id,
    case_num,
    bill_trans_num,
    charge_amount
FROM FilteredData
WHERE RowNumber = 1;
