DECLARE OUT_PARAM INT64 DEFAULT NULL;
CALL `thcdnaproddata.lmrs_ods.sp_lmrsrgpp_sum`(OUT_PARAM);
SELECT OUT_PARAM AS out_status;
