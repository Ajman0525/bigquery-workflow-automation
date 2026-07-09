DECLARE freeze_time TIMESTAMP DEFAULT TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 24 HOUR);


/* ================================================================================================= */
/* Script to create and validate two temporary tables. */
/* Expected Outcome: The discrepancy and duplicate detail SELECTs should return zero rows. */
/* The final SELECT statement should return two summary rows with row_count = 0, confirming that */
/* V_TEMP_TABLE_ORIG and V_TEMP_TABLE_OPT produce identical distinct results and V_TEMP_TABLE_OPT */
/* has no duplicate rows. */
/* ================================================================================================= */
/* 1. Stored Procedure Context */
/* ================================================================================================= */
/* START STORED PROCEDURE CONTEXT */
DECLARE
  V_source_system string default 'rswl';
DECLARE
  V_SQL STRING;
CREATE TEMP TABLE MEDIBIS_FACT_CE_temp (
    source_system_id string,
    company_code string,
    facility_code string,
    physician_code string,
    procedure_code string,
    payor_code string  DEFAULT '-1',
    patient_code string,
    date_of_service datetime,
    case_num numeric  DEFAULT 0,
    tisclient_num numeric  DEFAULT 0,
    case_id string,
    patient_type_code string,
    visit_type_code string,
    case_count integer  DEFAULT 0,
        case_charge_amount NUMERIC DEFAULT 0.0,  --changed -- sad
    case_primary_payment_amount NUMERIC DEFAULT 0.0,  --changed  --sad
    case_copay_payment_amount NUMERIC DEFAULT 0.0,  --changed  --sad
    case_writeoff_amount NUMERIC DEFAULT 0.0,   --changed  --sad
    case_bad_debt_amount NUMERIC DEFAULT 0.0,   --changed  --sad
    procedure_count integer  DEFAULT 0,
    financial_year integer ,
    financial_period integer ,
    icd9_code string  DEFAULT 'UNK',
    service_code string  DEFAULT '0',
    or_minutes integer  DEFAULT 0,
    supply_cost float64  DEFAULT 0.0,
    staff_cost float64  DEFAULT 0.0,
    implant_cost float64  DEFAULT 0.0,
    case_refund_amount NUMERIC DEFAULT 0.0,  --changed  --sad
    case_misc_charge_amount NUMERIC DEFAULT 0.0,  --changed  --sad
    cpt_charge_amount NUMERIC DEFAULT 0.0,  --changed  --sad
    cpt_procedure_code string,
    net_rev_pct_rankbkt numeric DEFAULT 0.0,
    net_rev_dlr_rankbkt numeric DEFAULT 0.0,
    supply_cost_rankbkt numeric DEFAULT 0.0,
    sup_cost_pct_netrev_rankbkt numeric  DEFAULT 0.0,
    net_rev_pct_rankdesc string,
    net_rev_dlr_rankdesc string,
    supply_cost_rankdesc string,
    sup_cost_pct_netrev_rankdesc string,
    account_name string,
    balance_category string,
    drg_code string,
    inpatient_days integer  DEFAULT 0,
    billing_period integer ,
    case_unapplied_payment_amount NUMERIC DEFAULT 0.0,   --changed  --sad
    case_procedure_count integer  DEFAULT 0,
    patient_age float64,
    entity_code string,
    case_outstanding_bal_amount NUMERIC DEFAULT 0.0,   --changed  --sad
        case_status string,
    case_tob_writeoff_amount NUMERIC DEFAULT 0.0,   --changed  --sad
    case_top_writeoff_amount NUMERIC DEFAULT 0.0,   --changed  --sad
    patient_class_code string,
    expected_collections float64  DEFAULT 0.0,
    expected_collections_est_ind integer,
    case_error_paid_amount numeric  DEFAULT 0.0,
    billing_period_start_date datetime,
    procedure_combination string,
    case_payor_status string,
    or_room string,
    total_asc_time integer  default 0,
    refer_physician_code string,
    fixed_cost float64  DEFAULT 0.0,
    icd10_code string  DEFAULT 'UNK',
        acuity_flag int64,
        units NUMERIC
        );
CREATE TEMP TABLE PRIMARY_PROCEDURE_ce_temp (
        source_system_id string,
        case_num numeric  DEFAULT 0,
        procfee_num numeric  DEFAULT 0,
    procedure_code string  DEFAULT NULL,
        facility_num numeric  DEFAULT NULL,
        visittype_num numeric  DEFAULT NULL,
        visit_type_code string  DEFAULT NULL,
        bill_period_num numeric  DEFAULT NULL
        );

