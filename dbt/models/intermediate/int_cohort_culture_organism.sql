{{ config(materialized='view') }}

with culture_organisms as (

    select *
    from {{ ref('fct_culture_organism') }}

),

cultures as (

    select
        culture_key,
        culture_time_shifted,
        culture_description,
        was_positive
    from {{ ref('fct_culture') }}

),

joined as (

    select
        co.culture_organism_key,
        co.culture_key,

        co.source_version,
        co.patient_key,
        co.encounter_key,
        co.culture_order_key,

        co.organism,

        c.culture_time_shifted,
        c.culture_description,
        c.was_positive,

        case
            when c.culture_description = 'BLOOD'
                then 'blood'
            when c.culture_description = 'URINE'
                then 'urine'
            when c.culture_description = 'RESPIRATORY'
                then 'respiratory'
        end as cohort_id

    from culture_organisms co

    inner join cultures c
        on co.culture_key = c.culture_key

),

final as (

    select *
    from joined
    where cohort_id is not null

)

select *
from final