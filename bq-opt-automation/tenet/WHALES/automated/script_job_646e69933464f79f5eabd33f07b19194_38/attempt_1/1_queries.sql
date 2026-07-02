# Parent job id: 8c118861-1ae3-439b-b270-2a0af61dd182
# Job id: script_job_646e69933464f79f5eabd33f07b19194_38


# SP details:

select   job_id,   query  
from   `thc-dna-prod-project.region-us-central1`.INFORMATION_SCHEMA.JOBS_BY_PROJECT  
where   job_id = '8c118861-1ae3-439b-b270-2a0af61dd182';


# Original query:

select * from thcdnadevdata.staging.queries_for_optimization 
where job_id = 'script_job_646e69933464f79f5eabd33f07b19194_38';

-- update thcdnadevdata.staging.queries_for_optimization
-- set is_active = true 
-- where job_id = 'script_job_646e69933464f79f5eabd33f07b19194_38';


# Optimized query:

select * from thcdnadevdata.staging.query_ai_optimization_results 
where job_id = 'script_job_646e69933464f79f5eabd33f07b19194_38'
order by created_at desc, updated_at desc; 