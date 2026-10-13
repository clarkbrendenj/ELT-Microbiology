{{ config(materialized='table') }}

-- Overall S. aureus only: earliest Staphylococcus aureus culture per
-- patient/cohort/release, independent of phenotype. Other organisms are
-- reported as separate baseline and resistance-phenotype groups.

with
ranked as (

    select
        *,
        row_number() over (
            partition by
                source_version,
                cohort_id,
                patient_key,
                organism_reporting_group
            order by
                culture_time_shifted,
                culture_key
        ) as overall_isolate_rank
    from {{ ref('int_culture_reporting_observation') }}
    where organism_reporting_group = 'Staphylococcus aureus'

),

final as (

    select
        {{ dbt_utils.generate_surrogate_key([
            'source_version',
            'cohort_id',
            'patient_key',
            'organism_reporting_group'
        ]) }} as overall_reporting_isolate_key,

        source_version,
        cohort_id,
        patient_key,
        organism_reporting_group,
        organism_reporting_group as organism_name,
        culture_key,
        culture_time_shifted,
        reporting_culture_observation_key,
        source_culture_organism_keys,
        size(source_culture_organism_keys)
            as source_organism_record_count,
        source_reporting_phenotypes,
        phenotype_records_on_culture,
        ast_cre_status,
        ast_esce_enterobacterales_status,
        ast_oxacillin_resistance_status,
        ast_vancomycin_resistance_status,
        ast_mdr_p_aeruginosa_status

    from ranked
    where overall_isolate_rank = 1

)

select *
from final
