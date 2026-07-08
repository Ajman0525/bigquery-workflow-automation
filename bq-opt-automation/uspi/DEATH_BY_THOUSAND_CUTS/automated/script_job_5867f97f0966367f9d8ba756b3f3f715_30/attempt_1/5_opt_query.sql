MERGE MEDIBIS_FACT_CE_temp AS T
USING (
  WITH
    -- Join to find all possible payors for each case, filtered by the relevant source system.
    -- The original's LEFT JOIN followed by an INNER JOIN is semantically equivalent to two INNER JOINs.
    -- This step can produce multiple `pers_org_num` rows for each case, causing the join amplification seen in the execution graph.
    all_case_payors AS (
      SELECT
        A.source_system_id,
        A.case_num,
        C.pers_org_num
      FROM
        MEDIBIS_FACT_CE_temp AS A
      INNER JOIN
        `uspidnaproddata.advantx_ods.ad_case_ps_ins` AS B
        ON A.case_num = B.case_num AND A.source_system_id = B.source_system_id
      INNER JOIN
        `uspidnaproddata.advantx_ods.ad_ps_rolehist_ins` AS C
        ON B.pers_org_num_pt = C.pers_org_num_pers_ins
      WHERE
        A.source_system_id = V_source_system -- Predicate from the original MERGE ON clause applied early to the source scan.
        AND C.role_num = 6
    )
  -- For each case, find the single payor that matches the original ROW_NUMBER() logic.
  -- ARRAY_AGG with ORDER BY and LIMIT 1 is an efficient way to perform a top-1-per-group selection.
  -- This avoids shuffling all the amplified rows from the join above, drastically reducing shuffle bytes and compute.
  SELECT
    source_system_id,
    case_num,
    (ARRAY_AGG(
      CAST(IFNULL(pers_org_num, -1) AS STRING)
      ORDER BY IFNULL(pers_org_num, -1) ASC
      LIMIT 1
    )[OFFSET(0)]) AS pers_org_num
  FROM
    all_case_payors
  GROUP BY
    source_system_id,
    case_num
) AS S
ON
  T.source_system_id = S.source_system_id
  AND T.case_num = S.case_num
  AND T.source_system_id = V_source_system -- This predicate on the target table is essential for the MERGE operation's performance and correctness.
WHEN MATCHED THEN
  UPDATE SET payor_code = S.pers_org_num;
