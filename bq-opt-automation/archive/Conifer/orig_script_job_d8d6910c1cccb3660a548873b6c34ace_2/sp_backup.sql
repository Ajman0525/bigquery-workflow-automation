CREATE OR REPLACE PROCEDURE `cfrdnaproddata3.ace_ods.sp_ace_job_qamecs106`(OUT OUT_PARAM INT64)
BEGIN

    /* ------------------------------------------------------------------------------------------------------------------------------------------------------- */
    -- Proc name 	: sp_ace_job_qamecs106
    -- Database		: ace_ods
    -- Author 		: Subash Tiwari
    -- Project		: Conifer Conversion
    -- Proc Desc 	: Stored procedure for job qamecs106 from ACE to BQ.
    -- Frequency  : 
    -- Notes		  : 
    -- Parameters : OUT_PARAM

    -- Revision History:
    -- When 	  Version 	Modified by 					    Change description
    -- --------	  -------	-----------------------		------------------------------------------------------------------------------------------------------------- */
    -- 20250702   1.0 		 		                        Created!    
    -- 20260205   1.1     Sarthak                     Added processing for activity code: CHPPE
    -- 20260226   1.2     Sarthak                     Added trims to avcfac
    -- 20260310   1.3     Sarthak                     Add new column revcatg_desc added, column pulled from uq_ancs.xwrefas
	-- 20260430	  1.4	  Vidhya					  ADDING PCCHN FLAG	
	-- 05142026	1.5	 	 Vidhya							Adding fac_target - Vidhya
    /* ---------------------------------------------------------------------------------------------------------------------------------------------------------- */

    DECLARE V_PROC_NAME STRING;
    DECLARE V_LOG_MESSAGE STRING;



    BEGIN 
    /* Start Procedure */
        SET V_PROC_NAME = 'sp_ace_job_qamecs106';
        SET V_LOG_MESSAGE = 'Starting Procedure - ' || V_PROC_NAME || ' - ' || CURRENT_DATETIME("America/Chicago");
        SELECT  '%', V_LOG_MESSAGE;

        -- SO_PAROCSA 

