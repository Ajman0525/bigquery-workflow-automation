# Parent job id: c67eab69-dd51-4595-8f3e-ef493b6f2fdf
# Job id: script_job_5f1f88898722762805765e9ab9cfd51d_2


# SP details:

select   job_id,   query  
from   `uspi-dna-prod-project.region-us-central1`.INFORMATION_SCHEMA.JOBS_BY_PROJECT  
where   job_id = 'c67eab69-dd51-4595-8f3e-ef493b6f2fdf';


# Original query:

select * from thcdnadevdata.staging.queries_for_optimization 
where job_id = 'script_job_5f1f88898722762805765e9ab9cfd51d_2';

-- update thcdnadevdata.staging.queries_for_optimization
-- set is_active = true 
-- where job_id = 'script_job_5f1f88898722762805765e9ab9cfd51d_2';


# Optimized query:

select * from thcdnadevdata.staging.query_ai_optimization_results 
where job_id = 'script_job_5f1f88898722762805765e9ab9cfd51d_2'
order by created_at desc, updated_at desc; 