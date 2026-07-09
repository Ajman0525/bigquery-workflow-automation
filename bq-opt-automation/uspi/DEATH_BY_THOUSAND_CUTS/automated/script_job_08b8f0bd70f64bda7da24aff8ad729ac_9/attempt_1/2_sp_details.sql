DECLARE OUT_PARAM INT64 DEFAULT NULL;
CALL `uspidnaproddata.edw_advantx.csp_odsadvantxdw_fact_sd_update`('scjb', OUT_PARAM);
SELECT OUT_PARAM AS out_status;
