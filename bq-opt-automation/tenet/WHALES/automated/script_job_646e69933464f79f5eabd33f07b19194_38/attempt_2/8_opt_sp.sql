CREATE PROCEDURE thcdnaproddata.aci.sp_ade_report_lab_ade_types(OUT OUT_PARAM INT64)
BEGIN

-- declare OUT_PARAM BOOL;
 DECLARE v_proc STRING(255);


	DECLARE v_count INT64 ;
	DECLARE v_ts STRING(40);
	DECLARE v_day STRUCT<>;

	DECLARE v_result boolean;
	DECLARE v_sql STRING(4000);
	DECLARE v_options STRING(4000);
	
	
BEGIN
SET v_proc  = 'SP_ADE_REPORT_LAB_ADE_TYPES';
SET v_count = 0;
drop table IF EXISTS thcdnaproddata.aci.ade_lab1_lab2_tmp;
drop table IF EXISTS thcdnaproddata.aci.t_ade_fact_med1;
drop table IF EXISTS thcdnaproddata.aci.t_ade_fact_med2;
drop table IF EXISTS thcdnaproddata.aci.t_ade_fact_med3;
drop table IF EXISTS thcdnaproddata.aci.t_ade_report1;
drop table IF EXISTS thcdnaproddata.aci.t_ade_report2;
drop table IF EXISTS thcdnaproddata.aci.t_ade_report_lab_final;


--STEP-1
create table IF NOT EXISTS thcdnaproddata.aci.ade_lab1_lab2_tmp as 
SELECT  t.ADE_TYPE_DK as ADE_TYPE_SK,t.ADE_NAME,t.DRUG_NAME as DRUG_NAME, t.EVENT_NAME, t.EVENT_TYPE, ar.ADE_HSS_ID, ar.LAB_PRIMARY_ORDERABLE, ar.LAB_EVENT_DISPLAY
,'M1' as MED_TYPE
FROM thcdnaproddata.aci.dw_ade_ref ar
inner JOIN thcdnaproddata.aci.dim_ade_type t
 on t.EVENT_NAME = ar.ADE_NAME	
WHERE 
      ar.ACTIVE_IND = 1 and 
	  
	  t.EVENT_TYPE='LABORATORY' 
	  and ar.ADE_HSS_ID is null --Sanal 05162019
UNION DISTINCT
SELECT  t.ADE_TYPE_DK as ADE_TYPE_SK,t.ADE_NAME,t.DRUG_NAME, t.EVENT_NAME as EVENT_NAME, t.EVENT_TYPE, ar.ADE_HSS_ID, ar.MLTM_CATEGORY_NAME, 
        IFNULL(ar.MLTM_DRUG_IDENTIFIER, mr.MLTM_DRUG_IDENTIFIER) as MLTM_DRUG_IDENTIFIER,'M2' as MED_TYPE
FROM thcdnaproddata.aci.dw_ade_ref ar --Looks like its a one time load
inner JOIN thcdnaproddata.aci.dw_mltm_ref mr --(Staging Table for this table are not used in IDM)
  on ar.ADE_HSS_ID = mr.MLTM_HSS_ID and
     ar.MLTM_CATEGORY_NAME = mr.MLTM_CATEGORY_NAME and
	 mr.ACTIVE_IND = 1 
	 inner JOIN thcdnaproddata.aci.dim_ade_type t
 on t.DRUG_NAME = ar.ADE_NAME	
WHERE 
      ar.ACTIVE_IND = 1  
	
	  and t.EVENT_TYPE='LABORATORY' ;



create table IF NOT EXISTS thcdnaproddata.aci.t_ade_fact_med1 CLUSTER BY DIM_ORDER_SK as 
select  t.ADE_TYPE_SK,t.ADE_NAME,t.DRUG_NAME, t.EVENT_NAME, t.EVENT_TYPE,dm.DIM_ORDER_SK,dm.ORDER_DESC,dm.ORDER_NM
			  FROM thcdnaproddata.idm.dim_order dm
				inner JOIN thcdnaproddata.aci.ade_lab1_lab2_tmp t
				    on  upper(t.LAB_PRIMARY_ORDERABLE) = upper(ORDER_NM) 	
				/*inner join IDM..DIM_RESULT_TYPE_ADE rt 
				    --on (upper(RESULT_NM) =upper(LAB_PRIMARY_ORDERABLE) )	   
					 on (upper(RESULT_NM) =upper(LAB_EVENT_DISPLAY) )
					 */
					where t.MED_TYPE='M1' --and ADE_TYPE_SK=4
UNION DISTINCT			
select  t.ADE_TYPE_SK,t.ADE_NAME,t.DRUG_NAME, t.EVENT_NAME, t.EVENT_TYPE,dm.DIM_ORDER_SK,dm.ORDER_DESC,dm.ORDER_NM
			  FROM thcdnaproddata.idm.dim_order dm
				inner JOIN thcdnaproddata.aci.ade_lab1_lab2_tmp t
				    on (upper(t.LAB_EVENT_DISPLAY) = upper(ORDER_NM) --OR LAB_EVENT_DISPLAY is NULL
					)
					where t.MED_TYPE='M1';

					
create table IF NOT EXISTS thcdnaproddata.aci.t_ade_fact_med2 AS
select DIM_ORDER_SK,ADE_TYPE_SK,ADE_NAME,DRUG_NAME,EVENT_NAME,EVENT_TYPE FROM (
select  t.ADE_TYPE_SK,t.ADE_NAME,t.DRUG_NAME, t.EVENT_NAME, t.EVENT_TYPE,DIM_ORDER_SK,ORDER_DESC,ORDER_NM
		,row_number()over (partition by DIM_ORDER_SK order by 1) as rn
FROM thcdnaproddata.aci.ade_lab1_lab2_tmp t	
inner JOIN thcdnaproddata.idm.dim_order dm 
on t.LAB_EVENT_DISPLAY = dm.multum_cd --LAB_EVENT_DISPLAY is MULTUM DRUG IDENTIFIER
where MED_TYPE='M2'
) as foo where rn=1	
;



--STEP:3

CREATE TABLE IF NOT EXISTS thcdnaproddata.aci.t_ade_fact_med3 as 
select fo.patient_account_nbr,fo.facility_cd 
FROM thcdnaproddata.aci.t_ade_fact_med1 t
inner JOIN thcdnaproddata.idm.fact_order fo
on t.dim_order_sk = fo.dim_order_sk 
--WHERE fo.facility_cd='AHD'

