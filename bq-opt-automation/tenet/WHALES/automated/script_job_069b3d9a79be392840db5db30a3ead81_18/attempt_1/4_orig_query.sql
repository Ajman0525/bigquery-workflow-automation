CREATE TABLE IF NOT EXISTS thcdnaproddata.aci.ordering_physician_stg CLUSTER BY hss_id,order_id AS
select * FROM (
--CERNER
select distinct o.order_id
,o.health_system_source_id as hss_id
, p.name_full_formatted as ordering_physician
FROM thcdnaproddata.cerner_ods.cerner_orders_hist o
inner JOIN thcdnaproddata.cerner_ods.cerner_order_action_hist oa
on oa.order_id = o.order_id
and oa.health_system_source_id = o.health_system_source_id
and oa.order_provider_id > 0
and oa.action_sequence = 1    
inner JOIN thcdnaproddata.cerner_ods.cerner_code_value_hist cv
on oa.action_type_cd = cv.code_value
and cv.display = 'Order'
and oa.health_system_source_id = cv.health_system_source_id
inner JOIN thcdnaproddata.cerner_ods.cerner_prsnl_hist p
on p.person_id = oa.order_provider_id
inner JOIN thcdnaproddata.cerner_ods.cerner_code_value_hist f 
on p.health_system_source_id = f.health_system_source_id 
and f.code_value = p.position_cd

UNION ALL
---DMC
select distinct o.order_id
,o.health_system_source_id as hss_id
, p.name_full_formatted as ordering_physician
FROM thcdnaproddata.cerner_ods.dmc_orders_hist o
inner JOIN thcdnaproddata.cerner_ods.dmc_order_action_hist oa
on oa.order_id = o.order_id
and oa.health_system_source_id = o.health_system_source_id
and oa.order_provider_id > 0
and oa.action_sequence = 1    
inner JOIN thcdnaproddata.cerner_ods.dmc_code_value_hist cv
on oa.action_type_cd = cv.code_value
and cv.display = 'Order'
and oa.health_system_source_id = cv.health_system_source_id
inner JOIN thcdnaproddata.cerner_ods.dmc_prsnl_hist p
on p.person_id = oa.order_provider_id
inner JOIN thcdnaproddata.cerner_ods.dmc_code_value_hist f 
on p.health_system_source_id = f.health_system_source_id 
and f.code_value = p.position_cd
) as foo
