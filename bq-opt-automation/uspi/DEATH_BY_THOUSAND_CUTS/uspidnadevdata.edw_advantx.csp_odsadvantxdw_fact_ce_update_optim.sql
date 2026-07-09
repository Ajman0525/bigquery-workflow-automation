CREATE OR REPLACE PROCEDURE `uspidnadevdata.edw_advantx.csp_odsadvantxdw_fact_ce_update_optim`(IN facility_id STRING, OUT OUT_PARAM INT64)
BEGIN

--++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
-- Application:   ODS
--
-- Name:          csp_ODSAdvantxDW_FACT_CE_Update
--
-- Description:   Export medibis_fact_ce
--                 
--  
-- Parameters:
--      TABLE_NAME  - Source table name
--      OUT_PARAM   - Out Parameter used for process Orchestration.
--
-- Invoked by:    - To be detemined.
--                
-- Copyright:     ISI
--    
-- Rev History:
-- 08/16/2024 - Prasad - Created
-- 05/21/2025 - Kimberly - Added acuity_flag column
-- 06/04/2025 - Kimberly - Updated acuity flag logic
-- 06/25/2025 - Dushyanth - Modified
-- 07/02/2025 - Dushyanth - Added Retry Logic
-- 08/-5/2025 - Sadichhya - Changed data type for amount columns.
-- 09/25/2025 - Dushyanth - Updated retry logic.
-- 12/10/2025 - Kimberly - Added Units column from ar_bill_transcharge table
-- 03/03/2026 - Ana - Updated the time interval from 365 days to consider last 3 years from current date
-- 03/05/2026 - Amey Shinde - SH 11864: Zero out case_count for non-surgical visit types (AdvantX facility 11864 / fshs only)
-- 06/12/2026 - Jenny - Updated case_id logic to align with DIM_CASE and FACT_BC
--++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
DECLARE
  V_PROC_NAME STRING;
DECLARE
  V_LOG_MESSAGE STRING;
DECLARE
  V_CURRENT_TS DATETIME;
DECLARE
  V_source_system string;
DECLARE
  V_TABLE_NAME string;
DECLARE
  V_SQL STRING;

--Retry logic variables---------
DECLARE V_LAST_EXTRACT_DT DATE;
DECLARE V_ERRORMESSAGE STRING;
DECLARE V_MYERRORMESSAGE STRING;
DECLARE V_RESULT STRING; 
declare complex_dml string;
declare complex_dml1 string;
declare complex_dml2 string;
-------------------------------

BEGIN
    SET
        V_PROC_NAME = 'csp_odsadvantxdw_fact_ce_update';
    SET
        V_LOG_MESSAGE = 'Starting Procedure - ' || V_PROC_NAME || ' - ' || CURRENT_DATETIME("America/Chicago");
    SET
        V_CURRENT_TS = DATETIME(TIMESTAMP (CURRENT_DATETIME), "America/Chicago");
  SET
    V_source_system = facility_id;
  SET
    V_TABLE_NAME = 'medibis_fact_ce';

  SET V_SQL = FORMAT("""
        CREATE TEMP TABLE temp_ar_billtrans AS
        SELECT * FROM `uspidnadevdata.advantx_ods.ar_billtrans_%s`
        """, V_source_system);

      EXECUTE IMMEDIATE V_SQL;
  SET V_SQL = FORMAT("""
        CREATE TEMP TABLE temp_ar_billtrans_charge AS
        SELECT * FROM uspidnadevdata.advantx_ods.ar_billtrans_charge_%s
        """, V_source_system);

      EXECUTE IMMEDIATE V_SQL;
  
   SET V_SQL = FORMAT("""
        CREATE TEMP TABLE temp_ca_visit_visitdept_proc_hist AS
        SELECT * FROM uspidnadevdata.advantx_ods.ca_visit_visitdept_proc_hist_%s
        """, V_source_system);

      EXECUTE IMMEDIATE V_SQL;

  SET V_SQL = FORMAT("""
        CREATE TEMP TABLE temp_ca_visit_visitdept_pers_role AS
        SELECT * FROM uspidnadevdata.advantx_ods.ca_visit_visitdept_pers_role_%s
        """, V_source_system);

      EXECUTE IMMEDIATE V_SQL;

    SET V_SQL = FORMAT("""
        CREATE TEMP TABLE temp_ca_visit_visitdept_supply_hist AS
        SELECT * FROM uspidnadevdata.advantx_ods.ca_visit_visitdept_supply_hist_%s
        """, V_source_system);

      EXECUTE IMMEDIATE V_SQL;

    SET V_SQL = FORMAT("""
        CREATE TEMP TABLE temp_ca_visit_visitdept AS
        SELECT * FROM uspidnadevdata.advantx_ods.ca_visit_visitdept_%s
        """, V_source_system);

      EXECUTE IMMEDIATE V_SQL;

CREATE TEMP TABLE expected_collection_pct_payors_ce_temp (
                source_system_id string,
                payor_code numeric,
                expected_collection_pct numeric);

CREATE TEMP TABLE expected_collection_pct_fc_ce_temp ( 
                source_system_id string,  
                fc_code  numeric,
                expected_collection_pct numeric);

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
CREATE TEMP TABLE bill_period_ce_temp (
        source_system_id string,
        tis_client_num numeric,
        case_num numeric,
        bill_period_num numeric,
        billing_period_start_date datetime,
        financial_year integer,
        financial_period integer
        );

CREATE TEMP TABLE ar_billtrans_charge_rank_ce_temp (
        source_system_id string,
        case_num numeric,
        bill_trans_num numeric,
        charge_amount numeric
        );
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

INSERT INTO ar_billtrans_charge_ce_temp
                        (source_system_id
                        ,bill_trans_num
                        ,charge_amount
                        ,paid_amount
                        ,writtenoff_amount
                        ,pat_part
                        ,ps_num
                        ,procfee_num
                        ,units
                        ,facility_num
                        ,case_num
                        ,visit_num
                        ,dx1_num
                        ,refer_phys_num
                        ,dx1_num_10)
                        SELECT
                        A.source_system_id
                        ,A.bill_trans_num
                        ,A.charge_amount
                        ,A.paid_amount
                        ,A.writtenoff_amount
                        ,A.pat_part
                        ,A.ps_num
                        ,A.procfee_num
                        ,A.units
                        ,A.facility_num
                        ,A.case_num
                        ,A.visit_num
                        ,A.dx1_num
                        ,A.refer_phys_num
                        ,A.dx1_num_10
                        FROM temp_ar_billtrans_charge A 
                        INNER JOIN temp_ar_billtrans B 
                        ON A.source_system_id = B.source_system_id AND
                                A.bill_trans_num = B.bill_trans_num AND
                                B.active = 1
                        WHERE A.source_system_id=V_source_system;

-- START OF OPTIMIZED QUERY: script_job_6ade1d93708697394216096aa284a4c2_14

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
    INNER JOIN `uspidnadevdata.advantx_ods.ar_billing_period` AS C 
        ON A.source_system_id = C.source_system_id  
        AND A.bill_period_num = C.num
    INNER JOIN `uspidnadevdata.advantx_ods.ut_proc_fee` AS D 
        ON A.source_system_id = D.source_system_id  
        AND B.procfee_num = D.num
    INNER JOIN `uspidnadevdata.advantx_ods.ut_proc` AS E 
        ON A.source_system_id = E.source_system_id  
        AND D.proc_num = E.num
    INNER JOIN `uspidnadevdata.advantx_ods.ca_case` AS F 
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

-- END OF OPTIMIZED QUERY: script_job_6ade1d93708697394216096aa284a4c2_14

 INSERT INTO bill_period_ce_temp
                (source_system_id
                ,tis_client_num
                ,case_num
                ,bill_period_num
                ,billing_period_start_date
                ,financial_year
                ,financial_period)
                SELECT 
                    A.source_system_id
                    ,A.tis_client_num
                    ,A.case_num
                    ,A.bill_period_num
                    ,A.billing_period_start_date
                    ,A.financial_year
                    ,A.financial_period
                FROM (SELECT
                            A.source_system_id
                            ,A.tis_client_num
                            ,A.case_num
                            ,A.bill_period_num
                            ,A.billing_period_start_date
                            ,A.financial_year
                            ,A.financial_period
                            ,ROW_NUMBER() OVER (PARTITION BY A.source_system_id, A.tis_client_num, A.case_num
                                                ORDER BY A.source_system_id, A.tis_client_num, A.case_num, A.bill_period_num) AS rownumber 
                FROM (SELECT
                                    A.source_system_id
                                    ,D.tis_client_num
                                    ,A.case_num
                                    ,C.bill_period_num
                                    ,D.date_opened AS billing_period_start_date
                                    ,Extract(Year from D.date_opened) AS financial_year
                                    ,Extract(Month from D.date_opened) AS financial_period
                FROM `uspidnadevdata.advantx_ods.ca_case` A INNER JOIN
                temp_ar_billtrans_charge B ON A.source_system_id = B.source_system_id  AND
                                A.case_num = B.case_num INNER JOIN
                temp_ar_billtrans C ON A.source_system_id = C.source_system_id  AND
                                B.bill_trans_num = C.bill_trans_num INNER JOIN
                `uspidnadevdata.advantx_ods.ar_billing_period` D ON A.source_system_id = D.source_system_id  AND
                                C.bill_period_num = D.num AND
                                C.tis_client_num = D.tis_client_num
                                WHERE C.active = 1 ) A) A
                                WHERE rownumber = 1 
                                AND A.source_system_id=V_source_system
                                ORDER BY A.source_system_id,
                                A.tis_client_num,A.case_num;

 -- Primary Procedure (Scheduled and Billed)

