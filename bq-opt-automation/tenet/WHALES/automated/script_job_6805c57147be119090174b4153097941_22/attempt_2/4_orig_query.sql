create table IF NOT EXISTS thcdnaproddata.aci.oredr_mnemonic_stg2 CLUSTER BY order_hss_id,ORDER_ID as	  
  select * FROM   (
  select s_o.HEALTH_SYSTEM_SOURCE_ID as order_hss_id, 
       s_o.ORDER_ID as ORDER_ID, 
	   s_o.ENCNTR_ID as ENCNTR_ID, 
	   s_o.PERSON_ID as PERSON_ID, 
	   s_o.ordered_as_mnemonic as ordered_as_mnemonic,
	   s_o.ORDER_MNEMONIC as PRIMARY_MNEMONIC,
	   s_o.CLINICAL_DISPLAY_LINE, 
	   s_o.ORDER_DETAIL_DISPLAY_LINE 
FROM thcdnaproddata.aci.oredr_mnemonic_stg1 stg1
inner JOIN thcdnaproddata.cerner_ods.cerner_orders_hist s_o
   on s_o.HEALTH_SYSTEM_SOURCE_ID = stg1.order_hss_id and
	  s_o.ORDER_ID = stg1.ORDER_id 
	  
	UNION ALL
	  
	select s_o.HEALTH_SYSTEM_SOURCE_ID as order_hss_id, 
       s_o.ORDER_ID as ORDER_ID, 
	   s_o.ENCNTR_ID as ENCNTR_ID, 
	   s_o.PERSON_ID as PERSON_ID, 
	   s_o.ordered_as_mnemonic as ordered_as_mnemonic,
	   s_o.ORDER_MNEMONIC as PRIMARY_MNEMONIC,
	   s_o.CLINICAL_DISPLAY_LINE, 
	   s_o.ORDER_DETAIL_DISPLAY_LINE 
FROM thcdnaproddata.aci.oredr_mnemonic_stg1 stg1
inner JOIN thcdnaproddata.cerner_ods.dmc_orders_hist s_o
   on s_o.HEALTH_SYSTEM_SOURCE_ID = stg1.order_hss_id and
	  s_o.ORDER_ID = stg1.ORDER_id 
	  
	  ) as foo