INTERSECT DISTINCT
select fo.patient_account_nbr,fo.facility_cd
FROM thcdnaproddata.aci.t_ade_fact_med2 t
inner JOIN thcdnaproddata.idm.fact_order fo
on t.dim_order_sk = fo.dim_order_sk
--WHERE fo.facility_cd='AHD'
;


drop table IF EXISTS thcdnaproddata.aci.t_ade_report_stging_lab1;


CREATE TABLE IF NOT EXISTS thcdnaproddata.aci.t_ade_report_stging_lab1
CLUSTER BY hss_id, ENCNTR_ID AS
WITH
  clinical_events AS (
    SELECT
      HEALTH_SYSTEM_SOURCE_ID,
      event_id,
      ORDER_ID,
      ENCNTR_ID,
      EVENT_CD,
      EVENT_TAG,
      CLINSIG_UPDT_DT_TM,
      EVENT_RELTN_CD,
      EVENT_START_DT_TM,
      PERFORMED_PRSNL_ID,
      catalog_cd,
      NORMALCY_CD,
      RESULT_VAL,
      updt_dt_tm
    FROM thcdnaproddata.cerner_ods.cerner_clinical_event_hist
    WHERE VALID_UNTIL_DT_TM > CURRENT_DATETIME('America/Chicago')
      AND EVENT_RELTN_CD IN (132, 135)
      AND RESULT_STATUS_CD IN (23, 25)
      AND EVENT_CLASS_CD NOT IN (654645)
      AND view_level = 1
      AND AUTHENTIC_FLAG = 1
      AND event_end_dt_tm >= DATE_TRUNC(DATE_SUB(CURRENT_DATE(), INTERVAL 2 YEAR), YEAR)
  ),
  orders AS (
    SELECT
      HEALTH_SYSTEM_SOURCE_ID,
      ORDER_ID
    FROM thcdnaproddata.cerner_ods.cerner_orders_hist
    WHERE CATALOG_TYPE_CD = 2513
  ),
  ade_ref AS (
    SELECT
      ade_hss_id,
      ADE_NAME,
      LAB_PRIMARY_ORDERABLE,
      LAB_EVENT_DISPLAY
    FROM thcdnaproddata.aci.dw_ade_ref
    WHERE ADE_TYPE = 'Laboratory'
      AND ACTIVE_IND = 1
  )
SELECT
  s_ce.HEALTH_SYSTEM_SOURCE_ID AS hss_id,
  s_ce.event_id,
  s_ce.ORDER_ID,
  s_ce.ENCNTR_ID,
  s_ce.EVENT_CD,
  cv.DISPLAY AS catalog_disp,
  cv.DESCRIPTION AS catalog_description,
  cv1.code_value_pk AS event_pk,
  cv1.code_value_ak AS event_ak,
  cv1.description AS event_desc,
  cv1.display AS event_disp,
  REPLACE(s_ce.EVENT_TAG, '\\\\', '\\') AS event_tag,
  s_ce.CLINSIG_UPDT_DT_TM,
  s_ce.EVENT_RELTN_CD,
  IFNULL(s_ce.EVENT_START_DT_TM, s_ce.CLINSIG_UPDT_DT_TM) AS PERFORMED_DT_TM_UTC,
  s_ce.PERFORMED_PRSNL_ID AS PERFORMED_PERSONNEL_sK,
  s_ce.catalog_cd AS event_catalog_sk,
  CASE WHEN s_ce.NORMALCY_CD IN (201, 203, 215) THEN 1 ELSE 0 END AS RESULT_VALUE_IND,
  REPLACE(TRIM(REPLACE(REPLACE(s_ce.RESULT_VAL, '>', '+'), '<', '-')), '\\\\', '\\') AS RESULT_VALUE,
  ar.ADE_NAME,
  s_ce.updt_dt_tm AS ods_process_dt_tm
FROM clinical_events AS s_ce
INNER JOIN orders AS s_o
  ON s_o.HEALTH_SYSTEM_SOURCE_ID = s_ce.HEALTH_SYSTEM_SOURCE_ID
  AND s_o.ORDER_ID = s_ce.ORDER_ID
INNER JOIN thcdnaproddata.aci.dw_code_value AS cv
  ON cv.CODE_VALUE_HSS_ID = s_ce.HEALTH_SYSTEM_SOURCE_ID
  AND cv.CODE_VALUE_SK = s_ce.CATALOG_CD
INNER JOIN thcdnaproddata.aci.dw_code_value AS cv1
  ON cv1.CODE_VALUE_HSS_ID = s_ce.HEALTH_SYSTEM_SOURCE_ID
  AND cv1.CODE_VALUE_SK = s_ce.EVENT_CD
INNER JOIN ade_ref AS ar
  ON cv.DISPLAY = ar.LAB_PRIMARY_ORDERABLE
  AND (
    s_ce.HEALTH_SYSTEM_SOURCE_ID = ar.ade_hss_id
    OR ar.ade_hss_id IS NULL
  )
  AND (
    cv1.DISPLAY LIKE ar.LAB_EVENT_DISPLAY
    OR ar.LAB_EVENT_DISPLAY IS NULL
  );
	  

drop table IF EXISTS thcdnaproddata.aci.t_ade_report_stging_lab2;