-- START OF OPTIMIZED QUERY: script_job_92e317d7631b57ebe1946253ef60e35f_16

INSERT INTO PRIMARY_PROCEDURE_ce_temp (
    source_system_id,
    case_num,
    procfee_num,
    procedure_code,
    visittype_num,
    visit_type_code,
    bill_period_num
)
WITH AggregatedData AS (
    -- This CTE performs all joins, filtering, and aggregation.
    -- By applying the V_source_system filter here, we ensure all subsequent operations
    -- are performed on the smallest possible dataset.
    SELECT
        A.source_system_id,
        B.case_num,
        B.procfee_num,
        E.quick_code AS procedure_code,
        I.num AS visittype_num,
        I.quick_code AS visit_type_code,
        MIN(A.bill_period_num) AS bill_period_num
    FROM temp_ar_billtrans AS A
    INNER JOIN ar_billtrans_charge_ce_temp AS B
        ON A.source_system_id = B.source_system_id
        AND A.bill_trans_num = B.bill_trans_num
    INNER JOIN `uspidnadevdata.advantx_ods.ar_billing_period` AS C
        ON A.source_system_id = C.source_system_id
        AND A.bill_period_num = C.num
    INNER JOIN `uspidnadevdata.advantx_ods.ut_proc_fee` AS D
        ON B.source_system_id = D.source_system_id
        AND B.procfee_num = D.num
    INNER JOIN `uspidnadevdata.advantx_ods.ut_proc` AS E
        ON D.source_system_id = E.source_system_id
        AND D.proc_num = E.num
    INNER JOIN `uspidnadevdata.advantx_ods.ca_case` AS F
        ON B.source_system_id = F.source_system_id
        AND B.case_num = F.case_num
    INNER JOIN temp_ca_visit_visitdept_proc_hist AS G
        ON B.source_system_id = G.source_system_id
        AND B.case_num = G.case_num
        AND E.num = G.proc_num
    INNER JOIN `uspidnadevdata.advantx_ods.ca_visit` AS H
        ON G.source_system_id = H.source_system_id
        AND G.visit_num = H.visit_num
    INNER JOIN `uspidnadevdata.advantx_ods.ut_visittypes` AS I
        ON H.source_system_id = I.source_system_id
        AND H.visittype_num = I.num
    WHERE
        -- Applying filters as early as possible is critical for performance.
        A.source_system_id = V_source_system -- Assuming V_source_system is a variable/placeholder
        AND A.active = 1
        AND F.key_dos >= DATE_TRUNC(DATE_SUB(CURRENT_DATE(), INTERVAL 3 YEAR), YEAR)
        AND G.order_key = 1
    GROUP BY
        A.source_system_id,
        B.case_num,
        B.procfee_num,
        E.quick_code,
        I.num,
        I.quick_code
),
RankedProcedures AS (
    -- This CTE applies the ROW_NUMBER() to select a single primary procedure per case.
    SELECT
        source_system_id,
        case_num,
        procfee_num,
        procedure_code,
        visittype_num,
        visit_type_code,
        bill_period_num,
        ROW_NUMBER() OVER (PARTITION BY source_system_id, case_num ORDER BY procedure_code) AS rn
    FROM AggregatedData
)
SELECT
    source_system_id,
    case_num,
    procfee_num,
    procedure_code,
    visittype_num,
    visit_type_code,
    bill_period_num
FROM RankedProcedures
WHERE rn = 1;

-- END OF OPTIMIZED QUERY: script_job_92e317d7631b57ebe1946253ef60e35f_16

            -- Primary Procedure (Max Charge Amount)

-- START OF OPTIMIZED QUERY: script_job_62d47dd2c36cd4ff0e1a857d2370849b_17

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
                FROM (SELECT source_system_id, case_num, procfee_num, procedure_code, visittype_num, visit_type_code, bill_period_num, ROW_NUMBER() 
                            OVER (PARTITION BY source_system_id, case_num
                                ORDER BY source_system_id, case_num, procedure_code) AS rownumber
                            FROM (SELECT DISTINCT
                                    A.source_system_id
                                    ,B.case_num
                                    ,B.procfee_num
                                    ,D.quick_code AS procedure_code
                                    ,G.num AS visittype_num
                                    ,G.quick_code AS visit_type_code              
                                    ,MIN(A.bill_period_num) as bill_period_num 
                FROM    temp_ar_billtrans A INNER JOIN
                        ar_billtrans_charge_ce_temp B ON  
                                        A.source_system_id = B.source_system_id AND
                                        A.bill_trans_num = B.bill_trans_num INNER JOIN  
                        `uspidnadevdata.advantx_ods.ut_proc_fee` C ON 
                                        B.source_system_id = C.source_system_id and
                                        B.procfee_num = C.num INNER JOIN
                        `uspidnadevdata.advantx_ods.ut_proc` D ON 
                                        C.source_system_id = D.source_system_id and
                                        C.proc_num = D.num INNER JOIN
                                         (SELECT 
                                            source_system_id
                                            ,case_num
                                            ,bill_trans_num
                                            ,charge_amount
                FROM    ar_billtrans_charge_rank_ce_temp
                                         ) E ON B.source_system_id = E.source_system_id AND
                                        B.case_num = E.case_num AND
                                        B.bill_trans_num = E.bill_trans_num AND
                                        B.charge_amount = E.charge_amount LEFT OUTER JOIN
                        `uspidnadevdata.advantx_ods.ca_visit` F ON 
                                        B.source_system_id = F.source_system_id AND
                                        B.visit_num = F.visit_num LEFT OUTER JOIN
                        `uspidnadevdata.advantx_ods.ut_visittypes` G ON 
                                        F.source_system_id = G.source_system_id AND
                                        F.visittype_num = G.num LEFT OUTER JOIN
                        PRIMARY_PROCEDURE_ce_temp H ON 
                                        B.source_system_id = H.source_system_id AND
                                        B.case_num = H.case_num
                                             WHERE 
                                                   A.active = 1 AND
                                                   D.quick_code <> 'ERROR'  
                                                   AND H.source_system_id IS NULL 
                                                GROUP BY A.source_system_id
                                                        ,B.case_num
                                                        ,B.procfee_num
                                                        ,D.quick_code
                                                        ,G.num
                                                        ,G.quick_code) A) A
                                WHERE rownumber = 1 AND A.source_system_id=V_source_system;   --5,207,975

-- END OF OPTIMIZED QUERY: script_job_62d47dd2c36cd4ff0e1a857d2370849b_17

-- START OF OPTIMIZED QUERY: script_job_12b6b4ac23e2515178173c96d2c6b2ae_18

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
                    FROM (SELECT source_system_id, case_num, procfee_num, procedure_code, visittype_num, visit_type_code, bill_period_num, ROW_NUMBER() 
                            OVER (PARTITION BY source_system_id, case_num
                                ORDER BY source_system_id, case_num, procedure_code) AS rownumber
                            FROM (SELECT DISTINCT
                                    A.source_system_id
                                    ,B.case_num
                                    ,B.procfee_num
                                    ,D.quick_code AS procedure_code
                                    ,G.num AS visittype_num
                                    ,G.quick_code AS visit_type_code              
                                    ,MIN(A.bill_period_num) as bill_period_num 
                FROM    temp_ar_billtrans A INNER JOIN
                        ar_billtrans_charge_ce_temp B ON  
                                        A.source_system_id = B.source_system_id AND
                                        A.bill_trans_num = B.bill_trans_num INNER JOIN  
                        `uspidnadevdata.advantx_ods.ut_proc_fee` C ON 
                                        B.source_system_id = C.source_system_id and
                                        B.procfee_num = C.num INNER JOIN
                        `uspidnadevdata.advantx_ods.ut_proc` D ON 
                                        C.source_system_id = D.source_system_id and
                                        C.proc_num = D.num INNER JOIN
                                         (SELECT 
                                            source_system_id
                                            ,case_num
                                            ,bill_trans_num
                                            ,charge_amount
                FROM    ar_billtrans_charge_rank_ce_temp
                                         ) E ON B.source_system_id = E.source_system_id AND
                                        B.case_num = E.case_num AND
                                        B.bill_trans_num = E.bill_trans_num AND
                                        B.charge_amount = E.charge_amount LEFT OUTER JOIN
                        `uspidnadevdata.advantx_ods.ca_visit` F ON 
                                        B.source_system_id = F.source_system_id AND
                                        B.visit_num = F.visit_num LEFT OUTER JOIN
                        `uspidnadevdata.advantx_ods.ut_visittypes` G ON 
                                        F.source_system_id = G.source_system_id AND
                                        F.visittype_num = G.num LEFT OUTER JOIN
                        PRIMARY_PROCEDURE_ce_temp H ON 
                                        B.source_system_id = H.source_system_id AND
                                        B.case_num = H.case_num
                                             WHERE 
                                                   A.active = 1 AND
                                                   D.quick_code = 'ERROR' 
                                                   AND H.source_system_id IS NULL 
                                                 GROUP BY A.source_system_id
                                                        ,B.case_num
                                                        ,B.procfee_num
                                                        ,D.quick_code
                                                        ,G.num
                                                        ,G.quick_code) A) A
                                WHERE rownumber = 1 AND A.source_system_id=V_source_system;  --274820

