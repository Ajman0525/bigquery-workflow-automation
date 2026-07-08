# Parent job id: bedac7aa-4a2b-4deb-b62f-6ff17b3999fa
# Job id: script_job_5867f97f0966367f9d8ba756b3f3f715_30


# SP details:

select   job_id,   query  
from   `uspi-dna-prod-project.region-us-central1`.INFORMATION_SCHEMA.JOBS_BY_PROJECT  
where   job_id = 'bedac7aa-4a2b-4deb-b62f-6ff17b3999fa';


# Original query:

select * from thcdnadevdata.staging.queries_for_optimization 
where job_id = 'script_job_5867f97f0966367f9d8ba756b3f3f715_30';

-- update thcdnadevdata.staging.queries_for_optimization
-- set is_active = true 
-- where job_id = 'script_job_5867f97f0966367f9d8ba756b3f3f715_30';


# Optimized query:

select * from thcdnadevdata.staging.query_ai_optimization_results 
where job_id = 'script_job_5867f97f0966367f9d8ba756b3f3f715_30'
order by created_at desc, updated_at desc; 