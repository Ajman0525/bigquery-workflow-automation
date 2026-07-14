-- Job ID: script_job_f7ec14a165d5afb473842fbce22bdfe0_11

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

CREATE OR REPLACE PROCEDURE thcdnadevdata.staging.opt_sp_lmrsrgpp_sum(OUT OUT_PARAM INT64)
BEGIN
	--++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
	-- Application:   LMRS
	--
	-- Name:          sp_lmrsrgpp_sum
	--
	-- Description:   
	--                                        
	-- Parameters:
	--
	-- Invoked by:    - To be detemined.
	--     
	-- Rev History:
	--            11/09/2025 - Ramprasad - New version
	--++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
	DECLARE
	  V_PROC_NAME STRING;
	DECLARE
	  V_LOG_MESSAGE STRING;
	DECLARE
	  V_TABLE_NAME STRING;
	DECLARE
	  V_CURRENT_TS DATETIME;
	DECLARE 
	  OUT_PARAM_LOCAL NUMERIC;
	DECLARE 
	  FILE_DATE DATE;
	DECLARE 
	  FILE_COUNT NUMERIC;

	BEGIN
		SET
			V_PROC_NAME = 'sp_lmrsrgpp_sum';
		SET
			V_LOG_MESSAGE = 'Starting Procedure - ' || V_PROC_NAME || ' - ' || CURRENT_DATETIME("America/Chicago");
		SET
			V_TABLE_NAME = 'godailyhrs';
		SET
			V_CURRENT_TS = DATETIME(TIMESTAMP (CURRENT_DATETIME), "America/Chicago");



create or replace table `lmrs_ods.getxyzstats` as
select
  fac,
  trim(dept) as dept,
  substr(wrkldsub1, 1, 4) as asub4,
  trim(wrklddept) as wrklddept,
  trim(wrkldsub1) as wrkldsub1,
  trim(wrklddesc) as wrklddesc
from `thcdnaproddata.lmrs_staging.vw_xgendept`
where fac is not null and
trim(wrkldsub1) != '';    ----1 record
 
 
truncate table `lmrs_ods.godailyhrs_seg1_pp_sum`;
-- truncate table `lmrs_ods.godailyhrs_seg2_pp_sum`;
 
 
merge into `lmrs_ods.godailyhrs_seg1_pp_sum` as target
using `lmrs_ods.getxyzstats` as source
on target.fac = source.fac and target.dept = source.dept
when matched then
  update set
    target.wrklddept = source.wrklddept,
    target.wrkldsub1 = source.wrkldsub1,
    target.wrklddesc = source.wrklddesc
when not matched then
  insert (fac, dept, wrklddept, wrkldsub1, wrklddesc)
  values (source.fac, source.dept, source.wrklddept, source.wrkldsub1, source.wrklddesc);   ---1 record
 
 
create or replace table `lmrs_ods.stdstats` as
select
  wrklddept,
  asub4
from
  `lmrs_ods.getxyzstats`
group by
  wrklddept,
  asub4 ;
 
 
create or replace table `lmrs_ods.ldone1` as
with unpivoted_pay_periods as (
  select distinct
    t1.fac,
    t1.paycycle,
    t2.year,
    t2.mascycle,
    parse_date('%Y%m%d', t2.pay_period_date) as pay_period_end_date
  from
    `thcdnaproddata.lmrs_staging.vw_xlbfac` as t1
  join (
    select
      mascycle,
      year,
      pay_period_date
    from
      `thcdnaproddata.lmrs_staging.ref_lbcycle`
    unpivot (
      pay_period_date for pay_period_col_name in (
        pp01date, pp02date, pp03date, pp04date, pp05date, pp06date, pp07date, pp08date, pp09date, pp10date,
        pp11date, pp12date, pp13date, pp14date, pp15date, pp16date, pp17date, pp18date, pp19date, pp20date,
        pp21date, pp22date, pp23date, pp24date, pp25date, pp26date, pp27date
      )
    )
  ) as t2 on t1.paycycle = t2.mascycle
  where t2.year >= '2023'
),
 
day_offsets as (
  select day_offset from unnest(generate_array(0, 13)) as day_offset
),
 
final_data as (
  select
    t.fac,
    trim(t.dept) as dept,
    p.paycycle,
    p.year,
    p.mascycle,
    p.pay_period_end_date as pp_end_date,
    date_sub(p.pay_period_end_date, interval day_offsets.day_offset day) as xdate,
    format('%02d', 14 - day_offsets.day_offset) as xday,
    1 as tmpdata, wrklddept, wrklddesc, wrkldsub1
  from
    `thcdnaproddata.lmrs_staging.vw_xgendept` as t
  join
    unpivoted_pay_periods as p on t.fac = p.fac
  cross join
    day_offsets
)
 
