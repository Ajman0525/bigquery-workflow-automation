DECLARE OUT_PARAM INT64 DEFAULT NULL;
CALL `thcdnaproddata.idm.sp_fact_modified_anr_load`('PMF', OUT_PARAM);
SELECT OUT_PARAM AS out_status;
