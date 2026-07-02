CREATE OR REPLACE PROCEDURE `thcdnadevdata.aci.sp_ade_report_lab_ade_types_optim`(OUT OUT_PARAM INT64)
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
drop table IF EXISTS thcdnadevdata.aci.ade_lab1_lab2_tmp;
drop table IF EXISTS thcdnadevdata.aci.t_ade_fact_med1;
drop table IF EXISTS thcdnadevdata.aci.t_ade_fact_med2;
drop table IF EXISTS thcdnadevdata.aci.t_ade_fact_med3;
drop table IF EXISTS thcdnadevdata.aci.t_ade_report1;
drop table IF EXISTS thcdnadevdata.aci.t_ade_report2;
drop table IF EXISTS thcdnadevdata.aci.t_ade_report_lab_final;


--STEP-1
create table IF NOT EXISTS thcdnadevdata.aci.ade_lab1_lab2_tmp as 
SELECT  t.ADE_TYPE_DK as ADE_TYPE_SK,t.ADE_NAME,t.DRUG_NAME as DRUG_NAME, t.EVENT_NAME, t.EVENT_TYPE, ar.ADE_HSS_ID, ar.LAB_PRIMARY_ORDERABLE, ar.LAB_EVENT_DISPLAY
,'M1' as MED_TYPE
FROM thcdnadevdata.aci.dw_ade_ref ar
inner JOIN thcdnadevdata.aci.dim_ade_type t
 on t.EVENT_NAME = ar.ADE_NAME	
WHERE 
      ar.ACTIVE_IND = 1 and 
	  
	  t.EVENT_TYPE='LABORATORY' 
	  and ar.ADE_HSS_ID is null --Sanal 05162019
UNION DISTINCT
SELECT  t.ADE_TYPE_DK as ADE_TYPE_SK,t.ADE_NAME,t.DRUG_NAME, t.EVENT_NAME as EVENT_NAME, t.EVENT_TYPE, ar.ADE_HSS_ID, ar.MLTM_CATEGORY_NAME, 
        IFNULL(ar.MLTM_DRUG_IDENTIFIER, mr.MLTM_DRUG_IDENTIFIER) as MLTM_DRUG_IDENTIFIER,'M2' as MED_TYPE
FROM thcdnadevdata.aci.dw_ade_ref ar --Looks like its a one time load
inner JOIN thcdnadevdata.aci.dw_mltm_ref mr --(Staging Table for this table are not used in IDM)
  on ar.ADE_HSS_ID = mr.MLTM_HSS_ID and
     ar.MLTM_CATEGORY_NAME = mr.MLTM_CATEGORY_NAME and
	 mr.ACTIVE_IND = 1 
	 inner JOIN thcdnadevdata.aci.dim_ade_type t
 on t.DRUG_NAME = ar.ADE_NAME	
WHERE 
      ar.ACTIVE_IND = 1  
	
	  and t.EVENT_TYPE='LABORATORY' ;



create table IF NOT EXISTS thcdnadevdata.aci.t_ade_fact_med1 CLUSTER BY DIM_ORDER_SK as 
select  t.ADE_TYPE_SK,t.ADE_NAME,t.DRUG_NAME, t.EVENT_NAME, t.EVENT_TYPE,dm.DIM_ORDER_SK,dm.ORDER_DESC,dm.ORDER_NM
			  FROM thcdnadevdata.idm.dim_order dm
				inner JOIN thcdnadevdata.aci.ade_lab1_lab2_tmp t
				    on  upper(t.LAB_PRIMARY_ORDERABLE) = upper(ORDER_NM) 	
				/*inner join IDM..DIM_RESULT_TYPE_ADE rt 
				    --on (upper(RESULT_NM) =upper(LAB_PRIMARY_ORDERABLE) )	   
					 on (upper(RESULT_NM) =upper(LAB_EVENT_DISPLAY) )
					 */
					where t.MED_TYPE='M1' --and ADE_TYPE_SK=4
UNION DISTINCT			
select  t.ADE_TYPE_SK,t.ADE_NAME,t.DRUG_NAME, t.EVENT_NAME, t.EVENT_TYPE,dm.DIM_ORDER_SK,dm.ORDER_DESC,dm.ORDER_NM
			  FROM thcdnadevdata.idm.dim_order dm
				inner JOIN thcdnadevdata.aci.ade_lab1_lab2_tmp t
				    on (upper(t.LAB_EVENT_DISPLAY) = upper(ORDER_NM) --OR LAB_EVENT_DISPLAY is NULL
					)
					where t.MED_TYPE='M1';

					
