-- Every approved overall organism/antibiotic row uses one selected
-- first culture per patient/cohort/reporting organism.
-- The overall pool includes all resistance phenotypes.
with expected as (
    select
        source_version,
        cohort_id,
        organism_reporting_group,
        count(*) as expected_eligible_count
    from {{ ref('int_overall_first_reporting_isolate') }}
    group by source_version, cohort_id, organism_reporting_group
)

select
    m.source_version,
    m.cohort_id,
    m.organism_reporting_group,
    m.antibiotic,
    m.eligible_count,
    e.expected_eligible_count
from {{ ref('mart_susceptibility') }} m
left join expected e
    on m.source_version = e.source_version
   and m.cohort_id = e.cohort_id
   and m.organism_reporting_group = e.organism_reporting_group
where m.reporting_phenotype = 'overall'
  and (
      e.expected_eligible_count is null
      or m.eligible_count <> e.expected_eligible_count
  )
