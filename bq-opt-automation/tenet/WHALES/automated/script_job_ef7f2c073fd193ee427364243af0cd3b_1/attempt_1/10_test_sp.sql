-- Job ID: script_job_ef7f2c073fd193ee427364243af0cd3b_1

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

CREATE OR REPLACE PROCEDURE thcdnadevdata.staging.opt_sp_rep_daily_performance_detail(OUT out_param INT64)
begin
--++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
-- application:   lmrs
--
-- name:          sp_rep_daily_performance_detail
--
-- description:   populates base table for productive and paid reports
--                                        
-- parameters:
--
-- source tables: lmrs_staging.vw_xlbfac
--                lmrs_ods.sattlco   
--                lmrs_staging.vw_xgendept  
--                lmrs_ods.divdaily_seg1_pp
--                lmrs_ods.divdaily_seg1_mm
--                lmrs_ods.divdaily_seg1_sd
--
-- target tables: lmrs_idm.daily_performance_detail
--
-- invoked by:    
--     
-- rev history:
--                07/02/2025 - Sunitha - created the procedure
--                09/12/2025 - Sunitha - Modified the query for divdaily to include different timeperiod    
--                data and addedd the timeperiod_identifier column
--
--++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
DECLARE
  V_PROC_NAME STRING;
DECLARE
  V_LOG_MESSAGE STRING;
DECLARE
  V_TABLE_NAME STRING;
DECLARE
  V_CURRENT_TS DATETIME;

BEGIN
SET
  V_PROC_NAME = 'sp_rep_daily_performance_detail';
SET
  V_LOG_MESSAGE = 'Starting Procedure - ' || V_PROC_NAME || ' - ' || CURRENT_DATETIME("America/Chicago");
SET
  V_TABLE_NAME = 'daily_performance_detail';
SET
  V_CURRENT_TS = DATETIME(TIMESTAMP (CURRENT_DATETIME), "America/Chicago");

  TRUNCATE TABLE `lmrs_idm.daily_performance_detail`;

	-- START OPTIMIZED QUERY
