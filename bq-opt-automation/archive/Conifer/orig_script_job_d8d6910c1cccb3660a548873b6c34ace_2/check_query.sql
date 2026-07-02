-- Optimized query:
 
SELECT *
FROM cfrdnadevdata.staging_framework.query_ai_optimization_results
WHERE job_id = 'script_job_d8d6910c1cccb3660a548873b6c34ace_2';
 
-- Original:
 
Select * from cfrdnadevdata.staging_framework.queries_for_optimization 
where job_id='script_job_d8d6910c1cccb3660a548873b6c34ace_2';
 
-- SP:
 
SELECT job_id, query
FROM
  `cfr-dna-prod-project3.region-us-central1`.INFORMATION_SCHEMA.JOBS_BY_PROJECT
WHERE job_id = 'airflow_ace_job_qamecs106_dag_trigger_process_dag_sp_ace_job_qamecs106_stored_procedure_9876808_run_stored_procedure_process_2026_04_20T12_02_58_633835_00_00_50571351fa07dfd1c53dae6e824c59ea';