# Parent job id: 786edb19-9f13-485e-944c-9f9ae0d335b5
# Job id: script_job_08b8f0bd70f64bda7da24aff8ad729ac_9


# SP details:

select   job_id,   query  
from   `uspi-dna-prod-project.region-us-central1`.INFORMATION_SCHEMA.JOBS_BY_PROJECT  
where   job_id = '786edb19-9f13-485e-944c-9f9ae0d335b5';


# Original query:

select * from thcdnadevdata.staging.queries_for_optimization 
where job_id = 'script_job_08b8f0bd70f64bda7da24aff8ad729ac_9';

-- update thcdnadevdata.staging.queries_for_optimization
-- set is_active = true 
-- where job_id = 'script_job_08b8f0bd70f64bda7da24aff8ad729ac_9';


# Optimized query:

select * from thcdnadevdata.staging.query_ai_optimization_results 
where job_id = 'script_job_08b8f0bd70f64bda7da24aff8ad729ac_9'
order by created_at desc, updated_at desc; 