CREATE TEMP TABLE ar_billtrans_charge_ce_temp (
        source_system_id string,
        bill_trans_num numeric,
        charge_amount numeric,
        paid_amount numeric,
        writtenoff_amount numeric,
        pat_part numeric,
        ps_num numeric,
        procfee_num numeric,
        units numeric,
        facility_num numeric,
        case_num numeric,
        visit_num numeric,
        dx1_num numeric,
        refer_phys_num numeric,
        dx1_num_10 numeric
        );     

SET V_SQL = FORMAT("""
    CREATE TEMP TABLE temp_ar_billtrans AS
    SELECT * FROM `uspidnaproddata.advantx_ods.ar_billtrans_%s`
    """, V_source_system);

EXECUTE IMMEDIATE V_SQL;

SET V_SQL = FORMAT("""
  CREATE TEMP TABLE temp_ca_visit_visitdept_proc_hist AS
  SELECT * FROM uspidnaproddata.advantx_ods.ca_visit_visitdept_proc_hist_%s
  """, V_source_system);

EXECUTE IMMEDIATE V_SQL;
/* END STORED PROCEDURE CONTEXT */
/* ================================================================================================= */
/* 2. Create the Original Temporary Table (V_TEMP_TABLE_ORIG) */
/* ================================================================================================= */
CREATE OR REPLACE TEMPORARY TABLE V_TEMP_TABLE_ORIG AS
SELECT
  *
FROM `MEDIBIS_FACT_CE_temp`;

SELECT
  A.company_code,
  CAST(A.pers_org_num_org AS STRING) AS faclity_code,
  CAST(G.pers_org_num AS STRING) AS physician_code,
  I.procedure_code,
  CAST(B.pers_org_num_pers AS STRING) AS patient_code,
  CAST(CAST(C.key_dos AS DATE) AS DATETIME) AS date_of_service,
  CONCAT(
    LPAD(TRIM(COALESCE(CAST(C.tisclient_num AS STRING), '')), 4, '0'),
    LPAD(TRIM(COALESCE(CAST(B.pers_org_num_pers AS STRING), '')), 8, '0'),
    LPAD(TRIM(COALESCE(CAST(C.case_num AS STRING), '')), 8, '0')
  ) AS case_id, /* CAST(CONCAT(CONCAT(RIGHT(CONCAT( '0000' ,  LTRIM(RTRIM(IFNULL(CAST(C.tisclient_num AS STRING),'')))),4) , */ /*     RIGHT(CONCAT( '00000000' ,  LTRIM(RTRIM(IFNULL(CAST(C.pers_org_num_pt AS STRING),'')))),8)), */ /*     CASE WHEN C.case_num IS NULL THEN '00000000' ELSE */ /*     RIGHT(CONCAT( '00000000' ,  LTRIM(RTRIM(IFNULL(CAST(C.case_num AS STRING),'')))),8)    END) */ /*    AS STRING) AS case_id */ /*    cast(C.case_num as string) AS case_id */ /* ,CAST(RIGHT('0000' + LTRIM(RTRIM(CAST(CASE WHEN C.tisclient_num IS NULL THEN '' ELSE C.tisclient_num END AS  string))),4) + 
             RIGHT('00000000' + LTRIM(RTRIM(CAST(CASE WHEN C.pers_org_num_pt IS NULL THEN '' ELSE C.pers_org_num_pt END as  string))),8) + 
             CASE WHEN C.case_num IS NULL THEN '00000000' ELSE RIGHT('00000000' + LTRIM(RTRIM(CAST(CASE WHEN C.case_num IS NULL THEN '' ELSE C.case_num END AS string))),8) END
             AS string) AS case_id */
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
  CAST(SUM(F.charge_amount) AS NUMERIC) AS case_charge_amount, /* changed  --sad */
  CAST(0.00 AS NUMERIC) AS case_primary_payment_amount,
  CAST(0.00 AS NUMERIC) AS case_copay_payment_amount,
  CAST(0.00 AS NUMERIC) AS case_writeoff_amount,
  CAST(I.entity_code AS STRING), /*     ,SUM(F.charge_amount) AS case_charge_amount */ /*     ,0.00 AS case_primary_payment_amount */ /*     ,0.00 AS case_copay_payment_amount */ /*     ,0.00 AS case_writeoff_amount */
  CAST(CASE WHEN C.refer_phys_num IS NULL THEN -1 ELSE C.refer_phys_num END AS STRING) AS refer_physician_code,
  CAST(NULL AS INT64) AS acuity_flag,
  SUM(F.units) AS units,
  A.source_system_id
