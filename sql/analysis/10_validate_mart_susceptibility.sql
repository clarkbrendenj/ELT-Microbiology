-- ============================================================
-- Validate final susceptibility reporting mart
--
-- Grain:
--   source release + cohort + standardized organism
--   + reviewed antibiotic
--
-- The mart uses first eligible culture-organisms selected
-- independently of antibiotic testing or susceptibility result.
--
-- Categorized denominator:
--   Susceptible + Resistant + Intermediate
--
-- Other states remain explicit:
--   Inconclusive, Synergism, missing, conflict, untested.
-- ============================================================


-- ------------------------------------------------------------
-- 1. Confirm mart grain is unique.
-- Expected result: zero rows.
-- ------------------------------------------------------------

select
    source_version,
    cohort_id,
    organism_standardized,
    antibiotic,
    count(*) as row_count

from workspace.micro_dev.mart_susceptibility

group by
    source_version,
    cohort_id,
    organism_standardized,
    antibiotic

having count(*) > 1;


-- ------------------------------------------------------------
-- 2. Confirm every eligible record is either tested or untested.
-- Expected result: zero rows.
-- ------------------------------------------------------------

select
    cohort_id,
    organism_standardized,
    antibiotic,
    eligible_count,
    tested_endpoint_count,
    untested_count

from workspace.micro_dev.mart_susceptibility

where tested_endpoint_count + untested_count <> eligible_count;


-- ------------------------------------------------------------
-- 3. Confirm tested endpoints reconcile across result states.
-- Expected result: zero rows.
--
-- Categorized =
--   Susceptible + Resistant + Intermediate
-- ------------------------------------------------------------

select
    cohort_id,
    organism_standardized,
    antibiotic,

    tested_endpoint_count,

    categorized_count,
    susceptible_count,
    resistant_count,
    intermediate_count,

    inconclusive_count,
    synergism_count,
    missing_result_count,
    conflict_result_count

from workspace.micro_dev.mart_susceptibility

where tested_endpoint_count <>
      categorized_count
    + inconclusive_count
    + synergism_count
    + missing_result_count
    + conflict_result_count

   or categorized_count <>
      susceptible_count
    + resistant_count
    + intermediate_count;


-- ------------------------------------------------------------
-- 4. Confirm analytical counts cannot exceed denominators.
-- Expected result: zero rows.
-- ------------------------------------------------------------

select
    cohort_id,
    organism_standardized,
    antibiotic,
    eligible_count,
    categorized_count,
    susceptible_count,
    resistant_count,
    intermediate_count

from workspace.micro_dev.mart_susceptibility

where categorized_count > eligible_count
   or susceptible_count > categorized_count
   or resistant_count > categorized_count
   or intermediate_count > categorized_count;


-- ------------------------------------------------------------
-- 5. Confirm every cohort-organism has every reviewed antibiotic
--    defined for that organism.
--
-- Expected result: zero rows.
-- ------------------------------------------------------------

with expected_pair_counts as (

    select
        organism_standardized,
        count(*) as expected_antibiotic_count

    from workspace.micro_dev.reportable_organism_antibiotic_pairs

    where include_primary_dashboard = 1
      and review_status = 'reviewed'

    group by organism_standardized

),

actual_pair_counts as (

    select
        cohort_id,
        organism_standardized,
        count(distinct antibiotic) as actual_antibiotic_count

    from workspace.micro_dev.mart_susceptibility

    group by
        cohort_id,
        organism_standardized

)

select
    a.cohort_id,
    a.organism_standardized,
    e.expected_antibiotic_count,
    a.actual_antibiotic_count

from actual_pair_counts a

inner join expected_pair_counts e
    on a.organism_standardized = e.organism_standardized

where a.actual_antibiotic_count <> e.expected_antibiotic_count;


-- ------------------------------------------------------------
-- 6. Confirm eligible_count is constant across antibiotics for
--    each cohort-organism and matches int_first_culture_organism.
--
-- Expected result: zero rows.
-- ------------------------------------------------------------

with source_counts as (

    select
        source_version,
        cohort_id,
        organism_standardized,
        count(*) as expected_eligible_count

    from workspace.micro_dev.int_first_culture_organism

    group by
        source_version,
        cohort_id,
        organism_standardized

),

mart_counts as (

    select
        source_version,
        cohort_id,
        organism_standardized,
        min(eligible_count) as min_eligible_count,
        max(eligible_count) as max_eligible_count

    from workspace.micro_dev.mart_susceptibility

    group by
        source_version,
        cohort_id,
        organism_standardized

)

select
    m.source_version,
    m.cohort_id,
    m.organism_standardized,
    s.expected_eligible_count,
    m.min_eligible_count,
    m.max_eligible_count

from mart_counts m

inner join source_counts s
    on m.source_version = s.source_version
   and m.cohort_id = s.cohort_id
   and m.organism_standardized = s.organism_standardized

where m.min_eligible_count <> m.max_eligible_count
   or m.min_eligible_count <> s.expected_eligible_count;


-- ------------------------------------------------------------
-- 7. Confirm display-status rule.
--
-- Project policy:
--   categorized_count >= 30 -> display
--   categorized_count < 30  -> insufficient_data
--
-- Expected result: zero rows.
-- ------------------------------------------------------------

select
    cohort_id,
    organism_standardized,
    antibiotic,
    categorized_count,
    display_status

from workspace.micro_dev.mart_susceptibility

where (
        categorized_count >= 30
        and display_status <> 'display'
      )
   or (
        categorized_count < 30
        and display_status <> 'insufficient_data'
      );


-- ------------------------------------------------------------
-- 8. Inspect primary blood results.
--
-- These are the values that will eventually feed the first
-- Tableau susceptibility view.
-- ------------------------------------------------------------

select
    organism_standardized,
    antibiotic,

    eligible_count,
    tested_endpoint_count,
    untested_count,
    categorized_count,

    susceptible_count,
    resistant_count,
    intermediate_count,

    inconclusive_count,
    synergism_count,
    missing_result_count,
    conflict_result_count,

    categorized_result_coverage_pct,
    susceptible_pct,
    resistant_pct,
    display_status

from workspace.micro_dev.mart_susceptibility

where cohort_id = 'blood'

order by
    organism_standardized,
    pair_order;


-- ------------------------------------------------------------
-- 9. Trace one important endpoint:
--    blood E. coli / ceftriaxone.
-- ------------------------------------------------------------

select *

from workspace.micro_dev.mart_susceptibility

where cohort_id = 'blood'
  and organism_standardized = 'Escherichia coli'
  and antibiotic = 'Ceftriaxone';