import sqlglot
from sqlglot import exp
import unittest
import os

def automate_dvt_snapshots(dvt_script: str) -> str:
    """
    Parses a BigQuery DVT script to inject a freeze_time declaration
    and append FOR SYSTEM_TIME AS OF to all physical tables.
    """
    freeze_decl = "DECLARE freeze_time TIMESTAMP DEFAULT TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 24 HOUR)"
    
    # Parse the raw script into a list of AST statement nodes
    statements = sqlglot.parse(dvt_script, read="bigquery")
    output_sqls = []
    declare_injected = False
    
    for stmt in statements:
        if not stmt:
            continue
            
        # 1. Inject the freeze_time declaration before the first existing DECLARE
        if not declare_injected and stmt.sql(dialect="bigquery").upper().startswith("DECLARE"):
            output_sqls.append(f"{freeze_decl};\n")
            declare_injected = True
            
        # 2. Traverse the AST to find all Table nodes
        for table in stmt.find_all(exp.Table):
            
            # Identify physical tables by checking for database or catalog attributes
            # This safely ignores CTEs like 'base_orders' which lack these attributes
            if table.args.get("db") or table.args.get("catalog"):
                
                # Prevent duplicate injection if a script is processed twice
                if not table.args.get("when"):
                    
                    # Extract the base table SQL and append the time travel clause
                    table_name_sql = table.sql(dialect="bigquery")
                    snapshot_sql = f"{table_name_sql} FOR SYSTEM_TIME AS OF freeze_time"
                    
                    # Parse the new string to create a valid replacement node
                    dummy_node = sqlglot.parse_one(f"SELECT * FROM {snapshot_sql}", read="bigquery")
                    new_table_node = dummy_node.find(exp.Table)
                    
                    # Mutate the AST by replacing the old table node with the new one
                    table.replace(new_table_node)
                    
        # Append the mutated statement to our output list
        # pretty=True standardizes the SQL formatting automatically
        output_sqls.append(stmt.sql(dialect="bigquery", pretty=True) + ";")
        
    # Fallback in case the script had no existing DECLARE statements
    if not declare_injected:
        output_sqls.insert(0, f"{freeze_decl};\n")
        
    return "\n\n".join(output_sqls)

# =====================================================================
# TEST-DRIVEN DEVELOPMENT SUITE
# =====================================================================
class TestDVTSnapshotAutomation(unittest.TestCase):
    
    def test_declare_injection(self):
        sample_sql = "DECLARE SYSTEM_ID INT64 DEFAULT 80040;"
        result = automate_dvt_snapshots(sample_sql)
        self.assertIn("DECLARE freeze_time", result)
        self.assertIn("INTERVAL 24 HOUR", result)
        
    def test_physical_table_mutation(self):
        sample_sql = "SELECT * FROM thcdnadevdata.cerner_ods.dmc_orders_hist WHERE ACTIVE_IND = 1;"
        result = automate_dvt_snapshots(sample_sql)
        self.assertIn("FOR SYSTEM_TIME AS OF freeze_time", result)
        self.assertIn("thcdnadevdata.cerner_ods.dmc_orders_hist", result)
        
    def test_cte_exclusion(self):
        sample_sql = """
        WITH base_orders AS (
            SELECT * FROM thcdnadevdata.cerner_ods.dmc_orders_hist
        )
        SELECT * FROM base_orders;
        """
        result = automate_dvt_snapshots(sample_sql)
        # The physical table inside the CTE should get the snapshot
        self.assertTrue(result.count("FOR SYSTEM_TIME AS OF freeze_time") == 1)
        # The naked CTE call at the bottom should NOT get the snapshot
        self.assertNotIn("base_orders FOR SYSTEM_TIME AS OF", result)