INSERT INTO `lmrs_idm.daily_performance_detail` (
  fac, facdesc, dept, ddesc, jfacdept, period, caldate, curday, realmin, varvol, bdgtvol, totvol, wrklddept, wrkldsub1, wrklddesc, targminvol, targhruos, targfixhrs, varhrs, fixact, varact, varvar, xptofctr, earntot, earndls, xreghrs, xregdls, xothrs, xotdls, xclhrs, xcldls, xcbackhrs, xcbackdls, prdhrs, prddls, totvar, totvardls, gopdptohrs, gopdptodls, gopdinshrs, gopdinsdls, gopdnonphrs, gopdnonpdls, gneworienhrs, gneworiendls, gnewinservhrs, gnewinservdls, xallprodhrs, overtimehrs, overtimedls, conthrs, contdls, dtargminvol, dtotvol, drealmin, dvarvol, dvarhrs, dearntot, dprdhrs, dfixact, dvaract, dvarvar, dtotvar, dovertimehrs, dconthrs, dnonphrs, mtargminvol, mtotvol, mrealmin, mvarvol, mvarhrs, mearntot, mprdhrs, mfixact, mvaract, mvarvar, mtotvar, movertimehrs, mconthrs, mnonphrs, daybudprodhrs, daybudnprodhrs, daybudptofctr, daybdgtvol, mthbudvol, newearntot, newearntotpaid, newearntotb, yearnhrs, xearndls, yearnhrspaid, xearndlspaid, dayactprodhrs, dayactnprodhrs, dayactvol, daybudproddls, dayactproddls, daybudnproddls, dayactnproddls, gprodacthrstra, gprodactdlstra, gregactdlstra, gregacthrstra, gotacthrstra, gotactdlstra, gpdptothrstra, gpdptodlstra, gprodactdlsoffset, gregactdlstraoffset, gotactdlstraoffset, gpdptodlstraoffset, nreg, source_system_id, load_ts, timeperiod_identifier
)
WITH
  unioned_data AS (
    SELECT
      'PP' AS timeperiod_identifier,
      -- Explicitly list all required columns to avoid `SELECT *`
      fac, dept, jfacdept, period, caldate, curday, realmin, varvol, bdgtvol, totvol, wrklddept, wrkldsub1, wrklddesc, targminvol, targhruos, targfixhrs, varhrs, fixact, varact, varvar, xptofctr, earntot, earndls, xreghrs, xregdls, xothrs, xotdls, xclhrs, xcldls, xcbackhrs, xcbackdls, prdhrs, prddls, totvar, totvardls, gopdptohrs, gopdptodls, gopdinshrs, gopdinsdls, gopdnonphrs, gopdnonpdls, gneworienhrs, gneworiendls, gnewinservhrs, gnewinservdls, xallprodhrs, overtimehrs, overtimedls, conthrs, contdls, dtargminvol, dtotvol, drealmin, dvarvol, dvarhrs, dearntot, dprdhrs, dfixact, dvaract, dvarvar, dtotvar, dovertimehrs, dconthrs, dnonphrs, mtargminvol, mtotvol, mrealmin, mvarvol, mvarhrs, mearntot, mprdhrs, mfixact, mvaract, mvarvar, mtotvar, movertimehrs, mconthrs, mnonphrs, daybudprodhrs, daybudnprodhrs, daybudptofctr, daybdgtvol, mthbudvol, newearntot, newearntotpaid, newearntotb, yearnhrs, xearndls, yearnhrspaid, xearndlspaid, dayactprodhrs, dayactnprodhrs, dayactvol, daybudproddls, dayactproddls, daybudnproddls, dayactnproddls, gprodacthrstra, gprodactdlstra, gregactdlstra, gregacthrstra, gotacthrstra, gotactdlstra, gpdptothrstra, gpdptodlstra, gprodactdlsoffset, gregactdlstraoffset, gotactdlstraoffset, gpdptodlstraoffset, nreg
    FROM `lmrs_ods.divdaily_seg1_pp`
    UNION ALL
    SELECT
      'MM' AS timeperiod_identifier,
      fac, dept, jfacdept, period, caldate, curday, realmin, varvol, bdgtvol, totvol, wrklddept, wrkldsub1, wrklddesc, targminvol, targhruos, targfixhrs, varhrs, fixact, varact, varvar, xptofctr, earntot, earndls, xreghrs, xregdls, xothrs, xotdls, xclhrs, xcldls, xcbackhrs, xcbackdls, prdhrs, prddls, totvar, totvardls, gopdptohrs, gopdptodls, gopdinshrs, gopdinsdls, gopdnonphrs, gopdnonpdls, gneworienhrs, gneworiendls, gnewinservhrs, gnewinservdls, xallprodhrs, overtimehrs, overtimedls, conthrs, contdls, dtargminvol, dtotvol, drealmin, dvarvol, dvarhrs, dearntot, dprdhrs, dfixact, dvaract, dvarvar, dtotvar, dovertimehrs, dconthrs, dnonphrs, mtargminvol, mtotvol, mrealmin, mvarvol, mvarhrs, mearntot, mprdhrs, mfixact, mvaract, mvarvar, mtotvar, movertimehrs, mconthrs, mnonphrs, daybudprodhrs, daybudnprodhrs, daybudptofctr, daybdgtvol, mthbudvol, newearntot, newearntotpaid, newearntotb, yearnhrs, xearndls, yearnhrspaid, xearndlspaid, dayactprodhrs, dayactnprodhrs, dayactvol, daybudproddls, dayactproddls, daybudnproddls, dayactnproddls, gprodacthrstra, gprodactdlstra, gregactdlstra, gregacthrstra, gotacthrstra, gotactdlstra, gpdptothrstra, gpdptodlstra, gprodactdlsoffset, gregactdlstraoffset, gotactdlstraoffset, gpdptodlstraoffset, nreg
    FROM `lmrs_ods.divdaily_seg1_mm`
    UNION ALL
    SELECT
      'SD' AS timeperiod_identifier,
      fac, dept, jfacdept, period, caldate, curday, realmin, varvol, bdgtvol, totvol, wrklddept, wrkldsub1, wrklddesc, targminvol, targhruos, targfixhrs, varhrs, fixact, varact, varvar, xptofctr, earntot, earndls, xreghrs, xregdls, xothrs, xotdls, xclhrs, xcldls, xcbackhrs, xcbackdls, prdhrs, prddls, totvar, totvardls, gopdptohrs, gopdptodls, gopdinshrs, gopdinsdls, gopdnonphrs, gopdnonpdls, gneworienhrs, gneworiendls, gnewinservhrs, gnewinservdls, xallprodhrs, overtimehrs, overtimedls, conthrs, contdls, dtargminvol, dtotvol, drealmin, dvarvol, dvarhrs, dearntot, dprdhrs, dfixact, dvaract, dvarvar, dtotvar, dovertimehrs, dconthrs, dnonphrs, mtargminvol, mtotvol, mrealmin, mvarvol, mvarhrs, mearntot, mprdhrs, mfixact, mvaract, mvarvar, mtotvar, movertimehrs, mconthrs, mnonphrs, daybudprodhrs, daybudnprodhrs, daybudptofctr, daybdgtvol, mthbudvol, newearntot, newearntotpaid, newearntotb, yearnhrs, xearndls, yearnhrspaid, xearndlspaid, dayactprodhrs, dayactnprodhrs, dayactvol, daybudproddls, dayactproddls, daybudnproddls, dayactnproddls, gprodacthrstra, gprodactdlstra, gregactdlstra, gregacthrstra, gotacthrstra, gotactdlstra, gpdptothrstra, gpdptodlstra, gprodactdlsoffset, gregactdlstraoffset, gotactdlstraoffset, gpdptodlstraoffset, nreg
    FROM `lmrs_ods.divdaily_seg1_sd`
  )
