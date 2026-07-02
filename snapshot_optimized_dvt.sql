DECLARE freeze_time TIMESTAMP DEFAULT TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 24 HOUR);


DECLARE   SYSTEM_ID INT64 DEFAULT 80040 /* ================================================================================================= */ /* Script to create and validate two temporary tables. */ /* Expected Outcome: The discrepancy and duplicate detail SELECTs should return zero rows. */ /* The final SELECT statement should return two summary rows with row_count = 0, confirming that */ /* V_TEMP_TABLE_ORIG and V_TEMP_TABLE_OPT produce identical distinct results and V_TEMP_TABLE_OPT */ /* has no duplicate rows. */ /* ================================================================================================= */ /* 1. Stored Procedure Context */ /* ================================================================================================= */ /* START STORED PROCEDURE CONTEXT */ /* Auto-generated from 2_sp_details.sql and 3_orig_sp.sql. */;

/* END STORED PROCEDURE CONTEXT */
/* ================================================================================================= */
/* 2. Create the Original Temporary Table (V_TEMP_TABLE_ORIG) */
/* ================================================================================================= */
CREATE OR REPLACE TEMPORARY TABLE V_TEMP_TABLE_ORIG AS
WITH base_orders AS (
  SELECT
    ORIG_ORDER_DT_TM,
    health_system_source_id,
    ENCNTR_ID,
    PERSON_ID,
    ORDER_ID,
    CATALOG_CD,
    CATALOG_TYPE_CD
  FROM thcdnadevdata.cerner_ods.dmc_orders_hist FOR SYSTEM_TIME AS OF freeze_time
  WHERE
    health_system_source_id = SYSTEM_ID AND ACTIVE_IND = 1
), base_order_detail AS (
  SELECT
    OE_FIELD_DISPLAY_VALUE,
    health_system_source_id,
    ORDER_ID,
    OE_FIELD_ID,
    OE_FIELD_VALUE
  FROM thcdnadevdata.cerner_ods.dmc_order_detail_hist FOR SYSTEM_TIME AS OF freeze_time
  WHERE
    health_system_source_id = SYSTEM_ID
), base_order_ef AS (
  SELECT
    FIELD_TYPE_FLAG,
    health_system_source_id,
    OE_FIELD_ID,
    DESCRIPTION
  FROM thcdnadevdata.cerner_ods.dmc_order_entry_fields_hist FOR SYSTEM_TIME AS OF freeze_time
  WHERE
    health_system_source_id = SYSTEM_ID AND DESCRIPTION IN ('Discharge Status')
), base_order_catalog AS (
  SELECT
    health_system_source_id,
    CATALOG_CD,
    CATALOG_TYPE_CD,
    PRIMARY_MNEMONIC
  FROM thcdnadevdata.cerner_ods.dmc_order_catalog_hist FOR SYSTEM_TIME AS OF freeze_time
  WHERE
    health_system_source_id = SYSTEM_ID
    AND PRIMARY_MNEMONIC IN (
      'Discharge/Expiration - HVSH',
      'ED Discharge/Expiration',
      'Discharge/Release',
      'Discharge/Release (CHM)',
      'OB/GYN Discharge Patient from OB Recovery',
      'ED Discharge/Release',
      'Discharge Patient.',
      'Discharge/Release - HVSH',
      'Discharge/Release Outpatient in a Bed',
      'Discharge/Expiration'
    )
)
SELECT
  health_system_source_id,
  ENCNTR_ID,
  ORIG_ORDER_DT_TM,
  DC_LOCATION
