-- ============================================================
-- Validate first eligible culture-organism selection
--
-- One culture is selected per patient, standardized organism,
-- cohort, and source release before antibiotic testing or
-- susceptibility results are considered.
--
-- Only resolved standardized culture-organism records with a
-- usable shifted culture timestamp are eligible.
-- ============================================================


-- ------------------------------------------------------------
-- 1. Final first-culture cohort sizes.
-- ------------------------------------------------------------

select
    cohort_id,
    organism_standardized,
    count(*) as first_culture_rows,
    count(distinct patient_key) as patients

from workspace.micro_dev.int_first_culture_organism

group by
    cohort_id,
    organism_standardized

order by
    cohort_id,
    first_culture_rows desc;


-- ------------------------------------------------------------
-- 2. Confirm intended grain.
-- Expected result: zero rows.
-- ------------------------------------------------------------

select
    source_version,
    cohort_id,
    patient_key,
    organism_standardized,
    count(*) as row_count

from workspace.micro_dev.int_first_culture_organism

group by
    source_version,
    cohort_id,
    patient_key,
    organism_standardized

having count(*) > 1;


-- ------------------------------------------------------------
-- 3. Confirm each selected culture is actually the earliest
--    eligible resolved culture for that patient / organism /
--    cohort.
--
-- Expected result: zero rows.
-- ------------------------------------------------------------

with expected as (

    select
        source_version,
        cohort_id,
        patient_key,
        organism_standardized,

        min(
            struct(
                culture_time_shifted,
                culture_key
            )
        ) as first_record

    from workspace.micro_dev.int_standardized_culture_organism

    where mapping_resolution_status = 'resolved'
      and culture_time_shifted is not null

    group by
        source_version,
        cohort_id,
        patient_key,
        organism_standardized

)

select
    f.source_version,
    f.cohort_id,
    f.patient_key,
    f.organism_standardized,

    f.culture_time_shifted as selected_time,
    f.culture_key as selected_culture_key,

    e.first_record.col1 as expected_time,
    e.first_record.col2 as expected_culture_key

from workspace.micro_dev.int_first_culture_organism f

inner join expected e
    on f.source_version = e.source_version
   and f.cohort_id = e.cohort_id
   and f.patient_key = e.patient_key
   and f.organism_standardized = e.organism_standardized

where f.culture_time_shifted <> e.first_record.col1
   or f.culture_key <> e.first_record.col2;


-- ------------------------------------------------------------
-- 4. Quantify resolved records excluded because the shifted
--    culture timestamp is missing.
-- ------------------------------------------------------------

select
    cohort_id,
    organism_standardized,
    count(*) as missing_timestamp_rows,
    count(distinct patient_key) as affected_patients

from workspace.micro_dev.int_standardized_culture_organism

where mapping_resolution_status = 'resolved'
  and culture_time_shifted is null

group by
    cohort_id,
    organism_standardized

order by
    missing_timestamp_rows desc;


-- ------------------------------------------------------------
-- 5. Reconcile final row count with distinct eligible
--    patient-organism combinations.
-- ------------------------------------------------------------

with eligible as (

    select
        source_version,
        cohort_id,
        patient_key,
        organism_standardized

    from workspace.micro_dev.int_standardized_culture_organism

    where mapping_resolution_status = 'resolved'
      and culture_time_shifted is not null

    group by
        source_version,
        cohort_id,
        patient_key,
        organism_standardized

)

select
    (select count(*) from eligible)
        as eligible_patient_organism_groups,

    (
        select count(*)
        from workspace.micro_dev.int_first_culture_organism
    ) as selected_first_culture_rows;