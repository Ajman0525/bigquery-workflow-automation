-- Job ID: script_job_265e586b3ed5115f618f9e12adb3405c_35

-- ---------------------------------------------------------------------------
-- Test stored procedure script.
-- Creates scratch objects in thcdnadevdata.staging,
-- invokes the optimized test SP, and drops those objects at the end.
-- ---------------------------------------------------------------------------

-- ---------------------------------------------------------------------------
-- 1. Create scratch tables and optimized test stored procedure.
-- ---------------------------------------------------------------------------

-- ---------------------------------------------------------------------------
-- Test scaffolding only.
-- The tables below are created in thcdnadevdata.staging
-- as prerequisites for manually testing the optimized SP.
-- They are not part of the stored procedure definition and are dropped in
-- the cleanup block at the end of the combined test script.
-- ---------------------------------------------------------------------------

-- No prod DML targets were detected.

CREATE OR REPLACE PROCEDURE thcdnadevdata.staging.opt_csp_odsadvantxdw_fact_ce_update(IN facility_id STRING, OUT OUT_PARAM INT64)
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
        SELECT * FROM `uspidnaproddata.advantx_ods.ar_billtrans_%s`
        """, V_source_system);

      EXECUTE IMMEDIATE V_SQL;
  SET V_SQL = FORMAT("""
        CREATE TEMP TABLE temp_ar_billtrans_charge AS
        SELECT * FROM uspidnaproddata.advantx_ods.ar_billtrans_charge_%s
        """, V_source_system);

      EXECUTE IMMEDIATE V_SQL;
  
   SET V_SQL = FORMAT("""
        CREATE TEMP TABLE temp_ca_visit_visitdept_proc_hist AS
        SELECT * FROM uspidnaproddata.advantx_ods.ca_visit_visitdept_proc_hist_%s
        """, V_source_system);

      EXECUTE IMMEDIATE V_SQL;

  SET V_SQL = FORMAT("""
        CREATE TEMP TABLE temp_ca_visit_visitdept_pers_role AS
        SELECT * FROM uspidnaproddata.advantx_ods.ca_visit_visitdept_pers_role_%s
        """, V_source_system);

      EXECUTE IMMEDIATE V_SQL;

    SET V_SQL = FORMAT("""
        CREATE TEMP TABLE temp_ca_visit_visitdept_supply_hist AS
        SELECT * FROM uspidnaproddata.advantx_ods.ca_visit_visitdept_supply_hist_%s
        """, V_source_system);

      EXECUTE IMMEDIATE V_SQL;

    SET V_SQL = FORMAT("""
        CREATE TEMP TABLE temp_ca_visit_visitdept AS
        SELECT * FROM uspidnaproddata.advantx_ods.ca_visit_visitdept_%s
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
                FROM `uspidnaproddata.advantx_ods.ca_case` A INNER JOIN
                temp_ar_billtrans_charge B ON A.source_system_id = B.source_system_id  AND
                                A.case_num = B.case_num INNER JOIN
                temp_ar_billtrans C ON A.source_system_id = C.source_system_id  AND
                                B.bill_trans_num = C.bill_trans_num INNER JOIN
                `uspidnaproddata.advantx_ods.ar_billing_period` D ON A.source_system_id = D.source_system_id  AND
                                C.bill_period_num = D.num AND
                                C.tis_client_num = D.tis_client_num
                                WHERE C.active = 1 ) A) A
                                WHERE rownumber = 1 
                                AND A.source_system_id=V_source_system
                                ORDER BY A.source_system_id,
                                A.tis_client_num,A.case_num;

 -- Primary Procedure (Scheduled and Billed)
 
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

            -- Primary Procedure (Max Charge Amount)

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
                        `uspidnaproddata.advantx_ods.ut_proc_fee` C ON 
                                        B.source_system_id = C.source_system_id and
                                        B.procfee_num = C.num INNER JOIN
                        `uspidnaproddata.advantx_ods.ut_proc` D ON 
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
                        `uspidnaproddata.advantx_ods.ca_visit` F ON 
                                        B.source_system_id = F.source_system_id AND
                                        B.visit_num = F.visit_num LEFT OUTER JOIN
                        `uspidnaproddata.advantx_ods.ut_visittypes` G ON 
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
                        `uspidnaproddata.advantx_ods.ut_proc_fee` C ON 
                                        B.source_system_id = C.source_system_id and
                                        B.procfee_num = C.num INNER JOIN
                        `uspidnaproddata.advantx_ods.ut_proc` D ON 
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
                        `uspidnaproddata.advantx_ods.ca_visit` F ON 
                                        B.source_system_id = F.source_system_id AND
                                        B.visit_num = F.visit_num LEFT OUTER JOIN
                        `uspidnaproddata.advantx_ods.ut_visittypes` G ON 
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

    -- Primary Procedure No Charges 

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
                        `uspidnaproddata.advantx_ods.ut_proc_fee` C ON 
                                        B.source_system_id = C.source_system_id and
                                        B.procfee_num = C.num INNER JOIN
                        `uspidnaproddata.advantx_ods.ut_proc` D ON 
                                        C.source_system_id = D.source_system_id and
                                        C.proc_num = D.num LEFT OUTER JOIN
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
                        `uspidnaproddata.advantx_ods.ca_visit` F ON 
                                        B.source_system_id = F.source_system_id AND
                                        B.visit_num = F.visit_num LEFT OUTER JOIN
                        `uspidnaproddata.advantx_ods.ut_visittypes` G ON 
                                        F.source_system_id = G.source_system_id AND
                                        F.visittype_num = G.num LEFT OUTER JOIN
                        PRIMARY_PROCEDURE_ce_temp H ON 
                                        B.source_system_id = H.source_system_id AND
                                        B.case_num = H.case_num
                                             WHERE 
                                                   A.active = 1 AND
                                                   D.quick_code <> 'ERROR' 
                                                      AND E.source_system_id IS NULL 
                                                       AND H.source_system_id IS NULL 
                                                GROUP BY A.source_system_id
                                                        ,B.case_num
                                                        ,B.procfee_num
                                                        ,D.quick_code
                                                        ,G.num
                                                        ,G.quick_code) A) A
                                WHERE rownumber = 1 AND A.source_system_id=V_source_system; 


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
                        `uspidnaproddata.advantx_ods.ut_proc_fee` C ON 
                                        B.source_system_id = C.source_system_id and
                                        B.procfee_num = C.num INNER JOIN
                        `uspidnaproddata.advantx_ods.ut_proc` D ON 
                                        C.source_system_id = D.source_system_id and
                                        C.proc_num = D.num LEFT OUTER JOIN
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
                        `uspidnaproddata.advantx_ods.ca_visit` F ON 
                                        B.source_system_id = F.source_system_id AND
                                        B.visit_num = F.visit_num LEFT OUTER JOIN
                        `uspidnaproddata.advantx_ods.ut_visittypes` G ON 
                                        F.source_system_id = G.source_system_id AND
                                        F.visittype_num = G.num LEFT OUTER JOIN
                        PRIMARY_PROCEDURE_ce_temp H ON 
                                        B.source_system_id = H.source_system_id AND
                                        B.case_num = H.case_num
                                             WHERE 
                                                   A.active = 1 AND
                                                   D.quick_code = 'ERROR' 
                                                     AND E.source_system_id IS NULL 
                                                      AND H.source_system_id IS NULL 
                                                GROUP BY A.source_system_id
                                                        ,B.case_num
                                                        ,B.procfee_num
                                                        ,D.quick_code
                                                        ,G.num
                                                        ,G.quick_code) A) A
                                WHERE rownumber = 1 and A.source_system_id=V_source_system;  

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
        FROM    `uspidnaproddata.advantx_ods.ca_case` a
        INNER JOIN  (SELECT * FROM ar_billtrans_charge_ce_temp) b
                    on      a.source_system_id = b.source_system_id and
                    a.case_num = b.case_num
        INNER JOIN `uspidnaproddata.advantx_ods.ut_proc_fee` d
            on      b.source_system_id = d.source_system_id and
                    b.procfee_num = d.num
        INNER JOIN `uspidnaproddata.advantx_ods.ut_proc` e
            on      d.source_system_id = e.source_system_id and
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


