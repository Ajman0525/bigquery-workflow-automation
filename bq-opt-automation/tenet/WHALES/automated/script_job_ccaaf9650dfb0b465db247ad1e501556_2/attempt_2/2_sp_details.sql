DECLARE OUT_PARAM INT64 DEFAULT NULL;
CALL `thcdnaproddata.idm.sp_fact_encounter_guarantor`('SMQ', OUT_PARAM);
SELECT OUT_PARAM AS out_status;
