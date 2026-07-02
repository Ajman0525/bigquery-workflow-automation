# Parent job id: d69aed7d-a3e7-4605-bdff-897839ff629c
# Job id: script_job_cf18afff406bd57425c787edd5338e7d_2


# SP details:

select   job_id,   query  
from   `cfr-dna-prod-project3.region-us-central1`.INFORMATION_SCHEMA.JOBS_BY_PROJECT  
where   job_id = 'd69aed7d-a3e7-4605-bdff-897839ff629c';


# Original query:

select * from cfrdnadevdata.staging_framework.queries_for_optimization 
where job_id = 'script_job_cf18afff406bd57425c787edd5338e7d_2';

-- update cfrdnadevdata.staging_framework.queries_for_optimization
-- set is_active = true 
-- where job_id = 'script_job_cf18afff406bd57425c787edd5338e7d_2';


# Optimized query:

select * from cfrdnadevdata.staging_framework.query_ai_optimization_results 
where job_id = 'script_job_cf18afff406bd57425c787edd5338e7d_2'
order by created_at desc, updated_at desc; 