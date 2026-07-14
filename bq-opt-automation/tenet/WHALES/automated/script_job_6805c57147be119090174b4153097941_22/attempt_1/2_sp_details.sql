DECLARE OUT_PARAM INT64 DEFAULT NULL;
CALL `thcdnaproddata.aci.sp_ade_report_lab_ade_types`(OUT_PARAM);
SELECT OUT_PARAM AS out_status;
