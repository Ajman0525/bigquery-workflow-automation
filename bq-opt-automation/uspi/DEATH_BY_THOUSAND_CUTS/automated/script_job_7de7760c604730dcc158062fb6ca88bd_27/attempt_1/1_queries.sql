# Parent job id: 3b1e27a3-cd93-4f19-952b-290cb4e170b8
# Job id: script_job_7de7760c604730dcc158062fb6ca88bd_27


# SP details:

select   job_id,   query  
from   `uspi-dna-prod-project.region-us-central1`.INFORMATION_SCHEMA.JOBS_BY_PROJECT  
where   job_id = '3b1e27a3-cd93-4f19-952b-290cb4e170b8';


# Original query:

select * from thcdnadevdata.staging.queries_for_optimization 
where job_id = 'script_job_7de7760c604730dcc158062fb6ca88bd_27';

-- update thcdnadevdata.staging.queries_for_optimization
-- set is_active = true 
-- where job_id = 'script_job_7de7760c604730dcc158062fb6ca88bd_27';


# Optimized query:

select * from thcdnadevdata.staging.query_ai_optimization_results 
where job_id = 'script_job_7de7760c604730dcc158062fb6ca88bd_27'
order by created_at desc, updated_at desc; 