select
  fac,
  dept,
  xday as period,
  xdate as caldate,
  tmpdata, wrklddept, wrklddesc, wrkldsub1
from
  final_data
where fac is not null
order by
  fac,
  dept,
  paycycle,
  xday, xdate, wrklddept, wrklddesc, wrkldsub1;
 
 
   
 
merge into
  `lmrs_ods.godailyhrs_seg1_pp_sum` as target
using
  lmrs_ods.ldone1 as source
on
  target.fac = source.fac
  and trim(target.dept) = trim(source.dept)
  and target.period = source.period
  -- and target.caldate = source.caldate
when matched then
  update set
    target.caldate = source.caldate,
    target.tmpdata = cast(source.tmpdata as numeric),
    target.wrklddept = source.wrklddept,
    target.wrklddesc = source.wrklddesc,
    target.wrkldsub1 = source.wrkldsub1
when not matched then
  insert
    (fac, dept, period, caldate, tmpdata, wrklddept, wrklddesc, wrkldsub1)
  values
    (source.fac, source.dept, source.period, source.caldate, cast(source.tmpdata as numeric), source.wrklddept, source.wrklddesc, source.wrkldsub1);
 
 
 
 
create or replace table `lmrs_ods.ldoneh1` as
with unpivoted_pay_periods as (
  select distinct
    t1.fac,
    t1.paycycle,
    t2.year,
    t2.mascycle,
    parse_date('%Y%m%d', t2.pay_period_date) as pay_period_end_date
  from
    `lmrs_staging.vw_xlbfac` as t1
  join (
    select
      mascycle,
      year,
      pay_period_date
    from
      `lmrs_staging.ref_lbcycle`
    unpivot (
      pay_period_date for pay_period_col_name in (
        pp01date, pp02date, pp03date, pp04date, pp05date, pp06date, pp07date, pp08date, pp09date, pp10date,
        pp11date, pp12date, pp13date, pp14date, pp15date, pp16date, pp17date, pp18date, pp19date, pp20date,
        pp21date, pp22date, pp23date, pp24date, pp25date, pp26date, pp27date
      )
    )
  ) as t2 on t1.paycycle = t2.mascycle
  where t2.year >= '2023'
),
 
day_offsets as (
  select day_offset from unnest(generate_array(0, 13)) as day_offset
),
 
filteredsource as (
  select
  fac, dept,
  count(distinct (jobclass || erole) ) tmpdata
  from
      `lmrs_ods.dailyhrs`
      group by fac, dept
      order by fac, dept
  ),
 
final_data as (
  select
    t.fac,
    trim(t.dept) as dept,
    p.paycycle,
    p.year,
    p.mascycle,
    p.pay_period_end_date as pp_end_date,
    date_sub(p.pay_period_end_date, interval day_offsets.day_offset day) as xdate,
    format('%02d', 14 - day_offsets.day_offset) as xday,
    t.tmpdata
  from
  filteredsource as t
    join
    unpivoted_pay_periods as p on t.fac = p.fac
  cross join
    day_offsets
)
 
select
  fac,
  dept,
  xday as period,
  xdate as caldate,
  tmpdata
from
  final_data
where fac is not null
order by
  fac,
  dept,
  paycycle,
  xday, xdate;
 
 
 
merge into `lmrs_ods.godailyhrs_seg1_pp_sum` as target
using `lmrs_ods.ldoneh1` as source
on
  target.fac = source.fac
  and target.dept = source.dept
  and target.period = source.period
  and target.caldate = source.caldate
when matched
  then
  update set
    target.caldate = source.caldate,
    target.tmpdata = cast(source.tmpdata as numeric)
when not matched
  then
  insert
    (fac, dept, period, caldate, tmpdata)
  values
    (source.fac, source.dept, source.period, source.caldate, cast(source.tmpdata as numeric));
 
 
 
 