FROM (
  SELECT
    ENCOUNTER.health_system_source_id,
    ENCOUNTER.ENCNTR_ID,
    ORDERS.ORIG_ORDER_DT_TM,
    CASE (
        ORDER_ENTRY_FIELDS.FIELD_TYPE_FLAG
      )
      WHEN 0
      THEN SAFE_CAST(ORDER_DETAIL.OE_FIELD_VALUE AS STRING)
      WHEN 1
      THEN SAFE_CAST(ORDER_DETAIL.OE_FIELD_VALUE AS STRING)
      WHEN 2
      THEN SAFE_CAST(ORDER_DETAIL.OE_FIELD_VALUE AS STRING)
      WHEN 3
      THEN (
        ORDER_DETAIL.OE_FIELD_DISPLAY_VALUE
      )
      WHEN 5
      THEN (
        ORDER_DETAIL.OE_FIELD_DISPLAY_VALUE
      )
      WHEN 6
      THEN (
        CV_OD_FIELD_VALUE.DISPLAY
      )
      WHEN 7
      THEN CASE (
        ORDER_DETAIL.OE_FIELD_VALUE
      ) WHEN 0 THEN 'No' ELSE 'Yes' END
      WHEN 8
      THEN (
        ORDER_DETAIL.OE_FIELD_DISPLAY_VALUE
      )
      WHEN 9
      THEN (
        CV_OD_FIELD_VALUE.DISPLAY
      )
      WHEN 10
      THEN (
        NOMENCLATURE_OD.SOURCE_STRING
      )
      WHEN 11
      THEN (
        ORDER_DETAIL.OE_FIELD_DISPLAY_VALUE
      )
      WHEN 12
      THEN (
        CV_OD_FIELD_VALUE.DISPLAY
      )
      WHEN 13
      THEN (
        ORDER_DETAIL.OE_FIELD_DISPLAY_VALUE
      )
      WHEN 14
      THEN (
        ORDER_DETAIL.OE_FIELD_DISPLAY_VALUE
      )
      WHEN 15
      THEN SAFE_CAST(ORDER_DETAIL.OE_FIELD_VALUE AS STRING)
    END AS DC_LOCATION,
    ROW_NUMBER() OVER (PARTITION BY ENCOUNTER.ENCNTR_ID ORDER BY ORIG_ORDER_DT_TM DESC) AS RN
  FROM (
    SELECT
      *
    FROM thcdnadevdata.dmor.etempo_base_encounters FOR SYSTEM_TIME AS OF freeze_time
    WHERE
      health_system_source_id = SYSTEM_ID
  ) AS ENCOUNTER
  INNER JOIN base_orders AS ORDERS
    ON (
      ORDERS.ENCNTR_ID = ENCOUNTER.ENCNTR_ID AND ORDERS.PERSON_ID = ENCOUNTER.PERSON_ID
    )
  LEFT JOIN base_order_detail AS ORDER_DETAIL
    ON (
      ORDER_DETAIL.health_system_source_id = ORDERS.health_system_source_id
      AND ORDER_DETAIL.ORDER_ID = ORDERS.ORDER_ID
    )
  LEFT JOIN base_order_ef AS ORDER_ENTRY_FIELDS
    ON (
      ORDER_DETAIL.health_system_source_id = ORDER_ENTRY_FIELDS.health_system_source_id
      AND ORDER_ENTRY_FIELDS.OE_FIELD_ID = ORDER_DETAIL.OE_FIELD_ID
    )
  INNER JOIN base_order_catalog AS ORDER_CATALOG
    ON (
      ORDER_CATALOG.health_system_source_id = ORDERS.health_system_source_id
      AND ORDERS.CATALOG_CD = ORDER_CATALOG.CATALOG_CD
      AND ORDERS.CATALOG_TYPE_CD = ORDER_CATALOG.CATALOG_TYPE_CD
    )
  LEFT JOIN thcdnadevdata.cerner_ods.dmc_code_value_hist AS CV_OD_FIELD_VALUE FOR SYSTEM_TIME AS OF freeze_time
    ON (
      CV_OD_FIELD_VALUE.health_system_source_id = ORDER_DETAIL.health_system_source_id
      AND CV_OD_FIELD_VALUE.CODE_VALUE = ORDER_DETAIL.OE_FIELD_VALUE
    )
  LEFT JOIN thcdnadevdata.cerner_ods.dmc_nomenclature_hist AS NOMENCLATURE_OD FOR SYSTEM_TIME AS OF freeze_time
    ON (
      CV_OD_FIELD_VALUE.health_system_source_id = ORDER_DETAIL.health_system_source_id
      AND ORDER_DETAIL.OE_FIELD_VALUE = NOMENCLATURE_OD.NOMENCLATURE_ID
    )
)
WHERE
  RN = 1;

