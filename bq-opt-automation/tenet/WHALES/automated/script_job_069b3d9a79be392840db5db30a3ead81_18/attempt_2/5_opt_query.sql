CREATE TABLE IF NOT EXISTS thcdnaproddata.aci.ordering_physician_stg CLUSTER BY hss_id, order_id AS
WITH
  cerner_data AS (
    SELECT DISTINCT
      o.order_id,
      o.health_system_source_id AS hss_id,
      p.name_full_formatted AS ordering_physician
    FROM
      thcdnaproddata.cerner_ods.cerner_orders_hist AS o
      INNER JOIN thcdnaproddata.cerner_ods.cerner_order_action_hist AS oa ON o.order_id = oa.order_id AND o.health_system_source_id = oa.health_system_source_id
      INNER JOIN thcdnaproddata.cerner_ods.cerner_prsnl_hist AS p ON p.person_id = oa.order_provider_id
    WHERE
      oa.order_provider_id > 0
      AND oa.action_sequence = 1
      AND EXISTS ( -- Replaced INNER JOIN to cv for filtering
        SELECT 1
        FROM thcdnaproddata.cerner_ods.cerner_code_value_hist AS cv
        WHERE
          cv.code_value = oa.action_type_cd
          AND cv.health_system_source_id = oa.health_system_source_id
          AND cv.display = 'Order'
      )
      AND EXISTS ( -- Replaced INNER JOIN to f for filtering
        SELECT 1
        FROM thcdnaproddata.cerner_ods.cerner_code_value_hist AS f
        WHERE
          f.health_system_source_id = p.health_system_source_id
          AND f.code_value = p.position_cd
      )
  ),
  dmc_data AS (
    SELECT DISTINCT
      o.order_id,
      o.health_system_source_id AS hss_id,
      p.name_full_formatted AS ordering_physician
    FROM
      thcdnaproddata.cerner_ods.dmc_orders_hist AS o
      INNER JOIN thcdnaproddata.cerner_ods.dmc_order_action_hist AS oa ON o.order_id = oa.order_id AND o.health_system_source_id = oa.health_system_source_id
      INNER JOIN thcdnaproddata.cerner_ods.dmc_prsnl_hist AS p ON p.person_id = oa.order_provider_id
    WHERE
      oa.order_provider_id > 0
      AND oa.action_sequence = 1
      AND EXISTS ( -- Replaced INNER JOIN to cv for filtering
        SELECT 1
        FROM thcdnaproddata.cerner_ods.dmc_code_value_hist AS cv
        WHERE
          cv.code_value = oa.action_type_cd
          AND cv.health_system_source_id = oa.health_system_source_id
          AND cv.display = 'Order'
      )
      AND EXISTS ( -- Replaced INNER JOIN to f for filtering
        SELECT 1
        FROM thcdnaproddata.cerner_ods.dmc_code_value_hist AS f
        WHERE
          f.health_system_source_id = p.health_system_source_id
          AND f.code_value = p.position_cd
      )
  )
SELECT
  order_id,
  hss_id,
  ordering_physician
FROM
  cerner_data
UNION ALL
SELECT
  order_id,
  hss_id,
  ordering_physician
FROM
  dmc_data;