INSERT INTO expected_collection_pct_fc_ce_temp
            SELECT          source_system_id, fc_code,
            CASE WHEN SUM(charge_amount) = 0.0 THEN 0.0 ELSE SUM(paid_amount)/SUM(charge_amount) END as expected_collection_pct
            FROM
            (
            SELECT  a.source_system_id,i.num as fc_code,
                a.case_num,
                SUM(b.charge_amount) as charge_amount,
                SUM(b.paid_amount) as paid_amount,
                SUM(b.writtenoff_amount) as writtenoff_amount                           
            FROM    `uspidnaproddata.advantx_ods.ca_case` a
            INNER JOIN  (SELECT * FROM ar_billtrans_charge_ce_temp) b
            on  a.source_system_id = b.source_system_id and
                a.case_num = b.case_num
            INNER JOIN `uspidnaproddata.advantx_ods.ut_proc_fee` d
            on  b.source_system_id = d.source_system_id and
                b.procfee_num = d.num
            INNER JOIN `uspidnaproddata.advantx_ods.ut_proc` e
            on  d.source_system_id = e.source_system_id and
                d.proc_num = e.num
            INNER JOIN (SELECT 
                ROW_NUMBER() OVER(PARTITION BY a_s.source_system_id, a_s.case_num ORDER BY policy_effective_date DESC) AS RowNum, 
                a_s.source_system_id, 
                a_s.case_num, 
                b_s.pers_org_num as payor_code, 
                IFNULL(copay_amt,0.00) as copay_amt
                FROM `uspidnaproddata.advantx_ods.ad_case_ps_ins` a_s  INNER JOIN             
                     `uspidnaproddata.advantx_ods.ad_ps_rolehist_ins` b_s  ON a_s.role_num = 6 AND
                a_s.source_system_id = b_s.source_system_id AND
                a_s.pers_org_num_pt = b_s.pers_org_num_pt AND 
                a_s.ps_num = b_s.ps_num and 
                a_s.role_num = b_s.role_num AND
                b_s.pers_org_num IS NOT NULL
                ) G ON g.RowNum = 1 AND
                    a.source_system_id = g.source_system_id AND
                    a.case_num = g.case_num 
            INNER JOIN `uspidnaproddata.advantx_ods.ut_insurcarrier`  h
            ON  g.source_system_id = h.source_system_id and
                g.payor_code = h.pers_org_num
            INNER JOIN `uspidnaproddata.advantx_ods.ut_insurcarrier_tisclient`    J
            ON  h.source_system_id = j.source_system_id and
                h.num = j.inscarr_num and
                a.tisclient_num = j.tisclient_num
            INNER JOIN `uspidnaproddata.advantx_ods.ut_insurtype`    I
            ON  j.source_system_id = i.source_system_id and
                j.insurtype_num = i.num
            WHERE   CAST(key_dos as DATE) BETWEEN DATE_TRUNC(DATE_SUB(CURRENT_DATE(), INTERVAL 3 YEAR), YEAR) and  CURRENT_DATE 
                and e.quick_code NOT IN ('ERROR','DUMMY')
        and a.source_system_id=V_source_system
            GROUP BY  a.source_system_id, i.num, a.case_num
                        HAVING          charge_amount - paid_amount - writtenoff_amount <= 10.00
            --HAVING    SUM(charge_amount) - SUM(paid_amount) - SUM(writtenoff_amount) <= 10.00
            ) cases
            GROUP BY source_system_id,fc_code;     

        -- Insert Summation Rows

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
                    A.company_code
                    ,CAST(A.pers_org_num_org AS STRING) AS faclity_code
                    ,CAST(G.pers_org_num AS STRING) AS physician_code
                    ,I.procedure_code
                    ,cast(B.pers_org_num_pers as string) AS patient_code
                    ,CAST(CAST(C.key_dos AS DATE) AS DATETIME) AS date_of_service,
                -- CAST(CONCAT(CONCAT(RIGHT(CONCAT( '0000' ,  LTRIM(RTRIM(IFNULL(CAST(C.tisclient_num AS STRING),'')))),4) ,
                --     RIGHT(CONCAT( '00000000' ,  LTRIM(RTRIM(IFNULL(CAST(C.pers_org_num_pt AS STRING),'')))),8)),
                --     CASE WHEN C.case_num IS NULL THEN '00000000' ELSE 
                --     RIGHT(CONCAT( '00000000' ,  LTRIM(RTRIM(IFNULL(CAST(C.case_num AS STRING),'')))),8)    END)
                --    AS STRING) AS case_id
                CONCAT(
                        LPAD(TRIM(COALESCE(CAST(C.tisclient_num AS STRING), '')), 4, '0'),
                        LPAD(TRIM(COALESCE(CAST(B.pers_org_num_pers AS STRING), '')), 8, '0'),
                        LPAD(TRIM(COALESCE(CAST(C.case_num AS STRING), '')), 8, '0')
                    ) AS case_id

                --    cast(C.case_num as string) AS case_id
            /*,CAST(RIGHT('0000' + LTRIM(RTRIM(CAST(CASE WHEN C.tisclient_num IS NULL THEN '' ELSE C.tisclient_num END AS  string))),4) + 
             RIGHT('00000000' + LTRIM(RTRIM(CAST(CASE WHEN C.pers_org_num_pt IS NULL THEN '' ELSE C.pers_org_num_pt END as  string))),8) + 
             CASE WHEN C.case_num IS NULL THEN '00000000' ELSE RIGHT('00000000' + LTRIM(RTRIM(CAST(CASE WHEN C.case_num IS NULL THEN '' ELSE C.case_num END AS string))),8) END
             AS string) AS case_id */
                    ,'O' AS patient_type_code
                    ,'U' AS visit_type_code
                    ,1 AS case_count
                    ,0 AS procedure_count
                    ,NULL AS financial_year
                    ,NULL AS financial_period
                    ,NULL AS bill_period_num
                    ,CAST(NULL AS DATETIME) billing_period_start_date
                    ,C.case_num
            ,C.tisclient_num
                    ,I.procedure_code AS cpt_procedure_code
                    ,B.account_num as account_name,

                     --changed  --sad
                    CAST(SUM(F.charge_amount) AS NUMERIC) AS case_charge_amount,
                CAST(0.00 AS NUMERIC) AS case_primary_payment_amount,
                CAST(0.00 AS NUMERIC) AS case_copay_payment_amount,
                CAST(0.00 AS NUMERIC) AS case_writeoff_amount,

                --     ,SUM(F.charge_amount) AS case_charge_amount
                --     ,0.00 AS case_primary_payment_amount 
                --     ,0.00 AS case_copay_payment_amount
                --     ,0.00 AS case_writeoff_amount
                    cast(I.entity_code as string)
                    ,cast(CASE WHEN C.refer_phys_num is null THEN -1 ELSE C.refer_phys_num END as string) AS refer_physician_code
                    ,CAST(NULL as int64) AS acuity_flag
                    ,SUM(F.units) AS units
                    ,A.source_system_id
                    FROM `uspidnaproddata.edw_advantx.vw_ad_tisclient`  A INNER JOIN
                         `uspidnaproddata.advantx_ods.ad_pt` B ON 
                                A.source_system_id = B.source_system_id INNER JOIN
                         `uspidnaproddata.advantx_ods.ca_case` C ON 
                                B.source_system_id = C.source_system_id AND
                                B.pers_org_num_pers = C.pers_org_num_pt LEFT OUTER JOIN
                         `uspidnaproddata.advantx_ods.ca_visit` D ON 
                                C.source_system_id = D.source_system_id AND
                                C.case_num = D.case_num LEFT OUTER JOIN
                         temp_ca_visit_visitdept_proc_hist E ON 
                                D.source_system_id = E.source_system_id AND
                                D.case_num = E.case_num AND
                                D.visit_num = E.visit_num AND
                                E.order_key = 1 LEFT OUTER JOIN
                         (SELECT A.source_system_id
                                 ,A.case_num
                                 ,A.visit_num
                                 ,A.procfee_num
                                 ,A.charge_amount
                                 ,C.tis_client_num
                                 ,CASE WHEN E.quick_code IS NULL THEN '0' ELSE E.quick_code END AS service_code
                                 ,A.bill_trans_num
                                 ,A.units
                              FROM ar_billtrans_charge_ce_temp A INNER JOIN
                                   temp_ar_billtrans B ON 
                                                A.source_system_id = B.source_system_id AND
                                                A.bill_trans_num = B.bill_trans_num INNER JOIN
                                    `uspidnaproddata.advantx_ods.ar_billing_period` C ON 
                                                B.source_system_id = C.source_system_id AND
                                                B.bill_period_num = C.num   LEFT OUTER JOIN
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
                         `uspidnaproddata.advantx_ods.ut_phys`  G ON C.source_system_id = G.source_system_id AND
                                                   C.primary_phys_num = G.num INNER JOIN
                         (SELECT 
                            A.source_system_id
                            ,A.case_num
                            ,A.procfee_num
                            ,A.procedure_code
                            ,B.tis_client_num
                            ,A.facility_num AS entity_code
                            ,A.visit_type_code, 
                            ROW_NUMBER() OVER (PARTITION BY A.source_system_id,  A.case_num,A.bill_period_num 
                            ORDER BY A.procedure_code,A.facility_num ) AS row_num
                            FROM PRIMARY_PROCEDURE_ce_temp A INNER JOIN
                                  `uspidnaproddata.advantx_ods.ar_billing_period` B ON A.source_system_id = B.source_system_id AND
                                                                     A.bill_period_num = B.num) I ON 
                                                                     F.source_system_id = I.source_system_id AND
                                                                     F.case_num = I.case_num 
                                                                     and I.row_num =1
                       WHERE   F.charge_amount IS NOT NULL  and   C.key_dos >=     (SELECT DATE_TRUNC(DATE_SUB(CURRENT_DATE(), INTERVAL 3 YEAR), YEAR) 
    AS datetime_three_years_ago) AND A.source_system_id=V_source_system
                           GROUP BY A.company_code
                                   ,A.pers_org_num_org 
                                   ,G.pers_org_num 
                                   ,I.procedure_code
                                   ,B.pers_org_num_pers 
                                   ,C.key_dos
                                   ,CAST(CONCAT(CONCAT(RIGHT(CONCAT( '0000' ,  LTRIM(RTRIM(IFNULL(CAST(C.tisclient_num AS STRING),'')))),4) ,
                                   RIGHT(CONCAT( '00000000' ,  LTRIM(RTRIM(IFNULL(CAST(C.pers_org_num_pt AS STRING),'')))),8)),
                                   CASE WHEN C.case_num IS NULL THEN '00000000' ELSE 
                                   RIGHT(CONCAT( '00000000' ,  LTRIM(RTRIM(IFNULL(CAST(C.case_num AS STRING),'')))),8)    END)
                                   AS STRING) 
                                   ,I.visit_type_code
                                   ,C.case_num
                   ,C.tisclient_num
                                   ,I.procedure_code
                                   ,B.account_num
                                   ,I.entity_code
                                   ,A.source_system_id
                                   ,C.refer_phys_num
                                   --,F.units;  
                                   ; 

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
        `uspidnaproddata.advantx_ods.ut_proc_fee` B ON   
                A.source_system_id = B.source_system_id AND
        A.procfee_num = B.num INNER JOIN
    `uspidnaproddata.advantx_ods.ut_proc` C ON 
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

MERGE MEDIBIS_FACT_CE_temp A
USING (SELECT  
                A.source_system_id
                ,A.case_num
                ,B.quick_code
                ,ROW_NUMBER() OVER(PARTITION BY A.source_system_id, A.case_num ORDER BY B.quick_code) AS row_num
FROM MEDIBIS_FACT_CE_temp A INNER JOIN
        (SELECT 
                A.source_system_id
                ,A.case_num
                ,A.quick_code
                FROM (SELECT
                A.source_system_id
                ,A.case_num
                ,B.quick_code
                ,ROW_NUMBER() OVER(PARTITION BY A.source_system_id, A.case_num ORDER BY A.source_system_id, A.case_num, B.num) AS RowNumber
        FROM `uspidnaproddata.advantx_ods.as_appointment` A INNER JOIN
         `uspidnaproddata.advantx_ods.ut_visittypes` B ON 
                                A.source_system_id = B.source_system_id AND
                A.visittype_num = B.num
                                    WHERE B.active = 1) A
        WHERE A.RowNumber = 1) B ON 
        A.source_system_id = B.source_system_id AND
        A.case_num = B.case_num) SRC ON
        SRC.source_system_id = A.source_system_id AND
        SRC.case_num = A.case_num  AND
        A.source_system_id = V_source_system AND
        SRC.row_num = 1
        WHEN MATCHED THEN 
        UPDATE SET visit_type_code = quick_code;

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

MERGE MEDIBIS_FACT_CE_temp A
USING (SELECT   
        A.source_system_id,
        A.case_num,
        CAST(IFNULL(C.pers_org_num,-1) AS STRING) AS pers_org_num,
        ROW_NUMBER() OVER (PARTITION BY A.source_system_id, A.case_num ORDER BY IFNULL(C.pers_org_num,-1)) AS row_num
        FROM MEDIBIS_FACT_CE_temp A LEFT OUTER JOIN
        `uspidnaproddata.advantx_ods.ad_case_ps_ins`  B on 
                        A.case_num = B.case_num AND
                        A.source_system_id = B.source_system_id INNER JOIN
        `uspidnaproddata.advantx_ods.ad_ps_rolehist_ins` C ON 
                        B.pers_org_num_pt = C.pers_org_num_pers_ins AND 
                        A.source_system_id = B.source_system_id AND
                        C.role_num = 6) SRC ON
                SRC.source_system_id = A.source_system_id AND
                A.source_system_id = V_source_system AND
                SRC.case_num = A.case_num AND
                SRC.row_num =1 
        WHEN MATCHED THEN 
        UPDATE SET payor_code = SRC.pers_org_num ;    

            -- ICD Codes


MERGE MEDIBIS_FACT_CE_temp A
USING (SELECT DISTINCT  
        A.source_system_id,
        A.case_num,
        C.quick_code,
        ROW_NUMBER() OVER (PARTITION BY A.source_system_id, A.case_num ORDER BY C.quick_code ) AS row_num
        FROM MEDIBIS_FACT_CE_temp A INNER JOIN
            ar_billtrans_charge_ce_temp B ON
                A.source_system_id = B.source_system_id and
                A.case_num = B.case_num   INNER JOIN 
        `uspidnaproddata.advantx_ods.ut_dx` C ON 
                        B.source_system_id = C.source_system_id AND
            B.dx1_num = C.num) SRC ON 
                SRC.source_system_id = A.source_system_id AND
                SRC.case_num = A.case_num AND
                A.source_system_id = V_source_system AND
                SRC.row_num =1 
        WHEN MATCHED THEN 
        UPDATE SET icd9_code = SRC.quick_code ;    


MERGE MEDIBIS_FACT_CE_temp A
USING (SELECT   
        A.source_system_id,
        A.case_num,
        C.quick_code,
        ROW_NUMBER() OVER (PARTITION BY A.source_system_id, A.case_num ORDER BY C.quick_code ) AS row_num
        FROM MEDIBIS_FACT_CE_temp A INNER JOIN 
        ar_billtrans_charge_ce_temp B ON
                A.source_system_id = B.source_system_id and
                A.case_num = B.case_num   INNER JOIN 
        `uspidnaproddata.advantx_ods.ut_dx` C ON 
                        B.source_system_id = C.source_system_id AND
            B.dx1_num_10 = C.num) SRC ON 
                SRC.source_system_id = A.source_system_id and
                SRC.case_num = A.case_num AND
                A.source_system_id = V_source_system AND
                SRC.row_num =1
        WHEN MATCHED THEN 
        UPDATE SET icd10_code = SRC.quick_code ;                            

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
        `uspidnaproddata.advantx_ods.ut_proc_fee`  C ON 
                        B.source_system_id = C.source_system_id AND
                        B.procfee_num = C.num INNER JOIN
        `uspidnaproddata.advantx_ods.ut_servicetypes`  D ON 
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
    INNER JOIN `uspidnaproddata.advantx_ods.ut_room` C 
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
--         `uspidnaproddata.advantx_ods.ad_pt`  B ON 
--                         A.source_system_id = B.source_system_id AND
--                         A.patient_code = CAST(B.pers_org_num_pers AS STRING) INNER JOIN
--         `uspidnaproddata.advantx_ods.co_pers`  C ON 
--                         B.source_system_id = C.source_system_id  
--                         WHERE B.pers_org_num_pers = C.pers_org_num ) SRC ON 
--                 SRC.source_system_id = A.source_system_id and
--                 SRC.pers_org_num_pers = A.patient_code AND
--                 A.source_system_id = V_source_system AND
--                 SRC.row_num =1
--         WHEN MATCHED THEN 
--         UPDATE SET patient_age = SRC.PATIENT_AGE ;



        -- START OPTIMIZED QUERY
