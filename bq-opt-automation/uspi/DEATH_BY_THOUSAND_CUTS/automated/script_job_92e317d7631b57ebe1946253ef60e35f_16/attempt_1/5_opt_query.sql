INSERT INTO PRIMARY_PROCEDURE_ce_temp (
    source_system_id,
    case_num,
    procfee_num,
    procedure_code,
    visittype_num,
    visit_type_code,
    bill_period_num
)
WITH AggregatedData AS (
    -- This CTE performs all joins, filtering, and aggregation.
    -- By applying the V_source_system filter here, we ensure all subsequent operations
    -- are performed on the smallest possible dataset.
    SELECT
        A.source_system_id,
        B.case_num,
        B.procfee_num,
        E.quick_code AS procedure_code,
        I.num AS visittype_num,
        I.quick_code AS visit_type_code,
        MIN(A.bill_period_num) AS bill_period_num
    FROM temp_ar_billtrans AS A
    INNER JOIN ar_billtrans_charge_ce_temp AS B
        ON A.source_system_id = B.source_system_id
        AND A.bill_trans_num = B.bill_trans_num
    INNER JOIN `uspidnaproddata.advantx_ods.ar_billing_period` AS C
        ON A.source_system_id = C.source_system_id
        AND A.bill_period_num = C.num
    INNER JOIN `uspidnaproddata.advantx_ods.ut_proc_fee` AS D
        ON B.source_system_id = D.source_system_id
        AND B.procfee_num = D.num
    INNER JOIN `uspidnaproddata.advantx_ods.ut_proc` AS E
        ON D.source_system_id = E.source_system_id
        AND D.proc_num = E.num
    INNER JOIN `uspidnaproddata.advantx_ods.ca_case` AS F
        ON B.source_system_id = F.source_system_id
        AND B.case_num = F.case_num
    INNER JOIN temp_ca_visit_visitdept_proc_hist AS G
        ON B.source_system_id = G.source_system_id
        AND B.case_num = G.case_num
        AND E.num = G.proc_num
    INNER JOIN `uspidnaproddata.advantx_ods.ca_visit` AS H
        ON G.source_system_id = H.source_system_id
        AND G.visit_num = H.visit_num
    INNER JOIN `uspidnaproddata.advantx_ods.ut_visittypes` AS I
        ON H.source_system_id = I.source_system_id
        AND H.visittype_num = I.num
    WHERE
        -- Applying filters as early as possible is critical for performance.
        A.source_system_id = V_source_system -- Assuming V_source_system is a variable/placeholder
        AND A.active = 1
        AND F.key_dos >= DATE_TRUNC(DATE_SUB(CURRENT_DATE(), INTERVAL 3 YEAR), YEAR)
        AND G.order_key = 1
    GROUP BY
        A.source_system_id,
        B.case_num,
        B.procfee_num,
        E.quick_code,
        I.num,
        I.quick_code
),
RankedProcedures AS (
    -- This CTE applies the ROW_NUMBER() to select a single primary procedure per case.
    SELECT
        source_system_id,
        case_num,
        procfee_num,
        procedure_code,
        visittype_num,
        visit_type_code,
        bill_period_num,
        ROW_NUMBER() OVER (PARTITION BY source_system_id, case_num ORDER BY procedure_code) AS rn
    FROM AggregatedData
)
SELECT
    source_system_id,
    case_num,
    procfee_num,
    procedure_code,
    visittype_num,
    visit_type_code,
    bill_period_num
FROM RankedProcedures
WHERE rn = 1;