/*#region 1 so_parocsa*/
truncate table cfranalyticsproddata3.tempqrydta.so_parocsa;
insert into cfranalyticsproddata3.tempqrydta.so_parocsa 
with base as (
  select
      max(avstamp) as max_stamp,
      avactivity,
      trim(avcfac),
      avmid
    from cfrdnaproddata3.ace_ods.chiactv
    where
      trim(avactivity) in ('PCCHR', 'CHPRO', 'PCCHN', 'PCCHB')
      and date(avstamp) > '2020-12-31'
    group by
      trim(avcfac),
      avactivity,
      avmid
  union all
  select
      max(avstamp) as max_stamp,
      avactivity,
      trim(avcfac),
      avmid
    from cfrdnaproddata3.ace_ods.dbactv
    where
      trim(avactivity) in ('PCCHR', 'CHPRO', 'PCCHN', 'PCCHB')
      and date(avstamp) > '2020-12-31'
    group by
      trim(avcfac),
      avactivity,
      avmid
),
base1 as (
  select
      max(avstamp) as max_stamp,
      avactivity,
      trim(avcfac),
      avmid
    from cfrdnaproddata3.ace_ods.chiactv
    where
      trim(avactivity) = 'PCCHE'
      and date(avstamp) > '2020-12-31'
    group by
      trim(avcfac),
      avactivity,
      avmid
  union all
  select
      max(avstamp) as max_stamp,
      avactivity,
      trim(avcfac),
      avmid
    from cfrdnaproddata3.ace_ods.dbactv
    where
      trim(avactivity) = 'PCCHE'
      and date(avstamp) > '2020-12-31'
    group by
      trim(avcfac),
      avactivity,
      avmid
),
main_base as (
  select
      *
    from base
  union all
  select
      *
    from base1
),
base2 as (
  select
      max(avstamp) as chipe_stamp,
      trim(avcfac),
      avmid
    from cfrdnaproddata3.ace_ods.chiactv
    where
      trim(avactivity) in ('CHIPE')
      and date(avstamp) > '2020-12-31'
      and avmid in (
        select
            avmid
          from main_base
      )
    group by
      trim(avcfac),
      avmid
  union all
  select
      max(avstamp) as chipe_stamp,
      trim(avcfac),
      avmid
    from cfrdnaproddata3.ace_ods.dbactv
    where
      trim(avactivity) in ('CHIPE')
      and date(avstamp) > '2020-12-31'
      and avmid in (
        select
            avmid
          from main_base
      )
    group by
      trim(avcfac),
      avmid
),
base2a as (
  select
      max(avstamp) as chipb_stamp,
      trim(avcfac),
      avmid
    from cfrdnaproddata3.ace_ods.chiactv
    where
      avactivity = ('CHIPB')
      and date(avstamp) > '2020-12-31'
      and avmid in (
        select
            avmid
          from main_base
      )
    group by
      trim(avcfac),
      avmid
  union all
  select
      max(avstamp) as chipb_stamp,
      trim(avcfac),
      avmid
    from cfrdnaproddata3.ace_ods.dbactv
    where
      trim(avactivity) in ('CHIPB')
      and date(avstamp) > '2020-12-31'
      and avmid in (
        select
            avmid
          from main_base
      )
    group by
      trim(avcfac),
      avmid
),
base3 as (
  select
      max(avstamp) as chrpc_stamp,
      trim(avcfac),
      avmid
    from cfrdnaproddata3.ace_ods.chiactv
    where
      trim(avactivity) = 'CHRPC'
      and date(avstamp) > '2020-12-31'
      and avmid in (
        select
            avmid
          from main_base
      )
    group by
      trim(avcfac),
      avactivity,
      avmid
  union all
  select
      max(avstamp) as chrpc_stamp,
      trim(avcfac),
      avmid
    from cfrdnaproddata3.ace_ods.dbactv
    where
      trim(avactivity) = 'CHRPC'
      and date(avstamp) > '2020-12-31'
      and avmid in (
        select
            avmid
          from main_base
      )
    group by
      trim(avcfac),
      avactivity,
      avmid
),
base4 as (
  select
      max(avstamp) as chipl_stamp,
      trim(avcfac),
      avmid
    from cfrdnaproddata3.ace_ods.chiactv
    where
      avactivity = ('CHIPL')
      and date(avstamp) > '2020-12-31'
      and avmid in (
        select
            avmid
          from main_base
      )
    group by
      trim(avcfac),
      avmid
  union all
  select
      max(avstamp) as chipl_stamp,
      trim(avcfac),
      avmid
    from cfrdnaproddata3.ace_ods.dbactv
    where
      trim(avactivity) in ('CHIPL')
      and date(avstamp) > '2020-12-31'
      and avmid in (
        select
            avmid
          from main_base
      )
    group by
      trim(avcfac),
      avmid
),
base4a as (
  select
      max(avstamp) as chi50_stamp,
      trim(avcfac),
      avmid
    from cfrdnaproddata3.ace_ods.chiactv
    where
      avactivity = ('CHI50')
      and date(avstamp) > '2020-12-31'
      and avmid in (
        select
            avmid
          from main_base
      )
    group by
      trim(avcfac),
      avmid
  union all
  select
      max(avstamp) as chi50_stamp,
      trim(avcfac),
      avmid
    from cfrdnaproddata3.ace_ods.dbactv
    where
      trim(avactivity) in ('CHI50')
      and date(avstamp) > '2020-12-31'
      and avmid in (
        select
            avmid
          from main_base
      )
    group by
      trim(avcfac),
      avmid
),
base4b as (
  select
      max(avstamp) as chi75_stamp,
      trim(avcfac),
      avmid
    from cfrdnaproddata3.ace_ods.chiactv
    where
      avactivity = ('CHI75')
      and date(avstamp) > '2020-12-31'
      and avmid in (
        select
            avmid
          from main_base
      )
    group by
      trim(avcfac),
      avmid
  union all
  select
      max(avstamp) as chi75_stamp,
      trim(avcfac),
      avmid
    from cfrdnaproddata3.ace_ods.dbactv
    where
      trim(avactivity) in ('CHI75')
      and date(avstamp) > '2020-12-31'
      and avmid in (
        select
            avmid
          from main_base
      )
    group by
      trim(avcfac),
      avmid
),
base5 as (
  select
      max(avstamp) as chpmt_stamp,
      trim(avcfac),
      avmid
    from cfrdnaproddata3.ace_ods.chiactv
    where
      trim(avactivity) in ('CHPMT')
      and date(avstamp) > '2020-12-31'
      and avmid in (
        select
            avmid
          from main_base
      )
    group by
      trim(avcfac),
      avmid
  union all
  select
      max(avstamp) as chpmt_stamp,
      trim(avcfac),
      avmid
    from cfrdnaproddata3.ace_ods.dbactv
    where
      trim(avactivity) in ('CHPMT')
      and date(avstamp) > '2020-12-31'
      and avmid in (
        select
            avmid
          from main_base
      )
    group by
      trim(avcfac),
      avmid
),
base6 as (
  select
      max(avstamp) as chppe_stamp,
      trim(avcfac),
      avmid
    from cfrdnaproddata3.ace_ods.chiactv
    where
      trim(avactivity) in ('CHPPE')
      and date(avstamp) > '2020-12-31'
      and avmid in (
        select
            avmid
          from main_base
      )
    group by
      trim(avcfac),
      avmid
  union all
  select
      max(avstamp) as chppe_stamp,
      trim(avcfac),
      avmid
    from cfrdnaproddata3.ace_ods.dbactv
    where
      trim(avactivity) in ('CHPPE')
      and date(avstamp) > '2020-12-31'
      and avmid in (
        select
            avmid
          from main_base
      )
    group by
      trim(avcfac),
      avmid
)
select
    a.*,
    b.chipe_stamp,
    c.chrpc_stamp,
    d.chipl_stamp,
    e.chpmt_stamp,
    g.chipb_stamp,
    h.chi50_stamp,
    i.chi75_stamp,
    j.chppe_stamp
  from main_base as a
  left join base2 as b
    on a.avmid = b.avmid
    and date(b.chipe_stamp) >= date(a.max_stamp)
  left join base3 as c
    on a.avmid = c.avmid
    and date(c.chrpc_stamp) >= date(a.max_stamp)
  left join base4 as d
    on a.avmid = d.avmid
    and date(d.chipl_stamp) >= date(a.max_stamp)
  left join base5 as e
    on a.avmid = e.avmid
    and date(e.chpmt_stamp) >= date(a.max_stamp)
  left join base2a as g
    on a.avmid = g.avmid
    and date(g.chipb_stamp) >= date(a.max_stamp)
  left join base4a as h
    on a.avmid = h.avmid
    and date(h.chi50_stamp) >= date(a.max_stamp)
  left join base4b as i
    on a.avmid = i.avmid
    and date(i.chi75_stamp) >= date(a.max_stamp)
  left join base6 as j
    on a.avmid = j.avmid
    and date(j.chppe_stamp) >= date(a.max_stamp);