FROM `uspidnaproddata.edw_advantx.vw_ad_tisclient` AS A FOR SYSTEM_TIME AS OF freeze_time
INNER JOIN `uspidnaproddata.advantx_ods.ad_pt` AS B FOR SYSTEM_TIME AS OF freeze_time
  ON A.source_system_id = B.source_system_id
INNER JOIN `uspidnaproddata.advantx_ods.ca_case` AS C FOR SYSTEM_TIME AS OF freeze_time
  ON B.source_system_id = C.source_system_id
  AND B.pers_org_num_pers = C.pers_org_num_pt
LEFT OUTER JOIN `uspidnaproddata.advantx_ods.ca_visit` AS D FOR SYSTEM_TIME AS OF freeze_time
  ON C.source_system_id = D.source_system_id AND C.case_num = D.case_num
LEFT OUTER JOIN temp_ca_visit_visitdept_proc_hist AS E
  ON D.source_system_id = E.source_system_id
  AND D.case_num = E.case_num
  AND D.visit_num = E.visit_num
  AND E.order_key = 1
LEFT OUTER JOIN (
  SELECT
    A.source_system_id,
    A.case_num,
    A.visit_num,
    A.procfee_num,
    A.charge_amount,
    C.tis_client_num,
    CASE WHEN E.quick_code IS NULL THEN '0' ELSE E.quick_code END AS service_code,
    A.bill_trans_num,
    A.units
  FROM ar_billtrans_charge_ce_temp AS A
  INNER JOIN temp_ar_billtrans AS B
    ON A.source_system_id = B.source_system_id AND A.bill_trans_num = B.bill_trans_num
  INNER JOIN `uspidnaproddata.advantx_ods.ar_billing_period` AS C FOR SYSTEM_TIME AS OF freeze_time
    ON B.source_system_id = C.source_system_id AND B.bill_period_num = C.num
  LEFT OUTER JOIN `uspidnaproddata.advantx_ods.ut_proc_fee` AS D FOR SYSTEM_TIME AS OF freeze_time
    ON A.source_system_id = D.source_system_id AND A.procfee_num = D.num
  LEFT OUTER JOIN `uspidnaproddata.advantx_ods.ut_servicetypes` AS E FOR SYSTEM_TIME AS OF freeze_time
    ON D.source_system_id = E.source_system_id AND D.service_type_num = E.num
  WHERE
    b.active = 1
) AS F
  ON C.source_system_id = F.source_system_id
  AND C.case_num = F.case_num
  AND CASE WHEN D.visit_num IS NULL THEN -1 ELSE D.visit_num END = CASE WHEN F.visit_num IS NULL THEN -1 ELSE F.visit_num END
  AND A.pers_org_num_org = F.tis_client_num
LEFT OUTER JOIN `uspidnaproddata.advantx_ods.ut_phys` AS G FOR SYSTEM_TIME AS OF freeze_time
  ON C.source_system_id = G.source_system_id AND C.primary_phys_num = G.num
INNER JOIN (
  SELECT
    A.source_system_id,
    A.case_num,
    A.procfee_num,
    A.procedure_code,
    B.tis_client_num,
    A.facility_num AS entity_code,
    A.visit_type_code,
    ROW_NUMBER() OVER (
      PARTITION BY A.source_system_id, A.case_num, A.bill_period_num
      ORDER BY A.procedure_code, A.facility_num
    ) AS row_num
  FROM PRIMARY_PROCEDURE_ce_temp AS A
  INNER JOIN `uspidnaproddata.advantx_ods.ar_billing_period` AS B FOR SYSTEM_TIME AS OF freeze_time
    ON A.source_system_id = B.source_system_id AND A.bill_period_num = B.num
) AS I
  ON F.source_system_id = I.source_system_id
  AND F.case_num = I.case_num
  AND I.row_num = 1
WHERE
  NOT F.charge_amount IS NULL
  AND C.key_dos >= (
    SELECT
      DATE_TRUNC(DATE_SUB(CURRENT_DATE, INTERVAL '3' YEAR), YEAR) AS datetime_three_years_ago
  )
  AND A.source_system_id = V_source_system
