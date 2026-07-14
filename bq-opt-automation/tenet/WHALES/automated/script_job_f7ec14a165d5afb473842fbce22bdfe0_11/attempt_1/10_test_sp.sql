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
/*
 CSQL-1: Added a CTE `source_deduplicated` to pre-process the source data.
 CSQL-2: Centralized all CAST operations into the CTE for clarity and to avoid repetition.
 CSQL-3: Added `QUALIFY ROW_NUMBER() OVER(...) = 1` to ensure the source provides exactly one row per join key, making the MERGE robust against duplicates and preventing runtime errors.
 CSQL-4: Removed the redundant `caldate = source.caldate` update, as `caldate` is part of the join key and cannot change.
*/
MERGE INTO `lmrs_ods.godailyhrs_seg1_pp_sum` AS target
USING (
  SELECT
    fac,
    dept,
    period,
    caldate,
    homedept,
    wrklddept,
    wrkldsub1,
    wrklddesc,
    daysopen,
    openyear,
    CAST(nonp AS NUMERIC) AS nonp,
    CAST(budvol AS NUMERIC) AS budvol,
    CAST(budprodhrs AS NUMERIC) AS budprodhrs,
    CAST(budnprodhrs AS NUMERIC) AS budnprodhrs,
    CAST(budproddls AS NUMERIC) AS budproddls,
    CAST(budnproddls AS NUMERIC) AS budnproddls,
    CAST(budptofctr AS NUMERIC) AS budptofctr,
    payperiod,
    rptmonth,
    CAST(targminvol AS NUMERIC) AS targminvol,
    CAST(targfixhrs AS NUMERIC) AS targfixhrs,
    CAST(targhruos AS NUMERIC) AS targhruos,
    CAST(pdrwrkldvol AS NUMERIC) AS pdrwrkldvol,
    CAST(prodacthrs AS NUMERIC) AS prodacthrs,
    CAST(regacthrs AS NUMERIC) AS regacthrs,
    CAST(nonpacthrs AS NUMERIC) AS nonpacthrs,
    CAST(otacthrs AS NUMERIC) AS otacthrs,
    CAST(clacthrs AS NUMERIC) AS clacthrs,
    CAST(cbackacthrs AS NUMERIC) AS cbackacthrs,
    CAST(pdptohrs AS NUMERIC) AS pdptohrs,
    CAST(pdinshrs AS NUMERIC) AS pdinshrs,
    CAST(pdnonphrs AS NUMERIC) AS pdnonphrs,
    CAST(prodactdls AS NUMERIC) AS prodactdls,
    CAST(regactdls AS NUMERIC) AS regactdls,
    CAST(otactdls AS NUMERIC) AS otactdls,
    CAST(clactdls AS NUMERIC) AS clactdls,
    CAST(cbackactdls AS NUMERIC) AS cbackactdls,
    CAST(pdptodls AS NUMERIC) AS pdptodls,
    CAST(pdinsdls AS NUMERIC) AS pdinsdls,
    CAST(pdnonpdls AS NUMERIC) AS pdnonpdls,
    CAST(tmpdata AS NUMERIC) AS tmpdata,
    xclosed,
    CAST(daybudvol AS NUMERIC) AS daybudvol,
    CAST(daybudprodhrs AS NUMERIC) AS daybudprodhrs,
    CAST(daybudnprodhrs AS NUMERIC) AS daybudnprodhrs,
    CAST(daybudearnrate AS NUMERIC) AS daybudearnrate,
    CAST(daybudptofctr AS NUMERIC) AS daybudptofctr,
    CAST(mthbudvol AS NUMERIC) AS mthbudvol,
    CAST(newearntot AS NUMERIC) AS newearntot,
    CAST(newearntotpaid AS NUMERIC) AS newearntotpaid,
    CAST(yearnhrs AS NUMERIC) AS yearnhrs,
    CAST(yearndls AS NUMERIC) AS yearndls,
    CAST(yearnhrspaid AS NUMERIC) AS yearnhrspaid,
    CAST(yearndlspaid AS NUMERIC) AS yearndlspaid,
    CAST(dayactvol AS NUMERIC) AS dayactvol,
    CAST(dayactprodhrs AS NUMERIC) AS dayactprodhrs,
    CAST(dayactnprodhrs AS NUMERIC) AS dayactnprodhrs,
    CAST(dayactproddls AS NUMERIC) AS dayactproddls,
    CAST(daybudproddls AS NUMERIC) AS daybudproddls,
    CAST(dayactnproddls AS NUMERIC) AS dayactnproddls,
    CAST(daybudnproddls AS NUMERIC) AS daybudnproddls,
    CAST(neworienhrs AS NUMERIC) AS neworienhrs,
    CAST(newinservhrs AS NUMERIC) AS newinservhrs,
    CAST(neworiendls AS NUMERIC) AS neworiendls,
    CAST(newinservdls AS NUMERIC) AS newinservdls,
    CAST(prodacthrstra AS NUMERIC) AS prodacthrstra,
    CAST(prodactdlstra AS NUMERIC) AS prodactdlstra,
    CAST(regactdlstra AS NUMERIC) AS regactdlstra,
    CAST(regacthrstra AS NUMERIC) AS regacthrstra,
    CAST(otacthrstra AS NUMERIC) AS otacthrstra,
    CAST(otactdlstra AS NUMERIC) AS otactdlstra,
    CAST(pdptothrstra AS NUMERIC) AS pdptothrstra,
    CAST(pdptodlstra AS NUMERIC) AS pdptodlstra,
    CAST(prodactdlsoffset AS NUMERIC) AS prodactdlsoffset,
    CAST(regactdlstraoffset AS NUMERIC) AS regactdlstraoffset,
    CAST(otactdlstraoffset AS NUMERIC) AS otactdlstraoffset,
    CAST(pdptodlstraoffset AS NUMERIC) AS pdptodlstraoffset
  FROM
    `lmrs_ods.hold1b1`
  QUALIFY
    ROW_NUMBER() OVER(PARTITION BY fac, dept, period, caldate) = 1
) AS source ON target.fac = source.fac
AND target.dept = source.dept
AND target.period = source.period
AND target.caldate = source.caldate
WHEN MATCHED THEN
UPDATE
SET
  homedept = source.homedept,
  wrklddept = source.wrklddept,
  wrkldsub1 = source.wrkldsub1,
  wrklddesc = source.wrklddesc,
  daysopen = source.daysopen,
  openyear = source.openyear,
  nonp = source.nonp,
  budvol = source.budvol,
  budprodhrs = source.budprodhrs,
  budnprodhrs = source.budnprodhrs,
  budproddls = source.budproddls,
  budnproddls = source.budnproddls,
  budptofctr = source.budptofctr,
  payperiod = source.payperiod,
  rptmonth = source.rptmonth,
  targminvol = source.targminvol,
  targfixhrs = source.targfixhrs,
  targhruos = source.targhruos,
  pdrwrkldvol = source.pdrwrkldvol,
  prodacthrs = source.prodacthrs,
  regacthrs = source.regacthrs,
  nonpacthrs = source.nonpacthrs,
  otacthrs = source.otacthrs,
  clacthrs = source.clacthrs,
  cbackacthrs = source.cbackacthrs,
  pdptohrs = source.pdptohrs,
  pdinshrs = source.pdinshrs,
  pdnonphrs = source.pdnonphrs,
  prodactdls = source.prodactdls,
  regactdls = source.regactdls,
  otactdls = source.otactdls,
  clactdls = source.clactdls,
  cbackactdls = source.cbackactdls,
  pdptodls = source.pdptodls,
  pdinsdls = source.pdinsdls,
  pdnonpdls = source.pdnonpdls,
  tmpdata = source.tmpdata,
  xclosed = source.xclosed,
  daybudvol = source.daybudvol,
  daybudprodhrs = source.daybudprodhrs,
  daybudnprodhrs = source.daybudnprodhrs,
  daybudearnrate = source.daybudearnrate,
  daybudptofctr = source.daybudptofctr,
  mthbudvol = source.mthbudvol,
  newearntot = source.newearntot,
  newearntotpaid = source.newearntotpaid,
  yearnhrs = source.yearnhrs,
  yearndls = source.yearndls,
  yearnhrspaid = source.yearnhrspaid,
  yearndlspaid = source.yearndlspaid,
  dayactvol = source.dayactvol,
  dayactprodhrs = source.dayactprodhrs,
  dayactnprodhrs = source.dayactnprodhrs,
  dayactproddls = source.dayactproddls,
  daybudproddls = source.daybudproddls,
  dayactnproddls = source.dayactnproddls,
  daybudnproddls = source.daybudnproddls,
  neworienhrs = source.neworienhrs,
  newinservhrs = source.newinservhrs,
  neworiendls = source.neworiendls,
  newinservdls = source.newinservdls,
  prodacthrstra = source.prodacthrstra,
  prodactdlstra = source.prodactdlstra,
  regactdlstra = source.regactdlstra,
  regacthrstra = source.regacthrstra,
  otacthrstra = source.otacthrstra,
  otactdlstra = source.otactdlstra,
  pdptothrstra = source.pdptothrstra,
  pdptodlstra = source.pdptodlstra,
  prodactdlsoffset = source.prodactdlsoffset,
  regactdlstraoffset = source.regactdlstraoffset,
  otactdlstraoffset = source.otactdlstraoffset,
  pdptodlstraoffset = source.pdptodlstraoffset
