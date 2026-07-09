# Parent job id: f63982f5-6197-47a9-91b6-908f2411eb0b
# Job id: script_job_ad13bebde601d85cc10549e896505400_31


# SP details:

select   job_id,   query  
from   `uspi-dna-prod-project.region-us-central1`.INFORMATION_SCHEMA.JOBS_BY_PROJECT  
where   job_id = 'f63982f5-6197-47a9-91b6-908f2411eb0b';


# Original query:

select * from thcdnadevdata.staging.queries_for_optimization 
where job_id = 'script_job_ad13bebde601d85cc10549e896505400_31';

-- update thcdnadevdata.staging.queries_for_optimization
-- set is_active = true 
-- where job_id = 'script_job_ad13bebde601d85cc10549e896505400_31';


# Optimized query:

select * from thcdnadevdata.staging.query_ai_optimization_results 
where job_id = 'script_job_ad13bebde601d85cc10549e896505400_31'
order by created_at desc, updated_at desc; 