CREATE TABLE IF NOT EXISTS thcdnaproddata.aci.t_ade_report_stging_lab2 CLUSTER BY FACILITY_CD AS
	SELECT 
		HSS_ID
       , EVENT_ID
       , ORDER_ID
       , ENCNTR_ID
       , EVENT_CD
       , CATALOG_DISP
       , CATALOG_DESCRIPTION
       , EVENT_PK
       , EVENT_AK
       , EVENT_DESC
       , EVENT_DISP
       , replace(EVENT_TAG,'\\\\\\\\','\\') EVENT_TAG
       , CLINSIG_UPDT_DT_TM
       , EVENT_RELTN_CD
       , PERFORMED_DT_TM_UTC
       , PERFORMED_PERSONNEL_SK
       , EVENT_CATALOG_SK
       , RESULT_VALUE_IND
       , replace(RESULT_VALUE,'\\\\\\\\','\\')  RESULT_VALUE
       , ADE_NAME
       , ODS_PROCESS_DT_TM
       , CASE WHEN FACILITY_CD ='AMS' THEN 'GBH'
			 WHEN FACILITY_CD = 'HCH' THEN 'CHF'
			 WHEN FACILITY_CD = 'SJH' THEN 'CSK'
			 WHEN FACILITY_CD =  'SMY' THEN 'CSM'
			ELSE FACILITY_CD 
			END as FACILITY_CD
       ,PATIENT_ACCOUNT_NBR FROM 	  (
	  SELECT s_ce.*,upper(trim(substr(cv2.DISPLAY,1,3))) as FACILITY_CD,
      replace(UPPER(TRIM(Ltrim(s_eah.ALIAS,'0' ))),'\\\\\\\\','\\') as Patient_Account_Nbr FROM thcdnaproddata.aci.t_ade_report_stging_lab1 s_ce
	  INNER JOIN thcdnaproddata.cerner_ods.cerner_encounter_hist s_eh
      ON s_eh.HEALTH_SYSTEM_SOURCE_ID = s_ce.hss_id and
      s_eh.ENCNTR_ID = s_ce.ENCNTR_ID and
	  
	  s_eh.ACTIVE_IND = 1	
INNER JOIN thcdnaproddata.cerner_ods.cerner_code_value_hist cv2
ON s_eh.HEALTH_SYSTEM_SOURCE_ID = cv2.HEALTH_SYSTEM_SOURCE_ID and
		cv2.CODE_VALUE = s_eh.LOC_FACILITY_CD and
		cv2.CODE_SET = 220 	
INNER JOIN thcdnaproddata.cerner_ods.cerner_encntr_alias_hist s_eah
ON s_eah.HEALTH_SYSTEM_SOURCE_ID = s_eh.HEALTH_SYSTEM_SOURCE_ID and
		s_eah.ENCNTR_ID = s_eh.ENCNTR_ID AND
		s_eah.ACTIVE_IND = 1 and
		s_eah.END_EFFECTIVE_DT_TM > CURRENT_DATETIME('America/Chicago') and
		s_eah.ENCNTR_ALIAS_TYPE_CD = 1077
		) as foo;	

drop table IF EXISTS thcdnaproddata.aci.t_ade_report_stging_final;

CREATE TABLE IF NOT EXISTS thcdnaproddata.aci.t_ade_report_stging_final AS		
	SELECT HSS_ID
       , EVENT_ID
       , ORDER_ID
       , ENCNTR_ID
       , EVENT_CD
       , CATALOG_DISP
       , CATALOG_DESCRIPTION
       , EVENT_PK
       , EVENT_AK
       , EVENT_DESC
       , EVENT_DISP
       , replace(EVENT_TAG,'\\\\\\\\','\\') EVENT_TAG
       , CLINSIG_UPDT_DT_TM
       , EVENT_RELTN_CD
       , PERFORMED_DT_TM_UTC
       , PERFORMED_PERSONNEL_SK
       , EVENT_CATALOG_SK
       , RESULT_VALUE_IND
	   	,case when (length(translate(result_value,'0123456789.',''))=0 and length(result_value)>0) is true
			   and result_value not like '%..%' 
			   and result_value not like '%.%.%' 
			   and result_value <> '.' then cast(result_value as numeric) 
	 	when (length(translate(substr(result_value,instr(result_value,'+')+1),'0123456789.',''))=0 and 
	 	length(substr(result_value,instr(result_value,'+')+1))>0) is true
			   and result_value not like '%..%' 
			   and result_value not like '%.%.%' 
			   and result_value <> '.' then cast(substr(result_value,instr(result_value,'+')+1) as numeric)+ 0.01
	 	when  (length(translate(substr(result_value,instr(result_value,'-')+1),'0123456789.',''))=0 and 
                    length(substr(result_value,instr(result_value,'-')+1))>0) is true
	                and  result_value not like '%..%' 
					and result_value not like '%.%.%'
					and result_value <> '.' 
					then cast(substr(result_value,instr(result_value,'-')+1) as numeric) - 0.01	
   		end as result_value 
       , ADE_NAME
       , ODS_PROCESS_DT_TM
       , stg.FACILITY_CD
       ,replace(IFNULL(PREFIX,'')||PATIENT_ACCOUNT_NBR,'\\\\\\\\','\\') as PATIENT_ACCOUNT_NBR
  FROM thcdnaproddata.aci.t_ade_report_stging_lab2 stg
  LEFT JOIN thcdnaproddata.clinical_ops.dim_facility_prefix fp
  ON stg.FACILITY_CD = fp.FACILITY_CD;

  
drop table IF EXISTS thcdnaproddata.aci.ordering_physician_stg;  


CREATE TABLE IF NOT EXISTS thcdnaproddata.aci.ordering_physician_stg CLUSTER BY hss_id,order_id AS
select * FROM (
--CERNER
select distinct o.order_id
,o.health_system_source_id as hss_id
, p.name_full_formatted as ordering_physician
FROM thcdnaproddata.cerner_ods.cerner_orders_hist o
inner JOIN thcdnaproddata.cerner_ods.cerner_order_action_hist oa
on oa.order_id = o.order_id
and oa.health_system_source_id = o.health_system_source_id
and oa.order_provider_id > 0
and oa.action_sequence = 1    
inner JOIN thcdnaproddata.cerner_ods.cerner_code_value_hist cv
on oa.action_type_cd = cv.code_value
and cv.display = 'Order'
and oa.health_system_source_id = cv.health_system_source_id
inner JOIN thcdnaproddata.cerner_ods.cerner_prsnl_hist p
on p.person_id = oa.order_provider_id
inner JOIN thcdnaproddata.cerner_ods.cerner_code_value_hist f 
on p.health_system_source_id = f.health_system_source_id 
and f.code_value = p.position_cd

UNION ALL
---DMC
select distinct o.order_id
,o.health_system_source_id as hss_id
, p.name_full_formatted as ordering_physician
FROM thcdnaproddata.cerner_ods.dmc_orders_hist o
inner JOIN thcdnaproddata.cerner_ods.dmc_order_action_hist oa
on oa.order_id = o.order_id
and oa.health_system_source_id = o.health_system_source_id
and oa.order_provider_id > 0
and oa.action_sequence = 1    
inner JOIN thcdnaproddata.cerner_ods.dmc_code_value_hist cv
on oa.action_type_cd = cv.code_value
and cv.display = 'Order'
and oa.health_system_source_id = cv.health_system_source_id
inner JOIN thcdnaproddata.cerner_ods.dmc_prsnl_hist p
on p.person_id = oa.order_provider_id
inner JOIN thcdnaproddata.cerner_ods.dmc_code_value_hist f 
on p.health_system_source_id = f.health_system_source_id 
and f.code_value = p.position_cd
) as foo;  

drop table IF EXISTS thcdnaproddata.aci.oredr_mnemonic_stg1;  


