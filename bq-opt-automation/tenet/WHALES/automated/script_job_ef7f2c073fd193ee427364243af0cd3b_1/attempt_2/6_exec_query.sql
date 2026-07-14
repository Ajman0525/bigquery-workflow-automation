-- =================================================================================================
-- Script to create and validate two temporary tables.
-- Expected Outcome: The discrepancy and duplicate detail SELECTs should return zero rows.
-- The final SELECT statement should return two summary rows with row_count = 0, confirming that
-- V_TEMP_TABLE_ORIG and V_TEMP_TABLE_OPT produce identical distinct results and V_TEMP_TABLE_OPT
-- has no duplicate rows.
-- =================================================================================================
-- 1. Stored Procedure Context
-- =================================================================================================
-- START STORED PROCEDURE CONTEXT
-- Auto-generated from 2_sp_details.sql and 3_orig_sp.sql.
-- No stored procedure context dependencies were detected.
-- END STORED PROCEDURE CONTEXT

-- =================================================================================================
-- 2. Create the Original Temporary Table (V_TEMP_TABLE_ORIG)
-- =================================================================================================
CREATE OR REPLACE TEMP TABLE V_TEMP_TABLE_ORIG AS
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

-- =================================================================================================
-- 3. Create the Optimized Temporary Table (V_TEMP_TABLE_OPT)
-- =================================================================================================
CREATE OR REPLACE TEMP TABLE V_TEMP_TABLE_OPT AS
WITH
  unioned_sources AS (
    SELECT
      *, 'PP' AS timeperiod_identifier
    FROM `lmrs_ods.divdaily_seg1_pp`
    UNION ALL
    SELECT
      *, 'MM' AS timeperiod_identifier
    FROM `lmrs_ods.divdaily_seg1_mm`
    UNION ALL
    SELECT
      *, 'SD' AS timeperiod_identifier
    FROM `lmrs_ods.divdaily_seg1_sd`
  ),
  prepared_data AS (
    SELECT
      -- Pre-compute join keys and trim all necessary columns once
      TRIM(fac) AS fac,
      TRIM(dept) AS dept,
      CONCAT(TRIM(fac), TRIM(dept)) AS join_key_dept,
      TRIM(jfacdept) AS jfacdept,
      TRIM(period) AS period,
      caldate,
      TRIM(curday) AS curday,
      realmin,
      varvol,
      bdgtvol,
      totvol,
      TRIM(wrklddept) AS wrklddept,
      TRIM(wrkldsub1) AS wrkldsub1,
      TRIM(wrklddesc) AS wrklddesc,
      targminvol, targhruos, targfixhrs, varhrs, fixact, varact, varvar, xptofctr, earntot, earndls, xreghrs, xregdls, xothrs, xotdls, xclhrs, xcldls, xcbackhrs, xcbackdls, prdhrs, prddls, totvar, totvardls, gopdptohrs, gopdptodls, gopdinshrs, gopdinsdls, gopdnonphrs, gopdnonpdls, gneworienhrs, gneworiendls, gnewinservhrs, gnewinservdls, xallprodhrs, overtimehrs, overtimedls, conthrs, contdls, dtargminvol, dtotvol, drealmin, dvarvol, dvarhrs, dearntot, dprdhrs, dfixact, dvaract, dvarvar, dtotvar, dovertimehrs, dconthrs, dnonphrs, mtargminvol, mtotvol, mrealmin, mvarvol, mvarhrs, mearntot, mprdhrs, mfixact, mvaract, mvarvar, mtotvar, movertimehrs, mconthrs, mnonphrs, daybudprodhrs, daybudnprodhrs, daybudptofctr, daybdgtvol, mthbudvol, newearntot, newearntotpaid, newearntotb, yearnhrs, xearndls, yearnhrspaid, xearndlspaid, dayactprodhrs, dayactnprodhrs, dayactvol, daybudproddls, dayactproddls, daybudnproddls, dayactnproddls, gprodacthrstra, gprodactdlstra, gregactdlstra, gregacthrstra, gotacthrstra, gotactdlstra, gpdptothrstra, gpdptodlstra, gprodactdlsoffset, gregactdlstraoffset, gotactdlstraoffset, gpdptodlstraoffset,
      TRIM(nreg) AS nreg,
      timeperiod_identifier
    FROM unioned_sources
  )
