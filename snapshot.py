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
# MAIN EXECUTION
# =====================================================================
if __name__ == '__main__':
    
    # Paste your raw DVT block inside these triple quotes
    RAW_DVT_SCRIPT = """
    
    """
    
    print("Processing DVT Script...")
    final_sql = automate_dvt_snapshots(RAW_DVT_SCRIPT)
    
    output_filename = "snapshot_optimized_dvt.sql"
    with open(output_filename, "w") as sql_file:
        sql_file.write(final_sql)
        
    print(f"Success. The formatted snapshot script has been saved to {os.path.abspath(output_filename)}")