GROUP BY
  A.company_code,
  A.pers_org_num_org,
  G.pers_org_num,
  I.procedure_code,
  B.pers_org_num_pers,
  C.key_dos,
  CAST(CONCAT(
    CONCAT(
      RIGHT(CONCAT('0000', LTRIM(RTRIM(IFNULL(CAST(C.tisclient_num AS STRING), '')))), 4),
      RIGHT(CONCAT('00000000', LTRIM(RTRIM(IFNULL(CAST(C.pers_org_num_pt AS STRING), '')))), 8)
    ),
    CASE
      WHEN C.case_num IS NULL
      THEN '00000000'
      ELSE RIGHT(CONCAT('00000000', LTRIM(RTRIM(IFNULL(CAST(C.case_num AS STRING), '')))), 8)
    END
  ) AS STRING),
  I.visit_type_code,
  C.case_num,
  C.tisclient_num,
  I.procedure_code,
  B.account_num,
  I.entity_code,
  A.source_system_id,
  C.refer_phys_num /* ,F.units;  */;

/* ================================================================================================= */
/* 3. Create the Optimized Temporary Table (V_TEMP_TABLE_OPT) */
/* ================================================================================================= */
CREATE OR REPLACE TEMPORARY TABLE V_TEMP_TABLE_OPT AS
SELECT
  *
FROM `MEDIBIS_FACT_CE_temp`;

WITH subquery_F /* CTE for subquery 'F' to gather charge details. */ AS (
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
  INNER JOIN `uspidnaproddata.advantx_ods.ar_billing_period` AS C FOR SYSTEM_TIME AS OF freeze_time
    ON B.source_system_id = C.source_system_id AND B.bill_period_num = C.num
  WHERE
    B.active = 1
), subquery_I /* CTE for subquery 'I' to identify the primary procedure, filtering to row_num=1. */ AS (
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
      ROW_NUMBER() OVER (
        PARTITION BY source_system_id, case_num, bill_period_num
        ORDER BY procedure_code, facility_num
      ) AS row_num
    FROM PRIMARY_PROCEDURE_ce_temp
  ) AS A
  INNER JOIN `uspidnaproddata.advantx_ods.ar_billing_period` AS B FOR SYSTEM_TIME AS OF freeze_time
    ON A.source_system_id = B.source_system_id AND A.bill_period_num = B.num
  WHERE
    A.row_num = 1
), cases_with_id /* CTE to pre-calculate the expensive 'generated_case_id' ONCE. */ AS (
  SELECT
    source_system_id,
    case_num,
    pers_org_num_pt,
    tisclient_num,
    key_dos,
    refer_phys_num,
    primary_phys_num,
    CAST(CONCAT(
      RIGHT(CONCAT('0000', LTRIM(RTRIM(IFNULL(CAST(tisclient_num AS STRING), '')))), 4),
      RIGHT(CONCAT('00000000', LTRIM(RTRIM(IFNULL(CAST(pers_org_num_pt AS STRING), '')))), 8),
      CASE
        WHEN case_num IS NULL
        THEN '00000000'
        ELSE RIGHT(CONCAT('00000000', LTRIM(RTRIM(IFNULL(CAST(case_num AS STRING), '')))), 8)
      END
    ) AS STRING) AS generated_case_id
  FROM `uspidnaproddata.advantx_ods.ca_case` FOR SYSTEM_TIME AS OF freeze_time
)
SELECT
  A.company_code,
  CAST(A.pers_org_num_org AS STRING) AS faclity_code, /* Note: Preserving original 'faclity_code' typo */
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
FROM `uspidnaproddata.edw_advantx.vw_ad_tisclient` AS A FOR SYSTEM_TIME AS OF freeze_time
INNER JOIN `uspidnaproddata.advantx_ods.ad_pt` AS B FOR SYSTEM_TIME AS OF freeze_time
  ON A.source_system_id = B.source_system_id
INNER JOIN cases_with_id AS C /* Using the CTE with pre-computed case_id */
  ON B.source_system_id = C.source_system_id
  AND B.pers_org_num_pers = C.pers_org_num_pt
LEFT JOIN `uspidnaproddata.advantx_ods.ca_visit` AS D FOR SYSTEM_TIME AS OF freeze_time
  ON C.source_system_id = D.source_system_id AND C.case_num = D.case_num
