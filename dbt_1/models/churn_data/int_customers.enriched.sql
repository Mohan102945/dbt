{{
    config(
        materialized='view',
        description='Enriches staged customers with derived features used across multiple marts.'
    )
}}

with customers as (

    select * from {{ ref('stg_customers') }}

),

enriched as (

    select
        -- Pass-through all staging columns
        customer_id,
        gender,
        is_senior_citizen,
        has_partner,
        has_dependents,
        tenure_months,
        contract_type,
        is_paperless_billing,
        payment_method,
        monthly_charges,
        total_charges,
        has_phone_service,
        has_multiple_lines,
        internet_service_type,
        has_internet_service,
        has_online_security,
        has_online_backup,
        has_device_protection,
        has_tech_support,
        has_streaming_tv,
        has_streaming_movies,
        has_churned,

        -- ── Tenure Segmentation ──────────────────────────────────────────────
        case
            when tenure_months = 0              then 'new'
            when tenure_months between 1 and 12  then 'early'      -- 0–1 yr
            when tenure_months between 13 and 24 then 'developing'  -- 1–2 yr
            when tenure_months between 25 and 48 then 'established' -- 2–4 yr
            else                                     'loyal'        -- 4+ yr
        end                                             as tenure_segment,

        -- ── Contract Normalisation ───────────────────────────────────────────
        case contract_type
            when 'month-to-month' then 1
            when 'one year'       then 12
            when 'two year'       then 24
        end                                             as contract_length_months,

        case contract_type
            when 'month-to-month' then 'short-term'
            when 'one year'       then 'medium-term'
            when 'two year'       then 'long-term'
        end                                             as contract_term_label,

        -- ── Payment Channel ──────────────────────────────────────────────────
        case
            when payment_method in (
                'bank transfer (automatic)',
                'credit card (automatic)'
            ) then true
            else false
        end                                             as is_auto_pay,

        -- ── Financial Metrics ────────────────────────────────────────────────
        -- Impute total_charges for 0-tenure customers
        coalesce(total_charges, monthly_charges)        as total_charges_imputed,

        round(
            coalesce(total_charges, monthly_charges)
            / nullif(tenure_months, 0),
            2
        )                                               as avg_monthly_spend,

        -- Discount proxy: compare actual monthly vs implied annual rate
        round(
            monthly_charges * 12
            - coalesce(total_charges, monthly_charges),
            2
        )                                               as implied_annual_discount,

        -- ── Service Counts ───────────────────────────────────────────────────
        (
            case when has_phone_service     then 1 else 0 end
          + case when has_multiple_lines    then 1 else 0 end
          + case when has_internet_service  then 1 else 0 end
          + case when has_online_security   then 1 else 0 end
          + case when has_online_backup     then 1 else 0 end
          + case when has_device_protection then 1 else 0 end
          + case when has_tech_support      then 1 else 0 end
          + case when has_streaming_tv      then 1 else 0 end
          + case when has_streaming_movies  then 1 else 0 end
        )                                               as total_services_subscribed,

        -- ── Household Profile ────────────────────────────────────────────────
        case
            when has_partner and has_dependents     then 'family'
            when has_partner and not has_dependents then 'couple'
            when not has_partner and has_dependents then 'single_parent'
            else                                         'single'
        end                                             as household_type,

        -- ── Churn Risk Score (rule-based) ────────────────────────────────────
        -- Composite heuristic; higher = more risk
        (
            -- Contract type risk (highest signal)
            case contract_type
                when 'month-to-month' then 3
                when 'one year'       then 1
                else                       0
            end
            -- Short tenure risk
          + case
                when tenure_months < {{ var('churn_risk_short_tenure_months') }}
                then 2 else 0
            end
            -- High charges relative to services
          + case
                when monthly_charges > {{ var('churn_risk_high_monthly_charges') }}
                then 2 else 0
            end
            -- No protective add-ons
          + case when not coalesce(has_online_security, false)  then 1 else 0 end
          + case when not coalesce(has_tech_support, false)     then 1 else 0 end
            -- Manual / non-sticky payment
          + case when not is_auto_pay                           then 1 else 0 end
            -- Senior with fiber (price-sensitive segment)
          + case
                when is_senior_citizen = 1
                 and internet_service_type = 'fiber optic'
                then 1 else 0
            end
        )                                               as churn_risk_score,

        -- ── Monthly Charges Tier ─────────────────────────────────────────────
        case
            when monthly_charges < 35  then 'low'
            when monthly_charges < 65  then 'medium'
            when monthly_charges < 90  then 'high'
            else                            'premium'
        end                                             as monthly_charges_tier

    from customers

)

select * from enriched