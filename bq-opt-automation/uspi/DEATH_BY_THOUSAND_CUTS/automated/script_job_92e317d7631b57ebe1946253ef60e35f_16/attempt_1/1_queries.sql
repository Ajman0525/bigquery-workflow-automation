# Parent job id: eb9adb06-b5d0-454a-a202-59599ef12eae
# Job id: script_job_92e317d7631b57ebe1946253ef60e35f_16


# SP details:

select   job_id,   query  
from   `uspi-dna-prod-project.region-us-central1`.INFORMATION_SCHEMA.JOBS_BY_PROJECT  
where   job_id = 'eb9adb06-b5d0-454a-a202-59599ef12eae';


# Original query:

select * from thcdnadevdata.staging.queries_for_optimization 
where job_id = 'script_job_92e317d7631b57ebe1946253ef60e35f_16';

-- update thcdnadevdata.staging.queries_for_optimization
-- set is_active = true 
-- where job_id = 'script_job_92e317d7631b57ebe1946253ef60e35f_16';


# Optimized query:

select * from thcdnadevdata.staging.query_ai_optimization_results 
where job_id = 'script_job_92e317d7631b57ebe1946253ef60e35f_16'
order by created_at desc, updated_at desc; 