-- GOIT FINAL PROJECT | REVENUE ANALYTICS
-- SUPPORTING SQL ANALYSES (01-07)
-- Database: PostgreSQL | Schema: project
-- All comments and output column names are in English.
-- Each section is an independent query: place the cursor inside it and press Ctrl+Enter in DBeaver.
-- Reporting period in supplied data: March-December 2022.
-- MRR is treated as calendar-month payment revenue, not independently validated subscription revenue.

-- =============================================================
-- 01 | DATA VALIDATION
-- =============================================================
SELECT
    (SELECT COUNT(*) FROM project.games_paid_users) AS total_users,
    COUNT(*) AS total_payments,
    COUNT(DISTINCT user_id) AS paying_users,
    ROUND(SUM(revenue_amount_usd)::numeric, 2) AS total_revenue_usd
FROM project.games_payments;

-- =============================================================
-- 02 | MONTHLY REVENUE, PAID USERS AND ARPPU
-- =============================================================
SELECT
    DATE_TRUNC('month', payment_date)::date AS payment_month,
    ROUND(SUM(revenue_amount_usd)::numeric, 2) AS mrr,
    COUNT(DISTINCT user_id) AS paid_users,
    ROUND(
        SUM(revenue_amount_usd)::numeric
        / NULLIF(COUNT(DISTINCT user_id), 0), 2
    ) AS arppu
FROM project.games_payments
GROUP BY 1
ORDER BY 1;

-- =============================================================
-- 03 | NEW PAID USERS AND NEW MRR
-- =============================================================
WITH monthly_user_revenue AS (
    SELECT
        user_id,
        DATE_TRUNC('month', payment_date)::date AS payment_month,
        SUM(revenue_amount_usd)::numeric AS monthly_revenue
    FROM project.games_payments
    GROUP BY 1, 2
),
first_payments AS (
    SELECT user_id, MIN(payment_month) AS first_payment_month
    FROM monthly_user_revenue
    GROUP BY user_id
)
SELECT
    mur.payment_month,
    COUNT(*) AS paid_users,
    COUNT(*) FILTER (
        WHERE mur.payment_month = fp.first_payment_month
    ) AS new_paid_users,
    ROUND(SUM(
        CASE WHEN mur.payment_month = fp.first_payment_month
             THEN mur.monthly_revenue ELSE 0 END
    ), 2) AS new_mrr,
    ROUND(SUM(mur.monthly_revenue), 2) AS total_mrr
FROM monthly_user_revenue mur
JOIN first_payments fp USING (user_id)
GROUP BY mur.payment_month
ORDER BY mur.payment_month;

-- =============================================================
-- 04 | CHURNED USERS, CHURN RATE, CHURNED REVENUE
-- =============================================================
WITH monthly_user_revenue AS (
    SELECT
        user_id,
        DATE_TRUNC('month', payment_date)::date AS payment_month,
        SUM(revenue_amount_usd)::numeric AS monthly_revenue
    FROM project.games_payments
    GROUP BY 1, 2
),
months AS (
    SELECT DISTINCT payment_month FROM monthly_user_revenue
),
churn_base AS (
    SELECT
        m.payment_month,
        COUNT(prev.user_id) AS previous_paid_users,
        COUNT(prev.user_id) FILTER (
            WHERE curr.user_id IS NULL
        ) AS churned_users,
        COALESCE(SUM(prev.monthly_revenue) FILTER (
            WHERE curr.user_id IS NULL
        ), 0) AS churned_revenue,
        COALESCE(SUM(prev.monthly_revenue), 0) AS previous_mrr
    FROM months m
    LEFT JOIN monthly_user_revenue prev
        ON prev.payment_month = (m.payment_month - INTERVAL '1 month')::date
    LEFT JOIN monthly_user_revenue curr
        ON curr.user_id = prev.user_id
       AND curr.payment_month = m.payment_month
    GROUP BY m.payment_month
)
SELECT
    payment_month,
    previous_paid_users,
    CASE WHEN previous_paid_users = 0 THEN NULL
         ELSE churned_users END AS churned_users,
    ROUND(
        100.0 * churned_users / NULLIF(previous_paid_users, 0), 2
    ) AS churn_rate_pct,
    CASE WHEN previous_paid_users = 0 THEN NULL
         ELSE ROUND(churned_revenue, 2) END AS churned_revenue,
    ROUND(
        100.0 * churned_revenue / NULLIF(previous_mrr, 0), 2
    ) AS revenue_churn_rate_pct
