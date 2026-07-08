MERGE MEDIBIS_FACT_CE_temp AS T
USING (
  -- Step 1: Pre-filter and de-duplicate the source data in a single pass.
  -- This avoids joining the entire medibis_dim_case table.
  SELECT
    source_system_id,
    case_id,
    total_asc_time,
    case_primary_payment_amount,
    case_unapplied_payment_amount,
    case_copay_payment_amount,
    case_outstanding_bal_amount,
    case_writeoff_amount,
    case_tob_writeoff_amount,
    case_top_writeoff_amount,
    balance_category,
    case_bad_debt_amount,
    implant_cost,
    expected_collections,
    expected_collections_est_ind
  FROM (
    SELECT
      source_system_id,
      case_id,
      total_asc_time,
      case_primary_payment_amount,
      case_unapplied_payment_amount,
      case_copay_payment_amount,
      case_outstanding_bal_amount,
      case_writeoff_amount,
      case_tob_writeoff_amount,
      case_top_writeoff_amount,
      balance_category,
      case_bad_debt_amount,
      implant_cost,
      expected_collections,
      expected_collections_est_ind,
      ROW_NUMBER() OVER (
        PARTITION BY source_system_id, case_id
        ORDER BY
          total_asc_time,
          case_primary_payment_amount,
          case_unapplied_payment_amount,
          case_copay_payment_amount,
          case_outstanding_bal_amount,
          case_writeoff_amount,
          case_tob_writeoff_amount,
          case_top_writeoff_amount,
          balance_category,
          case_bad_debt_amount,
          implant_cost,
          expected_collections,
          expected_collections_est_ind
      ) AS row_num
    FROM `uspidnaproddata.edw_advantx.medibis_dim_case`
    -- Step 2: Push the filter down to the source scan for maximum efficiency.
    WHERE source_system_id = V_source_system
  )
  WHERE row_num = 1
) AS S
ON T.source_system_id = S.source_system_id
  AND T.case_id = S.case_id
  -- Step 3: Keep the original filter on the target table, as required by the MERGE logic.
  AND T.source_system_id = V_source_system
WHEN MATCHED THEN
  UPDATE SET
    total_asc_time = S.total_asc_time,
    case_primary_payment_amount = S.case_primary_payment_amount,
    case_unapplied_payment_amount = S.case_unapplied_payment_amount,
    case_copay_payment_amount = S.case_copay_payment_amount,
    case_outstanding_bal_amount = S.case_outstanding_bal_amount,
    case_writeoff_amount = S.case_writeoff_amount,
    case_tob_writeoff_amount = S.case_tob_writeoff_amount,
    case_top_writeoff_amount = S.case_top_writeoff_amount,
    balance_category = S.balance_category,
    case_bad_debt_amount = S.case_bad_debt_amount,
    implant_cost = S.implant_cost,
    expected_collections = S.expected_collections,
    expected_collections_est_ind = S.expected_collections_est_ind;
