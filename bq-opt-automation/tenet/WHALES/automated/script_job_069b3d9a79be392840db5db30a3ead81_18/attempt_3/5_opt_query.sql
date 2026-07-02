CREATE TABLE IF NOT EXISTS thcdnaproddata.aci.ordering_physician_stg
CLUSTER BY hss_id, order_id AS
WITH cerner_data AS (
  SELECT DISTINCT
    o.order_id,
    o.health_system_source_id AS hss_id,
    p.name_full_formatted AS ordering_physician
  FROM
    `thcdnaproddata.cerner_ods.cerner_orders_hist` AS o
  INNER JOIN
    `thcdnaproddata.cerner_ods.cerner_order_action_hist` AS oa
    ON o.order_id = oa.order_id AND o.health_system_source_id = oa.health_system_source_id
  INNER JOIN
    `thcdnaproddata.cerner_ods.cerner_prsnl_hist` AS p
    ON oa.order_provider_id = p.person_id
  WHERE
    oa.action_sequence = 1
    AND oa.order_provider_id > 0
    -- Replaced INNER JOIN to 'cv' with a more efficient EXISTS subquery to act as a filter
    AND EXISTS (
      SELECT 1
      FROM `thcdnaproddata.cerner_ods.cerner_code_value_hist` AS cv
      WHERE
        cv.code_value = oa.action_type_cd
        AND cv.health_system_source_id = oa.health_system_source_id
        AND cv.display = 'Order'
    )
    -- Replaced filtering INNER JOIN to 'f' with a more efficient EXISTS subquery
    AND EXISTS (
      SELECT 1
      FROM `thcdnaproddata.cerner_ods.cerner_code_value_hist` AS f
      WHERE
        f.code_value = p.position_cd
        AND f.health_system_source_id = p.health_system_source_id
    )
),
dmc_data AS (
  SELECT DISTINCT
    o.order_id,
    o.health_system_source_id AS hss_id,
    p.name_full_formatted AS ordering_physician
  FROM
    `thcdnaproddata.cerner_ods.dmc_orders_hist` AS o
  INNER JOIN
    `thcdnaproddata.cerner_ods.dmc_order_action_hist` AS oa
    ON o.order_id = oa.order_id AND o.health_system_source_id = oa.health_system_source_id
  INNER JOIN
    `thcdnaproddata.cerner_ods.dmc_prsnl_hist` AS p
    ON oa.order_provider_id = p.person_id
  WHERE
    oa.action_sequence = 1
    AND oa.order_provider_id > 0
    -- Replaced INNER JOIN to 'cv' with a more efficient EXISTS subquery to act as a filter
    AND EXISTS (
      SELECT 1
      FROM `thcdnaproddata.cerner_ods.dmc_code_value_hist` AS cv
      WHERE
        cv.code_value = oa.action_type_cd
        AND cv.health_system_source_id = oa.health_system_source_id
        AND cv.display = 'Order'
    )
    -- Replaced filtering INNER JOIN to 'f' with a more efficient EXISTS subquery
    AND EXISTS (
      SELECT 1
      FROM `thcdnaproddata.cerner_ods.dmc_code_value_hist` AS f
      WHERE
        f.code_value = p.position_cd
        AND f.health_system_source_id = p.health_system_source_id
    )
)
SELECT order_id, hss_id, ordering_physician FROM cerner_data
UNION ALL
SELECT order_id, hss_id, ordering_physician FROM dmc_data;
