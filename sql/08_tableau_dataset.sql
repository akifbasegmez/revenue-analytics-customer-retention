-- GOIT FINAL PROJECT | REVENUE ANALYTICS
-- FINAL TABLEAU DATASET (08)
-- Database: PostgreSQL | Schema: project
-- Grain: one row per user and calendar month, user_id excluded from published output.
-- NOTE: All monetary metrics are based on monthly payments (MRR proxy).
-- The observed LT and LTV fields are tagged on each user's first observed month only.

WITH monthly_payments AS (
    SELECT
        user_id,
        DATE_TRUNC('month', payment_date)::date AS payment_month,
        ROUND(SUM(revenue_amount_usd)::numeric, 2) AS monthly_revenue
    FROM project.games_payments
    GROUP BY user_id, DATE_TRUNC('month', payment_date)::date
),
user_summary AS (
    SELECT
        user_id,
        MIN(payment_month) AS first_payment_month,
        MAX(payment_month) AS last_payment_month,
        SUM(monthly_revenue) AS lifetime_revenue,
        (
            EXTRACT(YEAR FROM AGE(MAX(payment_month), MIN(payment_month))) * 12
            + EXTRACT(MONTH FROM AGE(MAX(payment_month), MIN(payment_month)))
            + 1
        )::integer AS observed_lifetime_months
    FROM monthly_payments
    GROUP BY user_id
),
months AS (
    SELECT GENERATE_SERIES(
        (SELECT MIN(payment_month) FROM monthly_payments),
        (SELECT MAX(payment_month) FROM monthly_payments),
        INTERVAL '1 month'
    )::date AS payment_month
),
user_month AS (
    SELECT
        m.payment_month,
        u.user_id,
        u.game_name,
        u.language,
        u.age,
        u.has_older_device_model,
        COALESCE(p.monthly_revenue, 0) AS revenue,
        s.first_payment_month,
        s.observed_lifetime_months,
        s.lifetime_revenue
    FROM months m
    CROSS JOIN project.games_paid_users u
    JOIN user_summary s ON u.user_id = s.user_id
    LEFT JOIN monthly_payments p
        ON u.user_id = p.user_id
       AND m.payment_month = p.payment_month
),
with_previous AS (
    SELECT
        *,
        COALESCE(
            LAG(revenue) OVER (PARTITION BY user_id ORDER BY payment_month), 0
        ) AS previous_revenue
    FROM user_month
)
SELECT
    payment_month,
    game_name,
    language,
    age,
    has_older_device_model,
    revenue AS mrr,
    CASE WHEN revenue > 0 THEN 1 ELSE 0 END AS paid_users,
    CASE WHEN payment_month = first_payment_month AND revenue > 0
         THEN 1 ELSE 0 END AS new_paid_users,
    CASE WHEN payment_month = first_payment_month
         THEN revenue ELSE 0 END AS new_mrr,
    CASE WHEN payment_month > first_payment_month
               AND revenue > 0 AND previous_revenue = 0
         THEN 1 ELSE 0 END AS reactivated_users,
    CASE WHEN payment_month > first_payment_month
               AND revenue > 0 AND previous_revenue = 0
         THEN revenue ELSE 0 END AS reactivation_mrr,
    CASE WHEN previous_revenue > 0 AND revenue > previous_revenue
         THEN revenue - previous_revenue ELSE 0 END AS expansion_mrr,
    CASE WHEN revenue > 0 AND previous_revenue > revenue
         THEN previous_revenue - revenue ELSE 0 END AS contraction_mrr,
    CASE WHEN previous_revenue > 0 AND revenue = 0
         THEN 1 ELSE 0 END AS churned_users,
    CASE WHEN previous_revenue > 0 AND revenue = 0
         THEN previous_revenue ELSE 0 END AS churned_revenue,
    CASE WHEN previous_revenue > 0 THEN 1 ELSE 0 END AS previous_paid_users,
    previous_revenue AS previous_mrr,
    CASE WHEN payment_month = first_payment_month
         THEN observed_lifetime_months END AS observed_lt_months,
    CASE WHEN payment_month = first_payment_month
         THEN lifetime_revenue END AS observed_ltv_usd
FROM with_previous
ORDER BY payment_month, user_id;