WITH PatientMinDOB AS (
  SELECT
    B.source_system_id,
    CAST(B.pers_org_num_pers AS STRING) AS patient_code,
    MIN(C.dob) AS min_dob
  FROM
    `uspidnaproddata.advantx_ods.ad_pt` AS B
    INNER JOIN `uspidnaproddata.advantx_ods.co_pers` AS C ON B.source_system_id = C.source_system_id
    AND B.pers_org_num_pers = C.pers_org_num
  WHERE
    B.source_system_id = V_source_system
  GROUP BY
    1,
    2
)
MERGE MEDIBIS_FACT_CE_temp AS A
USING
  PatientMinDOB AS SRC
ON
  A.source_system_id = SRC.source_system_id
  AND A.patient_code = SRC.patient_code
  AND A.source_system_id = V_source_system
WHEN MATCHED THEN
  UPDATE
SET
  patient_age = FLOOR(DATE_DIFF(A.date_of_service, SRC.min_dob, DAY) / 365.25);
-- END OPTIMIZED QUERY ;

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

                
MERGE MEDIBIS_FACT_CE_temp A
USING (SELECT   
        A.source_system_id,
        A.case_num,
        CASE WHEN C.quick_code IS NULL THEN 'UNKNOWN' ELSE UPPER(C.quick_code) END  AS case_status1,
        ROW_NUMBER() OVER (PARTITION BY A.source_system_id, A.case_num ORDER BY CASE WHEN C.quick_code IS NULL THEN 'UNKNOWN' ELSE UPPER(C.quick_code) END ) AS row_num
        FROM MEDIBIS_FACT_CE_temp A INNER JOIN 
         `uspidnaproddata.advantx_ods.ca_case`  B  ON 
                        A.source_system_id = B.source_system_id AND
                        A.case_num = B.case_num LEFT OUTER JOIN
        `uspidnaproddata.advantx_ods.ods_case_status`  C  ON 
                        B.source_system_id = C.source_system_id 
                        WHERE B.case_status = C.case_status ) SRC ON 
                SRC.source_system_id = A.source_system_id and
                SRC.case_num = A.case_num AND
                 A.source_system_id = V_source_system AND
                SRC.row_num =1
        WHEN MATCHED THEN 
        UPDATE SET case_status = SRC.case_status1 ;

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
        `uspidnaproddata.advantx_ods.ut_supply_tisclient`   B ON 
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
        `uspidnaproddata.advantx_ods.ut_staff_role`  B ON 
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
        `uspidnaproddata.edw_advantx.medibis_dim_case` B ON 
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
        `uspidnaproddata.edw_advantx.medibis_dim_case` B ON 
                        A.source_system_id = B.source_system_id  
                       WHERE A.case_id = B.case_id) SRC ON 
                SRC.source_system_id = A.source_system_id and
                A.source_system_id = V_source_system AND
                SRC.case_id = A.case_id AND
                SRC.row_num =1
        WHEN MATCHED THEN 
        UPDATE SET payor_code = SRC.payor_code1 ;



