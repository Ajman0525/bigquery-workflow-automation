CREATE TABLE IF NOT EXISTS thcdnaproddata.aci.oredr_mnemonic_stg2
CLUSTER BY order_hss_id, ORDER_ID AS
WITH
  all_orders_hist AS (
    -- Combine the two large history tables first into a single logical view.
    -- This allows the query planner to treat them as one source.
    SELECT
      HEALTH_SYSTEM_SOURCE_ID,
      ORDER_ID,
      ENCNTR_ID,
      PERSON_ID,
      ordered_as_mnemonic,
      ORDER_MNEMONIC,
      CLINICAL_DISPLAY_LINE,
      ORDER_DETAIL_DISPLAY_LINE
    FROM
      thcdnaproddata.cerner_ods.cerner_orders_hist
    UNION ALL
    SELECT
      HEALTH_SYSTEM_SOURCE_ID,
      ORDER_ID,
      ENCNTR_ID,
      PERSON_ID,
      ordered_as_mnemonic,
      ORDER_MNEMONIC,
      CLINICAL_DISPLAY_LINE,
      ORDER_DETAIL_DISPLAY_LINE
    FROM
      thcdnaproddata.cerner_ods.dmc_orders_hist
  )
-- Join the driving table 'stg1' ONCE against the unified history data.
-- This avoids scanning 'stg1' twice and radically simplifies the execution plan.
SELECT
  s_o.HEALTH_SYSTEM_SOURCE_ID AS order_hss_id,
  s_o.ORDER_ID AS ORDER_ID,
  s_o.ENCNTR_ID,
  s_o.PERSON_ID,
  s_o.ordered_as_mnemonic,
  s_o.ORDER_MNEMONIC AS PRIMARY_MNEMONIC,
  s_o.CLINICAL_DISPLAY_LINE,
  s_o.ORDER_DETAIL_DISPLAY_LINE
FROM
  thcdnaproddata.aci.oredr_mnemonic_stg1 AS stg1
  INNER JOIN all_orders_hist AS s_o
    ON s_o.HEALTH_SYSTEM_SOURCE_ID = stg1.order_hss_id
   AND s_o.ORDER_ID = stg1.ORDER_id;
