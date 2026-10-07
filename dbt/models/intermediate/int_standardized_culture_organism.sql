{{ config(materialized='view') }}

with mapped as (

    select *
    from {{ ref('int_mapped_cohort_culture_organism') }}

    where include_primary_summary = 1
      and mapping_status = 'reviewed'

),

grouped as (

    select
        source_version,
        patient_key,
        encounter_key,
        culture_order_key,

        cohort_id,
        culture_key,
        culture_time_shifted,
        culture_description,
        was_positive,

        organism_standardized,

        count(distinct culture_organism_key)
            as source_organism_record_count,

        count(distinct organism_source)
            as source_label_count,

        array_sort(
            collect_set(organism_source)
        ) as source_labels,

        array_sort(
            collect_set(source_qualifier)
        ) as source_qualifiers,

        -- Safe only when exactly one source culture-organism
        -- maps to this standardized organism.
        case
            when count(distinct culture_organism_key) = 1
                then max(culture_organism_key)
        end as culture_organism_key

    from mapped

    group by
        source_version,
        patient_key,
        encounter_key,
        culture_order_key,
        cohort_id,
        culture_key,
        culture_time_shifted,
        culture_description,
        was_positive,
        organism_standardized

),

final as (

    select

        {{ dbt_utils.generate_surrogate_key([
            'source_version',
            'cohort_id',
            'culture_key',
            'organism_standardized'
        ]) }} as standardized_culture_organism_key,

        *,

        case
            when source_organism_record_count = 1
                then 'resolved'
            else 'collision'
        end as mapping_resolution_status

    from grouped

)

select *
from final