SELECT
  d.fac,
  xfac.facdesc,
  d.dept,
  xd.ddesc,
  d.jfacdept,
  d.period,
  d.caldate,
  d.curday,
  d.realmin,
  d.varvol,
  d.bdgtvol,
  d.totvol,
  d.wrklddept,
  d.wrkldsub1,
  d.wrklddesc,
  d.targminvol, d.targhruos, d.targfixhrs, d.varhrs, d.fixact, d.varact, d.varvar, d.xptofctr, d.earntot, d.earndls, d.xreghrs, d.xregdls, d.xothrs, d.xotdls, d.xclhrs, d.xcldls, d.xcbackhrs, d.xcbackdls, d.prdhrs, d.prddls, d.totvar, d.totvardls, d.gopdptohrs, d.gopdptodls, d.gopdinshrs, d.gopdinsdls, d.gopdnonphrs, d.gopdnonpdls, d.gneworienhrs, d.gneworiendls, d.gnewinservhrs, d.gnewinservdls, d.xallprodhrs, d.overtimehrs, d.overtimedls, d.conthrs, d.contdls, d.dtargminvol, d.dtotvol, d.drealmin, d.dvarvol, d.dvarhrs, d.dearntot, d.dprdhrs, d.dfixact, d.dvaract, d.dvarvar, d.dtotvar, d.dovertimehrs, d.dconthrs, d.dnonphrs, d.mtargminvol, d.mtotvol, d.mrealmin, d.mvarvol, d.mvarhrs, d.mearntot, d.mprdhrs, d.mfixact, d.mvaract, d.mvarvar, d.mtotvar, d.movertimehrs, d.mconthrs, d.mnonphrs, d.daybudprodhrs, d.daybudnprodhrs, d.daybudptofctr, d.daybdgtvol, d.mthbudvol, d.newearntot, d.newearntotpaid, d.newearntotb, d.yearnhrs, d.xearndls, d.yearnhrspaid, d.xearndlspaid, d.dayactprodhrs, d.dayactnprodhrs, d.dayactvol, d.daybudproddls, d.dayactproddls, d.daybudnproddls, d.dayactnproddls, d.gprodacthrstra, d.gprodactdlstra, d.gregactdlstra, d.gregacthrstra, d.gotacthrstra, d.gotactdlstra, d.gpdptothrstra, d.gpdptodlstra, d.gprodactdlsoffset, d.gregactdlstraoffset, d.gotactdlstraoffset, d.gpdptodlstraoffset,
  d.nreg,
  'lmrs' AS source_system_id,
  DATETIME(TIMESTAMP(CURRENT_DATETIME), 'America/Chicago') AS load_ts,
  d.timeperiod_identifier
FROM prepared_data AS d
LEFT JOIN `lmrs_staging.vw_xlbfac` AS xfac ON d.fac = xfac.fac
LEFT JOIN `lmrs_staging.vw_xgendept` AS xd ON d.join_key_dept = xd.jdept
LEFT JOIN `lmrs_ods.sattlco` AS s ON d.fac = TRIM(s.tlco);

-- =================================================================================================
-- 4. Validation Step: Compare the two tables and check optimized duplicates.
-- DISCREPANCY counts distinct rows that appear in one table but not the other.
-- DUPLICATE ROWS counts extra copies of duplicate rows in V_TEMP_TABLE_OPT.
-- The first two SELECT statements show the actual rows when discrepancies or duplicates exist.
-- The final SELECT statement shows only the summary counts.
-- =================================================================================================
CREATE OR REPLACE TEMP TABLE V_VALIDATION_DISCREPANCIES AS
(SELECT 'ONLY IN ORIGINAL' AS validation_diff_type, *
 FROM V_TEMP_TABLE_ORIG
 EXCEPT DISTINCT
 SELECT 'ONLY IN ORIGINAL' AS validation_diff_type, *
 FROM V_TEMP_TABLE_OPT
)
UNION ALL
(SELECT 'ONLY IN OPTIMIZED' AS validation_diff_type, *
 FROM V_TEMP_TABLE_OPT
 EXCEPT DISTINCT
 SELECT 'ONLY IN OPTIMIZED' AS validation_diff_type, *
 FROM V_TEMP_TABLE_ORIG
);

CREATE OR REPLACE TEMP TABLE V_VALIDATION_OPT_DUPLICATES AS
SELECT duplicate_row.*
FROM (
  SELECT ANY_VALUE(opt) AS duplicate_row
  FROM V_TEMP_TABLE_OPT AS opt
  GROUP BY TO_JSON_STRING(opt)
  HAVING COUNT(*) > 1
);

-- View discrepancy rows.
SELECT *
FROM V_VALIDATION_DISCREPANCIES;

-- View duplicate rows from the optimized query.
SELECT *
FROM V_VALIDATION_OPT_DUPLICATES;

-- View summary counts.
SELECT 'DISCREPANCY' AS validation_check, COUNT(*) AS row_count
FROM V_VALIDATION_DISCREPANCIES
UNION ALL
SELECT 'DUPLICATE ROWS' AS validation_check, COALESCE(SUM(row_count - 1), 0) AS row_count
FROM (
  SELECT COUNT(*) AS row_count
  FROM V_TEMP_TABLE_OPT AS opt
  GROUP BY TO_JSON_STRING(opt)
  HAVING COUNT(*) > 1
);
