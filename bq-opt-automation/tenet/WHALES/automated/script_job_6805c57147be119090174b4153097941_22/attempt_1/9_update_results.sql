UPDATE `thcdnadevdata.staging.query_ai_optimization_results`
SET
  optimized_sql = """CREATE TABLE IF NOT EXISTS thcdnaproddata.aci.oredr_mnemonic_stg2
CLUSTER BY order_hss_id, ORDER_ID AS
WITH all_orders_history AS (
    -- Combine the two history tables first to avoid multiple scans of the joining table
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
-- Join the combined history with the staging table once
SELECT
    s_o.HEALTH_SYSTEM_SOURCE_ID AS order_hss_id,
    s_o.ORDER_ID,
    s_o.ENCNTR_ID,
    s_o.PERSON_ID,
    s_o.ordered_as_mnemonic,
    s_o.ORDER_MNEMONIC AS PRIMARY_MNEMONIC,
    s_o.CLINICAL_DISPLAY_LINE,
    s_o.ORDER_DETAIL_DISPLAY_LINE
FROM
    thcdnaproddata.aci.oredr_mnemonic_stg1 AS stg1
INNER JOIN
    all_orders_history AS s_o
    ON stg1.order_hss_id = s_o.HEALTH_SYSTEM_SOURCE_ID
   AND stg1.ORDER_id = s_o.ORDER_ID;""",
  updated_at = CURRENT_DATETIME("America/Chicago")
WHERE job_id = 'script_job_6805c57147be119090174b4153097941_22'
  AND created_at = "2026-06-26T10:42:07.033115";
