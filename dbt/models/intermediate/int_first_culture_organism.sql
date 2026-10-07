{{ config(materialized='table') }}

with eligible as (

    select
        standardized_culture_organism_key,
        culture_organism_key,
        culture_key,

        source_version,
        patient_key,
        encounter_key,
        culture_order_key,

        cohort_id,
        culture_time_shifted,
        culture_description,
        was_positive,

        organism_standardized,
        source_labels,
        source_qualifiers

    from {{ ref('int_standardized_culture_organism') }}

    where mapping_resolution_status = 'resolved'
      and culture_time_shifted is not null

),

ranked as (

    select
        *,

        row_number() over (
            partition by
                source_version,
                cohort_id,
                patient_key,
                organism_standardized

            order by
                culture_time_shifted,
                culture_key
        ) as culture_rank

    from eligible

),

final as (

    select

        {{ dbt_utils.generate_surrogate_key([
            'source_version',
            'cohort_id',
            'patient_key',
            'organism_standardized'
        ]) }} as first_culture_organism_key,

        standardized_culture_organism_key,
        culture_organism_key,
        culture_key,

        source_version,
        patient_key,
        encounter_key,
        culture_order_key,

        cohort_id,
        culture_time_shifted,
        culture_description,
        was_positive,

        organism_standardized,
        source_labels,
        source_qualifiers,

        culture_rank

    from ranked

    where culture_rank = 1

)

select *
from final