CREATE TABLE IF NOT EXISTS thcdnaproddata.aci.oredr_mnemonic_stg1 CLUSTER BY order_hss_id,ORDER_ID AS
select * FROM (
select DISTINCT 
       	   s_o.HEALTH_SYSTEM_SOURCE_ID as order_hss_id,
		   s_o.ORDER_ID as ORDER_ID 
	FROM thcdnaproddata.cerner_ods.cerner_orders_hist s_o	
	LEFT JOIN thcdnaproddata.cerner_ods.cerner_order_action_hist s_oa
      on s_oa.HEALTH_SYSTEM_SOURCE_ID = s_o.HEALTH_SYSTEM_SOURCE_ID and
	     s_oa.ORDER_ID = s_o.ORDER_ID and
	     s_oa.ACTION_TYPE_CD = 2534 
	WHERE 
		  --s_o.TEMPLATE_ORDER_FLAG not in (4,2) AND  
	      s_o.ORIG_ORD_AS_FLAG in (0,1,2)
		  
	UNION ALL
	
	select DISTINCT 
       	   s_o.HEALTH_SYSTEM_SOURCE_ID as order_hss_id,
		   s_o.ORDER_ID as ORDER_ID 
	FROM thcdnaproddata.cerner_ods.dmc_orders_hist s_o	
	LEFT JOIN thcdnaproddata.cerner_ods.dmc_order_action_hist s_oa
      on s_oa.HEALTH_SYSTEM_SOURCE_ID = s_o.HEALTH_SYSTEM_SOURCE_ID and
	     s_oa.ORDER_ID = s_o.ORDER_ID and
	     s_oa.ACTION_TYPE_CD = 2534
	WHERE 
		  --s_o.TEMPLATE_ORDER_FLAG not in (4,2) AND  
	      s_o.ORIG_ORD_AS_FLAG in (0,1,2)	  
	)as foo;
		  
drop table IF EXISTS thcdnaproddata.aci.oredr_mnemonic_stg2; 

create table IF NOT EXISTS thcdnaproddata.aci.oredr_mnemonic_stg2 CLUSTER BY order_hss_id,ORDER_ID as	  
  select * FROM   (
  select s_o.HEALTH_SYSTEM_SOURCE_ID as order_hss_id, 
       s_o.ORDER_ID as ORDER_ID, 
	   s_o.ENCNTR_ID as ENCNTR_ID, 
	   s_o.PERSON_ID as PERSON_ID, 
	   s_o.ordered_as_mnemonic as ordered_as_mnemonic,
	   s_o.ORDER_MNEMONIC as PRIMARY_MNEMONIC,
	   s_o.CLINICAL_DISPLAY_LINE, 
	   s_o.ORDER_DETAIL_DISPLAY_LINE 
FROM thcdnaproddata.aci.oredr_mnemonic_stg1 stg1
inner JOIN thcdnaproddata.cerner_ods.cerner_orders_hist s_o
   on s_o.HEALTH_SYSTEM_SOURCE_ID = stg1.order_hss_id and
	  s_o.ORDER_ID = stg1.ORDER_id 
	  
	UNION ALL
	  
	select s_o.HEALTH_SYSTEM_SOURCE_ID as order_hss_id, 
       s_o.ORDER_ID as ORDER_ID, 
	   s_o.ENCNTR_ID as ENCNTR_ID, 
	   s_o.PERSON_ID as PERSON_ID, 
	   s_o.ordered_as_mnemonic as ordered_as_mnemonic,
	   s_o.ORDER_MNEMONIC as PRIMARY_MNEMONIC,
	   s_o.CLINICAL_DISPLAY_LINE, 
	   s_o.ORDER_DETAIL_DISPLAY_LINE 
FROM thcdnaproddata.aci.oredr_mnemonic_stg1 stg1
inner JOIN thcdnaproddata.cerner_ods.dmc_orders_hist s_o
   on s_o.HEALTH_SYSTEM_SOURCE_ID = stg1.order_hss_id and
	  s_o.ORDER_ID = stg1.ORDER_id 
	  
	  ) as foo;

--NURSING UNIT 06142019

drop table IF EXISTS thcdnaproddata.aci.ade_med_admin_nurse_unit_tmp;



CREATE TABLE IF NOT EXISTS thcdnaproddata.aci.ade_med_admin_nurse_unit_tmp 
CLUSTER BY hss_id, nursing_unit_location AS
WITH cerner_events AS (
  SELECT
    s_ce.health_system_source_id AS hss_id,
    s_ce.order_id,
    s_ce.encntr_id AS encounter_id,
    s_ce.event_cd,
    s_ce.event_id,
    s_ce.parent_event_id,
    s_ce.clinical_event_id,
    s_ce.event_tag,
    s_ce.clinsig_updt_dt_tm,
    s_ce.event_end_dt_tm,
    s_ce.event_reltn_cd,
    s_ce.event_start_dt_tm AS performed_dt_tm_utc,
    s_ce.performed_prsnl_id,
    nurse_unit_cd.nurse_unit_cd,
    nurse_unit_cd1.display AS nursing_unit_location
  FROM thcdnaproddata.cerner_ods.cerner_clinical_event_hist AS s_ce
  LEFT JOIN thcdnaproddata.cerner_ods.cerner_med_admin_event_hist AS nurse_unit_cd
    ON nurse_unit_cd.health_system_source_id = s_ce.health_system_source_id
    AND nurse_unit_cd.event_id = s_ce.event_id
  LEFT JOIN thcdnaproddata.cerner_ods.cerner_code_value_hist AS nurse_unit_cd1
    ON nurse_unit_cd.health_system_source_id = nurse_unit_cd1.health_system_source_id
    AND nurse_unit_cd.nurse_unit_cd = nurse_unit_cd1.code_value
  WHERE s_ce.VALID_UNTIL_DT_TM > CURRENT_DATETIME('America/Chicago')
    AND s_ce.EVENT_CLASS_CD = 232
    AND s_ce.EVENT_RELTN_CD IN (132, 135)
    AND s_ce.RESULT_STATUS_CD IN (23, 25)
    AND s_ce.event_end_dt_tm >= DATE_TRUNC(DATE_SUB(CURRENT_DATE(), INTERVAL 2 YEAR), YEAR)
    AND EXISTS (
      SELECT 1
      FROM thcdnaproddata.cerner_ods.cerner_orders_hist AS s_o
      WHERE s_o.HEALTH_SYSTEM_SOURCE_ID = s_ce.HEALTH_SYSTEM_SOURCE_ID
        AND s_o.ORDER_ID = s_ce.ORDER_ID
        AND s_o.CATALOG_TYPE_CD = 2516
    )
),
dmc_events AS (
  SELECT
    s_ce.health_system_source_id AS hss_id,
    s_ce.order_id,
    s_ce.encntr_id AS encounter_id,
    s_ce.event_cd,
    s_ce.event_id,
    s_ce.parent_event_id,
    s_ce.clinical_event_id,
    s_ce.event_tag,
    s_ce.clinsig_updt_dt_tm,
    s_ce.event_end_dt_tm,
    s_ce.event_reltn_cd,
    s_ce.event_start_dt_tm AS performed_dt_tm_utc,
    s_ce.performed_prsnl_id,
    nurse_unit_cd.nurse_unit_cd,
    nurse_unit_cd1.display AS nursing_unit_location
  FROM thcdnaproddata.cerner_ods.dmc_clinical_event_hist AS s_ce
  LEFT JOIN thcdnaproddata.cerner_ods.dmc_med_admin_event_hist AS nurse_unit_cd
    ON nurse_unit_cd.health_system_source_id = s_ce.health_system_source_id
    AND nurse_unit_cd.event_id = s_ce.event_id
  LEFT JOIN thcdnaproddata.cerner_ods.dmc_code_value_hist AS nurse_unit_cd1
    ON nurse_unit_cd.health_system_source_id = nurse_unit_cd1.health_system_source_id
    AND nurse_unit_cd.nurse_unit_cd = nurse_unit_cd1.code_value
  WHERE s_ce.VALID_UNTIL_DT_TM > CURRENT_DATETIME('America/Chicago')
    AND s_ce.EVENT_CLASS_CD = 128
    AND s_ce.EVENT_RELTN_CD IN (72, 74)
    AND s_ce.RESULT_STATUS_CD IN (11, 13)
    AND s_ce.event_end_dt_tm >= DATE_TRUNC(DATE_SUB(CURRENT_DATE(), INTERVAL 2 YEAR), YEAR)
    AND EXISTS (
      SELECT 1
      FROM thcdnaproddata.cerner_ods.dmc_orders_hist AS s_o
      WHERE s_o.HEALTH_SYSTEM_SOURCE_ID = s_ce.HEALTH_SYSTEM_SOURCE_ID
        AND s_o.ORDER_ID = s_ce.ORDER_ID
        AND s_o.CATALOG_TYPE_CD = 1227
    )
)
SELECT * FROM cerner_events
UNION ALL
SELECT * FROM dmc_events;


