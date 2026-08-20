# Parent job id: sample_parent_job_id
# Job id: sample_job_id


# SP details:

select   job_id,   query  
from   `cfr-dna-prod-project3.region-us-central1`.INFORMATION_SCHEMA.JOBS_BY_PROJECT  
where   job_id = 'sample_parent_job_id';


# Original query:

select * from cfrdnadevdata.staging_framework.queries_for_optimization 
where job_id = 'sample_job_id';

-- update cfrdnadevdata.staging_framework.queries_for_optimization
-- set is_active = true 
-- where job_id = 'sample_job_id';


# Optimized query:

select * from cfrdnadevdata.staging_framework.query_ai_optimization_results 
where job_id = 'sample_job_id'
order by created_at desc, updated_at desc; 