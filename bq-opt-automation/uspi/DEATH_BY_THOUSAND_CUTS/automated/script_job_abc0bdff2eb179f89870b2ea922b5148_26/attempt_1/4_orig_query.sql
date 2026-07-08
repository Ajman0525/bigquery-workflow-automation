MERGE MEDIBIS_FACT_CE_temp AS A
USING ( SELECT A.source_system_id,b.case_id, b.total_asc_time
                        ,b.case_primary_payment_amount
                        ,b.case_unapplied_payment_amount
                        ,b.case_copay_payment_amount
                        ,b.case_outstanding_bal_amount
                        ,b.case_writeoff_amount
                        ,b.case_tob_writeoff_amount
            ,b.case_top_writeoff_amount,b.balance_category
                        ,b.case_bad_debt_amount,b.implant_cost
            ,b.expected_collections
            ,b.expected_collections_est_ind, 
    ROW_NUMBER() OVER (PARTITION BY A.source_system_id, A.case_id ORDER BY b.total_asc_time
                        ,b.case_primary_payment_amount
                        ,b.case_unapplied_payment_amount
                        ,b.case_copay_payment_amount
                        ,b.case_outstanding_bal_amount
                        ,b.case_writeoff_amount
                        ,b.case_tob_writeoff_amount
            ,b.case_top_writeoff_amount,b.balance_category
                        ,b.case_bad_debt_amount,b.implant_cost
            ,b.expected_collections
            ,b.expected_collections_est_ind) AS row_num
FROM 
MEDIBIS_FACT_CE_temp A INNER JOIN       
        
                    (SELECT 
                        source_system_id
                        ,case_id
                        ,total_asc_time
                        ,case_primary_payment_amount
                        ,case_unapplied_payment_amount
                        ,case_copay_payment_amount
                        ,case_outstanding_bal_amount
                        ,case_writeoff_amount
                        ,case_tob_writeoff_amount
            ,case_top_writeoff_amount,balance_category
                        ,case_bad_debt_amount,implant_cost
            ,expected_collections
            ,expected_collections_est_ind
            FROM `uspidnaproddata.edw_advantx.medibis_dim_case` 
                        ) B ON  A.source_system_id = B.source_system_id 
                        where A.case_id = B.case_id) src on
            SRC.source_system_id =A.source_system_id AND
            SRC.case_id = A.case_id AND
      A.source_system_id = V_source_system AND
            SRC.row_num =1          
            WHEN  MATCHED THEN 
            UPDATE SET  
                total_asc_time =    src.total_asc_time
               ,case_primary_payment_amount = src.case_primary_payment_amount
                   ,case_unapplied_payment_amount = src.case_unapplied_payment_amount
                   ,case_copay_payment_amount = src.case_copay_payment_amount
                   ,case_outstanding_bal_amount = src.case_outstanding_bal_amount
                   ,case_writeoff_amount = src.case_writeoff_amount
                   ,case_tob_writeoff_amount = src.case_tob_writeoff_amount
                   ,case_top_writeoff_amount = src.case_top_writeoff_amount
                   ,balance_category = src.balance_category
                   ,case_bad_debt_amount = src.case_bad_debt_amount
                   ,implant_cost = src.implant_cost
           ,expected_collections = src.expected_collections
           ,expected_collections_est_ind = src.expected_collections_est_ind;