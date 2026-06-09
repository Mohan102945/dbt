{{
    config(
        materialized='view',
        description='Cleaned and typed raw customer records from the source Telco system.'
    )
}}

with source as (

    select * from {{ source('churn_db', 'customers') }}

),

renamed as (

    select
        -- Primary key
        "customerID"                                            as customer_id,

        -- Demographics
        lower(trim(gender))                                     as gender,
        "SeniorCitizen"                                         as is_senior_citizen,
        case when lower(trim("Partner")) = 'yes'
            then true else false end                            as has_partner,
        case when lower(trim("Dependents")) = 'yes'
            then true else false end                            as has_dependents,

        -- Account info
        "tenure"                                                as tenure_months,
        lower(trim("Contract"))                                 as contract_type,
        case when lower(trim("PaperlessBilling")) = 'yes'
            then true else false end                            as is_paperless_billing,
        lower(trim("PaymentMethod"))                            as payment_method,

        -- Financials
        "MonthlyCharges"::numeric(10,2)                        as monthly_charges,
        -- TotalCharges has blanks for new customers (tenure=0), coalesce to 0
        nullif(trim("TotalCharges"), '')::numeric(10,2)        as total_charges,

        -- Phone services
        case when lower(trim("PhoneService")) = 'yes'
            then true else false end                            as has_phone_service,
        case
            when lower(trim("MultipleLines")) = 'yes' then true
            when lower(trim("MultipleLines")) = 'no' then false
            else null  -- 'no phone service'
        end                                                     as has_multiple_lines,

        -- Internet services
        case
            when lower(trim("InternetService")) = 'no' then null
            else lower(trim("InternetService"))
        end                                                     as internet_service_type,
        case when lower(trim("InternetService")) = 'no'
            then false else true end                            as has_internet_service,

        -- Internet add-ons (null when no internet)
        case
            when lower(trim("InternetService")) = 'no' then null
            when lower(trim("OnlineSecurity")) = 'yes' then true
            else false
        end                                                     as has_online_security,
        case
            when lower(trim("InternetService")) = 'no' then null
            when lower(trim("OnlineBackup")) = 'yes' then true
            else false
        end                                                     as has_online_backup,
        case
            when lower(trim("InternetService")) = 'no' then null
            when lower(trim("DeviceProtection")) = 'yes' then true
            else false
        end                                                     as has_device_protection,
        case
            when lower(trim("InternetService")) = 'no' then null
            when lower(trim("TechSupport")) = 'yes' then true
            else false
        end                                                     as has_tech_support,
        case
            when lower(trim("InternetService")) = 'no' then null
            when lower(trim("StreamingTV")) = 'yes' then true
            else false
        end                                                     as has_streaming_tv,
        case
            when lower(trim("InternetService")) = 'no' then null
            when lower(trim("StreamingMovies")) = 'yes' then true
            else false
        end                                                     as has_streaming_movies,

        -- Target label
        case when lower(trim("Churn")) = 'yes'
            then true else false end                            as has_churned,

        -- Metadata
        current_timestamp                                       as _loaded_at

    from source

)

select * from renamed