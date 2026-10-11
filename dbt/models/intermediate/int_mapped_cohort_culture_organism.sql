{{ config(materialized='view') }}

with cohort_culture_organisms as (

    select *
    from {{ ref('int_cohort_culture_organism') }}

),

organisms as (

    select *
    from {{ ref('dim_organism') }}

),

final as (

    select
        cco.culture_organism_key,
        cco.culture_key,

        cco.source_version,
        cco.patient_key,
        cco.encounter_key,
        cco.culture_order_key,

        cco.cohort_id,
        cco.culture_time_shifted,
        cco.culture_description,
        cco.was_positive,

        -- Preserve the exact source label.
        cco.organism as organism_source,

        -- Reviewed terminology attributes.
        d.organism_source_key,
        d.organism_standardized,
        d.organism_reporting_group,
        d.source_qualifier,
        d.include_primary_summary,
        d.mapping_status,
        d.has_reviewed_mapping

    from cohort_culture_organisms cco

    inner join organisms d
        on cco.organism = d.organism_source

)

select *
from final