-- ============================================================
-- Validate standardized culture-organism reconciliation
--
-- Multiple source organism labels can map to the same
-- standardized organism within a single culture. Because ARMD
-- does not provide a verified isolate identifier, these cases
-- are flagged rather than arbitrarily collapsed.
-- ============================================================


-- ------------------------------------------------------------
-- 1. Reconciliation outcomes by cohort.
-- ------------------------------------------------------------

select
    cohort_id,
    mapping_resolution_status,
    count(*) as standardized_culture_organism_rows
from workspace.micro_dev.int_standardized_culture_organism
group by
    cohort_id,
    mapping_resolution_status
order by
    cohort_id,
    mapping_resolution_status;


-- ------------------------------------------------------------
-- 2. Collision burden by standardized organism.
-- ------------------------------------------------------------

select
    cohort_id,
    organism_standardized,
    count(*) as collision_cultures
from workspace.micro_dev.int_standardized_culture_organism
where mapping_resolution_status = 'collision'
group by
    cohort_id,
    organism_standardized
order by
    collision_cultures desc,
    cohort_id,
    organism_standardized;


-- ------------------------------------------------------------
-- 3. Confirm resolved records contain exactly one source
--    culture-organism record.
-- Expected result: zero rows.
-- ------------------------------------------------------------

select
    standardized_culture_organism_key,
    cohort_id,
    organism_standardized,
    source_organism_record_count,
    source_labels
from workspace.micro_dev.int_standardized_culture_organism
where mapping_resolution_status = 'resolved'
  and (
      source_organism_record_count <> 1
      or culture_organism_key is null
  );


-- ------------------------------------------------------------
-- 4. Confirm the standardized grain is unique.
-- Expected result: zero rows.
-- ------------------------------------------------------------

select
    cohort_id,
    culture_key,
    organism_standardized,
    count(*) as row_count
from workspace.micro_dev.int_standardized_culture_organism
group by
    cohort_id,
    culture_key,
    organism_standardized
having count(*) > 1;


-- ------------------------------------------------------------
-- 5. Quantify the analytical cohort remaining after ambiguous
--    standardized-organism collisions are excluded.
-- ------------------------------------------------------------

select
    cohort_id,
    organism_standardized,
    count(*) as resolved_culture_organism_rows,
    count(distinct patient_key) as patients
from workspace.micro_dev.int_standardized_culture_organism
where mapping_resolution_status = 'resolved'
group by
    cohort_id,
    organism_standardized
order by
    cohort_id,
    resolved_culture_organism_rows desc;