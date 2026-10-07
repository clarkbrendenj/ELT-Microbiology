{{ config(materialized='table') }}

with source as (

    select *
    from {{ ref('stg_armd_cohort') }}
    where organism is not null

),

organism_groups as (

    select
        source_version,
        patient_key,
        encounter_key,
        culture_order_key,
        organism,

        count(*) as source_row_count,

        sum(
            case
                when antibiotic is not null then 1
                else 0
            end
        ) as antibiotic_result_row_count,

        count(distinct antibiotic) as distinct_antibiotic_count,

        max(source_file) as source_file,
        max(ingested_at) as ingested_at

    from source

    group by
        source_version,
        patient_key,
        encounter_key,
        culture_order_key,
        organism

),

cultures as (

    select
        culture_key,
        source_version,
        patient_key,
        encounter_key,
        culture_order_key

    from {{ ref('fct_culture') }}

),

final as (

    select

        {{ dbt_utils.generate_surrogate_key([
            'c.culture_key',
            'o.organism'
        ]) }} as culture_organism_key,

        c.culture_key,

        o.source_version,
        o.patient_key,
        o.encounter_key,
        o.culture_order_key,
        o.organism,

        o.source_row_count,
        o.antibiotic_result_row_count,
        o.distinct_antibiotic_count,

        (
            o.antibiotic_result_row_count
            > o.distinct_antibiotic_count
        ) as has_repeated_antibiotic_records,

        o.source_file,
        o.ingested_at

    from organism_groups o

    inner join cultures c
        on o.source_version = c.source_version
        and o.patient_key = c.patient_key
        and o.encounter_key = c.encounter_key
        and o.culture_order_key = c.culture_order_key

)

select *
from final