/*#endregion*/

-- SO_PAROCSB 

/*#region 2 so_parocsb*/
truncate table cfranalyticsproddata3.tempqrydta.so_parocsb;
insert into cfranalyticsproddata3.tempqrydta.so_parocsb 
with base as (
select avmid from cfranalyticsproddata3.tempqrydta.so_parocsa
),
base1 as (
select avmid, max(avstamp) as lv1_stamp
from cfrdnaproddata3.ace_ods.chiactv
where trim(avactivity) = 'MWLV1'
and avmid in (select avmid from base)
group by avmid
union all
select avmid, max(avstamp) as lv1_stamp
from cfrdnaproddata3.ace_ods.dbactv
where trim(avactivity) = 'MWLV1'
and avmid in (select avmid from base)
group by avmid
),
base2 as (
select avmid, max(avstamp) as lv2_stamp
from cfrdnaproddata3.ace_ods.chiactv
where trim(avactivity) = 'MWLV2'
and avmid in (select avmid from base)
group by avmid
union all
select avmid, max(avstamp) as lv2_stamp
from cfrdnaproddata3.ace_ods.dbactv
where trim(avactivity) = 'MWLV2'
and avmid in (select avmid from base)
group by avmid
),
base3 as (
select avmid, max(avstamp) as lv3_stamp
from cfrdnaproddata3.ace_ods.chiactv
where trim(avactivity) = 'MWLV3'
and avmid in (select avmid from base)
group by avmid
union all
select avmid, max(avstamp) as lv3_stamp
from cfrdnaproddata3.ace_ods.dbactv
where trim(avactivity) = 'MWLV3'
and avmid in (select avmid from base)
group by avmid
),
base4 as (
select avmid, max(avstamp) as lv4_stamp
from cfrdnaproddata3.ace_ods.chiactv
where trim(avactivity) = 'MWLV4'
and avmid in (select avmid from base)
group by avmid
union all
select avmid, max(avstamp) as lv4_stamp
from cfrdnaproddata3.ace_ods.dbactv
where trim(avactivity) = 'MWLV4'
and avmid in (select avmid from base)
group by avmid
)
select a.*, b.lv1_stamp,c.lv2_stamp,d.lv3_stamp,e.lv4_stamp
from cfranalyticsproddata3.tempqrydta.so_parocsa a
left join base1 b on a.avmid = b.avmid
left join base2 c on a.avmid = c.avmid
left join base3 d on a.avmid = d.avmid
left join base4 e on a.avmid = e.avmid;
/*#endregion*/

