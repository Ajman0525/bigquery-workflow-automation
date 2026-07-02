UPDATE `cfrdnadevdata.staging_framework.query_ai_optimization_results`
SET
  optimized_sql = """MERGE `cfrdnaproddata3.ace_ods.rpadta_ptmdesk` T
USING (
  SELECT DISTINCT DTDBID, DTTRGTS
  FROM `cfrdnaproddata3.ace_staging.ptmdesk_dlta`
  WHERE INDICATOR IN ('A', 'C', 'D', 'P')
) S
ON T.DTDBID = S.DTDBID AND T.DTTRGTS = S.DTTRGTS
WHEN MATCHED THEN
  DELETE""",
  updated_at = CURRENT_DATETIME("America/Chicago")
WHERE job_id = '68bb03b7-0ca0-4ca0-a72b-abfb7119ee5b'
  AND created_at = "2026-04-20T18:25:08.565242";
