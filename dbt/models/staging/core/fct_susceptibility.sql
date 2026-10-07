{{ config(materialized='table') }}

with resolved as (

    select *
    from {{ ref('int_susceptibility_reconciliation') }}

    where resolution_status = 'resolved'

),

final as (

    select

        {{ dbt_utils.generate_surrogate_key([
            'culture_organism_key',
            'antibiotic'
        ]) }} as susceptibility_key,

        culture_organism_key,
        culture_key,

        source_version,
        patient_key,
        encounter_key,
        culture_order_key,

        organism,
        antibiotic,
        susceptibility,

        source_row_count,
        repeated_result_row_count,

        source_file,
        ingested_at

    from resolved

)

select *
from final