# Parent job id: e132b2b7-a023-4b4d-b411-73fd274664ec
# Job id: script_job_fc4316e24223b6d9baa313322f4b47e8_20


# SP details:

select   job_id,   query  
from   `uspi-dna-prod-project.region-us-central1`.INFORMATION_SCHEMA.JOBS_BY_PROJECT  
where   job_id = 'e132b2b7-a023-4b4d-b411-73fd274664ec';


# Original query:

select * from thcdnadevdata.staging.queries_for_optimization 
where job_id = 'script_job_fc4316e24223b6d9baa313322f4b47e8_20';

-- update thcdnadevdata.staging.queries_for_optimization
-- set is_active = true 
-- where job_id = 'script_job_fc4316e24223b6d9baa313322f4b47e8_20';


# Optimized query:

select * from thcdnadevdata.staging.query_ai_optimization_results 
where job_id = 'script_job_fc4316e24223b6d9baa313322f4b47e8_20'
order by created_at desc, updated_at desc; 