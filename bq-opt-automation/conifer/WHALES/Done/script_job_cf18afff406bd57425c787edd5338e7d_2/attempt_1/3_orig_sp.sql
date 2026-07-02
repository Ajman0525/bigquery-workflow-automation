CREATE PROCEDURE cfrdnaproddata3.rcm_mart.sp_fact_cash_summary_pos_goal(IN inparam_facility_cd STRING, OUT outparam INT64)
BEGIN

/* ------------------------------------------------------------------------------------------ */
-- Proc name 	: sp_fact_cash_summary_pos_goal
-- Dataset		: rcm_mart 
-- Author 		: Udo
-- Project		: Conifer Conversion	
-- Proc Desc 	: Stored procedure to merge pos_goal to fact_cash_summary table. 
-- Frequency  : Daily
-- Parameters : facility_code


-- Revision History:

-- When 	  Version 	Modified by 					Change description
---------------------------------------------------------------------------------------------
-- 20250425   1.0 		Udo                  Created!
-- 20250612   1.1     Udo					 Changed logic from Merge to Delete and Insert for performance
-- 20250805   1.2	  Sarah					 Removed V_EXTRACT_RECORD_FOUND for performance
-- 20250819   1.3     Udo          changed the filter for max_posting_date to posting_me
-- 20250114   1.4     Sampanna     changed the delta filter to posting_me >= V_LAST_EXTRACT_DT so the sp process this month's data too
/* ------------------------------------------------------------------------------------------ */
  
  DECLARE V_PROC_NAME STRING;
  DECLARE V_LOG_MESSAGE STRING;
  DECLARE V_FACILITY_CD STRING;
  DECLARE V_RUN_DT DATE;
  DECLARE V_METRIC_NAME STRING;
  DECLARE OUT_PARAM INT64;
  DECLARE V_TEMP_TABLE STRING;
  DECLARE V_TARGET_TBL_NM STRING;
  DECLARE V_LAST_EXTRACT_DT DATETIME;
  DECLARE V_NEXT_EXTRACT_DT DATETIME;

BEGIN
  SET V_FACILITY_CD = UPPER(inparam_facility_cd);
  SET V_METRIC_NAME   = 'pos_goal';
  SET V_TEMP_TABLE   = 'tmp_tbl_'|| V_METRIC_NAME ;
  SET V_TARGET_TBL_NM = 'fact_cash_summary';
  SET V_LAST_EXTRACT_DT = (SELECT MAX(last_extract_ts) FROM `rcm_mart.mart_data_control` 
										             WHERE source_system = 'daac'
													       AND target_table_nm = V_TARGET_TBL_NM
                                 AND metric_nm = V_METRIC_NAME
																 AND fac_cd = V_FACILITY_CD
                                 AND active_flg = 'Y');

   
-- Start Procedure
	SET V_PROC_NAME = 'sp_fact_cash_summary_pos_goal';				
	SET V_LOG_MESSAGE = 'Starting Procedure - ' || V_PROC_NAME || ' - ' || CURRENT_DATETIME("America/Chicago");
	SELECT  '%', V_LOG_MESSAGE;	

	IF  (V_LAST_EXTRACT_DT IS NOT NULL) THEN

 -- temp summary from the view
        CREATE OR REPLACE TEMP TABLE V_TEMP_TABLE AS
        SELECT
          framework_metadata.createhashkey(vw.client_id, vw.source_system, vw.facility_cd, CAST(vw.posting_me AS STRING), V_METRIC_NAME, null, null, null, null, null, null, null, null, null, null, null, null, null, null, null) AS ar_rev_adj_hk,
          vw.dim_facility_hk,
          vw.client_id,
          vw.source_system,
          vw.facility_cd,
          vw.posting_me,
          vw.max_posting_date,
          vw.prior_max_posting_me,
          vw.fiscal_year,
          vw.prior_fiscal_year,
          vw.current_max_year,
          vw.prior_max_year,
          vw.prior_year_max_posting_date,
          vw.posting_month_name,
          vw.current_mtd_posting_days,
          vw.current_fytd_posting_days,
          vw.current_me_posting_days,
          vw.me_fytd_posting_days,
          vw.fytd_posting_days_total,
          vw.max_posting_year,
          vw.max_posting_me,
          vw.quarter,
          vw.quarter_year,
          vw.prior_year_posting_date,
          vw.display,
          vw.tenet_novant,
          V_METRIC_NAME AS metric_key,
          vw.pos_goal AS metric_value
        FROM `cfrdnaproddata3.rcm_mart.vw_detail_consolidated_fact_cash_summary` vw
        WHERE vw.facility_cd = V_FACILITY_CD
          AND vw.posting_me >= V_LAST_EXTRACT_DT;

    