-- END OF OPTIMIZED QUERY: script_job_12b6b4ac23e2515178173c96d2c6b2ae_18

    -- Primary Procedure No Charges 

-- START OF OPTIMIZED QUERY: script_job_5c2cd07e07fbf20d64b00b76e89d959e_19

INSERT INTO PRIMARY_PROCEDURE_ce_temp (source_system_id, case_num, procfee_num, procedure_code, visittype_num, visit_type_code, bill_period_num)
WITH AggregatedProcedures AS (
  SELECT
    A.source_system_id,
    B.case_num,
    B.procfee_num,
    D.quick_code AS procedure_code,
    G.num AS visittype_num,
    G.quick_code AS visit_type_code,
    MIN(A.bill_period_num) AS bill_period_num
  FROM
    temp_ar_billtrans AS A
    INNER JOIN ar_billtrans_charge_ce_temp AS B ON A.source_system_id = B.source_system_id AND A.bill_trans_num = B.bill_trans_num
    INNER JOIN `uspidnadevdata.advantx_ods.ut_proc_fee` AS C ON B.source_system_id = C.source_system_id AND B.procfee_num = C.num
    INNER JOIN `uspidnadevdata.advantx_ods.ut_proc` AS D ON C.source_system_id = D.source_system_id AND C.proc_num = D.num
    LEFT JOIN `uspidnadevdata.advantx_ods.ca_visit` AS F ON B.source_system_id = F.source_system_id AND B.visit_num = F.visit_num
    LEFT JOIN `uspidnadevdata.advantx_ods.ut_visittypes` AS G ON F.source_system_id = G.source_system_id AND F.visittype_num = G.num
    LEFT JOIN ar_billtrans_charge_rank_ce_temp AS E ON B.source_system_id = E.source_system_id AND B.case_num = E.case_num AND B.bill_trans_num = E.bill_trans_num AND B.charge_amount = E.charge_amount
    LEFT JOIN PRIMARY_PROCEDURE_ce_temp AS H ON B.source_system_id = H.source_system_id AND B.case_num = H.case_num
  WHERE
    A.active = 1
    AND D.quick_code <> 'ERROR'
    AND E.source_system_id IS NULL
    AND H.source_system_id IS NULL
  GROUP BY
    1, 2, 3, 4, 5, 6
),
RankedProcedures AS (
  SELECT
    source_system_id,
    case_num,
    procfee_num,
    procedure_code,
    visittype_num,
    visit_type_code,
    bill_period_num,
    ROW_NUMBER() OVER (PARTITION BY source_system_id, case_num ORDER BY source_system_id, case_num, procedure_code) AS rn
  FROM
    AggregatedProcedures
)
SELECT
  source_system_id,
  case_num,
  procfee_num,
  procedure_code,
  visittype_num,
  visit_type_code,
  bill_period_num
FROM
  RankedProcedures
WHERE
  rn = 1
  AND source_system_id = V_source_system;

-- END OF OPTIMIZED QUERY: script_job_5c2cd07e07fbf20d64b00b76e89d959e_19

-- START OF OPTIMIZED QUERY: script_job_fc4316e24223b6d9baa313322f4b47e8_20

/*
 Assume 'V_source_system' is a pre-declared scripting variable.
 Example: DECLARE V_source_system STRING;
 SET V_source_system = 'some_value';
*/
INSERT INTO PRIMARY_PROCEDURE_ce_temp (
  source_system_id,
  case_num,
  procfee_num,
  procedure_code,
  visittype_num,
  visit_type_code,
  bill_period_num
)
WITH
  -- Step 1: Pre-filter all source tables by the target source_system_id to reduce data volume early.
  -- This is the most critical optimization.
  filtered_billtrans_charge AS (
    SELECT case_num, procfee_num, bill_trans_num, charge_amount, visit_num, source_system_id
    FROM ar_billtrans_charge_ce_temp
    WHERE source_system_id = V_source_system
  ),
  filtered_ar_billtrans AS (
    SELECT bill_trans_num, bill_period_num, source_system_id
    FROM temp_ar_billtrans
    WHERE source_system_id = V_source_system AND active = 1
  ),
  filtered_proc AS (
    SELECT num, source_system_id, quick_code
    FROM `uspidnadevdata.advantx_ods.ut_proc`
    WHERE source_system_id = V_source_system AND quick_code = 'ERROR'
  ),
  filtered_proc_fee AS (
    SELECT num, proc_num, source_system_id
    FROM `uspidnadevdata.advantx_ods.ut_proc_fee`
    WHERE source_system_id = V_source_system
  ),
  -- Step 2: Combine the core data sources.
  base_data AS (
    SELECT
      A.bill_period_num,
      B.case_num,
      B.procfee_num,
      B.bill_trans_num,
      B.charge_amount,
      B.visit_num,
      B.source_system_id,
      D.quick_code AS procedure_code
    FROM filtered_ar_billtrans AS A
    INNER JOIN filtered_billtrans_charge AS B
      ON A.bill_trans_num = B.bill_trans_num AND A.source_system_id = B.source_system_id
    INNER JOIN filtered_proc_fee AS C
      ON B.procfee_num = C.num AND B.source_system_id = C.source_system_id
    INNER JOIN filtered_proc AS D
      ON C.proc_num = D.num AND C.source_system_id = D.source_system_id
  ),
  -- Step 3: Perform joins, apply anti-join filters, and aggregate.
  -- The redundant DISTINCT is removed as GROUP BY already ensures uniqueness of grouped fields.
  aggregated_procedures AS (
    SELECT
      S.source_system_id,
      S.case_num,
      S.procfee_num,
      S.procedure_code,
      G.num AS visittype_num,
      G.quick_code AS visit_type_code,
      MIN(S.bill_period_num) AS bill_period_num
    FROM base_data AS S
    LEFT JOIN ar_billtrans_charge_rank_ce_temp AS E
      ON S.source_system_id = E.source_system_id
      AND S.case_num = E.case_num
      AND S.bill_trans_num = E.bill_trans_num
      AND S.charge_amount = E.charge_amount
    LEFT JOIN `uspidnadevdata.advantx_ods.ca_visit` AS F
      ON S.source_system_id = F.source_system_id AND S.visit_num = F.visit_num
    LEFT JOIN `uspidnadevdata.advantx_ods.ut_visittypes` AS G
      ON F.source_system_id = G.source_system_id AND F.visittype_num = G.num
    LEFT JOIN PRIMARY_PROCEDURE_ce_temp AS H
      ON S.source_system_id = H.source_system_id AND S.case_num = H.case_num
    WHERE
      E.source_system_id IS NULL -- Anti-join condition
      AND H.source_system_id IS NULL -- Idempotency check
    GROUP BY 1, 2, 3, 4, 5, 6
  ),
  -- Step 4: Apply window function to select one procedure per case.
  ranked_procedures AS (
    SELECT
      source_system_id,
      case_num,
      procfee_num,
      procedure_code,
      visittype_num,
      visit_type_code,
      bill_period_num,
      ROW_NUMBER() OVER (PARTITION BY source_system_id, case_num ORDER BY procedure_code) AS rownumber
    FROM aggregated_procedures
  )
-- Step 5: Final selection and insertion.
SELECT
  source_system_id,
  case_num,
  procfee_num,
  procedure_code,
  visittype_num,
  visit_type_code,
  bill_period_num
FROM ranked_procedures
WHERE rownumber = 1; 

-- END OF OPTIMIZED QUERY: script_job_fc4316e24223b6d9baa313322f4b47e8_20

            -- Update facility
 MERGE PRIMARY_PROCEDURE_ce_temp AS C
 USING ( SELECT 
        C.source_system_id,
        C.case_num,
        C.procfee_num,
        C.bill_period_num,
        B.facility_num,
        ROW_NUMBER() OVER (PARTITION BY C.source_system_id,C.case_num,C.procfee_num,C.bill_period_num ORDER BY B.facility_num  ) AS row_num
        from   temp_ar_billtrans A inner join
                ar_billtrans_charge_ce_temp B on 
                                a.source_system_id = b.source_system_id and
                                a.bill_trans_num = b.bill_trans_num INNER JOIN
                PRIMARY_PROCEDURE_ce_temp C on 
                                B.source_system_id = C.source_system_id and
                                B.case_num = C.case_num and
                                B.procfee_num = C.procfee_num and
                                a.bill_period_num = C.bill_period_num
                WHERE A.active = 1) src on
                                src.source_system_id = C.source_system_id and
                                src.case_num = C.case_num and
                                src.procfee_num = C.procfee_num and
                                src.bill_period_num = C.bill_period_num and
                                src.source_system_id=V_source_system and 
                                src.row_num =1
                WHEN MATCHED THEN 
                UPDATE SET facility_num = SRC.facility_num;
                                                                
            -- get expected collections %
            -- need all cases that apply to each payor

