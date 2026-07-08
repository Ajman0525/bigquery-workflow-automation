INSERT INTO MEDIBIS_FACT_CE_temp
    (company_code, facility_code, physician_code, procedure_code, patient_code, date_of_service, case_id, patient_type_code, visit_type_code, case_count, procedure_count, financial_year, financial_period, billing_period, billing_period_start_date, service_code, case_num, tisclient_num, cpt_procedure_code, account_name, case_charge_amount, case_primary_payment_amount, case_copay_payment_amount, case_writeoff_amount, cpt_charge_amount, entity_code, refer_physician_code, units, source_system_id)
WITH
  cte_F AS (
    SELECT
        charge.source_system_id,
        charge.case_num,
        charge.visit_num,
        charge.procfee_num,
        charge.charge_amount,
        charge.units,
        period.tis_client_num,
        IFNULL(st.quick_code, '0') AS service_code
    FROM `ar_billtrans_charge_ce_temp` AS charge
    INNER JOIN `temp_ar_billtrans` AS trans
        ON charge.source_system_id = trans.source_system_id AND charge.bill_trans_num = trans.bill_trans_num
    INNER JOIN `uspidnaproddata.advantx_ods.ar_billing_period` AS period
        ON trans.source_system_id = period.source_system_id AND trans.bill_period_num = period.num
    INNER JOIN `uspidnaproddata.advantx_ods.ut_proc_fee` AS proc_fee
        ON charge.source_system_id = proc_fee.source_system_id AND charge.procfee_num = proc_fee.num
    LEFT JOIN `uspidnaproddata.advantx_ods.ut_servicetypes` AS st
        ON proc_fee.source_system_id = st.source_system_id AND proc_fee.service_type_num = st.num
    WHERE trans.active = 1
  ),
  cte_I AS (
    SELECT
        source_system_id,
        case_num,
        procedure_code,
        entity_code
    FROM (
        SELECT
            pp.source_system_id,
            pp.case_num,
            pp.procedure_code,
            pp.facility_num AS entity_code,
            ROW_NUMBER() OVER (PARTITION BY pp.source_system_id, pp.case_num, pp.bill_period_num ORDER BY pp.procedure_code, pp.facility_num) AS row_num
        FROM `PRIMARY_PROCEDURE_ce_temp` AS pp
        INNER JOIN `uspidnaproddata.advantx_ods.ar_billing_period` AS period
            ON pp.source_system_id = period.source_system_id AND pp.bill_period_num = period.num
    )
    WHERE row_num = 1
  ),
  cte_L AS (
    SELECT
        fee.source_system_id,
        fee.num AS procfee_num,
        proc.quick_code AS cpt_procedure_code
    FROM `uspidnaproddata.advantx_ods.ut_proc_fee` AS fee
    INNER JOIN `uspidnaproddata.advantx_ods.ut_proc` AS proc
        ON fee.source_system_id = proc.source_system_id AND fee.proc_num = proc.num
  )
SELECT
    DISTINCT A.company_code,
    CAST(A.pers_org_num_org AS STRING) AS faclity_code,
    CAST(G.pers_org_num AS STRING) AS physician_code,
    I.procedure_code,
    CAST(B.pers_org_num_pers AS STRING) AS patient_code,
    CAST(CAST(C.key_dos AS DATE) AS DATETIME) AS date_of_service,
    CONCAT(
        LPAD(IFNULL(CAST(C.tisclient_num AS STRING), ''), 4, '0'),
        LPAD(IFNULL(CAST(C.pers_org_num_pt AS STRING), ''), 8, '0'),
        IFNULL(LPAD(CAST(C.case_num AS STRING), 8, '0'), '00000000')
    ) AS case_id,
    'O' AS patient_type_code,
    'U' AS visit_type_code,
    0 AS case_count,
    CAST(F.units AS INT64) AS procedure_count,
    NULL AS financial_year,
    NULL AS financial_period,
    NULL AS bill_period_num,
    CAST(NULL AS DATETIME) AS billing_period_start_date,
    F.service_code,
    C.case_num,
    C.tisclient_num,
    L.cpt_procedure_code,
    B.account_num AS account_name,
    CAST(0.00 AS NUMERIC) AS case_charge_amount,
    CAST(0.00 AS NUMERIC) AS case_primary_payment_amount,
    CAST(0.00 AS NUMERIC) AS case_copay_payment_amount,
    CAST(0.00 AS NUMERIC) AS case_writeoff_amount,
    F.charge_amount AS cpt_charge_amount,
    CAST(I.entity_code AS STRING) AS entity_code,
    CAST(IFNULL(C.refer_phys_num, -1) AS STRING) AS refer_physician_code,
    F.units,
    A.source_system_id
FROM `uspidnaproddata.edw_advantx.vw_ad_tisclient` AS A
INNER JOIN `uspidnaproddata.advantx_ods.ad_pt` AS B
    ON A.source_system_id = B.source_system_id
INNER JOIN `uspidnaproddata.advantx_ods.ca_case` AS C
    ON B.source_system_id = C.source_system_id AND B.pers_org_num_pers = C.pers_org_num_pt
LEFT JOIN `uspidnaproddata.advantx_ods.ca_visit` AS D
    ON C.source_system_id = D.source_system_id AND C.case_num = D.case_num
LEFT JOIN `temp_ca_visit_visitdept_proc_hist` AS E
    ON D.source_system_id = E.source_system_id AND D.case_num = E.case_num AND D.visit_num = E.visit_num AND E.order_key = 1
INNER JOIN cte_F AS F
    ON C.source_system_id = F.source_system_id
    AND C.case_num = F.case_num
    AND IFNULL(D.visit_num, -1) = IFNULL(F.visit_num, -1)
    AND A.pers_org_num_org = F.tis_client_num
LEFT JOIN `uspidnaproddata.advantx_ods.ut_phys` AS G
    ON C.source_system_id = G.source_system_id AND C.primary_phys_num = G.num
LEFT JOIN cte_I AS I
    ON F.source_system_id = I.source_system_id AND F.case_num = I.case_num
LEFT JOIN `uspidnaproddata.advantx_ods.ut_visittypes` AS K
    ON D.source_system_id = K.source_system_id AND D.visittype_num = K.num
LEFT JOIN cte_L AS L
    ON F.source_system_id = L.source_system_id AND F.procfee_num = L.procfee_num
WHERE
    F.charge_amount IS NOT NULL
    AND C.key_dos >= DATE_TRUNC(DATE_SUB(CURRENT_DATE(), INTERVAL 3 YEAR), YEAR)
    AND A.source_system_id = V_source_system;
