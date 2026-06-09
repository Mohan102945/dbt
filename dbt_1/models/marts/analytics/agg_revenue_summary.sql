{{
    config(
        materialized='table',
        description='Overall revenue health metrics: MRR, churn impact, LTV estimates. Feeds the finance and executive dashboards.'
    )
}}

with customers as (

    select * from {{ ref('dim_customers') }}

),

churn_events as (

    select * from {{ ref('fct_churn_events') }}

),

revenue_base as (

    select
        -- Volume
        count(*)                                                        as total_customers,
        sum(case when has_churned then 1 else 0 end)                   as total_churned,
        sum(case when not has_churned then 1 else 0 end)               as total_active,

        -- MRR
        round(sum(monthly_charges), 2)                                  as gross_mrr,
        round(sum(case when not has_churned then monthly_charges end), 2)
                                                                        as active_mrr,
        round(sum(case when has_churned then monthly_charges end), 2)   as churned_mrr,

        -- Revenue at risk (active customers at high/critical risk)
        round(sum(
            case when not has_churned
                 and churn_risk_label in ('high', 'critical')
             then monthly_charges else 0 end
        ), 2)                                                           as mrr_at_risk,

        -- LTV
        round(avg(total_charges_imputed), 2)                            as avg_ltv,
        round(avg(case when has_churned then total_charges_imputed end), 2)
                                                                        as avg_churned_ltv,
        round(avg(case when not has_churned then total_charges_imputed end), 2)
                                                                        as avg_active_ltv,

        -- Overall churn rate
        round(
            sum(case when has_churned then 1 else 0 end)::numeric
            / nullif(count(*), 0) * 100, 2
        )                                                               as overall_churn_rate_pct,

        -- Avg tenure
        round(avg(tenure_months), 1)                                    as avg_tenure_months,
        round(avg(case when has_churned then tenure_months end), 1)     as avg_churned_tenure_months

    from customers

),

revenue_summary as (

    select
        total_customers,
        total_churned,
        total_active,
        gross_mrr,
        active_mrr,
        churned_mrr,
        mrr_at_risk,
        round(mrr_at_risk / nullif(active_mrr, 0) * 100, 2)            as pct_mrr_at_risk,
        avg_ltv,
        avg_churned_ltv,
        avg_active_ltv,
        overall_churn_rate_pct,
        avg_tenure_months,
        avg_churned_tenure_months,
        -- Monthly churn rate approximation
        round(overall_churn_rate_pct / nullif(avg_tenure_months, 0), 4)
                                                                        as approx_monthly_churn_rate_pct,
        current_timestamp                                               as dbt_updated_at
    from revenue_base

)

select * from revenue_summary