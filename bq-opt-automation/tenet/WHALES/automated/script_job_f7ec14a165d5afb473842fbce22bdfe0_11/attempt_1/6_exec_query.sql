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

-- =================================================================================================
-- 3. Create the Optimized Temporary Table (V_TEMP_TABLE_OPT)
-- =================================================================================================
CREATE OR REPLACE TEMP TABLE V_TEMP_TABLE_OPT AS
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