set complex_dml1 = FORMAT(""" DELETE FROM `uspidnaproddata.edw_advantx.medibis_fact_ce` WHERE source_system_id = '%s' and  date(date_of_service) >= DATE_TRUNC(DATE_SUB(CURRENT_DATE(), INTERVAL 3 YEAR), YEAR);""", V_source_system);


            -- Insert rows

set complex_dml2 = FORMAT("""INSERT INTO `uspidnaproddata.edw_advantx.medibis_fact_ce`
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
                                        (SELECT procedurecode,MAX(drgweight) AS drgweight FROM uspidnaproddata.edw_advantx.cptcode_lookup 
                                        GROUP BY 1)c
                    ON c.procedurecode = A.cpt_procedure_code
                                        left outer join uspidnaproddata.edw_advantx.company_code_xref b
                                        on a.company_code = b.company_code
                                        and a.facility_code = b.facility_code
                                        left outer join uspidnaproddata.edw_advantx.combined_facilities d
                                        on b.oracleid = d.oracleid
                                        WHERE a.source_system_id = "%s" and
                                        date(date_of_service) >= DATE_TRUNC(DATE_SUB(CURRENT_DATE(), INTERVAL 3 YEAR), YEAR);""", V_source_system);
                                 
--------------------------------------------------------------

    select complex_dml1;
    select complex_dml2;


    CALL `uspidnaproddata.framework_metadata.execute_sql_dml` (complex_dml1, V_PROC_NAME,V_RESULT);

    if V_RESULT <> 'P' then 
      RAISE USING message = V_RESULT;
    end if;

    
    if V_RESULT <> 'P' then 
    SET V_ERRORMESSAGE = V_RESULT;
    else SET V_ERRORMESSAGE = @@error.message;
    end if;

    CALL `uspidnaproddata.framework_metadata.execute_sql_dml` (complex_dml2, V_PROC_NAME,V_RESULT);


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

-- ---------------------------------------------------------------------------
-- 2. Invoke optimized test stored procedure.
-- ---------------------------------------------------------------------------

BEGIN
  DECLARE OUT_PARAM INT64 DEFAULT NULL;
  CALL thcdnadevdata.staging.opt_csp_odsadvantxdw_fact_ce_update('rssc', OUT_PARAM);
  SELECT OUT_PARAM AS out_status;
END;

-- ---------------------------------------------------------------------------
-- 3. Cleanup scratch tables and optimized test stored procedure.
-- ---------------------------------------------------------------------------

DROP PROCEDURE IF EXISTS thcdnadevdata.staging.opt_csp_odsadvantxdw_fact_ce_update;
