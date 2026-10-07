{{ config(materialized='view') }}

with source as (

    select *
    from {{ ref('stg_armd_cohort') }}

    where organism is not null
      and antibiotic is not null

),

grouped as (

    select
        source_version,
        patient_key,
        encounter_key,
        culture_order_key,
        organism,
        antibiotic,

        count(*) as source_row_count,

        sum(
            case
                when susceptibility is null then 1
                else 0
            end
        ) as missing_susceptibility_row_count,

        count(distinct susceptibility)
            as distinct_nonnull_category_count,

        count(
            distinct coalesce(
                susceptibility,
                '__NULL__'
            )
        ) as distinct_result_state_count,

        max(susceptibility) as candidate_susceptibility,

        max(source_file) as source_file,
        max(ingested_at) as ingested_at

    from source

    group by
        source_version,
        patient_key,
        encounter_key,
        culture_order_key,
        organism,
        antibiotic

),

culture_organisms as (

    select
        culture_organism_key,
        culture_key,
        source_version,
        patient_key,
        encounter_key,
        culture_order_key,
        organism

    from {{ ref('fct_culture_organism') }}

),

final as (

    select
        co.culture_organism_key,
        co.culture_key,

        g.source_version,
        g.patient_key,
        g.encounter_key,
        g.culture_order_key,
        g.organism,
        g.antibiotic,

        g.source_row_count,
        g.missing_susceptibility_row_count,
        g.distinct_nonnull_category_count,
        g.distinct_result_state_count,

        greatest(
            g.source_row_count - g.distinct_result_state_count,
            0
        ) as repeated_result_row_count,

        case

            -- Exactly one non-null result state.
            when g.distinct_result_state_count = 1
             and g.distinct_nonnull_category_count = 1
                then 'resolved'

            -- Only missing susceptibility values.
            when g.distinct_result_state_count = 1
             and g.distinct_nonnull_category_count = 0
                then 'missing'

            -- Multiple source states remain.
            else 'conflict'

        end as resolution_status,

        case
            when g.distinct_result_state_count = 1
             and g.distinct_nonnull_category_count = 1
                then g.candidate_susceptibility
            else null
        end as susceptibility,

        g.source_file,
        g.ingested_at

    from grouped g

    inner join culture_organisms co
        on g.source_version = co.source_version
        and g.patient_key = co.patient_key
        and g.encounter_key = co.encounter_key
        and g.culture_order_key = co.culture_order_key
        and g.organism = co.organism

)

select *
from final