create table IF NOT EXISTS thcdnadevdata.aci.t_ade_fact_med2 AS
select DIM_ORDER_SK,ADE_TYPE_SK,ADE_NAME,DRUG_NAME,EVENT_NAME,EVENT_TYPE FROM (
select  t.ADE_TYPE_SK,t.ADE_NAME,t.DRUG_NAME, t.EVENT_NAME, t.EVENT_TYPE,DIM_ORDER_SK,ORDER_DESC,ORDER_NM
		,row_number()over (partition by DIM_ORDER_SK order by 1) as rn
FROM thcdnadevdata.aci.ade_lab1_lab2_tmp t	
inner JOIN thcdnadevdata.idm.dim_order dm 
on t.LAB_EVENT_DISPLAY = dm.multum_cd --LAB_EVENT_DISPLAY is MULTUM DRUG IDENTIFIER
where MED_TYPE='M2'
) as foo where rn=1	
;



--STEP:3

CREATE TABLE IF NOT EXISTS thcdnadevdata.aci.t_ade_fact_med3 as 
select fo.patient_account_nbr,fo.facility_cd 
FROM thcdnadevdata.aci.t_ade_fact_med1 t
inner JOIN thcdnadevdata.idm.fact_order fo
on t.dim_order_sk = fo.dim_order_sk 
--WHERE fo.facility_cd='AHD'

INTERSECT DISTINCT
select fo.patient_account_nbr,fo.facility_cd
FROM thcdnadevdata.aci.t_ade_fact_med2 t
inner JOIN thcdnadevdata.idm.fact_order fo
on t.dim_order_sk = fo.dim_order_sk
--WHERE fo.facility_cd='AHD'
;


drop table IF EXISTS thcdnadevdata.aci.t_ade_report_stging_lab1;


CREATE TABLE IF NOT EXISTS thcdnadevdata.aci.t_ade_report_stging_lab1
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
    FROM thcdnadevdata.cerner_ods.cerner_clinical_event_hist
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
    FROM thcdnadevdata.cerner_ods.cerner_orders_hist
    WHERE CATALOG_TYPE_CD = 2513
  ),
  ade_ref AS (
    SELECT
      ade_hss_id,
      ADE_NAME,
      LAB_PRIMARY_ORDERABLE,
      LAB_EVENT_DISPLAY
    FROM thcdnadevdata.aci.dw_ade_ref
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
INNER JOIN thcdnadevdata.aci.dw_code_value AS cv
  ON cv.CODE_VALUE_HSS_ID = s_ce.HEALTH_SYSTEM_SOURCE_ID
  AND cv.CODE_VALUE_SK = s_ce.CATALOG_CD
INNER JOIN thcdnadevdata.aci.dw_code_value AS cv1
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
	  

drop table IF EXISTS thcdnadevdata.aci.t_ade_report_stging_lab2;



CREATE TABLE IF NOT EXISTS thcdnadevdata.aci.t_ade_report_stging_lab2 CLUSTER BY FACILITY_CD AS
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
      replace(UPPER(TRIM(Ltrim(s_eah.ALIAS,'0' ))),'\\\\\\\\','\\') as Patient_Account_Nbr FROM thcdnadevdata.aci.t_ade_report_stging_lab1 s_ce
	  INNER JOIN thcdnadevdata.cerner_ods.cerner_encounter_hist s_eh
      ON s_eh.HEALTH_SYSTEM_SOURCE_ID = s_ce.hss_id and
      s_eh.ENCNTR_ID = s_ce.ENCNTR_ID and
	  
	  s_eh.ACTIVE_IND = 1	
INNER JOIN thcdnadevdata.cerner_ods.cerner_code_value_hist cv2
ON s_eh.HEALTH_SYSTEM_SOURCE_ID = cv2.HEALTH_SYSTEM_SOURCE_ID and
		cv2.CODE_VALUE = s_eh.LOC_FACILITY_CD and
		cv2.CODE_SET = 220 	
INNER JOIN thcdnadevdata.cerner_ods.cerner_encntr_alias_hist s_eah
ON s_eah.HEALTH_SYSTEM_SOURCE_ID = s_eh.HEALTH_SYSTEM_SOURCE_ID and
		s_eah.ENCNTR_ID = s_eh.ENCNTR_ID AND
		s_eah.ACTIVE_IND = 1 and
		s_eah.END_EFFECTIVE_DT_TM > CURRENT_DATETIME('America/Chicago') and
		s_eah.ENCNTR_ALIAS_TYPE_CD = 1077
		) as foo;	

drop table IF EXISTS thcdnadevdata.aci.t_ade_report_stging_final;

CREATE TABLE IF NOT EXISTS thcdnadevdata.aci.t_ade_report_stging_final AS		
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
  FROM thcdnadevdata.aci.t_ade_report_stging_lab2 stg
  LEFT JOIN thcdnadevdata.clinical_ops.dim_facility_prefix fp
  ON stg.FACILITY_CD = fp.FACILITY_CD;

  
drop table IF EXISTS thcdnadevdata.aci.ordering_physician_stg;  


