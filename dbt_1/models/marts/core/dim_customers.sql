{{
    config(
        materialized='table',
        description='Customer dimension table with full profile and churn label. The primary table for customer-level BI and ML feature engineering.'
    )
}}

with enriched as (

    select * from {{ ref('int_customers_enriched') }}

)

select
    -- Surrogate key
    {{ dbt_utils.generate_surrogate_key(['customer_id']) }}     as customer_sk,

    -- Natural key
    customer_id,

    -- Demographics
    gender,
    is_senior_citizen,
    has_partner,
    has_dependents,
    household_type,

    -- Tenure
    tenure_months,
    tenure_segment,

    -- Contract & payment
    contract_type,
    contract_length_months,
    contract_term_label,
    is_paperless_billing,
    payment_method,
    is_auto_pay,

    -- Services
    has_phone_service,
    has_multiple_lines,
    has_internet_service,
    internet_service_type,
    has_online_security,
    has_online_backup,
    has_device_protection,
    has_tech_support,
    has_streaming_tv,
    has_streaming_movies,
    total_services_subscribed,

    -- Financial profile
    monthly_charges,
    total_charges,
    total_charges_imputed,
    avg_monthly_spend,
    monthly_charges_tier,
    implied_annual_discount,

    -- Risk & outcome
    churn_risk_score,
    case
        when churn_risk_score <= 2  then 'low'
        when churn_risk_score <= 5  then 'medium'
        when churn_risk_score <= 8  then 'high'
        else                             'critical'
    end                                                         as churn_risk_label,
    has_churned,

    -- Metadata
    current_timestamp                                           as dbt_updated_at

from enriched