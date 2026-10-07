-- ============================================================
-- Validate culture-organism cohort membership
--
-- Cohorts are assigned using exact source culture categories.
-- No substring or inferred specimen classification is used.
-- ============================================================


-- ------------------------------------------------------------
-- 1. Culture-organism membership by cohort.
-- ------------------------------------------------------------

select
    cohort_id,
    count(*) as culture_organism_rows,
    count(distinct culture_key) as culture_orders,
    count(distinct patient_key) as patients,
    count(distinct organism) as source_organism_labels
from workspace.micro_dev.int_cohort_culture_organism
group by cohort_id
order by cohort_id;


-- ------------------------------------------------------------
-- 2. Confirm the intended grain is unique.
-- Expected result: zero rows.
-- ------------------------------------------------------------

select
    culture_organism_key,
    cohort_id,
    count(*) as row_count
from workspace.micro_dev.int_cohort_culture_organism
group by
    culture_organism_key,
    cohort_id
having count(*) > 1;


-- ------------------------------------------------------------
-- 3. Confirm every culture description maps to a defined cohort.
-- Expected result: zero rows for the current ARMD release.
-- ------------------------------------------------------------

select
    culture_description,
    count(*) as unmapped_culture_orders
from workspace.micro_dev.fct_culture
where culture_description not in (
    'BLOOD',
    'URINE',
    'RESPIRATORY'
)
group by culture_description
order by unmapped_culture_orders desc;


-- ------------------------------------------------------------
-- 4. Compare positive culture-organism memberships by cohort.
-- ------------------------------------------------------------

select
    cohort_id,
    count(*) as culture_organism_rows,
    sum(
        case when was_positive = 1 then 1 else 0 end
    ) as positive_rows
from workspace.micro_dev.int_cohort_culture_organism
group by cohort_id
order by cohort_id;