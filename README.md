# Revenue Analytics & Customer Retention

**PostgreSQL · SQL · Tableau Public | Revenue & Product Analytics**

## Project Overview

Analyzed payment transactions and paying-user behavior for a gaming platform to understand **monthly revenue, customer retention, and the drivers of revenue change**. Used PostgreSQL to transform transaction-level data into a user-month analytical model and Tableau Public to present the results in an interactive dashboard.

**[Explore the Interactive Tableau Dashboard](https://public.tableau.com/views/RevenueAnalyticsCustomerRetention/RevenueAnalyticsCustomerRetention)**

## Tools and Technologies

- **PostgreSQL & DBeaver:** Data extraction, joins, CTEs, conditional aggregation, date functions, `COALESCE`, and `LAG()` window functions
- **Tableau Public:** KPI cards, time-series charts, revenue and user-movement analysis, and interactive filters
- **Validation:** Transaction-to-monthly reconciliation, distinct paying-user checks, and month-over-month movement identities

## Analysis Process

### 1. Data Extraction & Modeling

- Combined `project.games_payments` and `project.games_paid_users` to link payments with user attributes such as language, age, and game.
- Aggregated transactions at **user × calendar month** level; generated a complete monthly series to distinguish inactivity, churn, and reactivation.
- Built a Tableau-ready dataset with monthly revenue, previous-month revenue, and user lifecycle indicators.

### 2. Revenue & Customer Retention Analysis

- Measured **monthly payment revenue (MRR proxy), Paid Users, ARPPU, New Paid Users, and New MRR**.
- Decomposed monthly revenue changes into **new, reactivated, expansion, contraction, and churned** revenue.
- Calculated **churned users, churn rates, revenue churn rates**, and observed customer lifetime and lifetime value (LT/LTV).

### 3. Interactive Dashboard

- Built an interactive Tableau workbook with **13 worksheets, one dashboard, and seven KPI cards**, including **payment-period, language, and age-range filters**.
- Presented monthly revenue and paying-user trends together with separate charts explaining their month-to-month movements.
- Organized metrics and charts for fast comparison of growth, retention, and revenue risk.

## Key Results

| Metric | Result |
| --- | ---: |
| Reporting period | **March–December 2022** |
| Unique paying users | **383** |
| Payment transactions | **3,026** |
| Total observed revenue | **$63,140.67** |
| Highest monthly revenue | **$9,343.86 (October 2022)** |
| December revenue | **$8,439.78** |
| December paying users | **189** |
| December ARPPU | **$44.65** |
| December customer churn rate | **34.04%** |
| Average observed customer lifetime | **4.19 months** |
| Average observed revenue per user (LTV) | **$164.86** |

**December 2022:** Paid users increased from **188 to 189** (**32 new + 33 reactivated − 64 churned = +1**). Monthly revenue rose by **$14.79** as new and reactivated revenue and expansion offset contraction and churn.

## Analysis Visualizations

*The charts below illustrate the aggregated data. For interactive Tableau worksheets and filters, use the live dashboard linked above.*

### Monthly Revenue & Paying Users

![Monthly revenue and paying users](assets/monthly-revenue-paid-users.svg)

### December 2022 Revenue Movement

![Revenue movement decomposition](assets/december-revenue-movement.svg)

### December 2022 Paid-User Movement

![Paid-user movement](assets/december-paid-user-movement.svg)

## Project Files

| File | Purpose |
| --- | --- |
| [Supporting SQL Queries](sql/01_07_supporting_analyses.sql) | Seven independent validation and analytical queries |
| [Final Tableau Dataset SQL](sql/08_tableau_dataset.sql) | User-month model used to prepare the dashboard extract |
| [Monthly KPI Summary](data/monthly_kpi_summary.csv) | Aggregated, validated monthly results |
| [Metric Definitions](docs/metric-definitions.md) | Formulas, scope, methodological limits, and reconciliation |
| [Live Tableau Dashboard](https://public.tableau.com/views/RevenueAnalyticsCustomerRetention/RevenueAnalyticsCustomerRetention) | Interactive revenue and retention dashboard |

## Data Source and Methodological Notes

The analysis uses the **GoIT training dataset** in PostgreSQL tables `project.games_paid_users` and `project.games_payments`.

**MRR terminology:** The source records payments, so reported “MRR” is **calendar-month payment revenue**, not independently verified contractual recurring subscription revenue. **Observed LT/LTV** describe activity within the March–December 2022 window and are not forward-looking estimates. See [Metric Definitions](docs/metric-definitions.md).

Only aggregated reporting data and SQL logic are included in this public repository; user-level records and payment transactions are not republished.