CREATE TABLE IF NOT EXISTS thcdnadevdata.aci.ordering_physician_stg CLUSTER BY hss_id, order_id AS

WITH cerner_physicians AS (
  SELECT DISTINCT
    o.order_id,
    o.health_system_source_id AS hss_id,
    p.name_full_formatted AS ordering_physician
  FROM
    thcdnadevdata.cerner_ods.cerner_orders_hist AS o
  INNER JOIN
    thcdnadevdata.cerner_ods.cerner_order_action_hist AS oa
    ON o.order_id = oa.order_id AND o.health_system_source_id = oa.health_system_source_id
  INNER JOIN
    thcdnadevdata.cerner_ods.cerner_code_value_hist AS cv
    ON oa.action_type_cd = cv.code_value AND oa.health_system_source_id = cv.health_system_source_id
  INNER JOIN
    thcdnadevdata.cerner_ods.cerner_prsnl_hist AS p
    ON p.person_id = oa.order_provider_id
  WHERE
    oa.order_provider_id > 0
    AND oa.action_sequence = 1
    AND cv.display = 'Order'
    -- This EXISTS clause replaces the INNER JOIN to `f`, preventing a row explosion.
    -- The original join's purpose was to filter, which is more efficiently done with EXISTS.
    AND EXISTS (
      SELECT 1
      FROM thcdnadevdata.cerner_ods.cerner_code_value_hist AS f
      WHERE f.health_system_source_id = p.health_system_source_id
        AND f.code_value = p.position_cd
    )
),
dmc_physicians AS (
  SELECT DISTINCT
    o.order_id,
    o.health_system_source_id AS hss_id,
    p.name_full_formatted AS ordering_physician
  FROM
    thcdnadevdata.cerner_ods.dmc_orders_hist AS o
  INNER JOIN
    thcdnadevdata.cerner_ods.dmc_order_action_hist AS oa
    ON o.order_id = oa.order_id AND o.health_system_source_id = oa.health_system_source_id
  INNER JOIN
    thcdnadevdata.cerner_ods.dmc_code_value_hist AS cv
    ON oa.action_type_cd = cv.code_value AND oa.health_system_source_id = cv.health_system_source_id
  INNER JOIN
    thcdnadevdata.cerner_ods.dmc_prsnl_hist AS p
    ON p.person_id = oa.order_provider_id
  WHERE
    oa.order_provider_id > 0
    AND oa.action_sequence = 1
    AND cv.display = 'Order'
    -- This EXISTS clause replaces the INNER JOIN to `f`, preventing a row explosion.
    AND EXISTS (
      SELECT 1
      FROM thcdnadevdata.cerner_ods.dmc_code_value_hist AS f
      WHERE f.health_system_source_id = p.health_system_source_id
        AND f.code_value = p.position_cd
    )
)
SELECT order_id, hss_id, ordering_physician FROM cerner_physicians
UNION ALL
SELECT order_id, hss_id, ordering_physician FROM dmc_physicians;  

drop table IF EXISTS thcdnadevdata.aci.oredr_mnemonic_stg1;  


CREATE TABLE IF NOT EXISTS thcdnadevdata.aci.oredr_mnemonic_stg1 CLUSTER BY order_hss_id,ORDER_ID AS
select * FROM (
select DISTINCT 
       	   s_o.HEALTH_SYSTEM_SOURCE_ID as order_hss_id,
		   s_o.ORDER_ID as ORDER_ID 
	FROM thcdnadevdata.cerner_ods.cerner_orders_hist s_o	
	LEFT JOIN thcdnadevdata.cerner_ods.cerner_order_action_hist s_oa
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
	FROM thcdnadevdata.cerner_ods.dmc_orders_hist s_o	
	LEFT JOIN thcdnadevdata.cerner_ods.dmc_order_action_hist s_oa
      on s_oa.HEALTH_SYSTEM_SOURCE_ID = s_o.HEALTH_SYSTEM_SOURCE_ID and
	     s_oa.ORDER_ID = s_o.ORDER_ID and
	     s_oa.ACTION_TYPE_CD = 2534
	WHERE 
		  --s_o.TEMPLATE_ORDER_FLAG not in (4,2) AND  
	      s_o.ORIG_ORD_AS_FLAG in (0,1,2)	  
	)as foo;
		  
drop table IF EXISTS thcdnadevdata.aci.oredr_mnemonic_stg2; 

