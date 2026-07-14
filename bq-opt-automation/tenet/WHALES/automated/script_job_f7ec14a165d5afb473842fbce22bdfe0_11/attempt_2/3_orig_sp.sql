CREATE PROCEDURE thcdnaproddata.lmrs_ods.sp_lmrsrgpp_sum(OUT OUT_PARAM INT64)
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
 
 
 
 
merge into `lmrs_ods.godailyhrs_seg1_pp_sum` as target
using `lmrs_ods.hold1b1` as source
on target.fac = source.fac
   and target.dept = source.dept
   and target.period = source.period
  and target.caldate = source.caldate
 
when matched then
update set
  caldate = source.caldate,
  homedept = source.homedept,
  wrklddept = source.wrklddept,
  wrkldsub1 = source.wrkldsub1,
  wrklddesc = source.wrklddesc,
  daysopen = source.daysopen,
  openyear = source.openyear,
  nonp = cast(source.nonp as numeric),
  budvol = cast(source.budvol as numeric),
  budprodhrs = cast(source.budprodhrs as numeric),
  budnprodhrs = cast(source.budnprodhrs as numeric),
  budproddls = cast(source.budproddls as numeric),
  budnproddls = cast(source.budnproddls as numeric),
  budptofctr = cast(source.budptofctr as numeric),
  payperiod = source.payperiod,
  rptmonth = source.rptmonth,
  targminvol = cast(source.targminvol as numeric),
  targfixhrs = cast(source.targfixhrs as numeric),
  targhruos = cast(source.targhruos as numeric),
  pdrwrkldvol = cast(source.pdrwrkldvol as numeric),
  prodacthrs = cast(source.prodacthrs as numeric),
  regacthrs = cast(source.regacthrs as numeric),
  nonpacthrs = cast(source.nonpacthrs as numeric),
  otacthrs = cast(source.otacthrs as numeric),
  clacthrs = cast(source.clacthrs as numeric),
  cbackacthrs = cast(source.cbackacthrs as numeric),
  pdptohrs = cast(source.pdptohrs as numeric),
  pdinshrs = cast(source.pdinshrs as numeric),
  pdnonphrs = cast(source.pdnonphrs as numeric),
  prodactdls = cast(source.prodactdls as numeric),
  regactdls = cast(source.regactdls as numeric),
  otactdls = cast(source.otactdls as numeric),
  clactdls = cast(source.clactdls as numeric),
  cbackactdls = cast(source.cbackactdls as numeric),
  pdptodls = cast(source.pdptodls as numeric),
  pdinsdls = cast(source.pdinsdls as numeric),
  pdnonpdls = cast(source.pdnonpdls as numeric),
  tmpdata = cast(source.tmpdata as numeric),
  xclosed = source.xclosed,
  daybudvol = cast(source.daybudvol as numeric),
  daybudprodhrs = cast(source.daybudprodhrs as numeric),
  daybudnprodhrs = cast(source.daybudnprodhrs as numeric),
  daybudearnrate = cast(source.daybudearnrate as numeric),
  daybudptofctr = cast(source.daybudptofctr as numeric),
  mthbudvol = cast(source.mthbudvol as numeric),
  newearntot = cast(source.newearntot as numeric),
  newearntotpaid = cast(source.newearntotpaid as numeric),
  yearnhrs = cast(source.yearnhrs as numeric),
  yearndls = cast(source.yearndls as numeric),
  yearnhrspaid = cast(source.yearnhrspaid as numeric),
  yearndlspaid = cast(source.yearndlspaid as numeric),
  dayactvol = cast(source.dayactvol as numeric),
  dayactprodhrs = cast(source.dayactprodhrs as numeric),
  dayactnprodhrs = cast(source.dayactnprodhrs as numeric),
  dayactproddls = cast(source.dayactproddls as numeric),
  daybudproddls = cast(source.daybudproddls as numeric),
  dayactnproddls = cast(source.dayactnproddls as numeric),
  daybudnproddls = cast(source.daybudnproddls as numeric),
  neworienhrs = cast(source.neworienhrs as numeric),
  newinservhrs = cast(source.newinservhrs as numeric),
  neworiendls = cast(source.neworiendls as numeric),
  newinservdls = cast(source.newinservdls as numeric),
  prodacthrstra = cast(source.prodacthrstra as numeric),
  prodactdlstra = cast(source.prodactdlstra as numeric),
  regactdlstra = cast(source.regactdlstra as numeric),
  regacthrstra = cast(source.regacthrstra as numeric),
  otacthrstra = cast(source.otacthrstra as numeric),
  otactdlstra = cast(source.otactdlstra as numeric),
  pdptothrstra = cast(source.pdptothrstra as numeric),
  pdptodlstra = cast(source.pdptodlstra as numeric),
  prodactdlsoffset = cast(source.prodactdlsoffset as numeric),
  regactdlstraoffset = cast(source.regactdlstraoffset as numeric),
  otactdlstraoffset = cast(source.otactdlstraoffset as numeric),
  pdptodlstraoffset = cast(source.pdptodlstraoffset as numeric)
 