drop table IF EXISTS thcdnaproddata.aci.cerner_dmc_prsnl_all;


CREATE TABLE IF NOT EXISTS thcdnaproddata.aci.cerner_dmc_prsnl_all AS
select p.HEALTH_SYSTEM_SOURCE_ID,p.PERSON_ID,substr(p.NAME_FIRST,1,100) as PERSONNEL_FIRST_NAME
			   ,substr(p.NAME_LAST,1,100) as PERSONNEL_LAST_NAME
			   ,p.NAME_FULL_FORMATTED as PERSONNEL_FULL_NAME
			   ,p.PHYSICIAN_IND 
			   ,p.ACTIVE_IND 	
			   ,p.POSITION_CD
				
FROM thcdnaproddata.cerner_ods.cerner_prsnl_hist p 	
UNION DISTINCT
select p.HEALTH_SYSTEM_SOURCE_ID,p.PERSON_ID,substr(p.NAME_FIRST,1,100) as PERSONNEL_FIRST_NAME
			   ,substr(p.NAME_LAST,1,100) as PERSONNEL_LAST_NAME
			   ,p.NAME_FULL_FORMATTED as PERSONNEL_FULL_NAME
			   ,p.PHYSICIAN_IND 
			   ,p.ACTIVE_IND 	
			   ,p.POSITION_CD
				
FROM thcdnaproddata.cerner_ods.dmc_prsnl_hist p ;

drop table IF EXISTS thcdnaproddata.aci.cerner_dmc_prsnl_alias_all;


CREATE TABLE IF NOT EXISTS thcdnaproddata.aci.cerner_dmc_prsnl_alias_all AS 
SELECT HEALTH_SYSTEM_SOURCE_ID,
 PERSON_ID,
 Prsnl_ALIAS_TYPE_CD
 FROM thcdnaproddata.cerner_ods.cerner_prsnl_alias_hist  UNION DISTINCT
 SELECT HEALTH_SYSTEM_SOURCE_ID,
 PERSON_ID,
 Prsnl_ALIAS_TYPE_CD
 FROM thcdnaproddata.cerner_ods.dmc_prsnl_alias_hist;	 
 
 drop table IF EXISTS thcdnaproddata.aci.ade_personnel;	  


CREATE TABLE IF NOT EXISTS thcdnaproddata.aci.ade_personnel AS
		SELECT p.HEALTH_SYSTEM_SOURCE_ID as PERSONNEL_HSS_ID,
    		   p.PERSON_ID as PERSONNEL_ID,
			   p. PERSONNEL_FIRST_NAME,
			   p. PERSONNEL_LAST_NAME,
			   p.PERSONNEL_FULL_NAME,
			   p.PHYSICIAN_IND as PHYSICIAN_IND,
			   p.ACTIVE_IND as ACTIVE_IND			
  		  FROM thcdnaproddata.aci.cerner_dmc_prsnl_all p
		  LEFT JOIN thcdnaproddata.aci.dw_code_value cv
			ON p.HEALTH_SYSTEM_SOURCE_ID = cv.CODE_VALUE_HSS_ID and 
			   p.POSITION_CD = cv.CODE_VALUE_SK 
		  left JOIN thcdnaproddata.aci.cerner_dmc_prsnl_alias_all pa1
   			on pa1.HEALTH_SYSTEM_SOURCE_ID = p.HEALTH_SYSTEM_SOURCE_ID and
    		   pa1.PERSON_ID = p.PERSON_ID and
    		   pa1.Prsnl_ALIAS_TYPE_CD = CASE WHEN p.HEALTH_SYSTEM_SOURCE_ID = 80041 THEN 5903754 WHEN p.HEALTH_SYSTEM_SOURCE_ID =  80047 THEN 4544624 WHEN p.HEALTH_SYSTEM_SOURCE_ID =  80048 THEN 131661687 ELSE 4007194 END ;

drop table IF EXISTS thcdnaproddata.aci.ade_admin_nurse_unit_location;


	CREATE TABLE IF NOT EXISTS thcdnaproddata.aci.ade_admin_nurse_unit_location CLUSTER BY hss_id AS 
	select 
	    md.hss_id,
	    md.order_id,
	    md.encounter_id,
	    md.event_cd,
	    md.event_id,
	    md.clinical_event_id,
	    md.event_tag,
        md.clinsig_updt_dt_tm,
	    md.event_end_dt_tm,
	    md.event_reltn_cd,
	    md.performed_dt_tm_utc,
	    md.performed_prsnl_id,
	    md.nurse_unit_cd,
	    md.nursing_unit_location
	FROM thcdnaproddata.aci.ade_med_admin_nurse_unit_tmp md
	WHERE md.nursing_unit_location is not null;
	
	