# =====================================================================
# MAIN EXECUTION
# =====================================================================
if __name__ == '__main__':
    # Run the unit tests silently to ensure the AST logic is sound
    unittest.TextTestRunner().run(unittest.TestLoader().loadTestsFromTestCase(TestDVTSnapshotAutomation))
    
    # Paste your raw DVT block inside these triple quotes
    RAW_DVT_SCRIPT = """
    -- =================================================================================================
-- Script to create and validate two temporary tables.
-- Expected Outcome: The discrepancy and duplicate detail SELECTs should return zero rows.
-- The final SELECT statement should return two summary rows with row_count = 0, confirming that
-- V_TEMP_TABLE_ORIG and V_TEMP_TABLE_OPT produce identical distinct results and V_TEMP_TABLE_OPT
-- has no duplicate rows.
-- =================================================================================================
-- 1. Stored Procedure Context
-- =================================================================================================
-- START STORED PROCEDURE CONTEXT
-- Auto-generated from 2_sp_details.sql and 3_orig_sp.sql.

DECLARE SYSTEM_ID INT64 DEFAULT 80040;
-- END STORED PROCEDURE CONTEXT

-- =================================================================================================
-- 2. Create the Original Temporary Table (V_TEMP_TABLE_ORIG)
-- =================================================================================================
CREATE OR REPLACE TEMP TABLE V_TEMP_TABLE_ORIG AS
WITH
        base_orders as (
            SELECT ORIG_ORDER_DT_TM,health_system_source_id,ENCNTR_ID,PERSON_ID,ORDER_ID,CATALOG_CD,CATALOG_TYPE_CD
            FROM thcdnadevdata.cerner_ods.dmc_orders_hist
            WHERE
                health_system_source_id=SYSTEM_ID
                AND ACTIVE_IND= 1
        ),
        base_order_detail as (
            SELECT OE_FIELD_DISPLAY_VALUE,health_system_source_id,ORDER_ID,OE_FIELD_ID,OE_FIELD_VALUE
            FROM thcdnadevdata.cerner_ods.dmc_order_detail_hist
            WHERE
                health_system_source_id=SYSTEM_ID
        ),
        base_order_ef as (
            SELECT FIELD_TYPE_FLAG,health_system_source_id,OE_FIELD_ID,DESCRIPTION
            FROM thcdnadevdata.cerner_ods.dmc_order_entry_fields_hist
            WHERE
                health_system_source_id=SYSTEM_ID
                AND DESCRIPTION IN ('Discharge Status')
        ),
        base_order_catalog as (
            SELECT health_system_source_id,CATALOG_CD,CATALOG_TYPE_CD,PRIMARY_MNEMONIC
            FROM thcdnadevdata.cerner_ods.dmc_order_catalog_hist
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
                (SELECT * FROM thcdnadevdata.dmor.etempo_base_encounters where health_system_source_id=SYSTEM_ID) ENCOUNTER
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
                LEFT JOIN thcdnadevdata.cerner_ods.dmc_code_value_hist CV_OD_FIELD_VALUE ON (
                    CV_OD_FIELD_VALUE.health_system_source_id = ORDER_DETAIL.health_system_source_id
                    AND CV_OD_FIELD_VALUE.CODE_VALUE = ORDER_DETAIL.OE_FIELD_VALUE
                )
                LEFT JOIN thcdnadevdata.cerner_ods.dmc_nomenclature_hist NOMENCLATURE_OD ON (
                    CV_OD_FIELD_VALUE.health_system_source_id = ORDER_DETAIL.health_system_source_id
                    AND ORDER_DETAIL.OE_FIELD_VALUE = NOMENCLATURE_OD.NOMENCLATURE_ID
                )
        )
    WHERE
        RN = 1;

-- =================================================================================================
-- 3. Create the Optimized Temporary Table (V_TEMP_TABLE_OPT)
-- =================================================================================================
CREATE OR REPLACE TEMP TABLE V_TEMP_TABLE_OPT AS
WITH
    -- CTE 1: Pre-filter to the specific encounters, orders, and catalog items of interest.
    -- This creates a small, highly-selective set of orders to drive the rest of the query.
    target_orders AS (
        SELECT
            enc.health_system_source_id,
            enc.ENCNTR_ID,
            enc.PERSON_ID,
            ord.ORDER_ID,
            ord.ORIG_ORDER_DT_TM,
            ord.CATALOG_CD,
            ord.CATALOG_TYPE_CD
        FROM
            -- By selecting only needed columns, we reduce bytes processed from this source.
            (
                SELECT health_system_source_id, ENCNTR_ID, PERSON_ID
                FROM thcdnadevdata.dmor.etempo_base_encounters
                WHERE health_system_source_id = SYSTEM_ID
            ) AS enc
        INNER JOIN
            thcdnadevdata.cerner_ods.dmc_orders_hist AS ord
            ON enc.ENCNTR_ID = ord.ENCNTR_ID AND enc.PERSON_ID = ord.PERSON_ID
        INNER JOIN
            thcdnadevdata.cerner_ods.dmc_order_catalog_hist AS cat
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
    ),
    -- CTE 2: Small lookup table for 'Discharge Status' field definitions.
    discharge_fields AS (
        SELECT health_system_source_id, OE_FIELD_ID, FIELD_TYPE_FLAG
        FROM thcdnadevdata.cerner_ods.dmc_order_entry_fields_hist
        WHERE
            health_system_source_id = SYSTEM_ID
            AND DESCRIPTION = 'Discharge Status'
    )
-- Main query body
SELECT
    health_system_source_id,
    ENCNTR_ID,
    ORIG_ORDER_DT_TM,
    DC_LOCATION
FROM
    (
        SELECT
            T_ORDERS.health_system_source_id,
            T_ORDERS.ENCNTR_ID,
            T_ORDERS.ORIG_ORDER_DT_TM,
            CASE DISCH_FIELDS.FIELD_TYPE_FLAG
                WHEN 0 THEN SAFE_CAST(ORDER_DETAIL.OE_FIELD_VALUE AS STRING)
                WHEN 1 THEN SAFE_CAST(ORDER_DETAIL.OE_FIELD_VALUE AS STRING)
                WHEN 2 THEN SAFE_CAST(ORDER_DETAIL.OE_FIELD_VALUE AS STRING)
                WHEN 3 THEN ORDER_DETAIL.OE_FIELD_DISPLAY_VALUE
                WHEN 5 THEN ORDER_DETAIL.OE_FIELD_DISPLAY_VALUE
                WHEN 6 THEN CV.DISPLAY
                WHEN 7 THEN CASE WHEN ORDER_DETAIL.OE_FIELD_VALUE = 0 THEN 'No' ELSE 'Yes' END
                WHEN 8 THEN ORDER_DETAIL.OE_FIELD_DISPLAY_VALUE
                WHEN 9 THEN CV.DISPLAY
                WHEN 10 THEN NMN.SOURCE_STRING
                WHEN 11 THEN ORDER_DETAIL.OE_FIELD_DISPLAY_VALUE
                WHEN 12 THEN CV.DISPLAY
                WHEN 13 THEN ORDER_DETAIL.OE_FIELD_DISPLAY_VALUE
                WHEN 14 THEN ORDER_DETAIL.OE_FIELD_DISPLAY_VALUE
                WHEN 15 THEN SAFE_CAST(ORDER_DETAIL.OE_FIELD_VALUE AS STRING)
            END AS DC_LOCATION,
            ROW_NUMBER() OVER (
                PARTITION BY T_ORDERS.ENCNTR_ID
                ORDER BY T_ORDERS.ORIG_ORDER_DT_TM DESC
            ) AS RN
        FROM
            target_orders AS T_ORDERS
        -- Join to order details using the pre-filtered target_orders set.
        -- This is the key optimization: we are now joining a small set of ORDER_IDs
        -- to the massive dmc_order_detail_hist table, allowing for massive scan reduction.
        LEFT JOIN
            thcdnadevdata.cerner_ods.dmc_order_detail_hist AS ORDER_DETAIL
            ON T_ORDERS.health_system_source_id = ORDER_DETAIL.health_system_source_id
                AND T_ORDERS.ORDER_ID = ORDER_DETAIL.ORDER_ID
        -- The rest of the joins are against the (now much smaller) result set.
        LEFT JOIN
            discharge_fields AS DISCH_FIELDS
            ON ORDER_DETAIL.health_system_source_id = DISCH_FIELDS.health_system_source_id
                AND ORDER_DETAIL.OE_FIELD_ID = DISCH_FIELDS.OE_FIELD_ID
        LEFT JOIN
            thcdnadevdata.cerner_ods.dmc_code_value_hist AS CV
            -- Explicitly cast to match data types and improve join performance
            ON ORDER_DETAIL.health_system_source_id = CV.health_system_source_id
                AND SAFE_CAST(ORDER_DETAIL.OE_FIELD_VALUE AS BIGNUMERIC) = CV.CODE_VALUE
        LEFT JOIN
            thcdnadevdata.cerner_ods.dmc_nomenclature_hist AS NMN
            -- Explicitly cast to match data types. The original query had a cross-join risk here.
            -- This assumes nomenclature is not tenant-specific and joins only on ID.
            ON SAFE_CAST(ORDER_DETAIL.OE_FIELD_VALUE AS BIGNUMERIC) = NMN.NOMENCLATURE_ID
    )
WHERE
    RN = 1;

-- =================================================================================================
-- 4. Validation Step: Compare the two tables and check optimized duplicates.
-- DISCREPANCY counts distinct rows that appear in one table but not the other.
-- DUPLICATE ROWS counts extra copies of duplicate rows in V_TEMP_TABLE_OPT.
-- The first two SELECT statements show the actual rows when discrepancies or duplicates exist.
-- The final SELECT statement shows only the summary counts.
-- =================================================================================================
CREATE OR REPLACE TEMP TABLE V_VALIDATION_DISCREPANCIES AS
(SELECT 'ONLY IN ORIGINAL' AS validation_diff_type, *
 FROM V_TEMP_TABLE_ORIG
 EXCEPT DISTINCT
 SELECT 'ONLY IN ORIGINAL' AS validation_diff_type, *
 FROM V_TEMP_TABLE_OPT
)
UNION ALL
(SELECT 'ONLY IN OPTIMIZED' AS validation_diff_type, *
 FROM V_TEMP_TABLE_OPT
 EXCEPT DISTINCT
 SELECT 'ONLY IN OPTIMIZED' AS validation_diff_type, *
 FROM V_TEMP_TABLE_ORIG
);

CREATE OR REPLACE TEMP TABLE V_VALIDATION_OPT_DUPLICATES AS
SELECT duplicate_row.*
FROM (
  SELECT ANY_VALUE(opt) AS duplicate_row
  FROM V_TEMP_TABLE_OPT AS opt
  GROUP BY TO_JSON_STRING(opt)
  HAVING COUNT(*) > 1
);

-- View discrepancy rows.
SELECT *
FROM V_VALIDATION_DISCREPANCIES;

-- View duplicate rows from the optimized query.
SELECT *
FROM V_VALIDATION_OPT_DUPLICATES;

-- View summary counts.
SELECT 'DISCREPANCY' AS validation_check, COUNT(*) AS row_count
FROM V_VALIDATION_DISCREPANCIES
UNION ALL
SELECT 'DUPLICATE ROWS' AS validation_check, COALESCE(SUM(row_count - 1), 0) AS row_count
FROM (
  SELECT COUNT(*) AS row_count
  FROM V_TEMP_TABLE_OPT AS opt
  GROUP BY TO_JSON_STRING(opt)
  HAVING COUNT(*) > 1
);
    """
    
    print("Processing DVT Script...")
    final_sql = automate_dvt_snapshots(RAW_DVT_SCRIPT)
    
    output_filename = "snapshot_optimized_dvt.sql"
    with open(output_filename, "w") as sql_file:
        sql_file.write(final_sql)
        
    print(f"Success. The formatted snapshot script has been saved to {os.path.abspath(output_filename)}")