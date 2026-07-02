CREATE OR REPLACE TEMP TABLE V_TEMP_TABLE AS
        SELECT
          framework_metadata.createhashkey(vw.client_id, vw.source_system, vw.facility_cd, CAST(vw.posting_me AS STRING), V_METRIC_NAME, null, null, null, null, null, null, null, null, null, null, null, null, null, null, null) AS ar_rev_adj_hk,
          vw.dim_facility_hk,
          vw.client_id,
          vw.source_system,
          vw.facility_cd,
          vw.posting_me,
          vw.max_posting_date,
          vw.prior_max_posting_me,
          vw.fiscal_year,
          vw.prior_fiscal_year,
          vw.current_max_year,
          vw.prior_max_year,
          vw.prior_year_max_posting_date,
          vw.posting_month_name,
          vw.current_mtd_posting_days,
          vw.current_fytd_posting_days,
          vw.current_me_posting_days,
          vw.me_fytd_posting_days,
          vw.fytd_posting_days_total,
          vw.max_posting_year,
          vw.max_posting_me,
          vw.quarter,
          vw.quarter_year,
          vw.prior_year_posting_date,
          vw.display,
          vw.tenet_novant,
          V_METRIC_NAME AS metric_key,
          vw.pos_goal AS metric_value
        FROM `cfrdnaproddata3.rcm_mart.vw_detail_consolidated_fact_cash_summary` vw
        WHERE vw.facility_cd = V_FACILITY_CD
          AND vw.posting_me >= V_LAST_EXTRACT_DT
