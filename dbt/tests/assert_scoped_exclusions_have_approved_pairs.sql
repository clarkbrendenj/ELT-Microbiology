-- Scoped project exclusions must identify an existing active reviewed panel.
-- Broad species-level rules can legitimately precede panel approval.
select e.*
from {{ ref('organism_antibiotic_exclusions') }} e
where (e.cohort_id <> '*' or e.reporting_phenotype <> '*')
  and not exists (
      select 1
      from {{ ref('reportable_organism_antibiotic_pairs') }} p
      where p.organism_reporting_group = e.organism_reporting_group
        and p.antibiotic = e.antibiotic
        and (e.cohort_id = '*' or p.cohort_id = e.cohort_id)
        and p.include_primary_dashboard = 1
        and p.review_status = 'reviewed'
  )