drop table IF EXISTS thcdnaproddata.aci.ade_admin_administering_rn ;

CREATE TABLE IF NOT EXISTS thcdnaproddata.aci.ade_admin_administering_rn AS 
	SELECT 
	    md.hss_id,
	    md.order_id,
	    md.encounter_id,
	    md.event_cd,
	    md.event_id,
	    md.clinical_event_id,
	    md.event_tag,
        md.CLINSIG_UPDT_DT_TM,
	    md.EVENT_END_DT_TM,
	    md.EVENT_RELTN_CD,
	    md.PERFORMED_DT_TM_UTC,
	    md.PERFORMED_PRSNL_ID,
	    md.NURSE_UNIT_CD,
	    md.NURSING_UNIT_LOCATION,
		p.PERSONNEL_FIRST_NAME,
		p.PERSONNEL_LAST_NAME,
		p.PERSONNEL_FULL_NAME,
		p.PHYSICIAN_IND,
		p.ACTIVE_IND
	FROM thcdnaproddata.aci.ade_med_admin_nurse_unit_tmp md
	LEFT JOIN thcdnaproddata.aci.ade_personnel p
	ON md.hss_id = p.PERSONNEL_HSS_ID
	and md.PERFORMED_PRSNL_ID = p.PERSONNEL_ID
	WHERE p.PERSONNEL_FULL_NAME is not null
	;
	  

-- drop table IF EXISTS thcdnaproddata.aci.t_ade_report1;

CREATE TABLE IF NOT EXISTS thcdnaproddata.aci.t_ade_report1 as 
select  med1.ADE_TYPE_SK
       , med1.ADE_NAME as ADE_NAME
       , med1.DRUG_NAME as DRUG_NAME
       , med1.EVENT_NAME as EVENT_NAME
       , med1.EVENT_TYPE as EVENT_TYPE
   ,f.FACILITY_CD as FACILITY_DISP
   ,f.FACILITY_NM_AND_CD as FACILITY_DESC
   ,f.MRKT_ID as MRKT_ID
   ,f.MRKT_NM as MRKT_NM
   ,f.REGN_ID as REGN_ID
   ,f.REGN_NM as REGN_NM
   ,CAST(NULL AS STRING) as DC_DATE_DK --?
   ,e.DISCHARGE_DT||' '||DISCHARGE_TM as DC_DT_TM
   ,e.DIM_ENCOUNTER_TYPE_SK as ENCOUNTER_SK
   ,e.PATIENT_ACCOUNT_NBR as FIN_NBR
   ,p.MEDICAL_RECORD_NBR as MRN
   ,e.ADMISSION_DT||' '||e.ADMISSION_TM as ADMIT_DT_TM
   ,fl.event_tag as EVENT_TAG --Need to Identify
   ,(case when trunc(timestamp_DIFF(CURRENT_DATETIME('America/Chicago'), p.DATE_OF_BIRTH, SECOND )/31536000) < 3 then 
	              trunc(timestamp_DIFF( CURRENT_DATETIME('America/Chicago'), p.DATE_OF_BIRTH, SECOND )/2628000 )|| ' Months'
			 else trunc(timestamp_DIFF(CURRENT_DATETIME('America/Chicago'), p.DATE_OF_BIRTH, SECOND)/31536000) || ' Years' end ) as EVENT_AGE
   ,pa.FIRST_NM||IFNULL(pa.MIDDLE_NM,' ')||pa.LAST_NM as attending_physician
   ,cast(NULL as STRING) as DRUG_ADMIN_SK
   ,cast(NULL as STRING) as DRUG_ADMIN_DT_TM
   ,cast(NULL as STRING) as DRUG_EVENT_TAG--?
   ,cast(NULL as STRING) as DRUG_ADMIN_UNIT_SK
   ,cast(NULL as STRING) as DRUG_ADMIN_UNIT
   ,cast(NULL as STRING) as PARENT_ORDER_SK
   ,cast(NULL as STRING) as DRUG_ORDER_DT_TM
   ,cast(NULL as STRING) as DRUG_MNEMONIC 
   ,cast(NULL as STRING) as DRUG_ORDER_DETAIL
   ,cast(NULL as STRING) as DRUG_PHYSICIAN_SK
   ,cast(NULL as STRING) as DRUG_ORDERING_MD
   ,cast(NULL as STRING) as DRUG_PERSONNEL_SK
   ,cast(NULL as STRING) as DRUG_ADMINISTRATING_RN
   
   ,CAST(NULL AS STRING)as EVENT_ADMIN_SK
   , CAST(NULL AS STRING) as EVENT_ADMIN_DT_TM
   , CAST(NULL AS STRING)as EVENT_EVENT_TAG 
   , o.DIM_ORDER_LOCATION_SK as EVENT_ADMIN_UNIT_DK
       , d.LOCATION_CD as EVENT_ADMIN_UNIT
       ,(case when o.TEMPLATE_ORDER_FLG = 0 or o.TEMPLATE_ORDER_FLG is null then o.fact_order_sk end ) as EVENT_PARENT_ORDER_DK
       , o.ORDER_ACTION_TS as EVENT_ORDER_DT_TM
       , med1.ORDER_NM as EVENT_MNEMONIC
       ,  med1.ORDER_DESC as EVENT_ORDER_DETAIL
       , CAST(NULL AS STRING) as EVENT_RESULT_DK--?
       , CAST(NULL AS STRING) as EVENT_TEST_RESULT--?
       , fl.RESULT_VALUE
       , fl.RESULT_VALUE_IND
       ,thcdnaproddata.staging.convert_timezone(fl.PERFORMED_DT_TM_UTC, CAST( case IFNULL(f.DST_IND,'X') WHEN 'X' THEN NULL when 'Y' then 1 else 0 end AS BOOL), f.TM_ZONE_NM) as EVENT_PERFORMED_DT_TM
       , o.DIM_ORDERING_PHYSICIAN_SK as EVENT_PHYSICIAN_DK
       --, pa1.FIRST_NM||' '||pa1.MIDDLE_NM||' '||pa1.LAST_NM  as EVENT_ORDERING_MD
	   , stg.ordering_physician as EVENT_ORDERING_MD 
       , CAST(NULL AS STRING)as EVENT_PERSONNEL_DK--?
       , CAST(NULL AS STRING) as EVENT_ADMINISTRATING_RN--?
	    , 1 as ADE_IND

			,(case when timestamp_diff( cast(cast(current_datetime('America/Chicago') as string) as datetime),cast(cast(p.DATE_OF_BIRTH as string) as datetime) , second )/31536000 <18 then 1 else 0 end) as PEDIATRIC_PATIENT
      --  , (case when DATE_DIFF(CURRENT_DATETIME('America/Chicago'), p.DATE_OF_BIRTH, SECOND )/31536000 < 18 then 1 else 0 end) as PEDIATRIC_PATIENT
       , CURRENT_DATETIME('America/Chicago') as DM_CREATE_DT_TM FROM thcdnaproddata.aci.t_ade_report_stging_final fl
