{{ config(materialized='table') }}

with source as (

    select *
    from {{ ref('stg_armd_cohort') }}

),

profiled as (

    select
        source_version,
        patient_key,
        encounter_key,
        culture_order_key,

        count(*) as source_row_count,

        -- Count distinct order-level values, including null as a value.
        count(
            distinct coalesce(
                cast(culture_time_shifted as string),
                '__NULL__'
            )
        ) as culture_time_value_count,

        count(
            distinct coalesce(ordering_mode, '__NULL__')
        ) as ordering_mode_value_count,

        count(
            distinct coalesce(culture_description, '__NULL__')
        ) as culture_description_value_count,

        count(
            distinct coalesce(
                cast(was_positive as string),
                '__NULL__'
            )
        ) as was_positive_value_count,

        -- Candidate values. These are used only when the field
        -- is internally consistent within the culture order.
        max(culture_time_shifted) as culture_time_value,
        max(ordering_mode) as ordering_mode_value,
        max(culture_description) as culture_description_value,
        max(was_positive) as was_positive_value,

        max(source_file) as source_file,
        max(ingested_at) as ingested_at

    from source

    group by
        source_version,
        patient_key,
        encounter_key,
        culture_order_key

),

final as (

    select

        {{ dbt_utils.generate_surrogate_key([
            'source_version',
            'patient_key',
            'encounter_key',
            'culture_order_key'
        ]) }} as culture_key,

        source_version,
        patient_key,
        encounter_key,
        culture_order_key,

        case
            when culture_time_value_count = 1
                then culture_time_value
        end as culture_time_shifted,

        case
            when ordering_mode_value_count = 1
                then ordering_mode_value
        end as ordering_mode,

        case
            when culture_description_value_count = 1
                then culture_description_value
        end as culture_description,

        case
            when was_positive_value_count = 1
                then was_positive_value
        end as was_positive,

        (
            culture_time_value_count > 1
            or ordering_mode_value_count > 1
            or culture_description_value_count > 1
            or was_positive_value_count > 1
        ) as has_order_level_conflict,

        source_row_count,
        source_file,
        ingested_at

    from profiled

)

select *
from final