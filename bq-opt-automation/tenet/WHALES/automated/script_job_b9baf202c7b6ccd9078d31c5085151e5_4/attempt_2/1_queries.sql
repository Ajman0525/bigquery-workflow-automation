# Parent job id: a668c4f5-dcb8-46e2-9091-6b1df3a0e548
# Job id: script_job_b9baf202c7b6ccd9078d31c5085151e5_4


# SP details:

select   job_id,   query  
from   `thc-dna-prod-project.region-us-central1`.INFORMATION_SCHEMA.JOBS_BY_PROJECT  
where   job_id = 'a668c4f5-dcb8-46e2-9091-6b1df3a0e548';


# Original query:

select * from thcdnadevdata.staging.queries_for_optimization 
where job_id = 'script_job_b9baf202c7b6ccd9078d31c5085151e5_4';

-- update thcdnadevdata.staging.queries_for_optimization
-- set is_active = true 
-- where job_id = 'script_job_b9baf202c7b6ccd9078d31c5085151e5_4';


# Optimized query:

select * from thcdnadevdata.staging.query_ai_optimization_results 
where job_id = 'script_job_b9baf202c7b6ccd9078d31c5085151e5_4'
order by created_at desc, updated_at desc; 