SELECT
  TRIM(d.fac),
  xfac.facdesc,
  TRIM(d.dept),
  xd.ddesc,
  TRIM(d.jfacdept),
  TRIM(d.period),
  d.caldate,
  TRIM(d.curday),
  d.realmin,
  d.varvol,
  d.bdgtvol,
  d.totvol,
  TRIM(d.wrklddept),
  TRIM(d.wrkldsub1),
  TRIM(d.wrklddesc),
  d.targminvol, d.targhruos, d.targfixhrs, d.varhrs, d.fixact, d.varact, d.varvar, d.xptofctr, d.earntot, d.earndls, d.xreghrs, d.xregdls, d.xothrs, d.xotdls, d.xclhrs, d.xcldls, d.xcbackhrs, d.xcbackdls, d.prdhrs, d.prddls, d.totvar, d.totvardls, d.gopdptohrs, d.gopdptodls, d.gopdinshrs, d.gopdinsdls, d.gopdnonphrs, d.gopdnonpdls, d.gneworienhrs, d.gneworiendls, d.gnewinservhrs, d.gnewinservdls, d.xallprodhrs, d.overtimehrs, d.overtimedls, d.conthrs, d.contdls, d.dtargminvol, d.dtotvol, d.drealmin, d.dvarvol, d.dvarhrs, d.dearntot, d.dprdhrs, d.dfixact, d.dvaract, d.dvarvar, d.dtotvar, d.dovertimehrs, d.dconthrs, d.dnonphrs, d.mtargminvol, d.mtotvol, d.mrealmin, d.mvarvol, d.mvarhrs, d.mearntot, d.mprdhrs, d.mfixact, d.mvaract, d.mvarvar, d.mtotvar, d.movertimehrs, d.mconthrs, d.mnonphrs, d.daybudprodhrs, d.daybudnprodhrs, d.daybudptofctr, d.daybdgtvol, d.mthbudvol, d.newearntot, d.newearntotpaid, d.newearntotb, d.yearnhrs, d.xearndls, d.yearnhrspaid, d.xearndlspaid, d.dayactprodhrs, d.dayactnprodhrs, d.dayactvol, d.daybudproddls, d.dayactproddls, d.daybudnproddls, d.dayactnproddls, d.gprodacthrstra, d.gprodactdlstra, d.gregactdlstra, d.gregacthrstra, d.gotacthrstra, d.gotactdlstra, d.gpdptothrstra, d.gpdptodlstra, d.gprodactdlsoffset, d.gregactdlstraoffset, d.gotactdlstraoffset, d.gpdptodlstraoffset,
  TRIM(d.nreg),
  'lmrs' AS source_system_id,
  DATETIME(TIMESTAMP(CURRENT_DATETIME), "America/Chicago") AS load_ts,
  d.timeperiod_identifier
