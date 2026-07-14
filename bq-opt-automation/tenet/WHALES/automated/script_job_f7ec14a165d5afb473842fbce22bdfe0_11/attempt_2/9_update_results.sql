UPDATE `thcdnadevdata.staging.query_ai_optimization_results`
SET
  optimized_sql = """WITH
source_with_hash AS (
  SELECT
    s.*,
    FARM_FINGERPRINT(TO_JSON_STRING(STRUCT(
      s.homedept,
      s.wrklddept,
      s.wrkldsub1,
      s.wrklddesc,
      s.daysopen,
      s.openyear,
      CAST(s.nonp AS NUMERIC) AS nonp,
      CAST(s.budvol AS NUMERIC) AS budvol,
      CAST(s.budprodhrs AS NUMERIC) AS budprodhrs,
      CAST(s.budnprodhrs AS NUMERIC) AS budnprodhrs,
      CAST(s.budproddls AS NUMERIC) AS budproddls,
      CAST(s.budnproddls AS NUMERIC) AS budnproddls,
      CAST(s.budptofctr AS NUMERIC) AS budptofctr,
      s.payperiod,
      s.rptmonth,
      CAST(s.targminvol AS NUMERIC) AS targminvol,
      CAST(s.targfixhrs AS NUMERIC) AS targfixhrs,
      CAST(s.targhruos AS NUMERIC) AS targhruos,
      CAST(s.pdrwrkldvol AS NUMERIC) AS pdrwrkldvol,
      CAST(s.prodacthrs AS NUMERIC) AS prodacthrs,
      CAST(s.regacthrs AS NUMERIC) AS regacthrs,
      CAST(s.nonpacthrs AS NUMERIC) AS nonpacthrs,
      CAST(s.otacthrs AS NUMERIC) AS otacthrs,
      CAST(s.clacthrs AS NUMERIC) AS clacthrs,
      CAST(s.cbackacthrs AS NUMERIC) AS cbackacthrs,
      CAST(s.pdptohrs AS NUMERIC) AS pdptohrs,
      CAST(s.pdinshrs AS NUMERIC) AS pdinshrs,
      CAST(s.pdnonphrs AS NUMERIC) AS pdnonphrs,
      CAST(s.prodactdls AS NUMERIC) AS prodactdls,
      CAST(s.regactdls AS NUMERIC) AS regactdls,
      CAST(s.otactdls AS NUMERIC) AS otactdls,
      CAST(s.clactdls AS NUMERIC) AS clactdls,
      CAST(s.cbackactdls AS NUMERIC) AS cbackactdls,
      CAST(s.pdptodls AS NUMERIC) AS pdptodls,
      CAST(s.pdinsdls AS NUMERIC) AS pdinsdls,
      CAST(s.pdnonpdls AS NUMERIC) AS pdnonpdls,
      CAST(s.tmpdata AS NUMERIC) AS tmpdata,
      s.xclosed,
      CAST(s.daybudvol AS NUMERIC) AS daybudvol,
      CAST(s.daybudprodhrs AS NUMERIC) AS daybudprodhrs,
      CAST(s.daybudnprodhrs AS NUMERIC) AS daybudnprodhrs,
      CAST(s.daybudearnrate AS NUMERIC) AS daybudearnrate,
      CAST(s.daybudptofctr AS NUMERIC) AS daybudptofctr,
      CAST(s.mthbudvol AS NUMERIC) AS mthbudvol,
      CAST(s.newearntot AS NUMERIC) AS newearntot,
      CAST(s.newearntotpaid AS NUMERIC) AS newearntotpaid,
      CAST(s.yearnhrs AS NUMERIC) AS yearnhrs,
      CAST(s.yearndls AS NUMERIC) AS yearndls,
      CAST(s.yearnhrspaid AS NUMERIC) AS yearnhrspaid,
      CAST(s.yearndlspaid AS NUMERIC) AS yearndlspaid,
      CAST(s.dayactvol AS NUMERIC) AS dayactvol,
      CAST(s.dayactprodhrs AS NUMERIC) AS dayactprodhrs,
      CAST(s.dayactnprodhrs AS NUMERIC) AS dayactnprodhrs,
      CAST(s.dayactproddls AS NUMERIC) AS dayactproddls,
      CAST(s.daybudproddls AS NUMERIC) AS daybudproddls,
      CAST(s.dayactnproddls AS NUMERIC) AS dayactnproddls,
      CAST(s.daybudnproddls AS NUMERIC) AS daybudnproddls,
      CAST(s.neworienhrs AS NUMERIC) AS neworienhrs,
      CAST(s.newinservhrs AS NUMERIC) AS newinservhrs,
      CAST(s.neworiendls AS NUMERIC) AS neworiendls,
      CAST(s.newinservdls AS NUMERIC) AS newinservdls,
      CAST(s.prodacthrstra AS NUMERIC) AS prodacthrstra,
      CAST(s.prodactdlstra AS NUMERIC) AS prodactdlstra,
      CAST(s.regactdlstra AS NUMERIC) AS regactdlstra,
      CAST(s.regacthrstra AS NUMERIC) AS regacthrstra,
      CAST(s.otacthrstra AS NUMERIC) AS otacthrstra,
      CAST(s.otactdlstra AS NUMERIC) AS otactdlstra,
      CAST(s.pdptothrstra AS NUMERIC) AS pdptothrstra,
      CAST(s.pdptodlstra AS NUMERIC) AS pdptodlstra,
      CAST(s.prodactdlsoffset AS NUMERIC) AS prodactdlsoffset,
      CAST(s.regactdlstraoffset AS NUMERIC) AS regactdlstraoffset,
      CAST(s.otactdlstraoffset AS NUMERIC) AS otactdlstraoffset,
      CAST(s.pdptodlstraoffset AS NUMERIC) AS pdptodlstraoffset
    ))) AS row_hash
  FROM `lmrs_ods.hold1b1` AS s
),
target_with_hash AS (
  SELECT
    t.fac,
    t.dept,
    t.period,
    t.caldate,
    FARM_FINGERPRINT(TO_JSON_STRING(STRUCT(
      t.homedept, t.wrklddept, t.wrkldsub1, t.wrklddesc, t.daysopen, t.openyear, t.nonp, t.budvol, t.budprodhrs, t.budnprodhrs, t.budproddls, t.budnproddls, t.budptofctr, t.payperiod, t.rptmonth, t.targminvol, t.targfixhrs, t.targhruos, t.pdrwrkldvol, t.prodacthrs, t.regacthrs, t.nonpacthrs, t.otacthrs, t.clacthrs, t.cbackacthrs, t.pdptohrs, t.pdinshrs, t.pdnonphrs, t.prodactdls, t.regactdls, t.otactdls, t.clactdls, t.cbackactdls, t.pdptodls, t.pdinsdls, t.pdnonpdls, t.tmpdata, t.xclosed, t.daybudvol, t.daybudprodhrs, t.daybudnprodhrs, t.daybudearnrate, t.daybudptofctr, t.mthbudvol, t.newearntot, t.newearntotpaid, t.yearnhrs, t.yearndls, t.yearnhrspaid, t.yearndlspaid, t.dayactvol, t.dayactprodhrs, t.dayactnprodhrs, t.dayactproddls, t.daybudproddls, t.dayactnproddls, t.daybudnproddls, t.neworienhrs, t.newinservhrs, t.neworiendls, t.newinservdls, t.prodacthrstra, t.prodactdlstra, t.regactdlstra, t.regacthrstra, t.otacthrstra, t.otactdlstra, t.pdptothrstra, t.pdptodlstra, t.prodactdlsoffset, t.regactdlstraoffset, t.otactdlstraoffset, t.pdptodlstraoffset
    ))) AS row_hash
  FROM `lmrs_ods.godailyhrs_seg1_pp_sum` AS t
),
changes_to_apply AS (
  SELECT s.*
  FROM source_with_hash AS s
  LEFT JOIN target_with_hash AS t
    ON s.fac = t.fac
    AND s.dept = t.dept
    AND s.period = t.period
    AND s.caldate = t.caldate
  WHERE t.fac IS NULL -- Row is new and needs to be inserted
     OR s.row_hash <> t.row_hash -- Row exists but has changed and needs to be updated
)
MERGE INTO `lmrs_ods.godailyhrs_seg1_pp_sum` AS target
USING changes_to_apply AS source
  ON target.fac = source.fac
  AND target.dept = source.dept
  AND target.period = source.period
  AND target.caldate = source.caldate
WHEN MATCHED THEN
  UPDATE SET
    caldate = source.caldate, homedept = source.homedept, wrklddept = source.wrklddept, wrkldsub1 = source.wrkldsub1, wrklddesc = source.wrklddesc, daysopen = source.daysopen, openyear = source.openyear, nonp = CAST(source.nonp AS NUMERIC), budvol = CAST(source.budvol AS NUMERIC), budprodhrs = CAST(source.budprodhrs AS NUMERIC), budnprodhrs = CAST(source.budnprodhrs AS NUMERIC), budproddls = CAST(source.budproddls AS NUMERIC), budnproddls = CAST(source.budnproddls AS NUMERIC), budptofctr = CAST(source.budptofctr AS NUMERIC), payperiod = source.payperiod, rptmonth = source.rptmonth, targminvol = CAST(source.targminvol AS NUMERIC), targfixhrs = CAST(source.targfixhrs AS NUMERIC), targhruos = CAST(source.targhruos AS NUMERIC), pdrwrkldvol = CAST(source.pdrwrkldvol AS NUMERIC), prodacthrs = CAST(source.prodacthrs AS NUMERIC), regacthrs = CAST(source.regacthrs AS NUMERIC), nonpacthrs = CAST(source.nonpacthrs AS NUMERIC), otacthrs = CAST(source.otacthrs AS NUMERIC), clacthrs = CAST(source.clacthrs AS NUMERIC), cbackacthrs = CAST(source.cbackacthrs AS NUMERIC), pdptohrs = CAST(source.pdptohrs AS NUMERIC), pdinshrs = CAST(source.pdinshrs AS NUMERIC), pdnonphrs = CAST(source.pdnonphrs AS NUMERIC), prodactdls = CAST(source.prodactdls AS NUMERIC), regactdls = CAST(source.regactdls AS NUMERIC), otactdls = CAST(source.otactdls AS NUMERIC), clactdls = CAST(source.clactdls AS NUMERIC), cbackactdls = CAST(source.cbackactdls AS NUMERIC), pdptodls = CAST(source.pdptodls AS NUMERIC), pdinsdls = CAST(source.pdinsdls AS NUMERIC), pdnonpdls = CAST(source.pdnonpdls AS NUMERIC), tmpdata = CAST(source.tmpdata AS NUMERIC), xclosed = source.xclosed, daybudvol = CAST(source.daybudvol AS NUMERIC), daybudprodhrs = CAST(source.daybudprodhrs AS NUMERIC), daybudnprodhrs = CAST(source.daybudnprodhrs AS NUMERIC), daybudearnrate = CAST(source.daybudearnrate AS NUMERIC), daybudptofctr = CAST(source.daybudptofctr AS NUMERIC), mthbudvol = CAST(source.mthbudvol AS NUMERIC), newearntot = CAST(source.newearntot AS NUMERIC), newearntotpaid = CAST(source.newearntotpaid AS NUMERIC), yearnhrs = CAST(source.yearnhrs AS NUMERIC), yearndls = CAST(source.yearndls AS NUMERIC), yearnhrspaid = CAST(source.yearnhrspaid AS NUMERIC), yearndlspaid = CAST(source.yearndlspaid AS NUMERIC), dayactvol = CAST(source.dayactvol AS NUMERIC), dayactprodhrs = CAST(source.dayactprodhrs AS NUMERIC), dayactnprodhrs = CAST(source.dayactnprodhrs AS NUMERIC), dayactproddls = CAST(source.dayactproddls AS NUMERIC), daybudproddls = CAST(source.daybudproddls AS NUMERIC), dayactnproddls = CAST(source.dayactnproddls AS NUMERIC), daybudnproddls = CAST(source.daybudnproddls AS NUMERIC), neworienhrs = CAST(source.neworienhrs AS NUMERIC), newinservhrs = CAST(source.newinservhrs AS NUMERIC), neworiendls = CAST(source.neworiendls AS NUMERIC), newinservdls = CAST(source.newinservdls AS NUMERIC), prodacthrstra = CAST(source.prodacthrstra AS NUMERIC), prodactdlstra = CAST(source.prodactdlstra AS NUMERIC), regactdlstra = CAST(source.regactdlstra AS NUMERIC), regacthrstra = CAST(source.regacthrstra AS NUMERIC), otacthrstra = CAST(source.otacthrstra AS NUMERIC), otactdlstra = CAST(source.otactdlstra AS NUMERIC), pdptothrstra = CAST(source.pdptothrstra AS NUMERIC), pdptodlstra = CAST(source.pdptodlstra AS NUMERIC), prodactdlsoffset = CAST(source.prodactdlsoffset AS NUMERIC), regactdlstraoffset = CAST(source.regactdlstraoffset AS NUMERIC), otactdlstraoffset = CAST(source.otactdlstraoffset AS NUMERIC), pdptodlstraoffset = CAST(source.pdptodlstraoffset AS NUMERIC)
WHEN NOT MATCHED THEN
  INSERT (fac, dept, period, caldate, homedept, wrklddept, wrkldsub1, wrklddesc, daysopen, openyear, nonp, budvol, budprodhrs, budnprodhrs, budproddls, budnproddls, budptofctr, payperiod, rptmonth, targminvol, targfixhrs, targhruos, pdrwrkldvol, prodacthrs, regacthrs, nonpacthrs, otacthrs, clacthrs, cbackacthrs, pdptohrs, pdinshrs, pdnonphrs, prodactdls, regactdls, otactdls, clactdls, cbackactdls, pdptodls, pdinsdls, pdnonpdls, tmpdata, xclosed, daybudvol, daybudprodhrs, daybudnprodhrs, daybudearnrate, daybudptofctr, mthbudvol, newearntot, newearntotpaid, yearnhrs, yearndls, yearnhrspaid, yearndlspaid, dayactvol, dayactprodhrs, dayactnprodhrs, dayactproddls, daybudproddls, dayactnproddls, daybudnproddls, neworienhrs, newinservhrs, neworiendls, newinservdls, prodacthrstra, prodactdlstra, regactdlstra, regacthrstra, otacthrstra, otactdlstra, pdptothrstra, pdptodlstra, prodactdlsoffset, regactdlstraoffset, otactdlstraoffset, pdptodlstraoffset)
  VALUES (source.fac, source.dept, source.period, source.caldate, source.homedept, source.wrklddept, source.wrkldsub1, source.wrklddesc, source.daysopen, source.openyear, CAST(source.nonp AS NUMERIC), CAST(source.budvol AS NUMERIC), CAST(source.budprodhrs AS NUMERIC), CAST(source.budnprodhrs AS NUMERIC), CAST(source.budproddls AS NUMERIC), CAST(source.budnproddls AS NUMERIC), CAST(source.budptofctr AS NUMERIC), source.payperiod, source.rptmonth, CAST(source.targminvol AS NUMERIC), CAST(source.targfixhrs AS NUMERIC), CAST(source.targhruos AS NUMERIC), CAST(source.pdrwrkldvol AS NUMERIC), CAST(source.prodacthrs AS NUMERIC), CAST(source.regacthrs AS NUMERIC), CAST(source.nonpacthrs AS NUMERIC), CAST(source.otacthrs AS NUMERIC), CAST(source.clacthrs AS NUMERIC), CAST(source.cbackacthrs AS NUMERIC), CAST(source.pdptohrs AS NUMERIC), CAST(source.pdinshrs AS NUMERIC), CAST(source.pdnonphrs AS NUMERIC), CAST(source.prodactdls AS NUMERIC), CAST(source.regactdls AS NUMERIC), CAST(source.otactdls AS NUMERIC), CAST(source.clactdls AS NUMERIC), CAST(source.cbackactdls AS NUMERIC), CAST(source.pdptodls AS NUMERIC), CAST(source.pdinsdls AS NUMERIC), CAST(source.pdnonpdls AS NUMERIC), CAST(source.tmpdata AS NUMERIC), source.xclosed, CAST(source.daybudvol AS NUMERIC), CAST(source.daybudprodhrs AS NUMERIC), CAST(source.daybudnprodhrs AS NUMERIC), CAST(source.daybudearnrate AS NUMERIC), CAST(source.daybudptofctr AS NUMERIC), CAST(source.mthbudvol AS NUMERIC), CAST(source.newearntot AS NUMERIC), CAST(source.newearntotpaid AS NUMERIC), CAST(source.yearnhrs AS NUMERIC), CAST(source.yearndls AS NUMERIC), CAST(source.yearnhrspaid AS NUMERIC), CAST(source.yearndlspaid AS NUMERIC), CAST(source.dayactvol AS NUMERIC), CAST(source.dayactprodhrs AS NUMERIC), CAST(source.dayactnprodhrs AS NUMERIC), CAST(source.dayactproddls AS NUMERIC), CAST(source.daybudproddls AS NUMERIC), CAST(source.dayactnproddls AS NUMERIC), CAST(source.daybudnproddls AS NUMERIC), CAST(source.neworienhrs AS NUMERIC), CAST(source.newinservhrs AS NUMERIC), CAST(source.neworiendls AS NUMERIC), CAST(source.newinservdls AS NUMERIC), CAST(source.prodacthrstra AS NUMERIC), CAST(source.prodactdlstra AS NUMERIC), CAST(source.regactdlstra AS NUMERIC), CAST(source.regacthrstra AS NUMERIC), CAST(source.otacthrstra AS NUMERIC), CAST(source.otactdlstra AS NUMERIC), CAST(source.pdptothrstra AS NUMERIC), CAST(source.pdptodlstra AS NUMERIC), CAST(source.prodactdlsoffset AS NUMERIC), CAST(source.regactdlstraoffset AS NUMERIC), CAST(source.otactdlstraoffset AS NUMERIC), CAST(source.pdptodlstraoffset AS NUMERIC))""",
  updated_at = CURRENT_DATETIME("America/Chicago")
WHERE job_id = 'script_job_f7ec14a165d5afb473842fbce22bdfe0_11'
  AND created_at = "2026-07-14T10:38:01.915023";
