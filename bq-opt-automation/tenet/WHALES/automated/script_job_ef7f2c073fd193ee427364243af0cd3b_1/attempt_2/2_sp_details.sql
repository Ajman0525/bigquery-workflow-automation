DECLARE OUT_PARAM INT64 DEFAULT NULL;
CALL `thcdnaproddata.lmrs_idm.sp_rep_daily_performance_detail`(OUT_PARAM);
SELECT OUT_PARAM AS out_status;