FROM churn_base
ORDER BY payment_month;

-- =============================================================
-- 05 | MONTHLY REVENUE MOVEMENT AND RECONCILIATION
-- =============================================================
WITH monthly_user_revenue AS (
    SELECT
        user_id,
        DATE_TRUNC('month', payment_date)::date AS payment_month,
        SUM(revenue_amount_usd)::numeric AS monthly_revenue
    FROM project.games_payments
    GROUP BY 1, 2
),
first_payments AS (
    SELECT user_id, MIN(payment_month) AS first_payment_month
    FROM monthly_user_revenue
    GROUP BY user_id
),
current_user_movements AS (
    SELECT
        curr.payment_month,
        curr.user_id,
        curr.monthly_revenue AS current_revenue,
        prev.monthly_revenue AS previous_revenue,
        fp.first_payment_month
    FROM monthly_user_revenue curr
    LEFT JOIN monthly_user_revenue prev
        ON prev.user_id = curr.user_id
       AND prev.payment_month = (curr.payment_month - INTERVAL '1 month')::date
    JOIN first_payments fp ON fp.user_id = curr.user_id
),
revenue_components AS (
    SELECT
        payment_month,
        SUM(current_revenue) AS mrr,
        SUM(CASE WHEN payment_month = first_payment_month
                 THEN current_revenue ELSE 0 END) AS new_mrr,
        COUNT(*) FILTER (
            WHERE payment_month > first_payment_month
              AND previous_revenue IS NULL
        ) AS reactivated_users,
        SUM(CASE WHEN payment_month > first_payment_month
                     AND previous_revenue IS NULL
                 THEN current_revenue ELSE 0 END) AS reactivation_mrr,
        SUM(CASE WHEN previous_revenue IS NOT NULL
                     AND current_revenue > previous_revenue
                 THEN current_revenue - previous_revenue ELSE 0 END) AS expansion_mrr,
        SUM(CASE WHEN previous_revenue IS NOT NULL
                     AND current_revenue < previous_revenue
                 THEN previous_revenue - current_revenue ELSE 0 END) AS contraction_mrr
    FROM current_user_movements
    GROUP BY payment_month
),
churn AS (
    SELECT
        (prev.payment_month + INTERVAL '1 month')::date AS payment_month,
        SUM(prev.monthly_revenue) AS churned_revenue
    FROM monthly_user_revenue prev
    LEFT JOIN monthly_user_revenue curr
        ON curr.user_id = prev.user_id
       AND curr.payment_month = (prev.payment_month + INTERVAL '1 month')::date
    WHERE curr.user_id IS NULL
    GROUP BY 1
),
comparison AS (
    SELECT
        rc.*,
        COALESCE(c.churned_revenue, 0) AS churned_revenue,
        LAG(rc.mrr) OVER (ORDER BY rc.payment_month) AS previous_mrr
    FROM revenue_components rc
    LEFT JOIN churn c ON rc.payment_month = c.payment_month
)
SELECT
    payment_month,
    ROUND(mrr, 2) AS mrr,
    ROUND(new_mrr, 2) AS new_mrr,
    reactivated_users,
    ROUND(reactivation_mrr, 2) AS reactivation_mrr,
    ROUND(expansion_mrr, 2) AS expansion_mrr,
    ROUND(contraction_mrr, 2) AS contraction_mrr,
    ROUND(churned_revenue, 2) AS churned_revenue,
    ROUND(mrr - previous_mrr, 2) AS actual_mrr_change,
    ROUND(new_mrr + reactivation_mrr + expansion_mrr
          - contraction_mrr - churned_revenue, 2) AS explained_mrr_change,
    ROUND((mrr - previous_mrr)
          - (new_mrr + reactivation_mrr + expansion_mrr
             - contraction_mrr - churned_revenue), 2) AS reconciliation_difference
