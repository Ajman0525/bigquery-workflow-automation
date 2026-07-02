import sqlglot
from sqlglot import exp
import argparse
import os
import sys

def automate_dvt_snapshots(dvt_script: str) -> str:
    """
    Parses a BigQuery DVT script using an AST to safely inject a freeze_time 
    declaration and append FOR SYSTEM_TIME AS OF to all physical tables.
    """
    freeze_decl = "DECLARE freeze_time TIMESTAMP DEFAULT TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 24 HOUR)"
    
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
            if table.args.get("db") or table.args.get("catalog"):
                
                # Prevent duplicate injection if a script is processed twice
                if not table.args.get("when"):
                    
                    table_name_sql = table.sql(dialect="bigquery")
                    snapshot_sql = f"{table_name_sql} FOR SYSTEM_TIME AS OF freeze_time"
                    
                    dummy_node = sqlglot.parse_one(f"SELECT * FROM {snapshot_sql}", read="bigquery")
                    new_table_node = dummy_node.find(exp.Table)
                    
                    table.replace(new_table_node)
                    
        # Append the mutated statement to our output list
        output_sqls.append(stmt.sql(dialect="bigquery", pretty=True) + ";")
        
    # Fallback in case the script had no existing DECLARE statements
    if not declare_injected:
        output_sqls.insert(0, f"{freeze_decl};\n")
        
    return "\n\n".join(output_sqls)

# =====================================================================
# MAIN EXECUTION (Command Line Interface)
# =====================================================================
if __name__ == '__main__':
    # Set up the command line argument parser
    parser = argparse.ArgumentParser(description="Inject BigQuery Time Travel into DVT SQL scripts.")
    
    # Required positional argument: the input file
    parser.add_argument(
        "input_file", 
        help="Path to the original DVT .sql file that needs snapshotting."
    )
    
    # Optional argument: the output file (defaults to snapshot_optimized_dvt.sql)
    parser.add_argument(
        "-o", "--output", 
        default="snapshot_optimized_dvt.sql", 
        help="Path where the formatted snapshot script will be saved."
    )
    
    # Parse the arguments from the terminal
    args = parser.parse_args()
    
    # Verify the input file actually exists before trying to read it
    if not os.path.exists(args.input_file):
        print(f"Error: The file '{args.input_file}' was not found.")
        sys.exit(1)
        
    print(f"Reading DVT Script from: {args.input_file}...")
    
    # Read the contents of the provided SQL file
    with open(args.input_file, "r") as file:
        raw_sql = file.read()
        
    print("Processing AST and injecting Time Travel clauses...")
    final_sql = automate_dvt_snapshots(raw_sql)
    
    # Write the results to the output file
    with open(args.output, "w") as file:
        file.write(final_sql)
        
    print(f"Success! The automated snapshot script has been saved to: {os.path.abspath(args.output)}")