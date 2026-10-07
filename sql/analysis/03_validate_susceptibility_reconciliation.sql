-- ============================================================
-- Validate antimicrobial susceptibility reconciliation
--
-- Source records may contain repeated or conflicting results
-- for the same culture-organism-antibiotic combination.
--
-- Only unambiguous results are promoted to fct_susceptibility.
-- Missing and conflicting result groups remain available in
-- int_susceptibility_exceptions for review.
-- ============================================================


-- ------------------------------------------------------------
-- 1. Distribution of reconciliation outcomes.
-- ------------------------------------------------------------

select
    resolution_status,
    count(*) as susceptibility_groups,
    sum(source_row_count) as source_rows
from workspace.micro_dev.int_susceptibility_reconciliation
group by resolution_status
order by resolution_status;


-- ------------------------------------------------------------
-- 2. Validate fct_susceptibility uniqueness.
-- ------------------------------------------------------------

select
    count(*) as susceptibility_rows,
    count(distinct susceptibility_key) as distinct_susceptibility_keys
from workspace.micro_dev.fct_susceptibility;


-- ------------------------------------------------------------
-- 3. Explicitly check for duplicate analytical endpoints.
-- Expected result: zero rows.
-- ------------------------------------------------------------

select
    culture_organism_key,
    antibiotic,
    count(*) as result_count
from workspace.micro_dev.fct_susceptibility
group by
    culture_organism_key,
    antibiotic
having count(*) > 1
order by result_count desc;


-- ------------------------------------------------------------
-- 4. Distribution of retained susceptibility categories.
-- ------------------------------------------------------------

select
    susceptibility,
    count(*) as result_count
from workspace.micro_dev.fct_susceptibility
group by susceptibility
order by result_count desc;


-- ------------------------------------------------------------
-- 5. Summarize excluded exception types.
-- ------------------------------------------------------------

select
    resolution_status,
    count(*) as susceptibility_groups,
    sum(source_row_count) as source_rows
from workspace.micro_dev.int_susceptibility_exceptions
group by resolution_status
order by resolution_status;


-- ------------------------------------------------------------
-- 6. Inspect high-complexity exception groups.
-- ------------------------------------------------------------

select
    resolution_status,
    organism,
    antibiotic,
    distinct_result_state_count,
    distinct_nonnull_category_count,
    missing_susceptibility_row_count,
    repeated_result_row_count,
    source_row_count
from workspace.micro_dev.int_susceptibility_exceptions
order by
    distinct_result_state_count desc,
    source_row_count desc
limit 50;


-- ------------------------------------------------------------
-- 7. Examine the most common organism-antibiotic combinations
--    among conflicting groups.
-- ------------------------------------------------------------

select
    organism,
    antibiotic,
    count(*) as conflicting_groups
from workspace.micro_dev.int_susceptibility_exceptions
where resolution_status = 'conflict'
group by
    organism,
    antibiotic
order by conflicting_groups desc
limit 50;