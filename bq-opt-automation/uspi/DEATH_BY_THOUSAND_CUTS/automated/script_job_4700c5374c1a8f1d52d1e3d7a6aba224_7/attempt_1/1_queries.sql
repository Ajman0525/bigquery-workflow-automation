# Parent job id: c67eab69-dd51-4595-8f3e-ef493b6f2fdf
# Job id: script_job_4700c5374c1a8f1d52d1e3d7a6aba224_7


# SP details:

select   job_id,   query  
from   `uspi-dna-prod-project.region-us-central1`.INFORMATION_SCHEMA.JOBS_BY_PROJECT  
where   job_id = 'c67eab69-dd51-4595-8f3e-ef493b6f2fdf';


# Original query:

select * from thcdnadevdata.staging.queries_for_optimization 
where job_id = 'script_job_4700c5374c1a8f1d52d1e3d7a6aba224_7';

-- update thcdnadevdata.staging.queries_for_optimization
-- set is_active = true 
-- where job_id = 'script_job_4700c5374c1a8f1d52d1e3d7a6aba224_7';


# Optimized query:

select * from thcdnadevdata.staging.query_ai_optimization_results 
where job_id = 'script_job_4700c5374c1a8f1d52d1e3d7a6aba224_7'
order by created_at desc, updated_at desc; 