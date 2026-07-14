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
