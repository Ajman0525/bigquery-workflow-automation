CREATE PROCEDURE thcdnaproddata.lmrs_idm.sp_rep_daily_performance_detail(OUT out_param INT64)
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

	INSERT INTO `lmrs_idm.daily_performance_detail`
	(
fac ,
  facdesc ,
  dept ,
  ddesc ,
  jfacdept ,
  period ,
  caldate ,
  curday ,
  realmin ,
  varvol ,
  bdgtvol ,
  totvol ,
  wrklddept ,
  wrkldsub1 ,
  wrklddesc ,
  targminvol ,
  targhruos ,
  targfixhrs ,
  varhrs ,
  fixact ,
  varact ,
  varvar ,
  xptofctr ,
  earntot ,
  earndls ,
  xreghrs ,
  xregdls ,
  xothrs ,
  xotdls ,
  xclhrs ,
  xcldls ,
  xcbackhrs ,
  xcbackdls ,
  prdhrs ,
  prddls ,
  totvar ,
  totvardls ,
  gopdptohrs ,
  gopdptodls ,
  gopdinshrs ,
  gopdinsdls ,
  gopdnonphrs ,
  gopdnonpdls ,
  gneworienhrs ,
  gneworiendls ,
  gnewinservhrs ,
  gnewinservdls ,
  xallprodhrs ,
  overtimehrs ,
  overtimedls ,
  conthrs ,
  contdls ,
  dtargminvol ,
  dtotvol ,
  drealmin ,
  dvarvol ,
  dvarhrs ,
  dearntot ,
  dprdhrs ,
  dfixact ,
  dvaract ,
  dvarvar ,
  dtotvar ,
  dovertimehrs ,
  dconthrs ,
  dnonphrs ,
  mtargminvol ,
  mtotvol ,
  mrealmin ,
  mvarvol ,
  mvarhrs ,
  mearntot ,
  mprdhrs ,
  mfixact ,
  mvaract ,
  mvarvar ,
  mtotvar ,
  movertimehrs ,
  mconthrs ,
  mnonphrs ,
  daybudprodhrs ,
  daybudnprodhrs ,
  daybudptofctr ,
  daybdgtvol ,
  mthbudvol ,
  newearntot ,
  newearntotpaid ,
  newearntotb ,
  yearnhrs ,
  xearndls ,
  yearnhrspaid ,
  xearndlspaid ,
  dayactprodhrs ,
  dayactnprodhrs ,
  dayactvol ,
  daybudproddls ,
  dayactproddls ,
  daybudnproddls ,
  dayactnproddls ,
  gprodacthrstra ,
  gprodactdlstra ,
  gregactdlstra ,
  gregacthrstra ,
  gotacthrstra ,
  gotactdlstra ,
  gpdptothrstra ,
  gpdptodlstra ,
  gprodactdlsoffset ,
  gregactdlstraoffset ,
  gotactdlstraoffset ,
  gpdptodlstraoffset ,
  nreg ,
  source_system_id ,
  load_ts,
  timeperiod_identifier 

  )

    SELECT
    TRIM(d.fac) AS fac,
    xfac.facdesc,
    TRIM(d.dept) AS dept,
    xd.ddesc,
    TRIM(jfacdept) AS jfacdept,
    TRIM(period) AS period,
    caldate,
    TRIM(curday) AS curday,
    realmin,
    varvol,
    bdgtvol,
    totvol,
    TRIM(d.wrklddept) AS wrklddept,
    TRIM(d.wrkldsub1) AS wrkldsub1,
    TRIM(d.wrklddesc) AS wrklddesc,
    targminvol,
    targhruos,
    targfixhrs,
    varhrs,
    fixact,
    varact,
    varvar,
    xptofctr,
    earntot,
    earndls,
    xreghrs,
    xregdls,
    xothrs,
    xotdls,
    xclhrs,
    xcldls,
    xcbackhrs,
    xcbackdls,
    prdhrs,
    prddls,
    totvar,
    totvardls,
    gopdptohrs,
    gopdptodls,
    gopdinshrs,
    gopdinsdls,
    gopdnonphrs,
    gopdnonpdls,
    gneworienhrs,
    gneworiendls,
    gnewinservhrs,
    gnewinservdls,
    xallprodhrs,
    overtimehrs,
    overtimedls,
    conthrs,
    contdls,
    dtargminvol,
    dtotvol,
    drealmin,
    dvarvol,
    dvarhrs,
    dearntot,
    dprdhrs,
    dfixact,
    dvaract,
    dvarvar,
    dtotvar,
    dovertimehrs,
    dconthrs,
    dnonphrs,
    mtargminvol,
    mtotvol,
    mrealmin,
    mvarvol,
    mvarhrs,
    mearntot,
    mprdhrs,
    mfixact,
    mvaract,
    mvarvar,
    mtotvar,
    movertimehrs,
    mconthrs,
    mnonphrs,
    daybudprodhrs,
    daybudnprodhrs,
    daybudptofctr,
    daybdgtvol,
    mthbudvol,
    newearntot,
    newearntotpaid,
    newearntotb,
    yearnhrs,
    xearndls,
    yearnhrspaid,
    xearndlspaid,
    dayactprodhrs,
    dayactnprodhrs,
    dayactvol,
    daybudproddls,
    dayactproddls,
    daybudnproddls,
    dayactnproddls,
    gprodacthrstra,
    gprodactdlstra,
    gregactdlstra,
    gregacthrstra,
    gotacthrstra,
    gotactdlstra,
    gpdptothrstra,
    gpdptodlstra,
    gprodactdlsoffset,
    gregactdlstraoffset,
    gotactdlstraoffset,
    gpdptodlstraoffset,
    TRIM(nreg) AS nreg,
    'lmrs' AS source_system_id,
    DATETIME(TIMESTAMP(CURRENT_DATETIME), "America/Chicago") AS load_ts
    , d.timeperiod_identifier
from
   ( select *, 'PP' as timeperiod_identifier from `lmrs_ods.divdaily_seg1_pp` 
    union all
    select *, 'MM' as timeperiod_identifier from `lmrs_ods.divdaily_seg1_mm`
    union all
    select *, 'SD' as timeperiod_identifier from `lmrs_ods.divdaily_seg1_sd`
  )
     d
LEFT JOIN `lmrs_staging.vw_xlbfac` xfac ON TRIM(d.fac) = xfac.fac
LEFT JOIN `lmrs_staging.vw_xgendept` xd ON CONCAT(TRIM(d.fac), TRIM(d.dept)) = xd.jdept
LEFT JOIN `lmrs_ods.sattlco` s ON TRIM(d.fac) = TRIM(s.tlco);
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