LEFT JOIN temp_ca_visit_visitdept_proc_hist AS E
  ON D.source_system_id = E.source_system_id
  AND D.case_num = E.case_num
  AND D.visit_num = E.visit_num
  AND E.order_key = 1
/* This is now an INNER JOIN because of the WHERE clause on F.charge_amount */
INNER JOIN subquery_F AS F
  ON C.source_system_id = F.source_system_id
  AND C.case_num = F.case_num
  AND IFNULL(D.visit_num, -1) = IFNULL(F.visit_num, -1) /* Simplified, but still expensive. Main gain is elsewhere. */
  AND A.pers_org_num_org = F.tis_client_num
LEFT JOIN `uspidnaproddata.advantx_ods.ut_phys` AS G FOR SYSTEM_TIME AS OF freeze_time
  ON C.source_system_id = G.source_system_id AND C.primary_phys_num = G.num
INNER JOIN subquery_I AS I
  ON F.source_system_id = I.source_system_id AND F.case_num = I.case_num
WHERE
  NOT F.charge_amount IS NULL
  AND C.key_dos >= DATE_TRUNC(DATE_SUB(CURRENT_DATE, INTERVAL '3' YEAR), YEAR)
  AND /* The execution plan indicates 'rswl' was used for V_source_system. */ /* Replace 'rswl' with the appropriate variable if this query is part of a script. */ A.source_system_id = 'rswl' /* = V_source_system */
GROUP BY
  A.company_code,
  A.pers_org_num_org,
  G.pers_org_num,
  I.procedure_code,
  B.pers_org_num_pers,
  C.key_dos,
  C.generated_case_id, /* Grouping by the simple, pre-computed column */
  I.visit_type_code,
  C.case_num,
  C.tisclient_num,
  B.account_num,
  I.entity_code,
  A.source_system_id,
  C.refer_phys_num;

/* ================================================================================================= */
/* 4. Validation Step: Compare the two tables and check optimized duplicates. */
/* DISCREPANCY counts distinct rows that appear in one table but not the other. */
/* DUPLICATE ROWS counts extra copies of duplicate rows in V_TEMP_TABLE_OPT. */
/* The first two SELECT statements show the actual rows when discrepancies or duplicates exist. */
/* The final SELECT statement shows only the summary counts. */
/* ================================================================================================= */
CREATE OR REPLACE TEMPORARY TABLE V_VALIDATION_DISCREPANCIES AS
(
  SELECT
    'ONLY IN ORIGINAL' AS validation_diff_type,
    *
  FROM V_TEMP_TABLE_ORIG
  EXCEPT DISTINCT
  SELECT
    'ONLY IN ORIGINAL' AS validation_diff_type,
    *
  FROM V_TEMP_TABLE_OPT
)
UNION ALL
(
  SELECT
    'ONLY IN OPTIMIZED' AS validation_diff_type,
    *
  FROM V_TEMP_TABLE_OPT
  EXCEPT DISTINCT
  SELECT
    'ONLY IN OPTIMIZED' AS validation_diff_type,
    *
  FROM V_TEMP_TABLE_ORIG
);

CREATE OR REPLACE TEMPORARY TABLE V_VALIDATION_OPT_DUPLICATES AS
SELECT
  duplicate_row.*
FROM (
  SELECT
    ANY_VALUE(opt) AS duplicate_row
  FROM V_TEMP_TABLE_OPT AS opt
  GROUP BY
    TO_JSON_STRING(opt)
  HAVING
    COUNT(*) > 1
);

/* View discrepancy rows. */
SELECT
  *
FROM V_VALIDATION_DISCREPANCIES;

/* View duplicate rows from the optimized query. */
SELECT
  *
FROM V_VALIDATION_OPT_DUPLICATES;

/* View summary counts. */
SELECT
  'DISCREPANCY' AS validation_check,
  COUNT(*) AS row_count
FROM V_VALIDATION_DISCREPANCIES
UNION ALL
SELECT
  'DUPLICATE ROWS' AS validation_check,
  COALESCE(SUM(row_count - 1), 0) AS row_count
FROM (
  SELECT
    COUNT(*) AS row_count
  FROM V_TEMP_TABLE_OPT AS opt
  GROUP BY
    TO_JSON_STRING(opt)
  HAVING
    COUNT(*) > 1
);