CREATE OR REPLACE TABLE `lmrs_ods.firstx1` AS
select
  fac as fac1, dept as dept1, caldate as caldate1, homedept, wrklddept, wrkldsub1, wrklddesc, daysopen, openyear, nonp, budvol, budprodhrs, budnprodhrs,
  budproddls, budnproddls, budptofctr, payperiod, rptmonth,
  targminvol, targfixhrs, targhruos, pdrwrkldvol,
  prodacthrs, regacthrs, nonpacthrs, otacthrs, clacthrs, cbackacthrs, pdptohrs,
  pdinshrs, pdnonphrs,
  neworienhrs, newinservhrs, neworiendls, newinservdls,
  prodactdls, regactdls, otactdls, clactdls, cbackactdls, pdptodls, pdinsdls, pdnonpdls,
  tmpdata, xclosed, daybudvol, daybudprodhrs, daybudnprodhrs, daybudearnrate, daybudptofctr,
  mthbudvol, newearntot, newearntotpaid, yearnhrs, yearndls, yearnhrspaid, yearndlspaid,
  dayactvol, dayactprodhrs, dayactnprodhrs, dayactproddls, daybudproddls, dayactnproddls, daybudnproddls,
  prodacthrstra, prodactdlstra,
  regactdlstra, regacthrstra,
  otacthrstra, otactdlstra,
  pdptothrstra, pdptodlstra,
  prodactdlsoffset, regactdlstraoffset, otactdlstraoffset, pdptodlstraoffset
from `lmrs_ods.gonewdailyhrs_seg1`
where fac is not null;
 
 
 
create or replace table `lmrs_ods.secondx1` as
select
  fac,
  dept,
  hrsjobclass,
  hrsemporcont,
  hrsearncode,
  hrscaldate,
  hrssub1,
  hrsnorp,
  hrserole,
  hrsval,
  avgrate,
  avghrstra,
  avgdoltra,
  realhrstra,
  realdoltra,
  traoffsetdol,
from `lmrs_ods.gonewdailyhrs_seg2`
where fac is not null;
 
 
 
 
 
 
create or replace table `lmrs_ods.hold1b1` as (
select
a.period, a.fac, a.dept, a.caldate, b.*
from (
   SELECT
        fac,
        dept,
        caldate,
        period,wrklddept,wrkldsub1,wrklddesc
    FROM
        `lmrs_ods.godailyhrs_seg1_pp_sum`
) a
full outer join (
  select * from `lmrs_ods.firstx1` where fac1 is not null
) b
on a.fac = b.fac1 and a.dept = b.dept1 and a.caldate = b.caldate1);
 
 
 
 
-- START OPTIMIZED QUERY
WITH
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
  VALUES (source.fac, source.dept, source.period, source.caldate, source.homedept, source.wrklddept, source.wrkldsub1, source.wrklddesc, source.daysopen, source.openyear, CAST(source.nonp AS NUMERIC), CAST(source.budvol AS NUMERIC), CAST(source.budprodhrs AS NUMERIC), CAST(source.budnprodhrs AS NUMERIC), CAST(source.budproddls AS NUMERIC), CAST(source.budnproddls AS NUMERIC), CAST(source.budptofctr AS NUMERIC), source.payperiod, source.rptmonth, CAST(source.targminvol AS NUMERIC), CAST(source.targfixhrs AS NUMERIC), CAST(source.targhruos AS NUMERIC), CAST(source.pdrwrkldvol AS NUMERIC), CAST(source.prodacthrs AS NUMERIC), CAST(source.regacthrs AS NUMERIC), CAST(source.nonpacthrs AS NUMERIC), CAST(source.otacthrs AS NUMERIC), CAST(source.clacthrs AS NUMERIC), CAST(source.cbackacthrs AS NUMERIC), CAST(source.pdptohrs AS NUMERIC), CAST(source.pdinshrs AS NUMERIC), CAST(source.pdnonphrs AS NUMERIC), CAST(source.prodactdls AS NUMERIC), CAST(source.regactdls AS NUMERIC), CAST(source.otactdls AS NUMERIC), CAST(source.clactdls AS NUMERIC), CAST(source.cbackactdls AS NUMERIC), CAST(source.pdptodls AS NUMERIC), CAST(source.pdinsdls AS NUMERIC), CAST(source.pdnonpdls AS NUMERIC), CAST(source.tmpdata AS NUMERIC), source.xclosed, CAST(source.daybudvol AS NUMERIC), CAST(source.daybudprodhrs AS NUMERIC), CAST(source.daybudnprodhrs AS NUMERIC), CAST(source.daybudearnrate AS NUMERIC), CAST(source.daybudptofctr AS NUMERIC), CAST(source.mthbudvol AS NUMERIC), CAST(source.newearntot AS NUMERIC), CAST(source.newearntotpaid AS NUMERIC), CAST(source.yearnhrs AS NUMERIC), CAST(source.yearndls AS NUMERIC), CAST(source.yearnhrspaid AS NUMERIC), CAST(source.yearndlspaid AS NUMERIC), CAST(source.dayactvol AS NUMERIC), CAST(source.dayactprodhrs AS NUMERIC), CAST(source.dayactnprodhrs AS NUMERIC), CAST(source.dayactproddls AS NUMERIC), CAST(source.daybudproddls AS NUMERIC), CAST(source.dayactnproddls AS NUMERIC), CAST(source.daybudnproddls AS NUMERIC), CAST(source.neworienhrs AS NUMERIC), CAST(source.newinservhrs AS NUMERIC), CAST(source.neworiendls AS NUMERIC), CAST(source.newinservdls AS NUMERIC), CAST(source.prodacthrstra AS NUMERIC), CAST(source.prodactdlstra AS NUMERIC), CAST(source.regactdlstra AS NUMERIC), CAST(source.regacthrstra AS NUMERIC), CAST(source.otacthrstra AS NUMERIC), CAST(source.otactdlstra AS NUMERIC), CAST(source.pdptothrstra AS NUMERIC), CAST(source.pdptodlstra AS NUMERIC), CAST(source.prodactdlsoffset AS NUMERIC), CAST(source.regactdlstraoffset AS NUMERIC), CAST(source.otactdlstraoffset AS NUMERIC), CAST(source.pdptodlstraoffset AS NUMERIC));
