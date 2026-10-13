-- Independently verify earliest culture WITHIN each reporting category.
with ranked as (
    select
        source_version, cohort_id, patient_key, organism_reporting_group,
        reporting_phenotype, reporting_culture_organism_key,
        row_number() over (
            partition by source_version, cohort_id, patient_key,
                         organism_reporting_group, reporting_phenotype
            order by culture_time_shifted, culture_key,
                     reporting_culture_organism_key
        ) as expected_rank
    from {{ ref('int_stratified_reporting_candidates') }}
),
expected as (
    select * from ranked where expected_rank = 1
),
actual as (
    select * from {{ ref('int_first_stratified_reporting_culture') }}
)
select
    coalesce(e.source_version,a.source_version) as source_version,
    coalesce(e.cohort_id,a.cohort_id) as cohort_id,
    coalesce(e.patient_key,a.patient_key) as patient_key,
    coalesce(e.organism_reporting_group,a.organism_reporting_group) as organism_reporting_group,
    coalesce(e.reporting_phenotype,a.reporting_phenotype) as reporting_phenotype,
    e.reporting_culture_organism_key as expected_key,
    a.reporting_culture_organism_key as actual_key
from expected e
full outer join actual a
    on e.source_version = a.source_version
   and e.cohort_id = a.cohort_id
   and e.patient_key = a.patient_key
   and e.organism_reporting_group = a.organism_reporting_group
   and e.reporting_phenotype = a.reporting_phenotype
where e.reporting_culture_organism_key is null
   or a.reporting_culture_organism_key is null
   or e.reporting_culture_organism_key <> a.reporting_culture_organism_key