create table IF NOT EXISTS thcdnadevdata.aci.oredr_mnemonic_stg2 CLUSTER BY order_hss_id,ORDER_ID as	  
  select * FROM   (
  select s_o.HEALTH_SYSTEM_SOURCE_ID as order_hss_id, 
       s_o.ORDER_ID as ORDER_ID, 
	   s_o.ENCNTR_ID as ENCNTR_ID, 
	   s_o.PERSON_ID as PERSON_ID, 
	   s_o.ordered_as_mnemonic as ordered_as_mnemonic,
	   s_o.ORDER_MNEMONIC as PRIMARY_MNEMONIC,
	   s_o.CLINICAL_DISPLAY_LINE, 
	   s_o.ORDER_DETAIL_DISPLAY_LINE 
FROM thcdnadevdata.aci.oredr_mnemonic_stg1 stg1
inner JOIN thcdnadevdata.cerner_ods.cerner_orders_hist s_o
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
FROM thcdnadevdata.aci.oredr_mnemonic_stg1 stg1
inner JOIN thcdnadevdata.cerner_ods.dmc_orders_hist s_o
   on s_o.HEALTH_SYSTEM_SOURCE_ID = stg1.order_hss_id and
	  s_o.ORDER_ID = stg1.ORDER_id 
	  
	  ) as foo;

--NURSING UNIT 06142019

drop table IF EXISTS thcdnadevdata.aci.ade_med_admin_nurse_unit_tmp;



CREATE TABLE IF NOT EXISTS thcdnadevdata.aci.ade_med_admin_nurse_unit_tmp 
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
  FROM thcdnadevdata.cerner_ods.cerner_clinical_event_hist AS s_ce
  LEFT JOIN thcdnadevdata.cerner_ods.cerner_med_admin_event_hist AS nurse_unit_cd
    ON nurse_unit_cd.health_system_source_id = s_ce.health_system_source_id
    AND nurse_unit_cd.event_id = s_ce.event_id
  LEFT JOIN thcdnadevdata.cerner_ods.cerner_code_value_hist AS nurse_unit_cd1
    ON nurse_unit_cd.health_system_source_id = nurse_unit_cd1.health_system_source_id
    AND nurse_unit_cd.nurse_unit_cd = nurse_unit_cd1.code_value
  WHERE s_ce.VALID_UNTIL_DT_TM > CURRENT_DATETIME('America/Chicago')
    AND s_ce.EVENT_CLASS_CD = 232
    AND s_ce.EVENT_RELTN_CD IN (132, 135)
    AND s_ce.RESULT_STATUS_CD IN (23, 25)
    AND s_ce.event_end_dt_tm >= DATE_TRUNC(DATE_SUB(CURRENT_DATE(), INTERVAL 2 YEAR), YEAR)
    AND EXISTS (
      SELECT 1
      FROM thcdnadevdata.cerner_ods.cerner_orders_hist AS s_o
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
  FROM thcdnadevdata.cerner_ods.dmc_clinical_event_hist AS s_ce
  LEFT JOIN thcdnadevdata.cerner_ods.dmc_med_admin_event_hist AS nurse_unit_cd
    ON nurse_unit_cd.health_system_source_id = s_ce.health_system_source_id
    AND nurse_unit_cd.event_id = s_ce.event_id
  LEFT JOIN thcdnadevdata.cerner_ods.dmc_code_value_hist AS nurse_unit_cd1
    ON nurse_unit_cd.health_system_source_id = nurse_unit_cd1.health_system_source_id
    AND nurse_unit_cd.nurse_unit_cd = nurse_unit_cd1.code_value
  WHERE s_ce.VALID_UNTIL_DT_TM > CURRENT_DATETIME('America/Chicago')
    AND s_ce.EVENT_CLASS_CD = 128
    AND s_ce.EVENT_RELTN_CD IN (72, 74)
    AND s_ce.RESULT_STATUS_CD IN (11, 13)
    AND s_ce.event_end_dt_tm >= DATE_TRUNC(DATE_SUB(CURRENT_DATE(), INTERVAL 2 YEAR), YEAR)
    AND EXISTS (
      SELECT 1
      FROM thcdnadevdata.cerner_ods.dmc_orders_hist AS s_o
      WHERE s_o.HEALTH_SYSTEM_SOURCE_ID = s_ce.HEALTH_SYSTEM_SOURCE_ID
        AND s_o.ORDER_ID = s_ce.ORDER_ID
        AND s_o.CATALOG_TYPE_CD = 1227
    )
)
SELECT * FROM cerner_events
UNION ALL
SELECT * FROM dmc_events;


drop table IF EXISTS thcdnadevdata.aci.cerner_dmc_prsnl_all;


CREATE TABLE IF NOT EXISTS thcdnadevdata.aci.cerner_dmc_prsnl_all AS
select p.HEALTH_SYSTEM_SOURCE_ID,p.PERSON_ID,substr(p.NAME_FIRST,1,100) as PERSONNEL_FIRST_NAME
			   ,substr(p.NAME_LAST,1,100) as PERSONNEL_LAST_NAME
			   ,p.NAME_FULL_FORMATTED as PERSONNEL_FULL_NAME
			   ,p.PHYSICIAN_IND 
			   ,p.ACTIVE_IND 	
			   ,p.POSITION_CD
				
