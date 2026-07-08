WITH
-- CTE for subquery 'F' to gather charge details.
subquery_F AS (
  SELECT
    A.source_system_id,
    A.case_num,
    A.visit_num,
    A.procfee_num,
    A.charge_amount,
    C.tis_client_num,
    A.units
  FROM ar_billtrans_charge_ce_temp AS A
  INNER JOIN temp_ar_billtrans AS B
    ON A.source_system_id = B.source_system_id AND A.bill_trans_num = B.bill_trans_num
  INNER JOIN `uspidnaproddata.advantx_ods.ar_billing_period` AS C
    ON B.source_system_id = C.source_system_id AND B.bill_period_num = C.num
  WHERE B.active = 1
),

-- CTE for subquery 'I' to identify the primary procedure, filtering to row_num=1.
subquery_I AS (
  SELECT
    A.source_system_id,
    A.case_num,
    A.procfee_num,
    A.procedure_code,
    B.tis_client_num,
    A.entity_code,
    A.visit_type_code
  FROM (
    SELECT
      source_system_id,
      case_num,
      procfee_num,
      procedure_code,
      bill_period_num,
      facility_num AS entity_code,
      visit_type_code,
      ROW_NUMBER() OVER (PARTITION BY source_system_id, case_num, bill_period_num ORDER BY procedure_code, facility_num) AS row_num
    FROM PRIMARY_PROCEDURE_ce_temp
  ) AS A
  INNER JOIN `uspidnaproddata.advantx_ods.ar_billing_period` AS B
    ON A.source_system_id = B.source_system_id AND A.bill_period_num = B.num
  WHERE A.row_num = 1
),

-- CTE to pre-calculate the expensive 'generated_case_id' ONCE.
cases_with_id AS (
    SELECT
        source_system_id,
        case_num,
        pers_org_num_pt,
        tisclient_num,
        key_dos,
        refer_phys_num,
        primary_phys_num,
        CAST(
            CONCAT(
                RIGHT(CONCAT('0000', LTRIM(RTRIM(IFNULL(CAST(tisclient_num AS STRING), '')))), 4),
                RIGHT(CONCAT('00000000', LTRIM(RTRIM(IFNULL(CAST(pers_org_num_pt AS STRING), '')))), 8),
                CASE
                    WHEN case_num IS NULL THEN '00000000'
                    ELSE RIGHT(CONCAT('00000000', LTRIM(RTRIM(IFNULL(CAST(case_num AS STRING), '')))), 8)
                END
            ) AS STRING
        ) AS generated_case_id
    FROM `uspidnaproddata.advantx_ods.ca_case`
)

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
                ,case_num
				,tisclient_num
                ,cpt_procedure_code
                ,account_name
                ,case_charge_amount
                ,case_primary_payment_amount
                ,case_copay_payment_amount
                ,case_writeoff_amount
                ,entity_code
                ,refer_physician_code
                ,acuity_flag
                ,units
                ,source_system_id)
SELECT
    A.company_code,
    CAST(A.pers_org_num_org AS STRING) AS faclity_code, -- Note: Preserving original 'faclity_code' typo
    CAST(G.pers_org_num AS STRING) AS physician_code,
    I.procedure_code,
    CAST(B.pers_org_num_pers AS STRING) AS patient_code,
    CAST(C.key_dos AS DATETIME) AS date_of_service,
    C.generated_case_id AS case_id,
    'O' AS patient_type_code,
    'U' AS visit_type_code,
    1 AS case_count,
    0 AS procedure_count,
    NULL AS financial_year,
    NULL AS financial_period,
    NULL AS bill_period_num,
    CAST(NULL AS DATETIME) AS billing_period_start_date,
    C.case_num,
    C.tisclient_num,
    I.procedure_code AS cpt_procedure_code,
    B.account_num AS account_name,
    CAST(SUM(F.charge_amount) AS NUMERIC) AS case_charge_amount,
    CAST(0.00 AS NUMERIC) AS case_primary_payment_amount,
    CAST(0.00 AS NUMERIC) AS case_copay_payment_amount,
    CAST(0.00 AS NUMERIC) AS case_writeoff_amount,
    CAST(I.entity_code AS STRING),
    CAST(IFNULL(C.refer_phys_num, -1) AS STRING) AS refer_physician_code,
    CAST(NULL AS INT64) AS acuity_flag,
    SUM(F.units) AS units,
    A.source_system_id
FROM `uspidnaproddata.edw_advantx.vw_ad_tisclient` AS A
INNER JOIN `uspidnaproddata.advantx_ods.ad_pt` AS B
    ON A.source_system_id = B.source_system_id
INNER JOIN cases_with_id AS C -- Using the CTE with pre-computed case_id
    ON B.source_system_id = C.source_system_id AND B.pers_org_num_pers = C.pers_org_num_pt
LEFT JOIN `uspidnaproddata.advantx_ods.ca_visit` AS D
    ON C.source_system_id = D.source_system_id AND C.case_num = D.case_num
LEFT JOIN temp_ca_visit_visitdept_proc_hist AS E
    ON D.source_system_id = E.source_system_id
    AND D.case_num = E.case_num
    AND D.visit_num = E.visit_num
    AND E.order_key = 1
-- This is now an INNER JOIN because of the WHERE clause on F.charge_amount
INNER JOIN subquery_F AS F
    ON C.source_system_id = F.source_system_id
    AND C.case_num = F.case_num
    AND IFNULL(D.visit_num, -1) = IFNULL(F.visit_num, -1) -- Simplified, but still expensive. Main gain is elsewhere.
    AND A.pers_org_num_org = F.tis_client_num
LEFT JOIN `uspidnaproddata.advantx_ods.ut_phys` AS G
    ON C.source_system_id = G.source_system_id AND C.primary_phys_num = G.num
INNER JOIN subquery_I AS I
    ON F.source_system_id = I.source_system_id AND F.case_num = I.case_num
WHERE
    F.charge_amount IS NOT NULL
    AND C.key_dos >= DATE_TRUNC(DATE_SUB(CURRENT_DATE(), INTERVAL 3 YEAR), YEAR)
    -- The execution plan indicates 'rswl' was used for V_source_system.
    -- Replace 'rswl' with the appropriate variable if this query is part of a script.
    AND A.source_system_id = 'rswl' -- = V_source_system
GROUP BY
    A.company_code,
    A.pers_org_num_org,
    G.pers_org_num,
    I.procedure_code,
    B.pers_org_num_pers,
    C.key_dos,
    C.generated_case_id, -- Grouping by the simple, pre-computed column
    I.visit_type_code,
    C.case_num,
    C.tisclient_num,
    B.account_num,
    I.entity_code,
    A.source_system_id,
    C.refer_phys_num;