-- SO_PAROCSC 

/*#region 3 so_parocsc*/
truncate table cfranalyticsproddata3.tempqrydta.so_parocsc;
insert into cfranalyticsproddata3.tempqrydta.so_parocsc 
with base as (
  select
    avmid
  from
    cfranalyticsproddata3.tempqrydta.so_parocsa
),
base2 as (
  select
    pdmid,
    max(pddate) as hrsa_date
  from
    cfrdnaproddata3.ace_ods.dbdate
  where
    trim(pddtyp) in ('B61', 'B63', 'B65')
  group by
    pdmid
)
select
  a.*,
  case when a.max_stamp = current_date('America/Chicago') then 'Y' else 'N' end as send_alert,
  case when (a.chipe_stamp = current_date('America/Chicago') or a.chrpc_stamp = current_date('America/Chicago') or a.chipb_stamp = current_date('America/Chicago'))
    then 'Y' else 'N' end as recieve_alert,
  c.hrsa_date,
  case when c.hrsa_date is null then 'N' else 'Y' end as hrsa_flag
from
  cfranalyticsproddata3.tempqrydta.so_parocsb a
left join
  base2 c on a.avmid = c.pdmid;
/*#endregion*/


-- SO_PAROCSD 

/*#region 4 so_parocsd*/
truncate table cfranalyticsproddata3.tempqrydta.so_parocsd;
insert into cfranalyticsproddata3.tempqrydta.so_parocsd 
WITH tempdateseries AS (
  SELECT day AS date
  FROM UNNEST(GENERATE_DATE_ARRAY('2018-01-01', current_date('America/Chicago'), INTERVAL 1 DAY)) AS day
),