-- END OPTIMIZED QUERY;


truncate table `lmrs_ods.godailyhrs_seg2_pp_sum`;

create or replace table `lmrs_ods.hold1c1` as
select
  -- a.fac,
  -- a.dept,
  -- a.caldate,
  a.period,
  b.* 
from (
  -- select * from `lmrs_ods.godailyhrs_seg1_pp_sum`
  -- where fac is not null
  --where fac = "010" -- replace with your actual value, e.g., '010'
     SELECT
        fac,
        dept,
        caldate,
        period,
        ROW_NUMBER() OVER (PARTITION BY fac, dept, caldate ORDER BY fac, dept, caldate) AS rn
    FROM
        `lmrs_ods.godailyhrs_seg1_pp_sum`
    WHERE
        fac IS NOT NULL
) a
right outer join (
  select *, hrscaldate as caldate from `lmrs_ods.secondx1`
  where fac is not null
  --where fac = "010" -- replace with your actual value, e.g., '010'
) b
  on a.fac = b.fac and a.dept = b.dept and a.caldate = b.caldate;



merge into `lmrs_ods.godailyhrs_seg2_pp_sum` as target
using (
  select *
  from `lmrs_ods.hold1c1`
  where fac is not null and dept is not null
) as source
on target.fac = source.fac
   and target.dept = source.dept
   and target.hrsjobclass = source.hrsjobclass
   and target.hrsemporcont = source.hrsemporcont
   and target.hrsearncode = source.hrsearncode
   and target.hrsperiod = source.period

when matched then
update set
  hrscaldate = source.hrscaldate,
  hrssub1 = source.hrssub1,
  hrsnorp = source.hrsnorp,
  hrserole = source.hrserole,
  hrsval = source.hrsval,
  avgrate = source.avgrate,
  avghrstra = source.avghrstra,
  avgdoltra = source.avgdoltra,
  realhrstra = source.realhrstra,
  realdoltra = source.realdoltra,
  traoffsetdol = source.traoffsetdol

when not matched then
insert (
  fac, dept, hrscaldate, hrsperiod, hrsjobclass, hrsemporcont, hrsearncode,
  hrssub1, hrsnorp, hrserole, hrsval, avgrate,
  avghrstra, avgdoltra, realhrstra, realdoltra, traoffsetdol
)
values (
  source.fac, source.dept, source.hrscaldate, source.period, source.hrsjobclass, source.hrsemporcont, source.hrsearncode,
  source.hrssub1, source.hrsnorp, source.hrserole, source.hrsval, source.avgrate,
  source.avghrstra, source.avgdoltra, source.realhrstra, source.realdoltra, source.traoffsetdol
);


/* ====================================================== */
/* Updates to Framework log table */
/* ====================================================== */
    INSERT INTO `framework_metadata.dependency_completion_log`
    (
        dependency_item_name,
        source_system_id,
        created_ts,
        created_by
	)
    VALUES 
    (
		v_table_name,
        'LMRS',
        v_current_ts,
        'watcher_framework'
    );

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
  CALL thcdnadevdata.staging.opt_sp_lmrsrgpp_sum(OUT_PARAM);
  SELECT OUT_PARAM AS out_status;
END;

-- ---------------------------------------------------------------------------
-- 3. Cleanup scratch tables and optimized test stored procedure.
-- ---------------------------------------------------------------------------

DROP PROCEDURE IF EXISTS thcdnadevdata.staging.opt_sp_lmrsrgpp_sum;