WHEN NOT MATCHED THEN
INSERT
  (fac, dept, period, caldate, homedept, wrklddept, wrkldsub1, wrklddesc, daysopen, openyear, nonp, budvol, budprodhrs, budnprodhrs, budproddls, budnproddls, budptofctr, payperiod, rptmonth, targminvol, targfixhrs, targhruos, pdrwrkldvol, prodacthrs, regacthrs, nonpacthrs, otacthrs, clacthrs, cbackacthrs, pdptohrs, pdinshrs, pdnonphrs, prodactdls, regactdls, otactdls, clactdls, cbackactdls, pdptodls, pdinsdls, pdnonpdls, tmpdata, xclosed, daybudvol, daybudprodhrs, daybudnprodhrs, daybudearnrate, daybudptofctr, mthbudvol, newearntot, newearntotpaid, yearnhrs, yearndls, yearnhrspaid, yearndlspaid, dayactvol, dayactprodhrs, dayactnprodhrs, dayactproddls, daybudproddls, dayactnproddls, daybudnproddls, neworienhrs, newinservhrs, neworiendls, newinservdls, prodacthrstra, prodactdlstra, regactdlstra, regacthrstra, otacthrstra, otactdlstra, pdptothrstra, pdptodlstra, prodactdlsoffset, regactdlstraoffset, otactdlstraoffset, pdptodlstraoffset)