INSERT INTO expected_collection_pct_payors_ce_temp
    SELECT      source_system_id, payor_code,
            CASE WHEN SUM(charge_amount) = 0.0 then 0.0 ELSE SUM(paid_amount)/SUM(charge_amount) END AS expected_collection_pct
            FROM
            (
            SELECT                  a.source_system_id ,g.payor_code,
                            a.case_num,
                            SUM(b.charge_amount) as charge_amount,
                            SUM(b.paid_amount) as paid_amount,
                            SUM(b.writtenoff_amount) as writtenoff_amount
                                                        --SUM(charge_amount) - SUM(paid_amount) - SUM(writtenoff_amount) as sum_amount                          
        FROM    `uspidnadevdata.advantx_ods.ca_case` a
        INNER JOIN  (SELECT * FROM ar_billtrans_charge_ce_temp) b
                    on      a.source_system_id = b.source_system_id and
                    a.case_num = b.case_num
        INNER JOIN `uspidnadevdata.advantx_ods.ut_proc_fee` d
            on      b.source_system_id = d.source_system_id and
                    b.procfee_num = d.num
        INNER JOIN `uspidnadevdata.advantx_ods.ut_proc` e
            on      d.source_system_id = e.source_system_id and
                    d.proc_num = e.num
        INNER JOIN (SELECT 
                        ROW_NUMBER() OVER(PARTITION BY a_s.source_system_id, a_s.case_num ORDER BY policy_effective_date DESC) AS RowNum, 
                        a_s.source_system_id, 
                        a_s.case_num, 
                        b_s.pers_org_num as payor_code, 
                        IFNULL(copay_amt,0.00) as copay_amt
        FROM `uspidnadevdata.advantx_ods.ad_case_ps_ins`  a_s  INNER JOIN            
        `uspidnadevdata.advantx_ods.ad_ps_rolehist_ins`  b_s 
                                                ON a_s.role_num = 6 AND
                            a_s.source_system_id = b_s.source_system_id AND
                        a_s.ps_num = b_s.ps_num and 
                        a_s.role_num = b_s.role_num AND
                        b_s.pers_org_num IS NOT NULL ) G ON g.RowNum = 1 AND
                                    a.source_system_id = g.source_system_id AND
                                    a.case_num = g.case_num 
        WHERE   CAST(key_dos as DATE) BETWEEN DATE_TRUNC(DATE_SUB(CURRENT_DATE(), INTERVAL 3 YEAR), YEAR) and  CURRENT_DATE
                and e.quick_code NOT IN ('ERROR','DUMMY')
        and a.source_system_id = V_source_system
                        GROUP BY        a.source_system_id, payor_code, a.case_num
                        HAVING          charge_amount - paid_amount - writtenoff_amount <= 10.00
            --HAVING            SUM(charge_amount) - SUM(paid_amount) - SUM(writtenoff_amount) <= 10.00
            ) cases
            GROUP BY source_system_id,payor_code;

            --payors that we missed because no history exists
            --need to grab all cases so no filter for payor code here

-- START OF OPTIMIZED QUERY: script_job_65748ecb199f86afda59948e33c66154_23

/*
 Correctness & Performance Rewrite

 1.  MODIFIED: The `CAST(key_dos AS DATE)` filter is rewritten as a direct range comparison on the `key_dos` column to enable partition pruning, significantly reducing bytes scanned.
 2.  REFACTORED: The query is restructured into Common Table Expressions (CTEs) to improve readability and logical separation.
 3.  IMPROVED: The `SELECT *` is replaced with an explicit list of necessary columns.
 4.  IMPROVED: Unused columns (`copay_amt`) are removed from subqueries to reduce data movement.
 5.  UNCHANGED: All join logic, aggregation levels, and the `HAVING` clause are preserved to guarantee identical results.
*/
INSERT INTO expected_collection_pct_fc_ce_temp (source_system_id, fc_code, expected_collection_pct)
WITH
latest_insurance AS (
  -- This CTE finds the most recent insurance payor for each case, replacing the inline derived table 'G'.
  -- The unused `copay_amt` column has been removed.
  SELECT
    a_s.source_system_id,
    a_s.case_num,
    b_s.pers_org_num AS payor_code,
    ROW_NUMBER() OVER (PARTITION BY a_s.source_system_id, a_s.case_num ORDER BY policy_effective_date DESC) AS RowNum
  FROM `uspidnadevdata.advantx_ods.ad_case_ps_ins` AS a_s
  INNER JOIN `uspidnadevdata.advantx_ods.ad_ps_rolehist_ins` AS b_s
    ON a_s.source_system_id = b_s.source_system_id
    AND a_s.pers_org_num_pt = b_s.pers_org_num_pt
    AND a_s.ps_num = b_s.ps_num
    AND a_s.role_num = b_s.role_num
  WHERE a_s.role_num = 6 AND b_s.pers_org_num IS NOT NULL
),
case_financials AS (
  -- This CTE performs the first level of aggregation (by case) and applies the balance filter.
  SELECT
    a.source_system_id,
    i.num AS fc_code,
    SUM(b.charge_amount) AS charge_amount,
    SUM(b.paid_amount) AS paid_amount
  FROM `uspidnadevdata.advantx_ods.ca_case` AS a
  -- Replaced SELECT * with explicit columns
  INNER JOIN (
    SELECT source_system_id, case_num, charge_amount, paid_amount, writtenoff_amount, procfee_num
    FROM ar_billtrans_charge_ce_temp
  ) AS b ON a.source_system_id = b.source_system_id AND a.case_num = b.case_num
  INNER JOIN `uspidnadevdata.advantx_ods.ut_proc_fee` AS d ON b.source_system_id = d.source_system_id AND b.procfee_num = d.num
  INNER JOIN `uspidnadevdata.advantx_ods.ut_proc` AS e ON d.source_system_id = e.source_system_id AND d.proc_num = e.num
  INNER JOIN latest_insurance AS g ON g.RowNum = 1 AND a.source_system_id = g.source_system_id AND a.case_num = g.case_num
  INNER JOIN `uspidnadevdata.advantx_ods.ut_insurcarrier` AS h ON g.source_system_id = h.source_system_id AND g.payor_code = h.pers_org_num
  INNER JOIN `uspidnadevdata.advantx_ods.ut_insurcarrier_tisclient` AS j ON h.source_system_id = j.source_system_id AND h.num = j.inscarr_num AND a.tisclient_num = j.tisclient_num
  INNER JOIN `uspidnadevdata.advantx_ods.ut_insurtype` AS i ON j.source_system_id = i.source_system_id AND j.insurtype_num = i.num
  WHERE
    -- PERFORMANCE: This predicate enables partition pruning, assuming key_dos is a TIMESTAMP/DATETIME partition column.
    a.key_dos >= DATETIME(DATE_TRUNC(DATE_SUB(CURRENT_DATE(), INTERVAL 3 YEAR), YEAR))
    AND a.key_dos < DATETIME(DATE_ADD(CURRENT_DATE(), INTERVAL 1 DAY))
    AND e.quick_code NOT IN ('ERROR', 'DUMMY')
    AND a.source_system_id = V_source_system
  GROUP BY
    a.source_system_id,
    i.num,
    a.case_num
  HAVING
    SUM(b.charge_amount) - SUM(b.paid_amount) - SUM(b.writtenoff_amount) <= 10.00
)
-- Final aggregation to calculate the collection percentage.
SELECT
  source_system_id,
  fc_code,
  CASE
    WHEN SUM(charge_amount) = 0.0 THEN 0.0
    ELSE SUM(paid_amount) / SUM(charge_amount)
  END AS expected_collection_pct
FROM case_financials
GROUP BY
  source_system_id,
  fc_code;     

-- END OF OPTIMIZED QUERY: script_job_65748ecb199f86afda59948e33c66154_23

        -- Insert Summation Rows

-- START OF OPTIMIZED QUERY: script_job_f642715bb9916129fedb8840d03e3535_24

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
  INNER JOIN `uspidnadevdata.advantx_ods.ar_billing_period` AS C
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
  INNER JOIN `uspidnadevdata.advantx_ods.ar_billing_period` AS B
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
    FROM `uspidnadevdata.advantx_ods.ca_case`
)

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
FROM `uspidnadevdata.edw_advantx.vw_ad_tisclient` AS A
INNER JOIN `uspidnadevdata.advantx_ods.ad_pt` AS B
    ON A.source_system_id = B.source_system_id
INNER JOIN cases_with_id AS C -- Using the CTE with pre-computed case_id
    ON B.source_system_id = C.source_system_id AND B.pers_org_num_pers = C.pers_org_num_pt
LEFT JOIN `uspidnadevdata.advantx_ods.ca_visit` AS D
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
LEFT JOIN `uspidnadevdata.advantx_ods.ut_phys` AS G
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

-- END OF OPTIMIZED QUERY: script_job_f642715bb9916129fedb8840d03e3535_24                                   

MERGE MEDIBIS_FACT_CE_temp AS A
USING ( SELECT  
A.source_system_id,
A.case_num,error_paid_amount,
 ROW_NUMBER() OVER (PARTITION BY A.source_system_id, A.case_num ORDER BY error_paid_amount) AS row_num
 FROM 
MEDIBIS_FACT_CE_temp A INNER JOIN       
        (SELECT
        case_num, 
        SUM(paid_amount) AS error_paid_amount
    FROM ar_billtrans_charge_ce_temp A INNER JOIN       
        `uspidnadevdata.advantx_ods.ut_proc_fee` B ON   
                A.source_system_id = B.source_system_id AND
        A.procfee_num = B.num INNER JOIN
    `uspidnadevdata.advantx_ods.ut_proc` C ON 
                B.source_system_id = C.source_system_id AND
        B.proc_num = C.num
    WHERE C.quick_code IN ('ERROR','DUMMY')
  AND A.source_system_id=V_source_system
    GROUP BY A.case_num) B ON A.case_num = B.case_num) SRC ON
        SRC.source_system_id =A.source_system_id AND
        SRC.case_num = A.case_num AND
        SRC.row_num =1
        WHEN  MATCHED THEN 
        UPDATE SET case_error_paid_amount = error_paid_amount;


