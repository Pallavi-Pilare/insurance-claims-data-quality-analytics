-- ============================================================
-- Insurance Claims Data Quality & Analysis
-- Author      : Pallavi Pilare
-- Date        : 2026
-- Description : SQL queries for claims validation, QA, and
--               month-end reporting on insurance claims data
-- ============================================================


-- ─────────────────────────────────────────────────────────────
-- SECTION 1: DATA QUALITY CHECKS
-- ─────────────────────────────────────────────────────────────

-- 1.1 Check for NULL / Missing Values per Column
SELECT
    'claim_id'        AS column_name, COUNT(*) - COUNT(claim_id)        AS null_count FROM insurance_claims
UNION ALL
SELECT 'claim_amount',   COUNT(*) - COUNT(claim_amount)   FROM insurance_claims
UNION ALL
SELECT 'claim_date',     COUNT(*) - COUNT(claim_date)     FROM insurance_claims
UNION ALL
SELECT 'settlement_days',COUNT(*) - COUNT(settlement_days)FROM insurance_claims
UNION ALL
SELECT 'claim_status',   COUNT(*) - COUNT(claim_status)   FROM insurance_claims;


-- 1.2 Duplicate Claim IDs (Data Integrity Check)
SELECT
    claim_id,
    COUNT(*) AS duplicate_count
FROM insurance_claims
GROUP BY claim_id
HAVING COUNT(*) > 1
ORDER BY duplicate_count DESC;


-- 1.3 Invalid Future Claim Dates (Compliance Check)
SELECT
    claim_id,
    claim_date,
    claim_status,
    claim_amount
FROM insurance_claims
WHERE claim_date > CURRENT_DATE
ORDER BY claim_date;


-- 1.4 Claims with Negative or Zero Amounts (Data Validation)
SELECT
    claim_id,
    claim_amount,
    claim_type,
    claim_status
FROM insurance_claims
WHERE claim_amount <= 0;


-- 1.5 Overall Data Quality Score
SELECT
    COUNT(*)                                              AS total_records,
    COUNT(*) - COUNT(claim_amount)                        AS missing_amounts,
    COUNT(*) - COUNT(claim_id)                            AS missing_ids,
    SUM(CASE WHEN claim_date > CURRENT_DATE THEN 1 END)  AS future_dates,
    ROUND(
        100.0 * (
            COUNT(claim_amount) +
            COUNT(claim_id)
        ) / (2.0 * COUNT(*)), 2
    )                                                     AS data_quality_score_pct
FROM insurance_claims;


-- ─────────────────────────────────────────────────────────────
-- SECTION 2: CLAIMS SUMMARY ANALYSIS
-- ─────────────────────────────────────────────────────────────

-- 2.1 Total Claims and Amount by Status
SELECT
    claim_status,
    COUNT(*)                            AS total_claims,
    ROUND(SUM(claim_amount), 2)         AS total_amount,
    ROUND(AVG(claim_amount), 2)         AS avg_claim_amount,
    ROUND(MIN(claim_amount), 2)         AS min_amount,
    ROUND(MAX(claim_amount), 2)         AS max_amount
FROM insurance_claims
WHERE claim_amount IS NOT NULL
GROUP BY claim_status
ORDER BY total_claims DESC;


-- 2.2 Claims by Type and Region
SELECT
    claim_type,
    region,
    COUNT(*)                            AS total_claims,
    ROUND(SUM(claim_amount), 2)         AS total_amount,
    ROUND(AVG(claim_amount), 2)         AS avg_amount
FROM insurance_claims
WHERE claim_amount IS NOT NULL
GROUP BY claim_type, region
ORDER BY claim_type, total_claims DESC;


-- 2.3 Handler Performance (Agent Workload & Efficiency)
SELECT
    handler,
    COUNT(*)                                                AS total_assigned,
    SUM(CASE WHEN claim_status = 'Closed' THEN 1 ELSE 0 END) AS closed_claims,
    ROUND(AVG(settlement_days), 1)                          AS avg_settlement_days,
    ROUND(
        100.0 * SUM(CASE WHEN claim_status = 'Closed' THEN 1 ELSE 0 END)
        / COUNT(*), 2
    )                                                       AS closure_rate_pct
FROM insurance_claims
GROUP BY handler
ORDER BY closure_rate_pct DESC;