FROM thcdnadevdata.cerner_ods.cerner_prsnl_hist p 	
UNION DISTINCT
select p.HEALTH_SYSTEM_SOURCE_ID,p.PERSON_ID,substr(p.NAME_FIRST,1,100) as PERSONNEL_FIRST_NAME
			   ,substr(p.NAME_LAST,1,100) as PERSONNEL_LAST_NAME
			   ,p.NAME_FULL_FORMATTED as PERSONNEL_FULL_NAME
			   ,p.PHYSICIAN_IND 
			   ,p.ACTIVE_IND 	
			   ,p.POSITION_CD
				
FROM thcdnadevdata.cerner_ods.dmc_prsnl_hist p ;

drop table IF EXISTS thcdnadevdata.aci.cerner_dmc_prsnl_alias_all;


CREATE TABLE IF NOT EXISTS thcdnadevdata.aci.cerner_dmc_prsnl_alias_all AS 
SELECT HEALTH_SYSTEM_SOURCE_ID,
 PERSON_ID,
 Prsnl_ALIAS_TYPE_CD
 FROM thcdnadevdata.cerner_ods.cerner_prsnl_alias_hist  UNION DISTINCT
 SELECT HEALTH_SYSTEM_SOURCE_ID,
 PERSON_ID,
 Prsnl_ALIAS_TYPE_CD
 FROM thcdnadevdata.cerner_ods.dmc_prsnl_alias_hist;	 
 
 drop table IF EXISTS thcdnadevdata.aci.ade_personnel;	  


CREATE TABLE IF NOT EXISTS thcdnadevdata.aci.ade_personnel AS
		SELECT p.HEALTH_SYSTEM_SOURCE_ID as PERSONNEL_HSS_ID,
    		   p.PERSON_ID as PERSONNEL_ID,
			   p. PERSONNEL_FIRST_NAME,
			   p. PERSONNEL_LAST_NAME,
			   p.PERSONNEL_FULL_NAME,
			   p.PHYSICIAN_IND as PHYSICIAN_IND,
			   p.ACTIVE_IND as ACTIVE_IND			
  		  FROM thcdnadevdata.aci.cerner_dmc_prsnl_all p
		  LEFT JOIN thcdnadevdata.aci.dw_code_value cv
			ON p.HEALTH_SYSTEM_SOURCE_ID = cv.CODE_VALUE_HSS_ID and 
			   p.POSITION_CD = cv.CODE_VALUE_SK 
		  left JOIN thcdnadevdata.aci.cerner_dmc_prsnl_alias_all pa1
   			on pa1.HEALTH_SYSTEM_SOURCE_ID = p.HEALTH_SYSTEM_SOURCE_ID and
    		   pa1.PERSON_ID = p.PERSON_ID and
    		   pa1.Prsnl_ALIAS_TYPE_CD = CASE WHEN p.HEALTH_SYSTEM_SOURCE_ID = 80041 THEN 5903754 WHEN p.HEALTH_SYSTEM_SOURCE_ID =  80047 THEN 4544624 WHEN p.HEALTH_SYSTEM_SOURCE_ID =  80048 THEN 131661687 ELSE 4007194 END ;

drop table IF EXISTS thcdnadevdata.aci.ade_admin_nurse_unit_location;


	CREATE TABLE IF NOT EXISTS thcdnadevdata.aci.ade_admin_nurse_unit_location CLUSTER BY hss_id AS 
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
	FROM thcdnadevdata.aci.ade_med_admin_nurse_unit_tmp md
	WHERE md.nursing_unit_location is not null;
	
	
drop table IF EXISTS thcdnadevdata.aci.ade_admin_administering_rn ;

CREATE TABLE IF NOT EXISTS thcdnadevdata.aci.ade_admin_administering_rn AS 
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
	FROM thcdnadevdata.aci.ade_med_admin_nurse_unit_tmp md
	LEFT JOIN thcdnadevdata.aci.ade_personnel p
	ON md.hss_id = p.PERSONNEL_HSS_ID
	and md.PERFORMED_PRSNL_ID = p.PERSONNEL_ID
	WHERE p.PERSONNEL_FULL_NAME is not null
	;
	  

-- drop table IF EXISTS thcdnadevdata.aci.t_ade_report1;