FROM unioned_data AS d
LEFT JOIN `lmrs_staging.vw_xlbfac` AS xfac
  ON TRIM(d.fac) = xfac.fac
LEFT JOIN `lmrs_staging.vw_xgendept` AS xd
  ON CONCAT(TRIM(d.fac), TRIM(d.dept)) = xd.jdept;
-- END OPTIMIZED QUERY;
---
 /*   -- Budget volume divided by 14 days logic
    (
        CASE
            WHEN ((CASE WHEN TRIM(d.wrkldsub1) = 'CDAY' THEN 1 ELSE bdgtvol / 14 END) * 100) > 0 THEN
                ((CASE WHEN TRIM(d.wrkldsub1) = 'CDAY' THEN 1 ELSE bdgtvol / 14 END) * 100) + 0.5
            WHEN ((CASE WHEN TRIM(d.wrkldsub1) = 'CDAY' THEN 1 ELSE bdgtvol / 14 END) * 100) = 0 THEN
                0
            WHEN ((CASE WHEN TRIM(d.wrkldsub1) = 'CDAY' THEN 1 ELSE bdgtvol / 14 END) * 100) < 0 THEN
                ((CASE WHEN TRIM(d.wrkldsub1) = 'CDAY' THEN 1 ELSE bdgtvol / 14 END) * 100) - 0.5
        END
    ) / 100 AS daybdgt_14,

    -- Budget volume divided by number of days in the month
    (
        CASE
            WHEN ((CASE WHEN TRIM(d.wrkldsub1) = 'CDAY' THEN 1 ELSE bdgtvol / EXTRACT(DAY FROM LAST_DAY(caldate)) END) * 100) > 0 THEN
                ((CASE WHEN TRIM(d.wrkldsub1) = 'CDAY' THEN 1 ELSE bdgtvol / EXTRACT(DAY FROM LAST_DAY(caldate)) END) * 100) + 0.5
            WHEN ((CASE WHEN TRIM(d.wrkldsub1) = 'CDAY' THEN 1 ELSE bdgtvol / EXTRACT(DAY FROM LAST_DAY(caldate)) END) * 100) = 0 THEN
                0
            WHEN ((CASE WHEN TRIM(d.wrkldsub1) = 'CDAY' THEN 1 ELSE bdgtvol / EXTRACT(DAY FROM LAST_DAY(caldate)) END) * 100) < 0 THEN
                ((CASE WHEN TRIM(d.wrkldsub1) = 'CDAY' THEN 1 ELSE bdgtvol / EXTRACT(DAY FROM LAST_DAY(caldate)) END) * 100) - 0.5
        END
    ) / 100 AS daybdgt_mnthdays,

    'lmrs' AS source_system_id,
    DATETIME(TIMESTAMP(CURRENT_DATETIME), "America/Chicago") AS load_ts

FROM `lmrs_temp_dataset.ss5_wf_divdaily` d
JOIN `lmrs_staging.vw_xlbfac` xfac ON TRIM(d.fac) = xfac.fac
JOIN `lmrs_staging.vw_xgendept` xd ON CONCAT(TRIM(d.fac), TRIM(d.dept)) = xd.jdept
JOIN `lmrs_idm.sattlco` s ON TRIM(d.fac) = TRIM(s.tlco);
*/
  
    /* ====================================================== */
    /* Updates to Framework log table */
    /* ====================================================== */
  --   INSERT INTO `framework_metadata.dependency_completion_log`
  --   (
  --       dependency_item_name,
  --       source_system_id,
  --       created_ts,
  --       created_by
	-- )
  --   VALUES 
  --   (
	-- 	v_table_name,
  --       'LMRS',
  --       v_current_ts,
  --       'watcher_framework'
  --   );

    SET out_param = 1;

    SELECT out_param; 

    /* ====================================================================== */
    /* HANDLE EXCEPTIONS */
    /* ====================================================================== */
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
  CALL thcdnadevdata.staging.opt_sp_rep_daily_performance_detail(OUT_PARAM);
  SELECT OUT_PARAM AS out_status;
END;

-- ---------------------------------------------------------------------------
-- 3. Cleanup scratch tables and optimized test stored procedure.
-- ---------------------------------------------------------------------------

DROP PROCEDURE IF EXISTS thcdnadevdata.staging.opt_sp_rep_daily_performance_detail;
