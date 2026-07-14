CREATE TABLE IF NOT EXISTS thcdnaproddata.aci.oredr_mnemonic_stg2
CLUSTER BY order_hss_id, ORDER_ID AS
WITH
  stg1_keys AS (
    SELECT
      order_hss_id,
      ORDER_id
    FROM
      thcdnaproddata.aci.oredr_mnemonic_stg1
  )
SELECT
  s_o.HEALTH_SYSTEM_SOURCE_ID AS order_hss_id,
  s_o.ORDER_ID AS ORDER_ID,
  s_o.ENCNTR_ID AS ENCNTR_ID,
  s_o.PERSON_ID AS PERSON_ID,
  s_o.ordered_as_mnemonic AS ordered_as_mnemonic,
  s_o.ORDER_MNEMONIC AS PRIMARY_MNEMONIC,
  s_o.CLINICAL_DISPLAY_LINE,
  s_o.ORDER_DETAIL_DISPLAY_LINE
FROM
  stg1_keys
INNER JOIN
  thcdnaproddata.cerner_ods.cerner_orders_hist AS s_o
  ON s_o.HEALTH_SYSTEM_SOURCE_ID = stg1_keys.order_hss_id
  AND s_o.ORDER_ID = stg1_keys.ORDER_id
UNION ALL
SELECT
  s_o.HEALTH_SYSTEM_SOURCE_ID AS order_hss_id,
  s_o.ORDER_ID AS ORDER_ID,
  s_o.ENCNTR_ID AS ENCNTR_ID,
  s_o.PERSON_ID AS PERSON_ID,
  s_o.ordered_as_mnemonic AS ordered_as_mnemonic,
  s_o.ORDER_MNEMONIC AS PRIMARY_MNEMONIC,
  s_o.CLINICAL_DISPLAY_LINE,
  s_o.ORDER_DETAIL_DISPLAY_LINE
FROM
  stg1_keys
INNER JOIN
  thcdnaproddata.cerner_ods.dmc_orders_hist AS s_o
  ON s_o.HEALTH_SYSTEM_SOURCE_ID = stg1_keys.order_hss_id
  AND s_o.ORDER_ID = stg1_keys.ORDER_id;