CREATE TABLE IF NOT EXISTS thcdnadevdata.aci.t_ade_report1 as 
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
       ,thcdnadevdata.staging.convert_timezone(fl.PERFORMED_DT_TM_UTC, CAST( case IFNULL(f.DST_IND,'X') WHEN 'X' THEN NULL when 'Y' then 1 else 0 end AS BOOL), f.TM_ZONE_NM) as EVENT_PERFORMED_DT_TM
       , o.DIM_ORDERING_PHYSICIAN_SK as EVENT_PHYSICIAN_DK
       --, pa1.FIRST_NM||' '||pa1.MIDDLE_NM||' '||pa1.LAST_NM  as EVENT_ORDERING_MD
	   , stg.ordering_physician as EVENT_ORDERING_MD 
       , CAST(NULL AS STRING)as EVENT_PERSONNEL_DK--?
       , CAST(NULL AS STRING) as EVENT_ADMINISTRATING_RN--?
	    , 1 as ADE_IND

			,(case when timestamp_diff( cast(cast(current_datetime('America/Chicago') as string) as datetime),cast(cast(p.DATE_OF_BIRTH as string) as datetime) , second )/31536000 <18 then 1 else 0 end) as PEDIATRIC_PATIENT
      --  , (case when DATE_DIFF(CURRENT_DATETIME('America/Chicago'), p.DATE_OF_BIRTH, SECOND )/31536000 < 18 then 1 else 0 end) as PEDIATRIC_PATIENT
       , CURRENT_DATETIME('America/Chicago') as DM_CREATE_DT_TM FROM thcdnadevdata.aci.t_ade_report_stging_final fl
inner join 	(select regexp_extract(unique_id,'[0-9]+',1,2) as order_id,
regexp_extract(unique_id,'[0-9]+',1,1) as hss_id,* FROM thcdnadevdata.idm.fact_order) o
on o.patient_account_nbr = fl.patient_account_nbr
and o.facility_cd = fl.facility_cd 
and o.order_id = CAST(fl.order_id AS STRING)
inner JOIN thcdnadevdata.aci.t_ade_fact_med1 med1
on med1.DIM_ORDER_SK = o.dim_order_sk 
inner JOIN thcdnadevdata.idm.dim_facility f
on f.dim_facility_sk = o.dim_facility_Sk
inner JOIN thcdnadevdata.idm.fact_encounter e
on e.patient_account_nbr = o.patient_account_nbr
and e.facility_cd = o.facility_cd
inner JOIN thcdnadevdata.idm.dim_patient p
on p.dim_patient_sk = e.dim_patient_sk
left JOIN thcdnadevdata.idm.dim_physician pa
on pa.DIM_PHYSICIAN_SK = e.DIM_ATTENDING_PHYSICIAN_SK
left JOIN thcdnadevdata.idm.dim_location d
on d.DIM_LOCATION_SK = o.DIM_ORDER_LOCATION_SK
left JOIN thcdnadevdata.aci.ordering_physician_stg stg
on CAST(stg.hss_id AS STRING) = o.hss_id
and CAST(stg.order_id AS STRING) = o.order_id  ;


drop table IF EXISTS thcdnadevdata.aci.ade_med_admin_tmp;


CREATE TABLE IF NOT EXISTS thcdnadevdata.aci.ade_med_admin_tmp CLUSTER BY fact_order_sk as select ma.* FROM thcdnadevdata.aci.t_ade_fact_med3 fca	   
inner JOIN thcdnadevdata.idm.fact_medications_administration ma
on fca.patient_account_nbr = ma.patient_account_nbr
and fca.facility_cd = ma.facility_cd
--WHERE ma.facility_cd='AHD'
;



CREATE TABLE IF NOT EXISTS thcdnadevdata.aci.t_ade_report2 as
select 
		 med2.ADE_TYPE_SK
       , med2.ADE_NAME as ADE_NAME
       , med2.DRUG_NAME  as DRUG_NAME
       , med2.EVENT_NAME as EVENT_NAME
       , med2.EVENT_TYPE as EVENT_TYPE
	   ,f.FACILITY_CD as FACILITY_DISP
	   ,f.FACILITY_NM_AND_CD as FACILITY_DESC
	   ,f.MRKT_ID as MRKT_ID
	   ,f.MRKT_NM as MRKT_NM
	   ,f.REGN_ID as REGN_ID
	   ,f.REGN_NM as REGN_NM
	   ,cast(NULL as STRING) as DC_DATE_DK --?
	   ,e.DISCHARGE_DT||' '||DISCHARGE_TM as DC_DT_TM
	   ,e.DIM_ENCOUNTER_TYPE_SK as ENCOUNTER_SK
	   ,e.PATIENT_ACCOUNT_NBR as FIN_NBR
	   ,p.MEDICAL_RECORD_NBR as MRN
	   ,e.ADMISSION_DT||' '||e.ADMISSION_TM as ADMIT_DT_TM
	   ,cast(NULL as string) as EVENT_TAG --Need to Identify

	   
-- ,(case when TRIM(substr(staging.age(datetime(md.ADMINISTER_TS), datetime(p.DATE_OF_BIRTH)),1,3)) < cast(3 as string) then 
-- 	           TRIM(substr(staging.age(datetime(md.ADMINISTER_TS), datetime(p.DATE_OF_BIRTH)),instr(staging.age(datetime(md.ADMINISTER_TS), datetime(p.DATE_OF_BIRTH)),'years',1)+6,2)) || ' Months'
-- 		 else TRIM(substr(staging.age(datetime(md.ADMINISTER_TS), datetime(p.DATE_OF_BIRTH)),1,3)) || ' Years' end ) as EVENT_AGE 

