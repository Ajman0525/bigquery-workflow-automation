CREATE TABLE IF NOT EXISTS thcdnaproddata.aci.t_ade_report2 as
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

-- 			,(case when thcdnaproddata.staging.age_calculation(date(md.ADMINISTER_TS),date(p.DATE_OF_BIRTH)) < 3 thEN																
-- 		MOD((case when DATE_DIFF(md.ADMINISTER_TS,p.DATE_OF_BIRTH,  MONTH) < 0 then 
																																	   
-- (DATE_DIFF(md.ADMINISTER_TS,p.DATE_OF_BIRTH, MONTH) + (IF(EXTRACT(day FROM p.DATE_OF_BIRTH) < EXTRACT(day FROM md.ADMINISTER_TS),1,0)))
-- when DATE_DIFF(md.ADMINISTER_TS,p.DATE_OF_BIRTH, MONTH)=0 Then DATE_DIFF(md.ADMINISTER_TS,p.DATE_OF_BIRTH, MONTH)
-- else (DATE_DIFF(md.ADMINISTER_TS,p.DATE_OF_BIRTH, MONTH) - (IF(EXTRACT(day FROM p.DATE_OF_BIRTH) > EXTRACT(day FROM md.ADMINISTER_TS),1,0))) end),12) || ' Months'
-- 		else thcdnaproddata.staging.age_calculation(date(md.ADMINISTER_TS),date(p.DATE_OF_BIRTH)) || ' Years' end ) as EVENT_AGE	 

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
,* FROM thcdnaproddata.aci.ade_med_admin_tmp) md
inner join (select regexp_extract(unique_id,'[0-9]+',1,2) as order_id,
regexp_extract(unique_id,'[0-9]+',1,1) as hss_id,* FROM thcdnaproddata.idm.fact_order) o
on o.fact_order_sk = md.fact_order_sk
--and o.patient_account_nbr = md.patient_account_nbr
--and o.facility_cd = md.facility_cd --Commented out on 04172019
inner JOIN thcdnaproddata.aci.t_ade_fact_med2 med2
on med2.DIM_ORDER_SK = o.dim_order_sk 
--inner join idm..DIM_MEDICATIONS dm
--on dm.DIM_MEDICATION_SK = md.DIM_ORDERED_MEDICATION_SK
inner JOIN thcdnaproddata.idm.dim_patient p
on p.dim_patient_sk =md.dim_patient_sk
inner JOIN thcdnaproddata.idm.fact_encounter e
on e.patient_account_nbr = o.patient_account_nbr
and e.facility_cd = o.facility_cd
inner JOIN thcdnaproddata.idm.dim_facility f
on f.dim_facility_sk = md.dim_facility_sk
left JOIN thcdnaproddata.idm.dim_physician pa
on pa.DIM_PHYSICIAN_SK = e.DIM_ATTENDING_PHYSICIAN_SK
left JOIN thcdnaproddata.idm.dim_location d
on d.DIM_LOCATION_SK = md.DIM_ADMINISTERING_LOCATION_SK
left JOIN thcdnaproddata.idm.dim_location d1
on d1.DIM_LOCATION_SK = o.DIM_ORDER_LOCATION_SK
left JOIN thcdnaproddata.aci.ordering_physician_stg stg
on CAST(stg.hss_id AS STRING) = o.hss_id
and CAST(stg.order_id AS STRING) = o.order_id  
left JOIN thcdnaproddata.idm.dim_personnel pa2
on pa2.DIM_PERSONNEL_SK = md.DIM_ADMINISTERING_PERSONNEL_SK
left JOIN thcdnaproddata.idm.dim_measuring_units mu
on md.DIM_DOSAGE_MEASURING_UNITS_SK = mu.DIM_MEASURING_UNITS_SK
left JOIN thcdnaproddata.aci.oredr_mnemonic_stg2 stg1
on CAST(stg1.order_hss_id AS STRING) = o.hss_id
and CAST(stg1.order_id AS STRING) = o.order_id 
left JOIN thcdnaproddata.aci.ade_admin_nurse_unit_location stg2
on CAST(stg2.hss_id AS STRING) = md.hss_id
and CAST(stg2.event_id AS STRING) = md.EVENT_ID
and CAST(stg2.clinical_event_id AS STRING)  = md.CLINICAL_EVENT_ID
left JOIN thcdnaproddata.aci.ade_admin_administering_rn stg3
on CAST(stg3.hss_id AS STRING) = md.hss_id
and CAST(stg3.event_id AS STRING) = md.EVENT_ID
and CAST(stg3.clinical_event_id AS STRING)  = md.CLINICAL_EVENT_ID
