-- Subgroups are restricted to the same first-culture population.
-- They cannot have more eligible patient-organism records than overall.
select
    s.source_version,
    s.cohort_id,
    s.organism_reporting_group,
    s.reporting_phenotype,
    s.antibiotic,
    s.eligible_count as subgroup_eligible_count,
    o.eligible_count as overall_eligible_count
from {{ ref('mart_susceptibility') }} s
left join {{ ref('mart_susceptibility') }} o
    on s.source_version = o.source_version
   and s.cohort_id = o.cohort_id
   and s.organism_reporting_group = o.organism_reporting_group
   and s.antibiotic = o.antibiotic
   and o.reporting_phenotype = 'overall'
where s.reporting_phenotype <> 'overall'
  and (
      o.susceptibility_mart_key is null
      or s.eligible_count > o.eligible_count
  )
