DECLARE OUT_PARAM INT64 DEFAULT NULL;
CALL `uspidnaproddata.edw_advantx.csp_odsadvantxdw_fact_ce_update`('rswl', OUT_PARAM);
SELECT OUT_PARAM AS out_status;