-- 			,(case when thcdnadevdata.staging.age_calculation(date(md.ADMINISTER_TS),date(p.DATE_OF_BIRTH)) < 3 thEN																
-- 		MOD((case when DATE_DIFF(md.ADMINISTER_TS,p.DATE_OF_BIRTH,  MONTH) < 0 then 
																																	   
-- (DATE_DIFF(md.ADMINISTER_TS,p.DATE_OF_BIRTH, MONTH) + (IF(EXTRACT(day FROM p.DATE_OF_BIRTH) < EXTRACT(day FROM md.ADMINISTER_TS),1,0)))
-- when DATE_DIFF(md.ADMINISTER_TS,p.DATE_OF_BIRTH, MONTH)=0 Then DATE_DIFF(md.ADMINISTER_TS,p.DATE_OF_BIRTH, MONTH)
-- else (DATE_DIFF(md.ADMINISTER_TS,p.DATE_OF_BIRTH, MONTH) - (IF(EXTRACT(day FROM p.DATE_OF_BIRTH) > EXTRACT(day FROM md.ADMINISTER_TS),1,0))) end),12) || ' Months'
-- 		else thcdnadevdata.staging.age_calculation(date(md.ADMINISTER_TS),date(p.DATE_OF_BIRTH)) || ' Years' end ) as EVENT_AGE	 

  ,(case when staging.age_formatter(datetime(md.ADMINISTER_TS), datetime(p.DATE_OF_BIRTH),'Y') < 3 then 
	             staging.age_formatter(datetime(md.ADMINISTER_TS), datetime(p.DATE_OF_BIRTH) ,'M') || ' Months'
			 else staging.age_formatter(datetime(md.ADMINISTER_TS), datetime(p.DATE_OF_BIRTH),'Y') || ' Years' end ) as EVENT_AGE	
		
		 
 ,pa.FIRST_NM||IFNULL(pa.MIDDLE_NM,' ')||pa.LAST_NM as    attending_physician
	   ,FACT_MEDICATIONS_ADMINISTRATION_SK as DRUG_ADMIN_SK
	   ,md.ADMINISTER_TS as DRUG_ADMIN_DT_TM
	   ,FORMAT("%.*f",2,CAST(round(md.DOSAGE_QUANTITY,2) AS FLOAT64))||' '||mu.MEASURING_UNITS as DRUG_EVENT_TAG
	   ,md.DIM_ADMINISTERING_LOCATION_SK as DRUG_ADMIN_UNIT_SK
	   --,d.LOCATION_CD as DRUG_ADMIN_UNIT
	   ,(case when (d.LOCATION_CD is null or d.LOCATION_CD= 'N/A') then stg2.NURSING_UNIT_LOCATION ELSE f.FACILITY_CD ||'-'||d.LOCATION_CD END) as DRUG_ADMIN_UNIT
	   ,(case when o.TEMPLATE_ORDER_FLG = 0 or o.TEMPLATE_ORDER_FLG is null then o.fact_order_sk end ) as PARENT_ORDER_SK
	   ,o.ORDER_ACTION_TS AS DRUG_ORDER_DT_TM
	   --,med2.ORDER_NM as DRUG_MNEMONIC 
	   --,med2.ORDER_DESC as  DRUG_ORDER_DETAIL
	   ,stg1.ordered_as_mnemonic as DRUG_MNEMONIC
	   ,stg1.CLINICAL_DISPLAY_LINE as  DRUG_ORDER_DETAIL
	   --,pa1.DIM_PHYSICIAN_SK as DRUG_PHYSICIAN_SK
	   --,pa1.FIRST_NM||' '||pa1.MIDDLE_NM||' '||pa1.LAST_NM as DRUG_ORDERING_MD
	   ,stg.ordering_physician as DRUG_ORDERING_MD
	   ,pa2.DIM_PERSONNEL_SK as DRUG_PERSONNEL_SK
	   --,pa2.PERSONNEL_FULL_NAME as DRUG_ADMINISTRATING_RN
	   ,(CASE WHEN pa2.PERSONNEL_FULL_NAME IS NULL OR pa2.PERSONNEL_FULL_NAME ='N/A' 
	     THEN stg3.PERSONNEL_FULL_NAME ELSE pa2.PERSONNEL_FULL_NAME END )as DRUG_ADMINISTRATING_RN
	   ,-99 as EVENT_ADMIN_SK
       , cast(NULL as STRING) as EVENT_ADMIN_DT_TM
       , cast(NULL as STRING) as EVENT_EVENT_TAG --?


       , cast(NULL as STRING) as EVENT_ADMIN_UNIT_DK
       , cast(NULL as STRING) as EVENT_ADMIN_UNIT
       , cast(NULL as STRING) as EVENT_PARENT_ORDER_DK
       , cast(NULL as STRING) as EVENT_ORDER_DT_TM
       , cast(NULL as STRING) as EVENT_MNEMONIC
       , cast(NULL as STRING) as EVENT_ORDER_DETAIL
       , cast(NULL as STRING) as EVENT_RESULT_DK--?
       , cast(NULL as STRING) as EVENT_TEST_RESULT--?
       , cast(NULL as STRING) as RESULT_VALUE
       , cast(NULL as STRING) as RESULT_VALUE_IND--?
       , cast(NULL as STRING) as EVENT_PERFORMED_DT_TM
       , cast(NULL as STRING) as EVENT_PHYSICIAN_DK
       , cast(NULL as STRING) as  EVENT_ORDERING_MD
       , cast(NULL as STRING) as EVENT_PERSONNEL_DK--?
       , cast(NULL as STRING) as EVENT_ADMINISTRATING_RN--?
	   , 1 as ADE_IND
	   ,(case when DATE_DIFF(md.ADMINISTER_TS, p.DATE_OF_BIRTH, SECOND )/31536000 < 18 then 1 else 0 end) as PEDIATRIC_PATIENT
	   ,md.BEGIN_BAG_FLG as BEGIN_BAG_FLG  --added on 06062019
       ,CURRENT_DATETIME('America/Chicago') as DM_CREATE_DT_TM FROM (SELECT regexp_extract(unique_id,'[0-9]+',1,1) as hss_id
,regexp_extract(unique_id,'[0-9]+',1,2) as EVENT_ID
,regexp_extract(unique_id,'[0-9]+',1,3) as CLINICAL_EVENT_ID
,* FROM thcdnadevdata.aci.ade_med_admin_tmp) md
inner join (select regexp_extract(unique_id,'[0-9]+',1,2) as order_id,
regexp_extract(unique_id,'[0-9]+',1,1) as hss_id,* FROM thcdnadevdata.idm.fact_order) o
on o.fact_order_sk = md.fact_order_sk
--and o.patient_account_nbr = md.patient_account_nbr
--and o.facility_cd = md.facility_cd --Commented out on 04172019
inner JOIN thcdnadevdata.aci.t_ade_fact_med2 med2
on med2.DIM_ORDER_SK = o.dim_order_sk 
--inner join idm..DIM_MEDICATIONS dm
--on dm.DIM_MEDICATION_SK = md.DIM_ORDERED_MEDICATION_SK
inner JOIN thcdnadevdata.idm.dim_patient p
on p.dim_patient_sk =md.dim_patient_sk
inner JOIN thcdnadevdata.idm.fact_encounter e
on e.patient_account_nbr = o.patient_account_nbr
and e.facility_cd = o.facility_cd
inner JOIN thcdnadevdata.idm.dim_facility f
on f.dim_facility_sk = md.dim_facility_sk
left JOIN thcdnadevdata.idm.dim_physician pa
on pa.DIM_PHYSICIAN_SK = e.DIM_ATTENDING_PHYSICIAN_SK
left JOIN thcdnadevdata.idm.dim_location d
on d.DIM_LOCATION_SK = md.DIM_ADMINISTERING_LOCATION_SK
left JOIN thcdnadevdata.idm.dim_location d1
on d1.DIM_LOCATION_SK = o.DIM_ORDER_LOCATION_SK
left JOIN thcdnadevdata.aci.ordering_physician_stg stg
on CAST(stg.hss_id AS STRING) = o.hss_id
and CAST(stg.order_id AS STRING) = o.order_id  
left JOIN thcdnadevdata.idm.dim_personnel pa2
on pa2.DIM_PERSONNEL_SK = md.DIM_ADMINISTERING_PERSONNEL_SK
left JOIN thcdnadevdata.idm.dim_measuring_units mu
on md.DIM_DOSAGE_MEASURING_UNITS_SK = mu.DIM_MEASURING_UNITS_SK
left JOIN thcdnadevdata.aci.oredr_mnemonic_stg2 stg1
on CAST(stg1.order_hss_id AS STRING) = o.hss_id
and CAST(stg1.order_id AS STRING) = o.order_id 
left JOIN thcdnadevdata.aci.ade_admin_nurse_unit_location stg2
on CAST(stg2.hss_id AS STRING) = md.hss_id
and CAST(stg2.event_id AS STRING) = md.EVENT_ID
and CAST(stg2.clinical_event_id AS STRING)  = md.CLINICAL_EVENT_ID
left JOIN thcdnadevdata.aci.ade_admin_administering_rn stg3
on CAST(stg3.hss_id AS STRING) = md.hss_id
and CAST(stg3.event_id AS STRING) = md.EVENT_ID
and CAST(stg3.clinical_event_id AS STRING)  = md.CLINICAL_EVENT_ID;


  

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