when not matched then
insert (
  fac, dept, period, caldate, homedept, wrklddept, wrkldsub1, wrklddesc, daysopen, openyear, nonp, budvol,
  budprodhrs, budnprodhrs, budproddls, budnproddls, budptofctr, payperiod, rptmonth,
  targminvol, targfixhrs, targhruos, pdrwrkldvol,
  prodacthrs, regacthrs, nonpacthrs, otacthrs, clacthrs, cbackacthrs,
  pdptohrs, pdinshrs, pdnonphrs,
  prodactdls, regactdls, otactdls, clactdls, cbackactdls, pdptodls, pdinsdls, pdnonpdls, tmpdata,
  xclosed, daybudvol, daybudprodhrs, daybudnprodhrs, daybudearnrate, daybudptofctr,
  mthbudvol, newearntot, newearntotpaid, yearnhrs, yearndls, yearnhrspaid, yearndlspaid,
  dayactvol, dayactprodhrs, dayactnprodhrs, dayactproddls, daybudproddls, dayactnproddls, daybudnproddls,
  neworienhrs, newinservhrs, neworiendls, newinservdls,
  prodacthrstra, prodactdlstra,
  regactdlstra, regacthrstra,
  otacthrstra, otactdlstra,
  pdptothrstra, pdptodlstra,
  prodactdlsoffset, regactdlstraoffset, otactdlstraoffset, pdptodlstraoffset
)
values (
  source.fac, source.dept, source.period, source.caldate, source.homedept, source.wrklddept, source.wrkldsub1, source.wrklddesc, source.daysopen, source.openyear, cast(source.nonp as numeric), cast(source.budvol as numeric),
  cast(source.budprodhrs as numeric), cast(source.budnprodhrs as numeric), cast(source.budproddls as numeric), cast(source.budnproddls as numeric), cast(source.budptofctr as numeric), source.payperiod, source.rptmonth,
  cast(source.targminvol as numeric), cast(source.targfixhrs as numeric), cast(source.targhruos as numeric), cast(source.pdrwrkldvol as numeric),
  cast(source.prodacthrs as numeric), cast(source.regacthrs as numeric), cast(source.nonpacthrs as numeric), cast(source.otacthrs as numeric), cast(source.clacthrs as numeric), cast(source.cbackacthrs as numeric),
  cast(source.pdptohrs as numeric), cast(source.pdinshrs as numeric), cast(source.pdnonphrs as numeric),
  cast(source.prodactdls as numeric), cast(source.regactdls as numeric), cast(source.otactdls as numeric), cast(source.clactdls as numeric), cast(source.cbackactdls as numeric), cast(source.pdptodls as numeric), cast(source.pdinsdls as numeric), cast(source.pdnonpdls as numeric), cast(source.tmpdata as numeric),
  source.xclosed, cast(source.daybudvol as numeric), cast(source.daybudprodhrs as numeric), cast(source.daybudnprodhrs as numeric), cast(source.daybudearnrate as numeric), cast(source.daybudptofctr as numeric),
  cast(source.mthbudvol as numeric), cast(source.newearntot as numeric), cast(source.newearntotpaid as numeric), cast(source.yearnhrs as numeric), cast(source.yearndls as numeric), cast(source.yearnhrspaid as numeric), cast(source.yearndlspaid as numeric),
  cast(source.dayactvol as numeric), cast(source.dayactprodhrs as numeric), cast(source.dayactnprodhrs as numeric), cast(source.dayactproddls as numeric), cast(source.daybudproddls as numeric), cast(source.dayactnproddls as numeric), cast(source.daybudnproddls as numeric),
  cast(source.neworienhrs as numeric), cast(source.newinservhrs as numeric), cast(source.neworiendls as numeric), cast(source.newinservdls as numeric),
  cast(source.prodacthrstra as numeric), cast(source.prodactdlstra as numeric),
  cast(source.regactdlstra as numeric), cast(source.regacthrstra as numeric),
  cast(source.otacthrstra as numeric), cast(source.otactdlstra as numeric),
  cast(source.pdptothrstra as numeric), cast(source.pdptodlstra as numeric),
  cast(source.prodactdlsoffset as numeric), cast(source.regactdlstraoffset as numeric), cast(source.otactdlstraoffset as numeric), cast(source.pdptodlstraoffset as numeric)
);


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