FROM comparison
ORDER BY payment_month;

-- =============================================================
-- 06 | PAID USER MOVEMENT AND RECONCILIATION
-- =============================================================
WITH monthly_users AS (
    SELECT DISTINCT
        user_id,
        DATE_TRUNC('month', payment_date)::date AS payment_month
    FROM project.games_payments
),
first_payments AS (
    SELECT user_id, MIN(payment_month) AS first_payment_month
    FROM monthly_users
    GROUP BY user_id
),
user_movements AS (
    SELECT
        curr.payment_month,
        curr.user_id,
        CASE WHEN curr.payment_month = fp.first_payment_month
             THEN 1 ELSE 0 END AS new_paid_user,
        CASE WHEN curr.payment_month > fp.first_payment_month
                  AND prev.user_id IS NULL
             THEN 1 ELSE 0 END AS reactivated_user
    FROM monthly_users curr
    JOIN first_payments fp ON curr.user_id = fp.user_id
    LEFT JOIN monthly_users prev
        ON prev.user_id = curr.user_id
       AND prev.payment_month = (curr.payment_month - INTERVAL '1 month')::date
),
monthly_counts AS (
    SELECT
        payment_month,
        COUNT(*) AS paid_users,
        SUM(new_paid_user) AS new_paid_users,
        SUM(reactivated_user) AS reactivated_users
    FROM user_movements
    GROUP BY payment_month
),
churn AS (
    SELECT
        (prev.payment_month + INTERVAL '1 month')::date AS payment_month,
        COUNT(*) AS churned_users
    FROM monthly_users prev
    LEFT JOIN monthly_users curr
        ON curr.user_id = prev.user_id
       AND curr.payment_month = (prev.payment_month + INTERVAL '1 month')::date
    WHERE curr.user_id IS NULL
    GROUP BY 1
),
comparison AS (
    SELECT
        mc.*,
        LAG(mc.paid_users) OVER (ORDER BY mc.payment_month) AS previous_paid_users,
        COALESCE(c.churned_users, 0) AS churned_users
    FROM monthly_counts mc
    LEFT JOIN churn c ON mc.payment_month = c.payment_month
)
SELECT
    payment_month,
    previous_paid_users,
    new_paid_users,
    reactivated_users,
    CASE WHEN previous_paid_users IS NULL THEN NULL
         ELSE churned_users END AS churned_users,
    paid_users,
    previous_paid_users + new_paid_users
        + reactivated_users - churned_users AS explained_paid_users,
    paid_users - (previous_paid_users + new_paid_users
        + reactivated_users - churned_users) AS reconciliation_difference
FROM comparison
ORDER BY payment_month;

-- =============================================================
-- 07 | OBSERVED CUSTOMER LIFETIME (LT) AND VALUE (LTV)
-- =============================================================
WITH user_summary AS (
    SELECT
        user_id,
        MIN(DATE_TRUNC('month', payment_date)::date) AS first_payment_month,
        MAX(DATE_TRUNC('month', payment_date)::date) AS last_payment_month,
        COUNT(DISTINCT DATE_TRUNC('month', payment_date)::date) AS active_payment_months,
        SUM(revenue_amount_usd)::numeric AS total_user_revenue
    FROM project.games_payments
    GROUP BY user_id
),
lifetime AS (
    SELECT
        *,
        (EXTRACT(YEAR FROM AGE(last_payment_month, first_payment_month)) * 12
         + EXTRACT(MONTH FROM AGE(last_payment_month, first_payment_month))
         + 1) AS observed_lifetime_months
    FROM user_summary
)
SELECT
    COUNT(*) AS total_users,
    ROUND(AVG(observed_lifetime_months)::numeric, 2) AS avg_observed_lt_months,
    ROUND(AVG(active_payment_months)::numeric, 2) AS avg_active_payment_months,
    ROUND(AVG(total_user_revenue), 2) AS observed_ltv_usd,
    ROUND(SUM(total_user_revenue), 2) AS total_revenue_usd,
    COUNT(*) FILTER (
        WHERE last_payment_month = (SELECT MAX(last_payment_month) FROM lifetime)
    ) AS last_month_active_users
FROM lifetime;