# Parent job id: eb1ea615-2680-4e5a-8fc2-b02f3d4061a5
# Job id: script_job_ef7f2c073fd193ee427364243af0cd3b_1


# SP details:

select   job_id,   query  
from   `thc-dna-prod-project.region-us-central1`.INFORMATION_SCHEMA.JOBS_BY_PROJECT  
where   job_id = 'eb1ea615-2680-4e5a-8fc2-b02f3d4061a5';


# Original query:

select * from thcdnadevdata.staging.queries_for_optimization 
where job_id = 'script_job_ef7f2c073fd193ee427364243af0cd3b_1';

-- update thcdnadevdata.staging.queries_for_optimization
-- set is_active = true 
-- where job_id = 'script_job_ef7f2c073fd193ee427364243af0cd3b_1';


# Optimized query:

select * from thcdnadevdata.staging.query_ai_optimization_results 
where job_id = 'script_job_ef7f2c073fd193ee427364243af0cd3b_1'
order by created_at desc, updated_at desc; 