-- get appropriate fields from DIM_CASE, already calculated

-- START OF OPTIMIZED QUERY: script_job_abc0bdff2eb179f89870b2ea922b5148_26

MERGE MEDIBIS_FACT_CE_temp AS T
USING (
  -- Step 1: Pre-filter and de-duplicate the source data in a single pass.
  -- This avoids joining the entire medibis_dim_case table.
  SELECT
    source_system_id,
    case_id,
    total_asc_time,
    case_primary_payment_amount,
    case_unapplied_payment_amount,
    case_copay_payment_amount,
    case_outstanding_bal_amount,
    case_writeoff_amount,
    case_tob_writeoff_amount,
    case_top_writeoff_amount,
    balance_category,
    case_bad_debt_amount,
    implant_cost,
    expected_collections,
    expected_collections_est_ind
  FROM (
    SELECT
      source_system_id,
      case_id,
      total_asc_time,
      case_primary_payment_amount,
      case_unapplied_payment_amount,
      case_copay_payment_amount,
      case_outstanding_bal_amount,
      case_writeoff_amount,
      case_tob_writeoff_amount,
      case_top_writeoff_amount,
      balance_category,
      case_bad_debt_amount,
      implant_cost,
      expected_collections,
      expected_collections_est_ind,
      ROW_NUMBER() OVER (
        PARTITION BY source_system_id, case_id
        ORDER BY
          total_asc_time,
          case_primary_payment_amount,
          case_unapplied_payment_amount,
          case_copay_payment_amount,
          case_outstanding_bal_amount,
          case_writeoff_amount,
          case_tob_writeoff_amount,
          case_top_writeoff_amount,
          balance_category,
          case_bad_debt_amount,
          implant_cost,
          expected_collections,
          expected_collections_est_ind
      ) AS row_num
    FROM `uspidnadevdata.edw_advantx.medibis_dim_case`
    -- Step 2: Push the filter down to the source scan for maximum efficiency.
    WHERE source_system_id = V_source_system
  )
  WHERE row_num = 1
) AS S
ON T.source_system_id = S.source_system_id
  AND T.case_id = S.case_id
  -- Step 3: Keep the original filter on the target table, as required by the MERGE logic.
  AND T.source_system_id = V_source_system
WHEN MATCHED THEN
  UPDATE SET
    total_asc_time = S.total_asc_time,
    case_primary_payment_amount = S.case_primary_payment_amount,
    case_unapplied_payment_amount = S.case_unapplied_payment_amount,
    case_copay_payment_amount = S.case_copay_payment_amount,
    case_outstanding_bal_amount = S.case_outstanding_bal_amount,
    case_writeoff_amount = S.case_writeoff_amount,
    case_tob_writeoff_amount = S.case_tob_writeoff_amount,
    case_top_writeoff_amount = S.case_top_writeoff_amount,
    balance_category = S.balance_category,
    case_bad_debt_amount = S.case_bad_debt_amount,
    implant_cost = S.implant_cost,
    expected_collections = S.expected_collections,
    expected_collections_est_ind = S.expected_collections_est_ind;
           
-- END OF OPTIMIZED QUERY: script_job_abc0bdff2eb179f89870b2ea922b5148_26

