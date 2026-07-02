# BigQuery Optimization Automation Setup

This project generates BigQuery optimization review artifacts from `automation.py`.
Run the commands below from the `bq-opt-automation` folder unless noted otherwise.

## Prerequisites

- Python 3.10 or newer.
- Google Cloud CLI installed and available as `gcloud`.
- Access to the Google Cloud projects, BigQuery tables, routine metadata, and workflow used by the automation.
- A shell that can run Python commands. `run_single.sh` requires Bash, such as Git Bash, WSL, or macOS/Linux shell.

## 1. Install and initialize gcloud

Install the Google Cloud CLI using the official installer for your OS:

https://cloud.google.com/sdk/docs/install

After installation, open a new terminal and verify that `gcloud` is on your `PATH`:

```bash
gcloud version
```

Initialize the CLI and sign in:

```bash
gcloud init
gcloud auth login
gcloud config set project cfrdnadevdata
```

`gcloud init` configures the CLI itself. The Python libraries in `automation.py` use Application Default Credentials, so complete the next section too.

## 2. Configure Application Default Credentials

Create local Application Default Credentials for the Google Python client libraries:

```bash
gcloud auth application-default login
gcloud auth application-default set-quota-project cfrdnadevdata
```

Verify that ADC can mint an access token:

```bash
gcloud auth application-default print-access-token
```

If your team uses service account impersonation or a service account key instead of user ADC, follow your team's approved process and make sure the resulting ADC has the same project access. Do not commit service account keys to this repo.

## 3. Confirm Google Cloud access

By default, `automation.py` uses:

- BigQuery job project: `cfrdnadevdata`
- BigQuery location: `us-central1`
- Workflow project: `cfr-dna-dev-project`
- Workflow location: `us-central1`
- Workflow name: `bq_query_optimisation_workflow`
- Optimization input table: `cfrdnadevdata.staging_framework.queries_for_optimization`
- Optimization result table: `cfrdnadevdata.staging_framework.query_ai_optimization_results`
- Parent job metadata source: `` `cfr-dna-prod-project3.region-us-central1`.INFORMATION_SCHEMA.JOBS_BY_PROJECT ``

Ask a project admin for equivalent permissions if any of these checks fail:

- Submit BigQuery jobs from `cfrdnadevdata`.
- Read the parent job query from `cfr-dna-prod-project3.region-us-central1.INFORMATION_SCHEMA.JOBS_BY_PROJECT`.
- Read routine DDL from the routine project and dataset referenced by the parent job.
- Read and update `cfrdnadevdata.staging_framework.queries_for_optimization`.
- Read `cfrdnadevdata.staging_framework.query_ai_optimization_results`.
- Create and read Workflow executions for `projects/cfr-dna-dev-project/locations/us-central1/workflows/bq_query_optimisation_workflow`.

The BigQuery API should be enabled for `cfrdnadevdata`, and the Workflow Executions API should be enabled for `cfr-dna-dev-project`.

## 4. Install Python dependencies

Create and activate a virtual environment.

Windows PowerShell:

```powershell
python -m venv .venv
.\.venv\Scripts\Activate.ps1
python -m pip install --upgrade pip
python -m pip install -r requirements.txt
```

macOS/Linux/Git Bash:

```bash
python3 -m venv .venv
source .venv/bin/activate
python -m pip install --upgrade pip
python -m pip install -r requirements.txt
```

The dependencies are intentionally small:

- `google-cloud-bigquery` for BigQuery queries and updates.
- `google-auth[requests]` for Application Default Credentials and authenticated Workflow REST calls.
- `openpyxl` for reading `.xlsx` and `.xlsm` config files.

## 5. Run the automation

Replace the entity, metric name, parent job id, and job id in `run_single.sh` and run it.

```bash
bash run_single.sh
```

## Troubleshooting

- `DefaultCredentialsError`: rerun `gcloud auth application-default login`, then verify with `gcloud auth application-default print-access-token`.
- Quota project errors: rerun `gcloud auth application-default set-quota-project cfrdnadevdata`; your account may need `serviceusage.services.use` on the quota project.
- BigQuery `403` errors: confirm access to the job project, prod job metadata source, routine dataset, and staging tables listed above.
- Workflow `403` errors: confirm permission to create and read executions on `bq_query_optimisation_workflow`.
- Missing optimized SQL: check `cfrdnadevdata.staging_framework.query_ai_optimization_results` and the workflow execution logs before rerunning from `--from-step optimized_query` or using `--restart`.
- `run_single.sh` on Windows: run it from Git Bash or WSL, or copy the `python automation.py ...` command into PowerShell.

## References

- Google Cloud CLI install guide: https://cloud.google.com/sdk/docs/install
- Application Default Credentials setup: https://cloud.google.com/docs/authentication/provide-credentials-adc
- `gcloud auth application-default login`: https://cloud.google.com/sdk/gcloud/reference/auth/application-default/login
- `gcloud auth application-default set-quota-project`: https://cloud.google.com/sdk/gcloud/reference/auth/application-default/set-quota-project
