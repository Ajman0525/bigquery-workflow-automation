# Parent job id: 3b1e27a3-cd93-4f19-952b-290cb4e170b8
# Job id: script_job_65748ecb199f86afda59948e33c66154_23


# SP details:

select   job_id,   query  
from   `uspi-dna-prod-project.region-us-central1`.INFORMATION_SCHEMA.JOBS_BY_PROJECT  
where   job_id = '3b1e27a3-cd93-4f19-952b-290cb4e170b8';


# Original query:

select * from thcdnadevdata.staging.queries_for_optimization 
where job_id = 'script_job_65748ecb199f86afda59948e33c66154_23';

-- update thcdnadevdata.staging.queries_for_optimization
-- set is_active = true 
-- where job_id = 'script_job_65748ecb199f86afda59948e33c66154_23';


# Optimized query:

select * from thcdnadevdata.staging.query_ai_optimization_results 
where job_id = 'script_job_65748ecb199f86afda59948e33c66154_23'
order by created_at desc, updated_at desc; 