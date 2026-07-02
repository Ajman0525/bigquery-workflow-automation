import argparse
from datetime import datetime
import os
from dotenv import load_dotenv  # pip install python-dotenv
import pyperclip

# Load environment variables from the local .env file
load_dotenv()


def parse_clipboard_to_html_and_sh(output_html_path, output_sh_path, row_arg=None):
    """Takes a copied spreadsheet row from clipboard, generates a Word-ready HTML,

    and a customized shell script using dynamically loaded indices from a .env file.
    """
    try:
        # Determine row string based on the optional argument
        row_display = row_arg if row_arg else "{EDIT ME}"

        # Get text from clipboard
        clipboard_data = pyperclip.paste()

        if not clipboard_data.strip():
            print("Your clipboard is empty! Copy a spreadsheet row first.")
            return

        # Excel/Sheets separates columns by tabs ('\t')
        cells = [cell.strip() for cell in clipboard_data.split("\t")]

        # Helper function to return "null" if the cell is completely empty or out of bounds
        def get_val(env_key):
            env_idx = os.getenv(env_key)
            if env_idx is None:
                return "null"

            index = int(env_idx)
            if index < len(cells):
                val = cells[index]
                return val if val else "null"
            return "null"

        # Mapping indices dynamically from your plain .env configuration
        project_id = get_val("PROJECT_ID")
        entity = get_val("ENTITY")
        owner = get_val("OWNER")
        status = get_val("STATUS")
        job_id = get_val("JOB_ID")
        parent_id = get_val("PARENT_ID")
        frequency = get_val("FREQUENCY")
        sp = get_val("SP")
        metric_name = get_val("METRIC_NAME")
        comments = get_val("COMMENTS")

        # Generate current date & timestamps
        now = datetime.now()
        formatted_date = now.strftime("%d %B %Y")
        last_executed_ts = now.strftime("%d %B %Y %H:%M:%S")

        # --- 1. Build the HTML template ---
        html_template = f"""
        <html>
        <body style="font-family: Calibri, Arial, sans-serif; font-size: 11pt; line-height: 1.5;">
            <b>owner:</b> {owner}<br>
            <b>{formatted_date} | {status}</b><br>
            <b>Row {row_display}</b><br>
            <b>{metric_name}</b><br>
            <b>Project ID:</b> {project_id}<br>
            <b>Entity:</b> {entity}<br>
            <b>Job ID:</b> {job_id}<br>
            <b>Parent ID:</b> {parent_id}<br>
            <b>Frequency:</b> {frequency}<br>
            <b>SP:</b> {sp}<br>
            <b>Comment:</b> {"" if comments == "null" else comments}<br>
            <span style="color: #666666; font-size: 9pt;">Last Generated html: {last_executed_ts}</span>
        </body>
        </html>
        """

        with open(output_html_path, "w", encoding="utf-8") as out_f:
            out_f.write(html_template.strip())

        # --- 2. Build the Shell Script template ---
        # Handle the conditional parent argument line
        if parent_id != "null":
            parent_arg_line = f"    --parent-job-id {parent_id} \\\n"
        else:
            parent_arg_line = ""

        sh_template = f"""# entity: {entity.lower()}
# metric-name: {metric_name}
# parent: {parent_id}
# job_id: {job_id}


python automation.py \\
    --entity {entity.lower()} \\
    --metric-name {metric_name} \\
{parent_arg_line}    --job-id {job_id}


# python automation.py \\
#      --rerun-job-id {job_id}

# python automation.py \\
#      --rerun-job-id-no-workflow {job_id}


# last-generated-sh: {last_executed_ts}
# row: {row_display}
"""

        with open(output_sh_path, "w", encoding="utf-8", newline="\n") as sh_f:
            sh_f.write(sh_template)

        print(
            f"Success! Generated:\n"
            f"  1. Word-ready HTML -> {output_html_path}\n"
            f"  2. Shell Script     -> {output_sh_path}"
        )

    except Exception as e:
        print(f"An error occurred: {e}")


if __name__ == "__main__":
    # Setup CLI argument options
    parser = argparse.ArgumentParser(
        description="Parse clipboard data into HTML and Shell formats using a .env configuration."
    )
    parser.add_argument(
        "--row", type=str, help="Optional row number value to pass into the scripts"
    )
    args = parser.parse_args()

    # Pass the argument cleanly to execution block
    parse_clipboard_to_html_and_sh("documentation.html", "run_single.sh", row_arg=args.row)