/* Delete the existing records with posting_me_dt > last extract date from Fact_cash table */

        DELETE FROM `cfrdnaproddata3.rcm_mart.fact_cash_summary`
        WHERE metric_key = V_METRIC_NAME AND facility_cd = V_FACILITY_CD AND posting_me_dt >= V_LAST_EXTRACT_DT;


          INSERT INTO `cfrdnaproddata3.rcm_mart.fact_cash_summary` (
          ar_rev_adj_hk,
          dim_facility_hk,
          client_id,
          source_system_cd,
          facility_cd,
          posting_me_dt,
          max_posting_dt,
          prior_max_posting_me_dt,
          fiscal_yr,
          prior_fiscal_yr,
          curr_max_yr,
          prior_max_yr,
          prior_yr_max_posting_dt,
          posting_mth_nm,
          curr_mtd_posting_days,
          current_fytd_posting_days,
          current_me_posting_days,
          me_fytd_posting_days,
          fytd_posting_days_total,
          max_posting_yr,
          max_posting_me_dt,
          posting_qrtr,
          posting_qrtr_yr,
          prior_yr_posting_dt,
          display,
          is_tenet,
          metric_key,
          metric_value,
          create_uid,
          create_ts,
          update_uid,
          update_ts
        )
        SELECT
          ar_rev_adj_hk,
          dim_facility_hk,
          client_id,
          source_system,
          facility_cd,
          posting_me,
          max_posting_date,
          prior_max_posting_me,
          fiscal_year,
          prior_fiscal_year,
          current_max_year,
          prior_max_year,
          prior_year_max_posting_date,
          posting_month_name,
          current_mtd_posting_days,
          current_fytd_posting_days,
          current_me_posting_days,
          me_fytd_posting_days,
          fytd_posting_days_total,
          max_posting_year,
          max_posting_me,
          quarter,
          quarter_year,
          prior_year_posting_date,
          display,
          tenet_novant,
          metric_key,
          metric_value,
          V_PROC_NAME,
          CURRENT_DATETIME("America/Chicago"),
          V_PROC_NAME,
          CURRENT_DATETIME("America/Chicago")
        FROM V_TEMP_TABLE;

        SET V_NEXT_EXTRACT_DT = (
          SELECT MAX(posting_me)
          FROM V_TEMP_TABLE
          WHERE facility_cd = V_FACILITY_CD
            AND posting_me >= V_LAST_EXTRACT_DT
        );

        IF V_NEXT_EXTRACT_DT IS NOT NULL THEN
          INSERT INTO `cfrdnaproddata3.rcm_mart.mart_data_control`
          SELECT
            'daac',
            V_TARGET_TBL_NM,
            V_FACILITY_CD,
            V_PROC_NAME,
            V_METRIC_NAME,
            V_NEXT_EXTRACT_DT,
            CURRENT_DATETIME("America/Chicago"),
            'Y';
        END IF;

        SET OUT_PARAM = 1;
        SELECT OUT_PARAM;

         -- DROP TABLE V_TEMP_TABLE;
        DROP TABLE IF EXISTS V_TEMP_TABLE;

    END IF;

  EXCEPTION
    WHEN ERROR THEN
      SET V_LOG_MESSAGE = 'FAILED - Procedure ' || V_PROC_NAME || ', Reason: TRANSACTION_ABORTED - ' || REPLACE(@@error.message, '\'', '\'\'');
      SET V_LOG_MESSAGE = 'FAILED - Procedure ' || V_PROC_NAME || ', ' || REPLACE(@@error.message, '\'', '\'\'');
      SELECT '%', V_LOG_MESSAGE;
      SET OUT_PARAM = 0;
      SELECT OUT_PARAM;
      RAISE USING message = SUBSTR(@@error.message, 1, 5000);

  END;
END;
