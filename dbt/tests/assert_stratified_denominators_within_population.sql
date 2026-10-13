-- A phenotype-specific population is a subset of the eligible patient/
-- organism universe, NOT necessarily of another displayed phenotype row.
with all_patients as (
    select source_version, cohort_id, organism_reporting_group,
           count(distinct patient_key) as unique_patients
    from {{ ref('int_culture_reporting_observation') }}
    group by source_version, cohort_id, organism_reporting_group
),
stratified_mart as (
    select source_version, cohort_id, organism_reporting_group,
           reporting_phenotype, antibiotic, eligible_count
    from {{ ref('mart_susceptibility') }}
    where reporting_phenotype <> 'overall'
)
select s.*, a.unique_patients
from stratified_mart s
left join all_patients a
    on s.source_version = a.source_version
   and s.cohort_id = a.cohort_id
   and s.organism_reporting_group = a.organism_reporting_group
where a.unique_patients is null
   or s.eligible_count > a.unique_patients