inner join 	(select regexp_extract(unique_id,'[0-9]+',1,2) as order_id,
regexp_extract(unique_id,'[0-9]+',1,1) as hss_id,* FROM thcdnaproddata.idm.fact_order) o
on o.patient_account_nbr = fl.patient_account_nbr
and o.facility_cd = fl.facility_cd 
and o.order_id = CAST(fl.order_id AS STRING)
inner JOIN thcdnaproddata.aci.t_ade_fact_med1 med1
on med1.DIM_ORDER_SK = o.dim_order_sk 
inner JOIN thcdnaproddata.idm.dim_facility f
on f.dim_facility_sk = o.dim_facility_Sk
inner JOIN thcdnaproddata.idm.fact_encounter e
on e.patient_account_nbr = o.patient_account_nbr
and e.facility_cd = o.facility_cd
inner JOIN thcdnaproddata.idm.dim_patient p
on p.dim_patient_sk = e.dim_patient_sk
left JOIN thcdnaproddata.idm.dim_physician pa
on pa.DIM_PHYSICIAN_SK = e.DIM_ATTENDING_PHYSICIAN_SK
left JOIN thcdnaproddata.idm.dim_location d
on d.DIM_LOCATION_SK = o.DIM_ORDER_LOCATION_SK
left JOIN thcdnaproddata.aci.ordering_physician_stg stg
on CAST(stg.hss_id AS STRING) = o.hss_id
and CAST(stg.order_id AS STRING) = o.order_id  ;


drop table IF EXISTS thcdnaproddata.aci.ade_med_admin_tmp;


CREATE TABLE IF NOT EXISTS thcdnaproddata.aci.ade_med_admin_tmp CLUSTER BY fact_order_sk as select ma.* FROM thcdnaproddata.aci.t_ade_fact_med3 fca	   
inner JOIN thcdnaproddata.idm.fact_medications_administration ma
on fca.patient_account_nbr = ma.patient_account_nbr
and fca.facility_cd = ma.facility_cd
--WHERE ma.facility_cd='AHD'
;