-- 2.4 Fraud Flag Analysis by Claim Type
SELECT
    claim_type,
    COUNT(*)                                                  AS total_claims,
    SUM(fraud_flag)                                           AS flagged_claims,
    ROUND(100.0 * SUM(fraud_flag) / COUNT(*), 2)              AS fraud_rate_pct,
    ROUND(SUM(CASE WHEN fraud_flag = 1 THEN claim_amount ELSE 0 END), 2) AS fraud_exposure_amount
FROM insurance_claims
WHERE claim_amount IS NOT NULL
GROUP BY claim_type
ORDER BY fraud_rate_pct DESC;


-- ─────────────────────────────────────────────────────────────
-- SECTION 3: MONTH-END REPORTING
-- ─────────────────────────────────────────────────────────────

-- 3.1 Monthly Claims Volume and Revenue Report
SELECT
    STRFTIME('%Y-%m', claim_date)       AS month,
    COUNT(*)                            AS total_claims,
    SUM(CASE WHEN claim_status = 'Closed'   THEN 1 ELSE 0 END) AS closed,
    SUM(CASE WHEN claim_status = 'Open'     THEN 1 ELSE 0 END) AS open,
    SUM(CASE WHEN claim_status = 'Rejected' THEN 1 ELSE 0 END) AS rejected,
    ROUND(SUM(claim_amount), 2)         AS total_claim_value,
    ROUND(AVG(claim_amount), 2)         AS avg_claim_value
FROM insurance_claims
WHERE claim_amount IS NOT NULL
  AND claim_date NOT LIKE '%/%'          -- exclude wrong format dates
GROUP BY month
ORDER BY month;


-- 3.2 Priority-wise Backlog Report (Open + Pending)
SELECT
    priority,
    COUNT(*)                            AS backlog_count,
    ROUND(SUM(claim_amount), 2)         AS backlog_value,
    ROUND(AVG(claim_amount), 2)         AS avg_value
FROM insurance_claims
WHERE claim_status IN ('Open', 'Pending')
  AND claim_amount IS NOT NULL
GROUP BY priority
ORDER BY
    CASE priority
        WHEN 'Critical' THEN 1
        WHEN 'High'     THEN 2
        WHEN 'Medium'   THEN 3
        WHEN 'Low'      THEN 4
    END;


-- 3.3 Settlement Efficiency Report (Closed Claims)
SELECT
    claim_type,
    COUNT(*)                            AS settled_claims,
    ROUND(AVG(settlement_days), 1)      AS avg_days_to_settle,
    MIN(settlement_days)                AS fastest_days,
    MAX(settlement_days)                AS slowest_days,
    SUM(CASE WHEN settlement_days > 90 THEN 1 ELSE 0 END) AS breached_sla_count
FROM insurance_claims
WHERE claim_status = 'Closed'
  AND settlement_days IS NOT NULL
GROUP BY claim_type
ORDER BY avg_days_to_settle;


-- 3.4 Region-wise Month-End Summary
SELECT
    region,
    COUNT(*)                            AS total_claims,
    ROUND(SUM(claim_amount), 2)         AS total_value,
    SUM(fraud_flag)                     AS fraud_cases,
    ROUND(AVG(settlement_days), 1)      AS avg_settlement_days
FROM insurance_claims
WHERE claim_amount IS NOT NULL
GROUP BY region
ORDER BY total_value DESC;


-- ─────────────────────────────────────────────────────────────
-- SECTION 4: DATA CORRECTION QUERIES
-- ─────────────────────────────────────────────────────────────

-- 4.1 Flag records needing correction
SELECT
    claim_id,
    claim_date,
    claim_amount,
    claim_status,
    CASE
        WHEN claim_amount IS NULL         THEN 'Missing Amount'
        WHEN claim_date > CURRENT_DATE    THEN 'Future Date'
        WHEN claim_amount <= 0            THEN 'Invalid Amount'
        ELSE 'OK'
    END AS data_issue
FROM insurance_claims
WHERE
    claim_amount IS NULL OR
    claim_date > CURRENT_DATE OR
    claim_amount <= 0
ORDER BY data_issue;


-- 4.2 Update: Set default priority for NULL priorities
-- UPDATE insurance_claims
-- SET priority = 'Medium'
-- WHERE priority IS NULL;

-- 4.3 Correction Log View (for Audit Trail)
SELECT
    claim_id,
    claim_type,
    claim_status,
    claim_amount,
    'Null Amount Correction' AS correction_type,
    CURRENT_DATE             AS corrected_date
FROM insurance_claims
WHERE claim_amount IS NULL;
