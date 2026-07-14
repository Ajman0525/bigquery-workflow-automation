insert into thcdnaproddata.idm.fact_encounter_modified_anr 
  select PATIENT_ACCOUNT_NBR, FE.FACILITY_CD,PA_TOTAL_PAYMENTS as MODIFIED_ANR 
  from idm.fact_encounter FE join idm.dim_facility DF
  on FE.DIM_FACILITY_SK=DF.DIM_FACILITY_SK

	WHERE FE.DIM_FACILITY_SK IN 
	(
		SELECT DIM_FACILITY_SK FROM thcdnaproddata.idm.dim_facility DF
		WHERE ( (DF.MRKT_ID IN ('M16') AND DF.FACILITY_CD NOT IN ('BMC')) OR DF.FACILITY_CD IN ('HMD','EMC'))

	)
	AND (FE.FACILITY_CD, PATIENT_ACCOUNT_NBR) NOT IN (SELECT (FACILITY_CD, PATIENT_ACCOUNT_NBR) FROM thcdnaproddata.idm.fact_encounter_modified_anr)
  and (LOWER(TRIM(FE.FACILITY_CD)) = LOWER(TRIM(V_FACILITY_CD)))
