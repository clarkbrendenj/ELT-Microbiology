-- Full expected approved-pair grid versus actual mart (both directions).
-- Detects entirely missing organism/drug/cohort/phenotype rows; unlike
-- a test that begins at existing mart rows.
with selected_populations as (
    select source_version, cohort_id, organism_reporting_group,
           'overall' as reporting_phenotype
    from {{ ref('int_overall_first_reporting_isolate') }}
    union all
    select source_version, cohort_id, organism_reporting_group,
           reporting_phenotype
    from {{ ref('int_first_stratified_reporting_culture') }}
),
selected_counts as (
    select source_version, cohort_id, organism_reporting_group,
           reporting_phenotype, count(*) as expected_eligible_count
    from selected_populations
    group by source_version, cohort_id, organism_reporting_group, reporting_phenotype
),
approved_pairs as (
    select p.organism_reporting_group, p.cohort_id, p.antibiotic
    from {{ ref('reportable_organism_antibiotic_pairs') }} p
    where p.review_status = 'reviewed'
      and p.include_primary_dashboard = 1
),
expected as (
    select c.*, p.antibiotic
    from selected_counts c
    inner join approved_pairs p
        on c.cohort_id = p.cohort_id
       and c.organism_reporting_group = p.organism_reporting_group
    where not exists (
        select 1
        from {{ ref('organism_antibiotic_exclusions') }} e
        where p.organism_reporting_group = e.organism_reporting_group
          and p.antibiotic = e.antibiotic
          and (e.cohort_id = '*' or c.cohort_id = e.cohort_id)
          and (e.reporting_phenotype = '*'
               or c.reporting_phenotype = e.reporting_phenotype)
    )
),
actual as (
    select source_version, cohort_id, organism_reporting_group,
           reporting_phenotype, antibiotic, eligible_count
    from {{ ref('mart_susceptibility') }}
)
select
    coalesce(e.source_version,a.source_version) as source_version,
    coalesce(e.cohort_id,a.cohort_id) as cohort_id,
    coalesce(e.organism_reporting_group,a.organism_reporting_group) as organism_reporting_group,
    coalesce(e.reporting_phenotype,a.reporting_phenotype) as reporting_phenotype,
    coalesce(e.antibiotic,a.antibiotic) as antibiotic,
    e.expected_eligible_count, a.eligible_count
from expected e
full outer join actual a
    on e.source_version = a.source_version
   and e.cohort_id = a.cohort_id
   and e.organism_reporting_group = a.organism_reporting_group
   and e.reporting_phenotype = a.reporting_phenotype
   and e.antibiotic = a.antibiotic
where e.expected_eligible_count is null
   or a.eligible_count is null
   or e.expected_eligible_count <> a.eligible_count
