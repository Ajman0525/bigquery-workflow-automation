# Parent job id: a61d631c-fec4-4187-afed-100e29b18260
# Job id: script_job_ccaaf9650dfb0b465db247ad1e501556_2


# SP details:

select   job_id,   query  
from   `thc-dna-prod-project.region-us-central1`.INFORMATION_SCHEMA.JOBS_BY_PROJECT  
where   job_id = 'a61d631c-fec4-4187-afed-100e29b18260';


# Original query:

select * from thcdnadevdata.staging.queries_for_optimization 
where job_id = 'script_job_ccaaf9650dfb0b465db247ad1e501556_2';

-- update thcdnadevdata.staging.queries_for_optimization
-- set is_active = true 
-- where job_id = 'script_job_ccaaf9650dfb0b465db247ad1e501556_2';


# Optimized query:

select * from thcdnadevdata.staging.query_ai_optimization_results 
where job_id = 'script_job_ccaaf9650dfb0b465db247ad1e501556_2'
order by created_at desc, updated_at desc; 