VALUES
  (fac, dept, period, caldate, homedept, wrklddept, wrkldsub1, wrklddesc, daysopen, openyear, nonp, budvol, budprodhrs, budnprodhrs, budproddls, budnproddls, budptofctr, payperiod, rptmonth, targminvol, targfixhrs, targhruos, pdrwrkldvol, prodacthrs, regacthrs, nonpacthrs, otacthrs, clacthrs, cbackacthrs, pdptohrs, pdinshrs, pdnonphrs, prodactdls, regactdls, otactdls, clactdls, cbackactdls, pdptodls, pdinsdls, pdnonpdls, tmpdata, xclosed, daybudvol, daybudprodhrs, daybudnprodhrs, daybudearnrate, daybudptofctr, mthbudvol, newearntot, newearntotpaid, yearnhrs, yearndls, yearnhrspaid, yearndlspaid, dayactvol, dayactprodhrs, dayactnprodhrs, dayactproddls, daybudproddls, dayactnproddls, daybudnproddls, neworienhrs, newinservhrs, neworiendls, newinservdls, prodacthrstra, prodactdlstra, regactdlstra, regacthrstra, otacthrstra, otactdlstra, pdptothrstra, pdptodlstra, prodactdlsoffset, regactdlstraoffset, otactdlstraoffset, pdptodlstraoffset);
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
