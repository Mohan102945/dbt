{{
    config(
        materialized='table',
        description='Fact table of customer churn events. One row per churned customer. Used for funnel analysis, revenue impact, and cohort churn rates.'
    )
}}

with customers as (

    select * from {{ ref('dim_customers') }}

),

churned as (

    select * from customers where has_churned = true

),

churn_events as (

    select
        -- Surrogate key for this fact row
        {{ dbt_utils.generate_surrogate_key(['customer_id']) }}     as churn_event_sk,

        -- Foreign key to dim_customers
        customer_sk,
        customer_id,

        -- Churn context at time of event
        tenure_months                                               as months_before_churn,
        tenure_segment                                              as tenure_segment_at_churn,
        contract_type                                               as contract_at_churn,
        monthly_charges                                             as monthly_charges_at_churn,
        total_charges_imputed                                       as lifetime_revenue,

        -- Revenue impact metrics
        monthly_charges                                             as monthly_revenue_lost,
        -- Estimated annual revenue lost (prorated by remaining contract)
        round(
            monthly_charges
            * (contract_length_months - (tenure_months % contract_length_months)),
            2
        )                                                           as estimated_contract_revenue_lost,

        -- Lifetime value proxy
        round(total_charges_imputed / nullif(tenure_months, 0) * 12, 2)
                                                                    as annualised_ltv,

        -- Service profile at churn
        total_services_subscribed,
        has_internet_service,
        internet_service_type,
        churn_risk_score,
        churn_risk_label,

        -- Payment attributes
        payment_method,
        is_auto_pay,

        -- Demographics
        gender,
        is_senior_citizen,
        household_type,

        current_timestamp                                           as dbt_updated_at

    from churned

)

select * from churn_events