-- START OPTIMIZED QUERY
CREATE TABLE IF NOT EXISTS thcdnaproddata.aci.t_ade_report2
AS
WITH
med_admin_base AS (
  -- Prune columns and compute regex once
  SELECT
    regexp_extract(unique_id, '[0-9]+', 1, 1) AS hss_id,
    regexp_extract(unique_id, '[0-9]+', 1, 2) AS event_id,
    regexp_extract(unique_id, '[0-9]+', 1, 3) AS clinical_event_id,
    fact_medications_administration_sk,
    dim_facility_sk,
    dim_patient_sk,
    dim_dosage_measuring_units_sk,
    dim_administering_personnel_sk,
    dim_administering_location_sk,
    fact_order_sk,
    begin_bag_flg,
    dosage_quantity,
    administer_ts
  FROM thcdnaproddata.aci.ade_med_admin_tmp
),
orders_base AS (
  -- Prune columns and compute regex once
  SELECT
    regexp_extract(unique_id, '[0-9]+', 1, 2) AS order_id,
    regexp_extract(unique_id, '[0-9]+', 1, 1) AS hss_id,
    fact_order_sk,
    dim_order_sk,
    patient_account_nbr,
    facility_cd,
    template_order_flg,
    order_action_ts
  FROM thcdnaproddata.idm.fact_order
),
ordering_physician_stg_cte AS (
  SELECT
    CAST(hss_id AS STRING) AS hss_id,
    CAST(order_id AS STRING) AS order_id,
    ordering_physician
  FROM thcdnaproddata.aci.ordering_physician_stg
),
order_mnemonic_stg_cte AS (
  SELECT
    CAST(order_hss_id AS STRING) AS order_hss_id,
    CAST(order_id AS STRING) AS order_id,
    ordered_as_mnemonic,
    clinical_display_line
  FROM thcdnaproddata.aci.oredr_mnemonic_stg2
),
admin_nurse_unit_cte AS (
  SELECT
    CAST(hss_id AS STRING) AS hss_id,
    CAST(event_id AS STRING) AS event_id,
    CAST(clinical_event_id AS STRING) AS clinical_event_id,
    nursing_unit_location
  FROM thcdnaproddata.aci.ade_admin_nurse_unit_location
),
admin_rn_cte AS (
  SELECT
    CAST(hss_id AS STRING) AS hss_id,
    CAST(event_id AS STRING) AS event_id,
    CAST(clinical_event_id AS STRING) AS clinical_event_id,
    personnel_full_name
  FROM thcdnaproddata.aci.ade_admin_administering_rn
)
SELECT
    med2.ADE_TYPE_SK,
    med2.ADE_NAME,
    med2.DRUG_NAME,
    med2.EVENT_NAME,
    med2.EVENT_TYPE,
    f.FACILITY_CD AS FACILITY_DISP,
    f.FACILITY_NM_AND_CD AS FACILITY_DESC,
    f.MRKT_ID,
    f.MRKT_NM,
    f.REGN_ID,
    f.REGN_NM,
    CAST(NULL AS STRING) AS DC_DATE_DK,
    e.DISCHARGE_DT || ' ' || e.DISCHARGE_TM AS DC_DT_TM,
    e.DIM_ENCOUNTER_TYPE_SK AS ENCOUNTER_SK,
    e.PATIENT_ACCOUNT_NBR AS FIN_NBR,
    p.MEDICAL_RECORD_NBR AS MRN,
    e.ADMISSION_DT || ' ' || e.ADMISSION_TM AS ADMIT_DT_TM,
    CAST(NULL AS STRING) AS EVENT_TAG,
    (
      CASE
        WHEN staging.age_formatter(DATETIME(md.administer_ts), DATETIME(p.date_of_birth), 'Y') < 3
        THEN staging.age_formatter(DATETIME(md.administer_ts), DATETIME(p.date_of_birth), 'M') || ' Months'
        ELSE staging.age_formatter(DATETIME(md.administer_ts), DATETIME(p.date_of_birth), 'Y') || ' Years'
      END
    ) AS EVENT_AGE,
    pa.FIRST_NM || IFNULL(pa.MIDDLE_NM, ' ') || pa.LAST_NM AS attending_physician,
    md.fact_medications_administration_sk AS DRUG_ADMIN_SK,
    md.administer_ts AS DRUG_ADMIN_DT_TM,
    FORMAT('%.*f', 2, CAST(ROUND(md.dosage_quantity, 2) AS FLOAT64)) || ' ' || mu.MEASURING_UNITS AS DRUG_EVENT_TAG,
    md.dim_administering_location_sk AS DRUG_ADMIN_UNIT_SK,
    (
      CASE
        WHEN (d.LOCATION_CD IS NULL OR d.LOCATION_CD = 'N/A') THEN stg2.nursing_unit_location
        ELSE f.FACILITY_CD || '-' || d.LOCATION_CD
      END
    ) AS DRUG_ADMIN_UNIT,
    (CASE WHEN o.template_order_flg = 0 OR o.template_order_flg IS NULL THEN o.fact_order_sk END) AS PARENT_ORDER_SK,
    o.order_action_ts AS DRUG_ORDER_DT_TM,
    stg1.ordered_as_mnemonic AS DRUG_MNEMONIC,
    stg1.clinical_display_line AS DRUG_ORDER_DETAIL,
    stg.ordering_physician AS DRUG_ORDERING_MD,
    pa2.DIM_PERSONNEL_SK AS DRUG_PERSONNEL_SK,
    (
      CASE
        WHEN pa2.PERSONNEL_FULL_NAME IS NULL OR pa2.PERSONNEL_FULL_NAME = 'N/A' THEN stg3.personnel_full_name
        ELSE pa2.PERSONNEL_FULL_NAME
      END
    ) AS DRUG_ADMINISTRATING_RN,
    -99 AS EVENT_ADMIN_SK,
    CAST(NULL AS STRING) AS EVENT_ADMIN_DT_TM,
    CAST(NULL AS STRING) AS EVENT_EVENT_TAG,
    CAST(NULL AS STRING) AS EVENT_ADMIN_UNIT_DK,
    CAST(NULL AS STRING) AS EVENT_ADMIN_UNIT,
    CAST(NULL AS STRING) AS EVENT_PARENT_ORDER_DK,
    CAST(NULL AS STRING) AS EVENT_ORDER_DT_TM,
    CAST(NULL AS STRING) AS EVENT_MNEMONIC,
    CAST(NULL AS STRING) AS EVENT_ORDER_DETAIL,
    CAST(NULL AS STRING) AS EVENT_RESULT_DK,
    CAST(NULL AS STRING) AS EVENT_TEST_RESULT,
    CAST(NULL AS STRING) AS RESULT_VALUE,
    CAST(NULL AS STRING) AS RESULT_VALUE_IND,
    CAST(NULL AS STRING) AS EVENT_PERFORMED_DT_TM,
    CAST(NULL AS STRING) AS EVENT_PHYSICIAN_DK,
    CAST(NULL AS STRING) AS EVENT_ORDERING_MD,
    CAST(NULL AS STRING) AS EVENT_PERSONNEL_DK,
    CAST(NULL AS STRING) AS EVENT_ADMINISTRATING_RN,
    1 AS ADE_IND,
    -- Replaced inconsistent and inaccurate age logic with the same UDF used for EVENT_AGE.
    (CASE WHEN staging.age_formatter(DATETIME(md.administer_ts), DATETIME(p.date_of_birth), 'Y') < 18 THEN 1 ELSE 0 END) AS PEDIATRIC_PATIENT,
    md.begin_bag_flg,
    CURRENT_DATETIME('America/Chicago') AS DM_CREATE_DT_TM
FROM med_admin_base AS md
INNER JOIN orders_base AS o ON o.fact_order_sk = md.fact_order_sk
INNER JOIN thcdnaproddata.aci.t_ade_fact_med2 AS med2 ON med2.DIM_ORDER_SK = o.dim_order_sk
INNER JOIN thcdnaproddata.idm.dim_patient AS p ON p.dim_patient_sk = md.dim_patient_sk
INNER JOIN thcdnaproddata.idm.fact_encounter AS e ON e.patient_account_nbr = o.patient_account_nbr AND e.facility_cd = o.facility_cd
INNER JOIN thcdnaproddata.idm.dim_facility AS f ON f.dim_facility_sk = md.dim_facility_sk
LEFT JOIN thcdnaproddata.idm.dim_physician AS pa ON pa.DIM_PHYSICIAN_SK = e.DIM_ATTENDING_PHYSICIAN_SK
LEFT JOIN thcdnaproddata.idm.dim_location AS d ON d.DIM_LOCATION_SK = md.dim_administering_location_sk
LEFT JOIN ordering_physician_stg_cte AS stg ON stg.hss_id = o.hss_id AND stg.order_id = o.order_id
LEFT JOIN thcdnaproddata.idm.dim_personnel AS pa2 ON pa2.DIM_PERSONNEL_SK = md.dim_administering_personnel_sk
LEFT JOIN thcdnaproddata.idm.dim_measuring_units AS mu ON md.dim_dosage_measuring_units_sk = mu.DIM_MEASURING_UNITS_SK
LEFT JOIN order_mnemonic_stg_cte AS stg1 ON stg1.order_hss_id = o.hss_id AND stg1.order_id = o.order_id
LEFT JOIN admin_nurse_unit_cte AS stg2 ON stg2.hss_id = md.hss_id AND stg2.event_id = md.event_id AND stg2.clinical_event_id = md.clinical_event_id
LEFT JOIN admin_rn_cte AS stg3 ON stg3.hss_id = md.hss_id AND stg3.event_id = md.event_id AND stg3.clinical_event_id = md.clinical_event_id;
-- END OPTIMIZED QUERY;


  

--STEP:4
/*
CREATE TABLE internal.T_ADE_REPORT_LAB_FINAL as 
select * FROM internal.T_ADE_REPORT1 t1
union 
select * FROM internal.T_ADE_REPORT2 t2;
*/

SET OUT_PARAM = 1;
SELECT OUT_PARAM;
return ;
SELECT '%', @@error.message;

SET OUT_PARAM = 0;
SELECT OUT_PARAM;
RETURN ;

END;
END;
