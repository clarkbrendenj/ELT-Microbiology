{{ config(materialized='table') }}

with source_vocabulary as (

    select distinct
        organism as organism_source

    from {{ ref('fct_culture_organism') }}

    where organism is not null

),

mapping as (

    select
        organism_source,
        organism_standardized,
        nullif(trim(source_qualifier), '') as source_qualifier,
        cast(include_primary_summary as integer) as include_primary_summary,
        mapping_status,
        notes

    from {{ ref('organism_mapping') }}

),

final as (

    select

        {{ dbt_utils.generate_surrogate_key([
            'v.organism_source'
        ]) }} as organism_source_key,

        v.organism_source,

        m.organism_standardized,
        m.source_qualifier,

        coalesce(
            m.include_primary_summary,
            0
        ) as include_primary_summary,

        case
            when m.organism_source is null
                then 'unmapped'
            else m.mapping_status
        end as mapping_status,

        case
            when m.organism_source is not null
                then true
            else false
        end as has_reviewed_mapping,

        m.notes

    from source_vocabulary v

    left join mapping m
        on v.organism_source = m.organism_source

)

select *
from final