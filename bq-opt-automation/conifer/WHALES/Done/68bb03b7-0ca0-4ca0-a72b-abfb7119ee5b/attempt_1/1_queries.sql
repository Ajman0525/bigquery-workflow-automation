# Parent job id: 
# Job id: 68bb03b7-0ca0-4ca0-a72b-abfb7119ee5b


# SP details:

# No parent_job_id provided; this is a standalone query.

# Original query:

select * from cfrdnadevdata.staging_framework.queries_for_optimization 
where job_id = '68bb03b7-0ca0-4ca0-a72b-abfb7119ee5b';

-- update cfrdnadevdata.staging_framework.queries_for_optimization
-- set is_active = true 
-- where job_id = '68bb03b7-0ca0-4ca0-a72b-abfb7119ee5b';


# Optimized query:

select * from cfrdnadevdata.staging_framework.query_ai_optimization_results 
where job_id = '68bb03b7-0ca0-4ca0-a72b-abfb7119ee5b'
order by created_at desc, updated_at desc; 