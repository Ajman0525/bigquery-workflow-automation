INSERT INTO thcdnaproddata.dmor.etempo_discharge_order
    WITH
        base_orders as (
            SELECT ORIG_ORDER_DT_TM,health_system_source_id,ENCNTR_ID,PERSON_ID,ORDER_ID,CATALOG_CD,CATALOG_TYPE_CD
            FROM thcdnaproddata.cerner_ods.dmc_orders_hist
            WHERE
                health_system_source_id=SYSTEM_ID
                AND ACTIVE_IND= 1
        ),
        base_order_detail as (
            SELECT OE_FIELD_DISPLAY_VALUE,health_system_source_id,ORDER_ID,OE_FIELD_ID,OE_FIELD_VALUE
            FROM thcdnaproddata.cerner_ods.dmc_order_detail_hist
            WHERE
                health_system_source_id=SYSTEM_ID
        ),
        base_order_ef as (
            SELECT FIELD_TYPE_FLAG,health_system_source_id,OE_FIELD_ID,DESCRIPTION
            FROM thcdnaproddata.cerner_ods.dmc_order_entry_fields_hist
            WHERE
                health_system_source_id=SYSTEM_ID
                AND DESCRIPTION IN ('Discharge Status')
        ),
        base_order_catalog as (
            SELECT health_system_source_id,CATALOG_CD,CATALOG_TYPE_CD,PRIMARY_MNEMONIC
            FROM thcdnaproddata.cerner_ods.dmc_order_catalog_hist
            WHERE
                health_system_source_id=SYSTEM_ID
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
    FROM
        (
            SELECT
                ENCOUNTER.health_system_source_id,
                ENCOUNTER.ENCNTR_ID,
                ORDERS.ORIG_ORDER_DT_TM,
                CASE (ORDER_ENTRY_FIELDS.FIELD_TYPE_FLAG)
                    WHEN 0 THEN SAFE_CAST(ORDER_DETAIL.OE_FIELD_VALUE AS STRING)
                    WHEN 1 THEN SAFE_CAST(ORDER_DETAIL.OE_FIELD_VALUE AS STRING)
                    WHEN 2 THEN SAFE_CAST(ORDER_DETAIL.OE_FIELD_VALUE AS STRING)
                    WHEN 3 THEN (ORDER_DETAIL.OE_FIELD_DISPLAY_VALUE)
                    WHEN 5 THEN (ORDER_DETAIL.OE_FIELD_DISPLAY_VALUE)
                    WHEN 6 THEN (CV_OD_FIELD_VALUE.DISPLAY)
                    WHEN 7 THEN CASE (ORDER_DETAIL.OE_FIELD_VALUE)
                        WHEN 0 then 'No'
                        else 'Yes'
                    END
                    WHEN 8 THEN (ORDER_DETAIL.OE_FIELD_DISPLAY_VALUE)
                    WHEN 9 THEN (CV_OD_FIELD_VALUE.DISPLAY)
                    WHEN 10 THEN (NOMENCLATURE_OD.SOURCE_STRING)
                    WHEN 11 THEN (ORDER_DETAIL.OE_FIELD_DISPLAY_VALUE)
                    WHEN 12 THEN (CV_OD_FIELD_VALUE.DISPLAY)
                    WHEN 13 THEN (ORDER_DETAIL.OE_FIELD_DISPLAY_VALUE)
                    WHEN 14 THEN (ORDER_DETAIL.OE_FIELD_DISPLAY_VALUE)
                    WHEN 15 THEN SAFE_CAST(ORDER_DETAIL.OE_FIELD_VALUE AS STRING)
                END DC_LOCATION,
                ROW_NUMBER() OVER (
                    PARTITION BY
                        ENCOUNTER.ENCNTR_ID
                    ORDER BY
                        ORIG_ORDER_DT_TM DESC
                ) RN
            FROM
                (SELECT * FROM thcdnaproddata.dmor.etempo_base_encounters where health_system_source_id=SYSTEM_ID) ENCOUNTER
                INNER JOIN base_orders ORDERS ON (
                    ORDERS.ENCNTR_ID = ENCOUNTER.ENCNTR_ID
                    AND ORDERS.PERSON_ID = ENCOUNTER.PERSON_ID
                )
                LEFT JOIN base_order_detail ORDER_DETAIL ON (
                    ORDER_DETAIL.health_system_source_id = ORDERS.health_system_source_id
                    AND ORDER_DETAIL.ORDER_ID = ORDERS.ORDER_ID
                )
                LEFT JOIN base_order_ef ORDER_ENTRY_FIELDS ON (
                    ORDER_DETAIL.health_system_source_id = ORDER_ENTRY_FIELDS.health_system_source_id
                    AND ORDER_ENTRY_FIELDS.OE_FIELD_ID = ORDER_DETAIL.OE_FIELD_ID
                )
                INNER JOIN base_order_catalog ORDER_CATALOG ON (
                    ORDER_CATALOG.health_system_source_id = ORDERS.health_system_source_id
                    AND ORDERS.CATALOG_CD = ORDER_CATALOG.CATALOG_CD
                    AND ORDERS.CATALOG_TYPE_CD = ORDER_CATALOG.CATALOG_TYPE_CD
                )
                LEFT JOIN thcdnaproddata.cerner_ods.dmc_code_value_hist CV_OD_FIELD_VALUE ON (
                    CV_OD_FIELD_VALUE.health_system_source_id = ORDER_DETAIL.health_system_source_id
                    AND CV_OD_FIELD_VALUE.CODE_VALUE = ORDER_DETAIL.OE_FIELD_VALUE
                )
                LEFT JOIN thcdnaproddata.cerner_ods.dmc_nomenclature_hist NOMENCLATURE_OD ON (
                    CV_OD_FIELD_VALUE.health_system_source_id = ORDER_DETAIL.health_system_source_id
                    AND ORDER_DETAIL.OE_FIELD_VALUE = NOMENCLATURE_OD.NOMENCLATURE_ID
                )
        )
    WHERE
        RN = 1