-- pull distinct facid's from chiactv with pcchr act code
actcode AS (
  SELECT DISTINCT trim(facility_code) AS avcfac
  FROM cfranalyticsproddata3.uq_anic.mdsfaclist
),

facalldays AS (
  SELECT *
  FROM actcode
  CROSS JOIN tempdateseries
),

-- combine to previous output
combined AS (
  SELECT DISTINCT *
  FROM cfranalyticsproddata3.tempqrydta.so_parocsc a
  LEFT JOIN facalldays b
    ON DATE(a.max_stamp) = b.date
   AND trim(a.avcfac) = trim(b.avcfac)
),

-- pulling payments
bal AS (
  SELECT DISTINCT dbmid, dbpbal, fbpatrcv, fbinsrcv, fbnetchg
  FROM cfrdnaproddata3.ace_pii_ods.dbinfo
  LEFT JOIN cfrdnaproddata3.ace_ods.ptfbal
    ON dbmid = fbmid
  WHERE trim(dbcncl) <> 'Y'
),

-- prefinal table creating tat stamps
prefinal AS (
  SELECT DISTINCT 
    a.*,
    b.gichga AS tot_charges,
    t01.fbpatrcv AS patient_payments,
    t01.fbinsrcv AS third_party_payments,
    t01.fbnetchg AS total_charges2,
    t01.dbpbal AS amount_due,

    CASE WHEN a.lv1_stamp IS NOT NULL THEN 1 ELSE 0 END AS lv1ct,
    CASE WHEN a.lv2_stamp IS NOT NULL THEN 1 ELSE 0 END AS lv2ct,
    CASE WHEN a.lv3_stamp IS NOT NULL THEN 1 ELSE 0 END AS lv3ct,
    CASE WHEN a.lv4_stamp IS NOT NULL THEN 1 ELSE 0 END AS lv4ct,

    CASE WHEN a.chi50_stamp IS NOT NULL THEN 1 ELSE 0 END AS chi50_count,
    CASE WHEN a.chi75_stamp IS NOT NULL THEN 1 ELSE 0 END AS chi75_count,
    CASE WHEN a.chrpc_stamp IS NOT NULL THEN 1 ELSE 0 END AS chrpc_count,
    CASE WHEN a.chipe_stamp IS NOT NULL THEN 1 ELSE 0 END AS chipe_count,
    CASE WHEN a.chipb_stamp IS NOT NULL THEN 1 ELSE 0 END AS chipb_count,
    CASE WHEN a.chppe_stamp IS NOT NULL THEN 1 ELSE 0 END AS chppe_count,

    CASE WHEN a.chpmt_stamp IS NOT NULL THEN 'Y' ELSE 'N' END AS chpmt_flag,
    CASE 
      WHEN a.chipl_stamp IS NOT NULL 
        OR a.chi50_stamp IS NOT NULL 
        OR a.chi75_stamp IS NOT NULL 
      THEN 'Y' ELSE 'N' 
    END AS positive_partial,

    CASE WHEN a.chipl_stamp IS NOT NULL 
         THEN DATE_DIFF(a.chipl_stamp, a.max_stamp, DAY)
         ELSE 999 END AS chipl_tat,

    CASE WHEN a.chi50_stamp IS NOT NULL 
         THEN DATE_DIFF(a.chi50_stamp, a.max_stamp, DAY)
         ELSE 999 END AS chi50_tat,

    CASE WHEN a.chi75_stamp IS NOT NULL 
         THEN DATE_DIFF(a.chi75_stamp, a.max_stamp, DAY)
         ELSE 999 END AS chi75_tat,

    CASE WHEN a.chrpc_stamp IS NOT NULL 
         THEN DATE_DIFF(a.chrpc_stamp, a.max_stamp, DAY)
         ELSE 999 END AS chrpc_tat,

    CASE WHEN a.chipe_stamp IS NOT NULL 
         THEN DATE_DIFF(a.chipe_stamp, a.max_stamp, DAY)
         ELSE 999 END AS chipe_tat,

    CASE WHEN a.chipb_stamp IS NOT NULL 
         THEN DATE_DIFF(a.chipb_stamp, a.max_stamp, DAY)
         ELSE 999 END AS chipb_tat,

    CASE WHEN a.chpmt_stamp IS NOT NULL 
         THEN DATE_DIFF(a.chpmt_stamp, a.max_stamp, DAY)
         ELSE 999 END AS chpmt_tat,

    CASE WHEN a.chppe_stamp IS NOT NULL 
         THEN DATE_DIFF(a.chppe_stamp, a.max_stamp, DAY)
         ELSE 999 END AS chppe_tat

  FROM combined a
  LEFT JOIN cfrdnaproddata3.ace_pii_ods.tkpdgip b
    ON a.avmid = b.gimid
  LEFT JOIN bal t01
    ON a.avmid = t01.dbmid
),