/* ================================================================================================= */
/* 3. Create the Optimized Temporary Table (V_TEMP_TABLE_OPT) */
/* ================================================================================================= */
CREATE OR REPLACE TEMPORARY TABLE V_TEMP_TABLE_OPT AS
WITH target_orders /* CTE 1: Pre-filter to the specific encounters, orders, and catalog items of interest. */ /* This creates a small, highly-selective set of orders to drive the rest of the query. */ AS (
  SELECT
    enc.health_system_source_id,
    enc.ENCNTR_ID,
    enc.PERSON_ID,
    ord.ORDER_ID,
    ord.ORIG_ORDER_DT_TM,
    ord.CATALOG_CD,
    ord.CATALOG_TYPE_CD
  FROM (
    /* By selecting only needed columns, we reduce bytes processed from this source. */
    SELECT
      health_system_source_id,
      ENCNTR_ID,
      PERSON_ID
    FROM thcdnadevdata.dmor.etempo_base_encounters FOR SYSTEM_TIME AS OF freeze_time
    WHERE
      health_system_source_id = SYSTEM_ID
  ) AS enc
  INNER JOIN thcdnadevdata.cerner_ods.dmc_orders_hist AS ord FOR SYSTEM_TIME AS OF freeze_time
    ON enc.ENCNTR_ID = ord.ENCNTR_ID AND enc.PERSON_ID = ord.PERSON_ID
  INNER JOIN thcdnadevdata.cerner_ods.dmc_order_catalog_hist AS cat FOR SYSTEM_TIME AS OF freeze_time
    ON ord.health_system_source_id = cat.health_system_source_id
    AND ord.CATALOG_CD = cat.CATALOG_CD
    AND ord.CATALOG_TYPE_CD = cat.CATALOG_TYPE_CD
  WHERE
    ord.health_system_source_id = SYSTEM_ID
    AND ord.ACTIVE_IND = 1
    AND cat.health_system_source_id = SYSTEM_ID
    AND cat.PRIMARY_MNEMONIC IN (
      'Discharge/Expiration - HVSH',
      'ED Discharge/Expiration',
      'Discharge/Release',
      'Discharge/Release (CHM)',
      'OB/GYN Discharge Patient from OB Recovery',
      'ED Discharge/Release',
      'Discharge Patient.',
      'Discharge/Release - HVSH',
      'Discharge/Release Outpatient in a Bed',
      'Discharge/Expiration'
    )
), discharge_fields /* CTE 2: Small lookup table for 'Discharge Status' field definitions. */ AS (
  SELECT
    health_system_source_id,
    OE_FIELD_ID,
    FIELD_TYPE_FLAG
  FROM thcdnadevdata.cerner_ods.dmc_order_entry_fields_hist FOR SYSTEM_TIME AS OF freeze_time
  WHERE
    health_system_source_id = SYSTEM_ID AND DESCRIPTION = 'Discharge Status'
)
/* Main query body */
SELECT
  health_system_source_id,
  ENCNTR_ID,
  ORIG_ORDER_DT_TM,
  DC_LOCATION
