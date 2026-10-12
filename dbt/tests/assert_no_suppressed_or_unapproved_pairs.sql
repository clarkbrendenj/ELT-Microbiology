-- Every mart pair must be a reviewed, active, cohort-specific pair
-- and must not be on the exclusion override list.
with mart_pairs as (
    select distinct
        organism_reporting_group,
        cohort_id,
        antibiotic
    from {{ ref('mart_susceptibility') }}
),

approved as (
    select
        organism_reporting_group,
        cohort_id,
        antibiotic
    from {{ ref('reportable_organism_antibiotic_pairs') }}
    where include_primary_dashboard = 1
      and review_status = 'reviewed'
)

select m.*, 'not_approved' as failing_rule
from mart_pairs m
left join approved a
    on m.organism_reporting_group = a.organism_reporting_group
   and m.cohort_id = a.cohort_id
   and m.antibiotic = a.antibiotic
where a.organism_reporting_group is null

union all

select m.*, 'explicitly_excluded' as failing_rule
from mart_pairs m
inner join {{ ref('organism_antibiotic_exclusions') }} e
    on m.organism_reporting_group = e.organism_reporting_group
   and m.antibiotic = e.antibiotic
