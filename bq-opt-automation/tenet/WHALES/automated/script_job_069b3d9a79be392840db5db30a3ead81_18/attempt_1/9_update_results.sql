UPDATE `thcdnadevdata.staging.query_ai_optimization_results`
SET
  optimized_sql = """CREATE TABLE IF NOT EXISTS thcdnaproddata.aci.ordering_physician_stg CLUSTER BY hss_id, order_id AS

WITH cerner_physicians AS (
  SELECT DISTINCT
    o.order_id,
    o.health_system_source_id AS hss_id,
    p.name_full_formatted AS ordering_physician
  FROM
    thcdnaproddata.cerner_ods.cerner_orders_hist AS o
  INNER JOIN
    thcdnaproddata.cerner_ods.cerner_order_action_hist AS oa
    ON o.order_id = oa.order_id AND o.health_system_source_id = oa.health_system_source_id
  INNER JOIN
    thcdnaproddata.cerner_ods.cerner_code_value_hist AS cv
    ON oa.action_type_cd = cv.code_value AND oa.health_system_source_id = cv.health_system_source_id
  INNER JOIN
    thcdnaproddata.cerner_ods.cerner_prsnl_hist AS p
    ON p.person_id = oa.order_provider_id
  WHERE
    oa.order_provider_id > 0
    AND oa.action_sequence = 1
    AND cv.display = 'Order'
    -- This EXISTS clause replaces the INNER JOIN to `f`, preventing a row explosion.
    -- The original join's purpose was to filter, which is more efficiently done with EXISTS.
    AND EXISTS (
      SELECT 1
      FROM thcdnaproddata.cerner_ods.cerner_code_value_hist AS f
      WHERE f.health_system_source_id = p.health_system_source_id
        AND f.code_value = p.position_cd
    )
),
dmc_physicians AS (
  SELECT DISTINCT
    o.order_id,
    o.health_system_source_id AS hss_id,
    p.name_full_formatted AS ordering_physician
  FROM
    thcdnaproddata.cerner_ods.dmc_orders_hist AS o
  INNER JOIN
    thcdnaproddata.cerner_ods.dmc_order_action_hist AS oa
    ON o.order_id = oa.order_id AND o.health_system_source_id = oa.health_system_source_id
  INNER JOIN
    thcdnaproddata.cerner_ods.dmc_code_value_hist AS cv
    ON oa.action_type_cd = cv.code_value AND oa.health_system_source_id = cv.health_system_source_id
  INNER JOIN
    thcdnaproddata.cerner_ods.dmc_prsnl_hist AS p
    ON p.person_id = oa.order_provider_id
  WHERE
    oa.order_provider_id > 0
    AND oa.action_sequence = 1
    AND cv.display = 'Order'
    -- This EXISTS clause replaces the INNER JOIN to `f`, preventing a row explosion.
    AND EXISTS (
      SELECT 1
      FROM thcdnaproddata.cerner_ods.dmc_code_value_hist AS f
      WHERE f.health_system_source_id = p.health_system_source_id
        AND f.code_value = p.position_cd
    )
)
SELECT order_id, hss_id, ordering_physician FROM cerner_physicians
UNION ALL
SELECT order_id, hss_id, ordering_physician FROM dmc_physicians;""",
  updated_at = CURRENT_DATETIME("America/Chicago")
WHERE job_id = 'script_job_069b3d9a79be392840db5db30a3ead81_18'
  AND created_at = "2026-06-26T11:56:49.606583";