finale AS (
  SELECT DISTINCT
    a.*,
    CASE 
      WHEN chipl_tat = 999 
       AND chi50_tat = 999
       AND chi75_tat = 999
       AND chrpc_tat = 999
       AND chipe_tat = 999
       AND chipb_tat = 999
       AND chpmt_tat = 999 
       AND chppe_tat = 999 
      THEN '999' ELSE '1' 
    END AS turn_around_time
  FROM prefinal a
)

SELECT 
  a.*,
  ROW_NUMBER() OVER (PARTITION BY a.avmid ORDER BY a.avmid) AS rn
FROM finale a
ORDER BY a.avmid;
/*#endregion*/


-- SO_PAROCSE 

/*#region 5 so_parocse*/
truncate table cfranalyticsproddata3.tempqrydta.so_parocse;
insert into cfranalyticsproddata3.tempqrydta.so_parocse 
with base as (
  select distinct
    a.*,
    date(max_stamp) as act_date,
    b.*,
    date_sub(current_date('America/Chicago'), interval 3 day) as threedaysago,
    t02.dbref1 as ptacctnumber,
    dbdat1 as admit_date,
    b1.nmfnam as pt_first_name,
    b1.nmlnam as pt_last_name,
    c.nmfnam as gt_first_name,
    c.nmlnam as gt_last_name,
    case when cast(a.turn_around_time as numeric) < 999 then 'Y' else 'N' end as responcerecieved,
    case when trim(a.avactivity) = 'CHPRO' then 'Y' else 'N' end as chpro_flag,
    case when trim(a.avactivity) = 'PCCHR' then 'Y' else 'N' end as pcchr_flag,
    case when trim(a.avactivity) = 'PCCHE' then 'Y' else 'N' end as pcche_flag,
	case when trim(a.avactivity) = 'PCCHN' then 'Y' else 'N' end as pcchn_flag,
    case
      when chipe_stamp is not null then 'CHIPE'
      when chipb_stamp is not null then 'CHIPB'
      when chrpc_stamp is not null then 'CHRPC'
      when chipl_stamp is not null then 'CHIPL'
      when chi50_stamp is not null then 'CHI50'
      when chi75_stamp is not null then 'CHI75'
      when chpmt_stamp is not null then 'CHPMT'
      when chppe_stamp is not null then 'CHPPE'
      else ''
    end as activity_codes,
    case
      when (chipe_stamp is not null or chipb_stamp is not null or chppe_stamp is not null)
        then 'Full_Approved'
      when (chipl_stamp is not null or chi50_stamp is not null or chi75_stamp is not null)
        then 'Partial_Approved'
      when (chrpc_stamp is not null)
        then 'Denied'
      when (chpmt_stamp is not null)
        then 'PARO_Pt_Pymt_>=$150'
      else 'No_Status'
    end as presumptive_status,
    case
      when trim(d.asacatg) = 'SP' then "Uninsured"  
      when trim(d.asacatg) = 'BA' then "Bal After Ins"  
      when trim(d.asacatg) = 'MP' then "Bal After MCR"  
      when trim(d.asacatg) = 'CH' then "Charity/TFAC"  
      when trim(d.asacatg) = 'MS' then "MCR Supplemental"  
      when trim(d.asacatg) = 'WC' then "Work Comp"  
      when trim(d.asacatg) = 'IN' then "Ins/Govt/FU"  
      when trim(d.asacatg) = 'UP' then "Underpayment"  
      when trim(d.asacatg) = 'DN' then "Appeal"
      else "Others"  
    end as revcatg_desc,
    row_number() over (partition by avmid order by avmid) as row_num
  from
    cfranalyticsproddata3.tempqrydta.so_parocsd as a
  left join
    cfranalyticsproddata3.uq_anic.mdsfaclist as b
    on trim(a.avcfac) = trim(b.facility_code)
  left join
    cfrdnaproddata3.ace_pii_ods.dbinfo as t02
    on a.avmid = t02.dbmid
  left join
    cfrdnaproddata3.ace_pii_ods.abname as b1
    on a.avmid = b1.nmmid
  left join
    cfrdnaproddata3.ace_pii_ods.abname as c
    on a.avmid = c.nmmid
  left outer join
    cfranalyticsproddata3.uq_ancs.xwrefas as d
    on d.asacls = t02.DBACLS
    and d.ascont = t02.DBCONT
  where
    trim(b1.nmetype) = 'DBT'
    and trim(b1.nmversion) = 'CUR'
    and trim(c.nmetype) = 'GAR'
    and trim(c.nmversion) = 'CUR'
),
finale as (
  select
    *
  from
    base
  where
    row_num = 1
)
select
  a.*,
  case
    when a.avmid = b.mamid and trim(hosp_cde) in ('CCD01', 'ECH01', 'HHH01')
    then 'Commercial'
    else a.client_name_ees
  end as ees_client,
  case
    when a.avmid = b.mamid and trim(hosp_cde) in ('CCD01', 'ECH01', 'HHH01')
    then 'Novant'
    else a.region_ees
  end as ees_region,
  case
    when a.avmid = b.mamid and trim(hosp_cde) in ('CCD01', 'ECH01', 'HHH01')
    then 'South Carolina'
    else a.market_ees
  end as ees_market,
  case
    when a.avmid = b.mamid and trim(hosp_cde) in ('CCD01', 'ECH01', 'HHH01')
    then trim(b.hosp_cde)
    else trim(a.facility_code)
  end as facid,
  case
    when date(max_stamp) between date_sub(current_date('America/Chicago'), interval 2 day)
    and current_date('America/Chicago')
    then 'Y'
    else 'N'
  end as last_three_days_flag,
  ft.fac_target
from
  finale as a
left outer join
  cfranalyticsproddata3.uq_amecs.ees_novant as b
  on a.avmid = b.mamid
  left join  cfranalyticsproddata3.tempqrydta.fac_target_lookup ft
on a.avcfa00001 = ft.facid ; -- Vidhya

/*#endregion*/

SET OUT_PARAM = 1;
SELECT OUT_PARAM;

/* =============================================================================================================================== */
/* HANDLE EXCEPTIONS                                                                                                               */
/* =============================================================================================================================== */
EXCEPTION
    WHEN ERROR THEN
        SET V_LOG_MESSAGE = 'FAILED - Procedure ' || V_PROC_NAME || ', Reason: TRANSACTION_ABORTED - ' || REPLACE(@@error.message,'\'','\'\'');
        SET V_LOG_MESSAGE = 'FAILED - Procedure ' || V_PROC_NAME || ', ' || REPLACE(@@error.message,'\'','\'\'');
    SELECT '%', V_LOG_MESSAGE;
    SET OUT_PARAM = 0;
    SELECT OUT_PARAM;
    RAISE USING message = substr(@@error.message,1,5000);


END;
END;