FROM (
  SELECT
    T_ORDERS.health_system_source_id,
    T_ORDERS.ENCNTR_ID,
    T_ORDERS.ORIG_ORDER_DT_TM,
    CASE DISCH_FIELDS.FIELD_TYPE_FLAG
      WHEN 0
      THEN SAFE_CAST(ORDER_DETAIL.OE_FIELD_VALUE AS STRING)
      WHEN 1
      THEN SAFE_CAST(ORDER_DETAIL.OE_FIELD_VALUE AS STRING)
      WHEN 2
      THEN SAFE_CAST(ORDER_DETAIL.OE_FIELD_VALUE AS STRING)
      WHEN 3
      THEN ORDER_DETAIL.OE_FIELD_DISPLAY_VALUE
      WHEN 5
      THEN ORDER_DETAIL.OE_FIELD_DISPLAY_VALUE
      WHEN 6
      THEN CV.DISPLAY
      WHEN 7
      THEN CASE WHEN ORDER_DETAIL.OE_FIELD_VALUE = 0 THEN 'No' ELSE 'Yes' END
      WHEN 8
      THEN ORDER_DETAIL.OE_FIELD_DISPLAY_VALUE
      WHEN 9
      THEN CV.DISPLAY
      WHEN 10
      THEN NMN.SOURCE_STRING
      WHEN 11
      THEN ORDER_DETAIL.OE_FIELD_DISPLAY_VALUE
      WHEN 12
      THEN CV.DISPLAY
      WHEN 13
      THEN ORDER_DETAIL.OE_FIELD_DISPLAY_VALUE
      WHEN 14
      THEN ORDER_DETAIL.OE_FIELD_DISPLAY_VALUE
      WHEN 15
      THEN SAFE_CAST(ORDER_DETAIL.OE_FIELD_VALUE AS STRING)
    END AS DC_LOCATION,
    ROW_NUMBER() OVER (PARTITION BY T_ORDERS.ENCNTR_ID ORDER BY T_ORDERS.ORIG_ORDER_DT_TM DESC) AS RN
  FROM target_orders AS T_ORDERS
  /* Join to order details using the pre-filtered target_orders set. */
  /* This is the key optimization: we are now joining a small set of ORDER_IDs */
  /* to the massive dmc_order_detail_hist table, allowing for massive scan reduction. */
  LEFT JOIN thcdnadevdata.cerner_ods.dmc_order_detail_hist AS ORDER_DETAIL FOR SYSTEM_TIME AS OF freeze_time
    ON T_ORDERS.health_system_source_id = ORDER_DETAIL.health_system_source_id
    AND T_ORDERS.ORDER_ID = ORDER_DETAIL.ORDER_ID
  /* The rest of the joins are against the (now much smaller) result set. */
  LEFT JOIN discharge_fields AS DISCH_FIELDS
    ON ORDER_DETAIL.health_system_source_id = DISCH_FIELDS.health_system_source_id
    AND ORDER_DETAIL.OE_FIELD_ID = DISCH_FIELDS.OE_FIELD_ID
  LEFT JOIN thcdnadevdata.cerner_ods.dmc_code_value_hist AS CV FOR SYSTEM_TIME AS OF freeze_time
    ON ORDER_DETAIL.health_system_source_id = CV.health_system_source_id
    AND SAFE_CAST(ORDER_DETAIL.OE_FIELD_VALUE AS BIGNUMERIC) = CV.CODE_VALUE
  LEFT JOIN thcdnadevdata.cerner_ods.dmc_nomenclature_hist AS NMN FOR SYSTEM_TIME AS OF freeze_time
    ON SAFE_CAST(ORDER_DETAIL.OE_FIELD_VALUE AS BIGNUMERIC) = NMN.NOMENCLATURE_ID
)
WHERE
  RN = 1;

/* ================================================================================================= */
/* 4. Validation Step: Compare the two tables and check optimized duplicates. */
/* DISCREPANCY counts distinct rows that appear in one table but not the other. */
/* DUPLICATE ROWS counts extra copies of duplicate rows in V_TEMP_TABLE_OPT. */
/* The first two SELECT statements show the actual rows when discrepancies or duplicates exist. */
/* The final SELECT statement shows only the summary counts. */
/* ================================================================================================= */
CREATE OR REPLACE TEMPORARY TABLE V_VALIDATION_DISCREPANCIES AS
(
  SELECT
    'ONLY IN ORIGINAL' AS validation_diff_type,
    *
  FROM V_TEMP_TABLE_ORIG
  EXCEPT DISTINCT
  SELECT
    'ONLY IN ORIGINAL' AS validation_diff_type,
    *
  FROM V_TEMP_TABLE_OPT
)
UNION ALL
(
  SELECT
    'ONLY IN OPTIMIZED' AS validation_diff_type,
    *
  FROM V_TEMP_TABLE_OPT
  EXCEPT DISTINCT
  SELECT
    'ONLY IN OPTIMIZED' AS validation_diff_type,
    *
  FROM V_TEMP_TABLE_ORIG
);

CREATE OR REPLACE TEMPORARY TABLE V_VALIDATION_OPT_DUPLICATES AS
SELECT
  duplicate_row.*
FROM (
  SELECT
    ANY_VALUE(opt) AS duplicate_row
  FROM V_TEMP_TABLE_OPT AS opt
  GROUP BY
    TO_JSON_STRING(opt)
  HAVING
    COUNT(*) > 1
);

/* View discrepancy rows. */
SELECT
  *
FROM V_VALIDATION_DISCREPANCIES;

/* View duplicate rows from the optimized query. */
SELECT
  *
FROM V_VALIDATION_OPT_DUPLICATES;

/* View summary counts. */
SELECT
  'DISCREPANCY' AS validation_check,
  COUNT(*) AS row_count
FROM V_VALIDATION_DISCREPANCIES
UNION ALL
SELECT
  'DUPLICATE ROWS' AS validation_check,
  COALESCE(SUM(row_count - 1), 0) AS row_count
FROM (
  SELECT
    COUNT(*) AS row_count
  FROM V_TEMP_TABLE_OPT AS opt
  GROUP BY
    TO_JSON_STRING(opt)
  HAVING
    COUNT(*) > 1
);