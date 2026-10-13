{{ config(materialized='table') }}

-- First culture IN EACH published phenotype class, per patient, cohort,
-- organism, and source release. The same patient can have both a base and
-- a later ESCE-R / VRE culture; MRSA and MSSA also rank independently.
-- The reference period is already limited in the candidates model.

with ranked as (
    select *,
        row_number() over (
            partition by
                source_version, cohort_id, patient_key,
                organism_reporting_group, reporting_phenotype
            order by culture_time_shifted, culture_key,
                     reporting_culture_organism_key
        ) as reporting_culture_rank
    from {{ ref('int_stratified_reporting_candidates') }}
)

select
    {{ dbt_utils.generate_surrogate_key([
        'source_version', 'cohort_id', 'patient_key',
        'organism_reporting_group', 'reporting_phenotype'
    ]) }} as first_stratified_reporting_culture_key,
    reporting_culture_organism_key,
    source_version, cohort_id, patient_key,
    organism_reporting_group, organism_name, reporting_phenotype,
    culture_key, culture_time_shifted,
    source_culture_organism_keys,
    ast_cre_status, ast_esce_enterobacterales_status,
    ast_oxacillin_resistance_status, ast_vancomycin_resistance_status,
    ast_mdr_p_aeruginosa_status
from ranked
where reporting_culture_rank = 1