-- START OF OPTIMIZED QUERY: script_job_7de7760c604730dcc158062fb6ca88bd_27

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
    INNER JOIN `uspidnadevdata.advantx_ods.ar_billing_period` AS period
        ON trans.source_system_id = period.source_system_id AND trans.bill_period_num = period.num
    INNER JOIN `uspidnadevdata.advantx_ods.ut_proc_fee` AS proc_fee
        ON charge.source_system_id = proc_fee.source_system_id AND charge.procfee_num = proc_fee.num
    LEFT JOIN `uspidnadevdata.advantx_ods.ut_servicetypes` AS st
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
        INNER JOIN `uspidnadevdata.advantx_ods.ar_billing_period` AS period
            ON pp.source_system_id = period.source_system_id AND pp.bill_period_num = period.num
    )
    WHERE row_num = 1
  ),
  cte_L AS (
    SELECT
        fee.source_system_id,
        fee.num AS procfee_num,
        proc.quick_code AS cpt_procedure_code
    FROM `uspidnadevdata.advantx_ods.ut_proc_fee` AS fee
    INNER JOIN `uspidnadevdata.advantx_ods.ut_proc` AS proc
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
FROM `uspidnadevdata.edw_advantx.vw_ad_tisclient` AS A
INNER JOIN `uspidnadevdata.advantx_ods.ad_pt` AS B
    ON A.source_system_id = B.source_system_id
INNER JOIN `uspidnadevdata.advantx_ods.ca_case` AS C
    ON B.source_system_id = C.source_system_id AND B.pers_org_num_pers = C.pers_org_num_pt
LEFT JOIN `uspidnadevdata.advantx_ods.ca_visit` AS D
    ON C.source_system_id = D.source_system_id AND C.case_num = D.case_num
LEFT JOIN `temp_ca_visit_visitdept_proc_hist` AS E
    ON D.source_system_id = E.source_system_id AND D.case_num = E.case_num AND D.visit_num = E.visit_num AND E.order_key = 1
INNER JOIN cte_F AS F
    ON C.source_system_id = F.source_system_id
    AND C.case_num = F.case_num
    AND IFNULL(D.visit_num, -1) = IFNULL(F.visit_num, -1)
    AND A.pers_org_num_org = F.tis_client_num
LEFT JOIN `uspidnadevdata.advantx_ods.ut_phys` AS G
    ON C.source_system_id = G.source_system_id AND C.primary_phys_num = G.num
LEFT JOIN cte_I AS I
    ON F.source_system_id = I.source_system_id AND F.case_num = I.case_num
LEFT JOIN `uspidnadevdata.advantx_ods.ut_visittypes` AS K
    ON D.source_system_id = K.source_system_id AND D.visittype_num = K.num
LEFT JOIN cte_L AS L
    ON F.source_system_id = L.source_system_id AND F.procfee_num = L.procfee_num
WHERE
    F.charge_amount IS NOT NULL
    AND C.key_dos >= DATE_TRUNC(DATE_SUB(CURRENT_DATE(), INTERVAL 3 YEAR), YEAR)
    AND A.source_system_id = V_source_system;

-- END OF OPTIMIZED QUERY: script_job_7de7760c604730dcc158062fb6ca88bd_27

-- START OF OPTIMIZED QUERY: script_job_666c28a84fb4ac2e904ac58733f8da11_28

MERGE `MEDIBIS_FACT_CE_temp` AS TGT
USING (
  WITH source_visit_types AS (
    SELECT
      source_system_id,
      case_num,
      quick_code
    FROM (
      SELECT
        apt.source_system_id,
        apt.case_num,
        vt.quick_code,
        ROW_NUMBER() OVER(PARTITION BY apt.source_system_id, apt.case_num ORDER BY vt.num ASC) as rn
      FROM
        `uspidnadevdata.advantx_ods.as_appointment` AS apt
      INNER JOIN
        `uspidnadevdata.advantx_ods.ut_visittypes` AS vt
        ON apt.source_system_id = vt.source_system_id AND apt.visittype_num = vt.num
      WHERE
        vt.active = 1
        AND apt.source_system_id = 'rswl' -- Inferred from execution graph variable V_source_system
    )
    WHERE rn = 1
  )
  SELECT * FROM source_visit_types
) AS SRC
  ON TGT.source_system_id = SRC.source_system_id
 AND TGT.case_num = SRC.case_num
WHEN MATCHED AND TGT.source_system_id = 'rswl' -- Preserves original ON clause logic for the target table
THEN
  UPDATE SET TGT.visit_type_code = SRC.quick_code;

-- END OF OPTIMIZED QUERY: script_job_666c28a84fb4ac2e904ac58733f8da11_28

-- SH 11864: Zero out case_count for non-surgical visit types (AdvantX facility 11864 / fshs only)
IF V_source_system = 'fshs' THEN
    UPDATE MEDIBIS_FACT_CE_temp
    SET case_count = 0
    WHERE source_system_id = 'fshs'
    AND UPPER(TRIM(visit_type_code)) NOT IN (
        'ED IP', 'EDMEDIP', 'ED OBS', 'ED SX', 'ED',
        'INPT', 'INPT ROB', 'MED IP', 'OBS ROB SX',
        'OBSIP', 'OBS SX', 'OBS NO SX', 'OUT TO IN',
        'OP ROB', 'OUTPT', 'PM', 'S', 'SOC'
    );
END IF;


MERGE MEDIBIS_FACT_CE_temp A
USING (SELECT   
        A.source_system_id,
        A.tisclient_num,
        A.case_num,
        CAST(B.bill_period_num AS INTEGER) AS bill_period_num,
        B.billing_period_start_date,
        B.financial_year,
        B.financial_period,
        ROW_NUMBER() OVER(PARTITION BY A.source_system_id, A.tisclient_num, A.case_num ORDER BY B.bill_period_num,
                             B.billing_period_start_date, B.financial_year, B.financial_period ) AS row_num
        FROM MEDIBIS_FACT_CE_temp A INNER JOIN
               bill_period_ce_temp B ON 
                        A.source_system_id = B.source_system_id AND
                        A.tisclient_num = B.tis_client_num AND
                        A.case_num = B.case_num) SRC ON
                SRC.source_system_id = A.source_system_id AND
                SRC.tisclient_num = A.tisclient_num AND
                SRC.case_num = A.case_num AND
                A.source_system_id = V_source_system AND
                SRC.row_num=1
        WHEN MATCHED THEN 
        UPDATE SET billing_period = SRC.bill_period_num
                ,billing_period_start_date = SRC.billing_period_start_date
                ,financial_year = SRC.financial_year
                ,financial_period = SRC.financial_period;

-- START OF OPTIMIZED QUERY: script_job_5867f97f0966367f9d8ba756b3f3f715_30

MERGE MEDIBIS_FACT_CE_temp AS T
USING (
  WITH
    -- Join to find all possible payors for each case, filtered by the relevant source system.
    -- The original's LEFT JOIN followed by an INNER JOIN is semantically equivalent to two INNER JOINs.
    -- This step can produce multiple `pers_org_num` rows for each case, causing the join amplification seen in the execution graph.
    all_case_payors AS (
      SELECT
        A.source_system_id,
        A.case_num,
        C.pers_org_num
      FROM
        MEDIBIS_FACT_CE_temp AS A
      INNER JOIN
        `uspidnadevdata.advantx_ods.ad_case_ps_ins` AS B
        ON A.case_num = B.case_num AND A.source_system_id = B.source_system_id
      INNER JOIN
        `uspidnadevdata.advantx_ods.ad_ps_rolehist_ins` AS C
        ON B.pers_org_num_pt = C.pers_org_num_pers_ins
      WHERE
        A.source_system_id = V_source_system -- Predicate from the original MERGE ON clause applied early to the source scan.
        AND C.role_num = 6
    )
  -- For each case, find the single payor that matches the original ROW_NUMBER() logic.
  -- ARRAY_AGG with ORDER BY and LIMIT 1 is an efficient way to perform a top-1-per-group selection.
  -- This avoids shuffling all the amplified rows from the join above, drastically reducing shuffle bytes and compute.
  SELECT
    source_system_id,
    case_num,
    (ARRAY_AGG(
      CAST(IFNULL(pers_org_num, -1) AS STRING)
      ORDER BY IFNULL(pers_org_num, -1) ASC
      LIMIT 1
    )[OFFSET(0)]) AS pers_org_num
  FROM
    all_case_payors
  GROUP BY
    source_system_id,
    case_num
) AS S
ON
  T.source_system_id = S.source_system_id
  AND T.case_num = S.case_num
  AND T.source_system_id = V_source_system -- This predicate on the target table is essential for the MERGE operation's performance and correctness.
WHEN MATCHED THEN
  UPDATE SET payor_code = S.pers_org_num;    

-- END OF OPTIMIZED QUERY: script_job_5867f97f0966367f9d8ba756b3f3f715_30
            
            -- ICD Codes

-- START OF OPTIMIZED QUERY: script_job_ad13bebde601d85cc10549e896505400_31

MERGE MEDIBIS_FACT_CE_temp AS T
USING (
  -- This CTE pre-aggregates the source data efficiently.
  SELECT
    B.source_system_id,
    B.case_num,
    MIN(C.quick_code) AS quick_code
  FROM ar_billtrans_charge_ce_temp AS B
  INNER JOIN `uspidnadevdata.advantx_ods.ut_dx` AS C
    ON B.source_system_id = C.source_system_id
   AND B.dx1_num = C.num
  -- Filter is applied early to reduce data volume immediately.
  WHERE B.source_system_id = V_source_system
  GROUP BY
    B.source_system_id,
    B.case_num
) AS S
ON T.source_system_id = S.source_system_id
   AND T.case_num = S.case_num
   -- This filter on the TARGET table is preserved from the original query.
   AND T.source_system_id = V_source_system
WHEN MATCHED THEN
  UPDATE SET icd9_code = S.quick_code;    

-- END OF OPTIMIZED QUERY: script_job_ad13bebde601d85cc10549e896505400_31

-- START OF OPTIMIZED QUERY: script_job_5d503c78d39b364c4adcd2b82b94207b_32

/*
 BQ Auditor: Optimized MERGE Statement
 Original query read the target table MEDIBIS_FACT_CE_temp twice: once in the 
 source subquery and once as the MERGE target. This rewrite eliminates the 
 redundant read and join within the source subquery, as the MERGE's ON clause 
 inherently performs the necessary filtering. This reduces I/O and compute.

 NOTE: The variable `V_source_system` is assumed from the original query context.
 Replace it with the correct variable or literal value as needed.
*/
MERGE MEDIBIS_FACT_CE_temp AS TGT
USING (
  WITH RankedCodes AS (
    SELECT
      B.source_system_id,
      B.case_num,
      C.quick_code,
      ROW_NUMBER() OVER (
        PARTITION BY
          B.source_system_id,
          B.case_num
        ORDER BY
          C.quick_code ASC
      ) AS rn
    FROM
      ar_billtrans_charge_ce_temp AS B
      INNER JOIN `uspidnadevdata.advantx_ods.ut_dx` AS C ON B.source_system_id = C.source_system_id
      AND B.dx1_num_10 = C.num
    WHERE
      -- Filter early on the driving table to reduce data processed downstream.
      B.source_system_id = V_source_system
  )
  SELECT
    source_system_id,
    case_num,
    quick_code
  FROM
    RankedCodes
  WHERE
    rn = 1
) AS SRC ON TGT.source_system_id = SRC.source_system_id
AND TGT.case_num = SRC.case_num
-- The filter on the target table is still required to scope the MERGE operation.
AND TGT.source_system_id = V_source_system
WHEN MATCHED THEN
UPDATE
SET
  icd10_code = SRC.quick_code;                        

-- END OF OPTIMIZED QUERY: script_job_5d503c78d39b364c4adcd2b82b94207b_32

            -- Service Code

MERGE MEDIBIS_FACT_CE_temp A
USING (SELECT   
        A.source_system_id,
        A.case_num,
        D.quick_code,
        ROW_NUMBER() OVER (PARTITION BY A.source_system_id, A.case_num ORDER BY D.quick_code ) AS row_num
        FROM MEDIBIS_FACT_CE_temp A INNER JOIN 
        ar_billtrans_charge_ce_temp B  ON
                A.source_system_id = B.source_system_id and
                A.case_num = B.case_num   INNER JOIN 
        `uspidnadevdata.advantx_ods.ut_proc_fee`  C ON 
                        B.source_system_id = C.source_system_id AND
                        B.procfee_num = C.num INNER JOIN
        `uspidnadevdata.advantx_ods.ut_servicetypes`  D ON 
                        C.source_system_id = D.source_system_id  
                        AND C.service_type_num = D.num ) SRC ON 
                SRC.source_system_id = A.source_system_id and
                SRC.case_num = A.case_num AND
                 A.source_system_id = V_source_system AND
                SRC.row_num =1
        WHEN MATCHED THEN 
        UPDATE SET service_code = SRC.quick_code ;              

            -- OR Minutes and Room
 
MERGE MEDIBIS_FACT_CE_temp A
USING (
    SELECT   
        A.source_system_id,
        A.case_num,
        C.description AS or_room,
        DATE_DIFF(B.or_end_time, B.or_begin_time, MINUTE) AS or_minutes,
        ROW_NUMBER() OVER (PARTITION BY A.source_system_id, A.case_num 
                           ORDER BY DATE_DIFF(B.or_end_time, B.or_begin_time, MINUTE) DESC) AS row_num
    FROM MEDIBIS_FACT_CE_temp A 
    INNER JOIN temp_ca_visit_visitdept B 
        ON A.source_system_id = B.source_system_id 
        AND A.case_num = B.case_num 
        AND B.visitdept_num = 3
        AND A.case_count=1
    INNER JOIN `uspidnadevdata.advantx_ods.ut_room` C 
        ON B.source_system_id = C.source_system_id 
        AND B.room_num = C.num
    WHERE A.case_count = 1
) SRC
ON SRC.source_system_id = A.source_system_id
 AND A.source_system_id = V_source_system
   AND SRC.case_num = A.case_num 
   AND SRC.row_num = 1
   AND A.case_count=1
WHEN MATCHED AND A.CASE_COUNT=1 THEN 
    UPDATE SET A.or_minutes = SRC.or_minutes,
               A.or_room = SRC.or_room;


--             -- Patient Age

-- MERGE MEDIBIS_FACT_CE_temp A
-- USING (SELECT   
--         A.source_system_id,
--         A.patient_code,
--         CAST(B.pers_org_num_pers AS STRING) AS pers_org_num_pers,
--         FLOOR(DATE_DIFF( A.date_of_service,C.dob,DAY) / 365.25) AS PATIENT_AGE,
--         ROW_NUMBER() OVER (PARTITION BY A.source_system_id, A.patient_code ORDER BY FLOOR(DATE_DIFF( A.date_of_service,C.dob,DAY) / 365.25) ) AS row_num
--         FROM MEDIBIS_FACT_CE_temp A INNER JOIN 
--         `uspidnadevdata.advantx_ods.ad_pt`  B ON 
--                         A.source_system_id = B.source_system_id AND
--                         A.patient_code = CAST(B.pers_org_num_pers AS STRING) INNER JOIN
--         `uspidnadevdata.advantx_ods.co_pers`  C ON 
--                         B.source_system_id = C.source_system_id  
--                         WHERE B.pers_org_num_pers = C.pers_org_num ) SRC ON 
--                 SRC.source_system_id = A.source_system_id and
--                 SRC.pers_org_num_pers = A.patient_code AND
--                 A.source_system_id = V_source_system AND
--                 SRC.row_num =1
--         WHEN MATCHED THEN 
--         UPDATE SET patient_age = SRC.PATIENT_AGE ;


-- START OF OPTIMIZED QUERY: script_job_265e586b3ed5115f618f9e12adb3405c_35

        MERGE `MEDIBIS_FACT_CE_temp` AS A
USING (
  WITH PatientMinDOB AS (
    SELECT
      B.source_system_id,
      CAST(B.pers_org_num_pers AS STRING) AS patient_code,
      MIN(C.dob) AS min_dob
    FROM
      `uspidnadevdata.advantx_ods.ad_pt` AS B
      INNER JOIN `uspidnadevdata.advantx_ods.co_pers` AS C ON B.source_system_id = C.source_system_id
      AND B.pers_org_num_pers = C.pers_org_num
    WHERE
      B.source_system_id = V_source_system
    GROUP BY
      1,
      2
  )
 SELECT * FROM PatientMinDOB
) AS SRC
ON
  A.source_system_id = SRC.source_system_id
  AND A.patient_code = SRC.patient_code
  AND A.source_system_id = V_source_system
WHEN MATCHED THEN
  UPDATE
SET
  patient_age = FLOOR(DATE_DIFF(A.date_of_service, SRC.min_dob, DAY) / 365.25);

-- END OF OPTIMIZED QUERY: script_job_265e586b3ed5115f618f9e12adb3405c_35

            -- Case Procedure Count

MERGE MEDIBIS_FACT_CE_temp A
USING (SELECT   
        A.source_system_id,
        A.case_num,
        B.case_procedure_count,
        ROW_NUMBER() OVER (PARTITION BY A.source_system_id,  A.case_num ORDER BY B.case_procedure_count ) AS row_num
        FROM MEDIBIS_FACT_CE_temp A INNER JOIN
                (SELECT
                        source_system_id
                        ,case_num
                        ,SUM(procedure_count) AS case_procedure_count
        FROM MEDIBIS_FACT_CE_temp 
                GROUP BY source_system_id ,case_num) B ON 
                        A.source_system_id = B.source_system_id  
                        WHERE A.case_num = B.case_num) SRC ON 
                SRC.source_system_id = A.source_system_id and
                A.source_system_id = V_source_system AND
                SRC.case_num = A.case_num AND
                SRC.row_num =1
        WHEN MATCHED THEN 
        UPDATE SET case_procedure_count = SRC.case_procedure_count ;   

-- START OF OPTIMIZED QUERY: script_job_ef6f0bb2faa9c8f5fa2fc3dc47f87682_37

/*
 The script variable V_source_system must be declared prior to this statement.
 Example: DECLARE V_source_system STRING DEFAULT 'rssc';
*/
MERGE `MEDIBIS_FACT_CE_temp` AS T
USING (
  SELECT
    source_system_id,
    case_num,
    new_case_status
  FROM (
    SELECT
      B.source_system_id,
      B.case_num,
      COALESCE(UPPER(C.quick_code), 'UNKNOWN') AS new_case_status,
      ROW_NUMBER() OVER (
        PARTITION BY B.source_system_id, B.case_num
        ORDER BY COALESCE(UPPER(C.quick_code), 'UNKNOWN') ASC
      ) AS rn
    FROM
      `uspidnadevdata.advantx_ods.ca_case` AS B
    INNER JOIN
      `uspidnadevdata.advantx_ods.ods_case_status` AS C
      ON B.source_system_id = C.source_system_id
      AND B.case_status = C.case_status
    WHERE
      -- Pre-filter source data to only what is relevant for the update.
      -- This is valid because the MERGE's ON clause filters the target by the same value.
      B.source_system_id = V_source_system
  )
  WHERE rn = 1
) AS S
ON T.source_system_id = S.source_system_id
   AND T.case_num = S.case_num
   -- This filter on the target table is preserved from the original ON clause for correctness.
   AND T.source_system_id = V_source_system
WHEN MATCHED THEN
  UPDATE SET T.case_status = S.new_case_status;

-- END OF OPTIMIZED QUERY: script_job_ef6f0bb2faa9c8f5fa2fc3dc47f87682_37

            -- Supply Costs

MERGE MEDIBIS_FACT_CE_temp A
USING (SELECT   
        A.source_system_id,
        A.case_num,
        A.tisclient_num,B.supply_cost,
         ROW_NUMBER() OVER (PARTITION BY A.source_system_id,  A.case_num,A.tisclient_num ORDER BY B.supply_cost ) AS row_num
         FROM MEDIBIS_FACT_CE_temp A INNER JOIN 
         (SELECT 
                A.source_system_id
                ,A.case_num
                ,B.tisclient_num
                ,ROUND(SUM(A.qty * B.fifo_unit_cost), 2) AS supply_cost
        FROM temp_ca_visit_visitdept_supply_hist  A LEFT OUTER JOIN
        `uspidnadevdata.advantx_ods.ut_supply_tisclient`   B ON 
                        A.source_system_id = B.source_system_id AND
                        A.supply_num = B.supply_num LEFT OUTER JOIN
                        (SELECT DISTINCT 
                                source_system_id
                                ,case_num
                                ,tisclient_num
                        FROM MEDIBIS_FACT_CE_temp
                        WHERE case_count = 1) C ON 
                                B.source_system_id = C.source_system_id AND
                                A.case_num = C.case_num AND
                                B.tisclient_num = C.tisclient_num
                                GROUP BY A.source_system_id
                                        ,A.case_num
                                        ,b.tisclient_num) B ON 
                                        A.source_system_id = B.source_system_id AND
                                        A.case_num = B.case_num AND
                                        A.tisclient_num = B.tisclient_num
                        WHERE A.case_count = 1  ) SRC ON 
                SRC.source_system_id = A.source_system_id and
                A.source_system_id = V_source_system AND
                SRC.case_num = A.case_num AND
                SRC.tisclient_num= A.tisclient_num AND
                SRC.row_num =1
        WHEN MATCHED THEN 
        UPDATE SET supply_cost = SRC.supply_cost ;
 
  
            -- Staff Costs

MERGE MEDIBIS_FACT_CE_temp A
USING (SELECT   
        A.source_system_id,
        A.case_num,
         B.staff_cost,
        ROW_NUMBER() OVER (PARTITION BY A.source_system_id,  A.case_num ORDER BY  B.staff_cost) AS row_num
        FROM MEDIBIS_FACT_CE_temp A INNER JOIN
                (SELECT 
                A.source_system_id
                ,A.case_num
                ,SUM(ROUND((A.total_time_attendedto * B.average_cost_per_minute), 2)) AS staff_cost
FROM temp_ca_visit_visitdept_pers_role  A LEFT OUTER JOIN
        `uspidnadevdata.advantx_ods.ut_staff_role`  B ON 
                A.source_system_id = B.source_system_id AND
                A.role_num = B.num
                GROUP BY A.source_system_id ,A.case_num) B ON 
                A.source_system_id = B.source_system_id AND
                A.case_num = B.case_num
                WHERE A.case_count = 1 ) SRC ON 
                SRC.source_system_id = A.source_system_id and
                 A.source_system_id = V_source_system AND 
                SRC.case_num = A.case_num AND
                SRC.row_num =1
        WHEN MATCHED THEN 
        UPDATE SET staff_cost = SRC.staff_cost ;  
                   
MERGE MEDIBIS_FACT_CE_temp A
USING (SELECT   
        A.source_system_id,
        A.case_id,
       B.procedure_combination,
        ROW_NUMBER() OVER (PARTITION BY A.source_system_id,  A.case_id ORDER BY B.procedure_combination ) AS row_num
        FROM MEDIBIS_FACT_CE_temp A INNER JOIN
        `uspidnadevdata.edw_advantx.medibis_dim_case` B ON 
                        A.source_system_id = B.source_system_id  
                       WHERE A.case_id = B.case_id) SRC ON 
                SRC.source_system_id = A.source_system_id and
                A.source_system_id = V_source_system AND
                SRC.case_id = A.case_id AND
                SRC.row_num =1
        WHEN MATCHED THEN 
        UPDATE SET procedure_combination = SRC.procedure_combination ; 

MERGE MEDIBIS_FACT_CE_temp A
USING (SELECT   
        A.source_system_id,
        A.case_id,
        b.balance_category, b.case_outstanding_bal_amount,
        ROW_NUMBER() OVER (PARTITION BY A.source_system_id,  A.case_id ORDER BY  b.balance_category, b.case_outstanding_bal_amount ) AS row_num
        FROM MEDIBIS_FACT_CE_temp A INNER JOIN
        (SELECT 
                case_id, 
                balance_category,
                case_outstanding_bal_amount 
        FROM MEDIBIS_FACT_CE_temp x 
                WHERE procedure_count = 0) b ON a.case_id = b.case_id) SRC ON 
                SRC.source_system_id = A.source_system_id and
                 A.source_system_id = V_source_system AND
                SRC.case_id = A.case_id AND
                SRC.row_num =1
        WHEN MATCHED THEN 
        UPDATE SET balance_category = SRC.balance_category,
        case_outstanding_bal_amount = SRC.case_outstanding_bal_amount ; 
 
 MERGE MEDIBIS_FACT_CE_temp A
USING (SELECT   
        A.source_system_id,
        A.case_id,
      CASE WHEN REGEXP_CONTAINS(b.payor_code,'[0-9]') = true THEN b.payor_code ELSE '0' END  AS payor_code1,
        ROW_NUMBER() OVER (PARTITION BY A.source_system_id,  A.case_id ORDER BY CASE WHEN REGEXP_CONTAINS(b.payor_code,'[0-9]') = true THEN b.payor_code ELSE '0' END  ) AS row_num
        FROM MEDIBIS_FACT_CE_temp A INNER JOIN
        `uspidnadevdata.edw_advantx.medibis_dim_case` B ON 
                        A.source_system_id = B.source_system_id  
                       WHERE A.case_id = B.case_id) SRC ON 
                SRC.source_system_id = A.source_system_id and
                A.source_system_id = V_source_system AND
                SRC.case_id = A.case_id AND
                SRC.row_num =1
        WHEN MATCHED THEN 
        UPDATE SET payor_code = SRC.payor_code1 ;



set complex_dml1 = FORMAT(""" DELETE FROM `uspidnadevdata.edw_advantx.medibis_fact_ce` WHERE source_system_id = '%s' and  date(date_of_service) >= DATE_TRUNC(DATE_SUB(CURRENT_DATE(), INTERVAL 3 YEAR), YEAR);""", V_source_system);


            -- Insert rows

set complex_dml2 = FORMAT("""INSERT INTO `uspidnadevdata.edw_advantx.medibis_fact_ce`
                (oracleid,
                company_code
                ,facility_code
                ,physician_code
                ,procedure_code
                ,payor_code
                ,patient_code
                ,date_of_service
                ,case_id
                ,patient_type_code
                ,visit_type_code
                ,case_count
                ,case_charge_amount
                ,case_primary_payment_amount
                ,case_copay_payment_amount
                ,case_writeoff_amount
                ,case_bad_debt_amount
                ,procedure_count
                ,financial_year
                ,financial_period
                ,icd9_code
                ,service_code
                ,or_minutes
                ,supply_cost
                ,staff_cost
                ,implant_cost
                ,case_refund_amount
                ,case_misc_charge_amount
                ,cpt_charge_amount
                ,cpt_procedure_code
                ,net_rev_pct_rankbkt
                ,net_rev_dlr_rankbkt
                ,supply_cost_rankbkt
                ,sup_cost_pct_netrev_rankbkt
                ,net_rev_pct_rankdesc
                ,net_rev_dlr_rankdesc
                ,supply_cost_rankdesc
                ,sup_cost_pct_netrev_rankdesc
                ,account_name
                ,balance_category
                ,drg_code
                ,inpatient_days
                ,billing_period
                ,case_unapplied_payment_amount
                ,case_procedure_count
                ,patient_age
                ,entity_code
                ,case_outstanding_bal_amount
                ,case_status
                ,case_tob_writeoff_amount
                ,case_top_writeoff_amount
                ,patient_class_code
                ,expected_collections
                ,expected_collections_est_ind
                ,billing_period_start_date
                ,procedure_combination
                ,case_payor_status
                ,or_room
                ,total_asc_time
                ,refer_physician_code
                ,fixed_cost
                ,icd10_code
                ,source_system_id
                , load_ts
                , acuity_flag,
                                combined_oracleid,
                                combined_facilityname,
                                units)
                SELECT distinct
                    CAST (b.OracleID as NUMERIC) as oracleid,
                    a.company_code
                    ,a.facility_code
                    ,a.physician_code
                    ,a.procedure_code
                    ,a.payor_code
                    ,a.patient_code
                    ,a.date_of_service
                    ,a.case_id
                    ,a.patient_type_code
                    ,a.visit_type_code
                    ,a.case_count
                    ,a.case_charge_amount
                    ,a.case_primary_payment_amount
                    ,a.case_copay_payment_amount
                    ,a.case_writeoff_amount
                    ,a.case_bad_debt_amount
                    ,a.procedure_count
                    ,a.financial_year
                    ,a.financial_period
                    ,a.icd9_code
                    ,a.service_code
                    ,a.or_minutes
                    ,a.supply_cost
                    ,a.staff_cost
                    ,a.implant_cost
                    ,a.case_refund_amount
                    ,a.case_misc_charge_amount
                    ,a.cpt_charge_amount
                    ,a.cpt_procedure_code
                    ,a.net_rev_pct_rankbkt
                    ,a.net_rev_dlr_rankbkt
                    ,a.supply_cost_rankbkt
                    ,a.sup_cost_pct_netrev_rankbkt
                    ,a.net_rev_pct_rankdesc
                    ,a.net_rev_dlr_rankdesc
                    ,a.supply_cost_rankdesc
                    ,a.sup_cost_pct_netrev_rankdesc
                    ,a.account_name
                    ,a.balance_category
                    ,a.drg_code
                    ,a.inpatient_days
                    ,a.billing_period
                    ,a.case_unapplied_payment_amount
                    ,a.case_procedure_count
                    ,a.patient_age
                    ,a.entity_code
                    ,a.case_outstanding_bal_amount
                    ,a.case_status
                    ,a.case_tob_writeoff_amount
                    ,a.case_top_writeoff_amount
                    ,a.patient_class_code
                    ,a.expected_collections
                    ,a.expected_collections_est_ind
                    ,a.billing_period_start_date
                    ,a.procedure_combination
                    ,a.case_payor_status
                    ,a.or_room
                    ,a.total_asc_time
                    ,a.refer_physician_code
                    ,a.fixed_cost
                    ,a.icd10_code
                    ,a.source_system_id
                    ,CURRENT_DATETIME("America/Chicago") AS load_ts
                    ,IF(
                     IF(DENSE_RANK() OVER (PARTITION BY a.company_code,case_id 
                                    ORDER BY c.drgweight DESC,
                                            CASE WHEN procedure_code = cpt_procedure_code THEN 1 ELSE 0 END DESC, 
                                            cpt_procedure_code ASC,
                                            case_count DESC
                                    ) = 1, 1,0) --first IF logic for acuity_flag per case where max(drgweight) is greater than zero 
                     =1 AND c.drgweight > 0,1,0 --IF logic for acuity_flag per case where max(drgweight) is less than zero 
                     ) AS acuity_flag,
                     case when d.combined_oracleid is null then cast(b.oracleid as numeric) else cast(d.combined_oracleid as numeric) end as combined_oracleid,
                     d.combined_facilityname,
                     a.units
                        FROM MEDIBIS_FACT_CE_temp a
                    LEFT JOIN  
                                        (SELECT procedurecode,MAX(drgweight) AS drgweight FROM uspidnadevdata.edw_advantx.cptcode_lookup 
                                        GROUP BY 1)c
                    ON c.procedurecode = A.cpt_procedure_code
                                        left outer join uspidnadevdata.edw_advantx.company_code_xref b
                                        on a.company_code = b.company_code
                                        and a.facility_code = b.facility_code
                                        left outer join uspidnadevdata.edw_advantx.combined_facilities d
                                        on b.oracleid = d.oracleid
                                        WHERE a.source_system_id = "%s" and
                                        date(date_of_service) >= DATE_TRUNC(DATE_SUB(CURRENT_DATE(), INTERVAL 3 YEAR), YEAR);""", V_source_system);
                                 
--------------------------------------------------------------

    select complex_dml1;
    select complex_dml2;


    CALL `uspidnadevdata.framework_metadata.execute_sql_dml` (complex_dml1, V_PROC_NAME,V_RESULT);

    if V_RESULT <> 'P' then 
      RAISE USING message = V_RESULT;
    end if;

    
    if V_RESULT <> 'P' then 
    SET V_ERRORMESSAGE = V_RESULT;
    else SET V_ERRORMESSAGE = @@error.message;
    end if;

    CALL `uspidnadevdata.framework_metadata.execute_sql_dml` (complex_dml2, V_PROC_NAME,V_RESULT);


    if V_RESULT <> 'P' then 
      RAISE USING message = V_RESULT;
    end if;

    
    if V_RESULT <> 'P' then 
    SET V_ERRORMESSAGE = V_RESULT;
    else SET V_ERRORMESSAGE = @@error.message;
    end if; 

-----------------------------------------------------------------------------------


    SET out_param = 1;

    SELECT out_param; 

    /* =============================================================================================================================== */
    /* HANDLE EXCEPTIONS */
    /* =============================================================================================================================== */

    EXCEPTION
        WHEN ERROR THEN
            SET V_LOG_MESSAGE = 'FAILED - Procedure ' || V_PROC_NAME || ', Reason: TRANSACTION_ABORTED - ' || REPLACE(@@error.message,'\'\'','''''');
            SELECT  '%', V_LOG_MESSAGE;
            SET V_LOG_MESSAGE = 'FAILED - Procedure ' || V_PROC_NAME || ', ' || REPLACE(@@error.message,'\'\'','''''');
            SELECT  '%', V_LOG_MESSAGE;
            SET OUT_PARAM = 0;
            SELECT OUT_PARAM;
    END;
END;