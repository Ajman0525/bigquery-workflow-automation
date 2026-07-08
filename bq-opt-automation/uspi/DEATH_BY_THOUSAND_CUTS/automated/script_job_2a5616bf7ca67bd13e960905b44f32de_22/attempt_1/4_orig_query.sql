INSERT INTO	expected_collection_pct_payors_ce_temp
	SELECT		source_system_id, payor_code,
			CASE WHEN SUM(charge_amount) = 0.0 then 0.0 ELSE SUM(paid_amount)/SUM(charge_amount) END AS expected_collection_pct
			FROM
			(
			SELECT			        a.source_system_id ,g.payor_code,
							a.case_num,
							SUM(b.charge_amount) as charge_amount,
							SUM(b.paid_amount) as paid_amount,
							SUM(b.writtenoff_amount) as writtenoff_amount
                                                        --SUM(charge_amount) - SUM(paid_amount) - SUM(writtenoff_amount) as sum_amount							
		FROM	`uspidnaproddata.advantx_ods.ca_case` a
		INNER JOIN  (SELECT * FROM ar_billtrans_charge_ce_temp) b
			        on      a.source_system_id = b.source_system_id and
					a.case_num = b.case_num
		INNER JOIN `uspidnaproddata.advantx_ods.ut_proc_fee` d
			on		b.source_system_id = d.source_system_id and
					b.procfee_num = d.num
		INNER JOIN `uspidnaproddata.advantx_ods.ut_proc` e
			on		d.source_system_id = e.source_system_id and
					d.proc_num = e.num
		INNER JOIN (SELECT 
						ROW_NUMBER() OVER(PARTITION BY a_s.source_system_id, a_s.case_num ORDER BY policy_effective_date DESC) AS RowNum, 
						a_s.source_system_id, 
						a_s.case_num, 
						b_s.pers_org_num as payor_code, 
						IFNULL(copay_amt,0.00) as copay_amt
		FROM `uspidnaproddata.advantx_ods.ad_case_ps_ins`  a_s  INNER JOIN		     
		`uspidnaproddata.advantx_ods.ad_ps_rolehist_ins`  b_s 
                                                ON a_s.role_num = 6 AND
					        a_s.source_system_id = b_s.source_system_id AND
						a_s.ps_num = b_s.ps_num and 
						a_s.role_num = b_s.role_num AND
						b_s.pers_org_num IS NOT NULL ) G ON g.RowNum = 1 AND
								    a.source_system_id = g.source_system_id AND
								    a.case_num = g.case_num 
		WHERE	CAST(key_dos as DATE) BETWEEN DATE_TRUNC(DATE_SUB(CURRENT_DATE(), INTERVAL 3 YEAR), YEAR) and  CURRENT_DATE
				and e.quick_code NOT IN ('ERROR','DUMMY')
        and a.source_system_id = V_source_system
                        GROUP BY 		a.source_system_id, payor_code, a.case_num
                        HAVING			charge_amount - paid_amount - writtenoff_amount <= 10.00
			--HAVING			SUM(charge_amount) - SUM(paid_amount) - SUM(writtenoff_amount) <= 10.00
			) cases
			GROUP BY source_system_id,payor_code
