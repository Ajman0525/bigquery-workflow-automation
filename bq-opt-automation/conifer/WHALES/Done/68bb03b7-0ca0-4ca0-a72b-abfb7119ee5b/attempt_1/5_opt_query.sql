MERGE `cfrdnaproddata3.ace_ods.rpadta_ptmdesk` T
USING (
  SELECT DISTINCT DTDBID, DTTRGTS
  FROM `cfrdnaproddata3.ace_staging.ptmdesk_dlta`
  WHERE INDICATOR IN ('A', 'C', 'D', 'P')
) S
ON T.DTDBID = S.DTDBID AND T.DTTRGTS = S.DTTRGTS
WHEN MATCHED THEN
  DELETE
