# Parent job id: 543c9aa2-4422-4c3e-a2d3-b765705dfb79
# Job id: script_job_f7ec14a165d5afb473842fbce22bdfe0_11


# SP details:

select   job_id,   query  
from   `thc-dna-prod-project.region-us-central1`.INFORMATION_SCHEMA.JOBS_BY_PROJECT  
where   job_id = '543c9aa2-4422-4c3e-a2d3-b765705dfb79';


# Original query:

select * from thcdnadevdata.staging.queries_for_optimization 
where job_id = 'script_job_f7ec14a165d5afb473842fbce22bdfe0_11';

-- update thcdnadevdata.staging.queries_for_optimization
-- set is_active = true 
-- where job_id = 'script_job_f7ec14a165d5afb473842fbce22bdfe0_11';


# Optimized query:

select * from thcdnadevdata.staging.query_ai_optimization_results 
where job_id = 'script_job_f7ec14a165d5afb473842fbce22bdfe0_11'
order by created_at desc, updated_at desc; 