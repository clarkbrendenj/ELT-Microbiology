-- ============================================================
-- Validate reviewed organism terminology mappings
--
-- Source organism labels remain unchanged in the upstream
-- clinical facts. Reviewed mappings provide standardized
-- identities for explicitly selected analytical organisms.
--
-- These checks measure mapping coverage and identify cases
-- where multiple source labels within one culture map to the
-- same standardized organism.
-- ============================================================


-- ------------------------------------------------------------
-- 1. Mapping coverage by cohort.
-- ------------------------------------------------------------

select
    cohort_id,

    count(*) as culture_organism_rows,

    sum(
        case
            when mapping_status = 'reviewed' then 1
            else 0
        end
    ) as reviewed_mapping_rows,

    round(
        100.0
        * sum(
            case
                when mapping_status = 'reviewed' then 1
                else 0
            end
        )
        / count(*),
        1
    ) as reviewed_mapping_pct,

    count(distinct organism_source) as source_organism_labels,

    count(
        distinct case
            when mapping_status = 'reviewed'
                then organism_source
        end
    ) as reviewed_source_labels,

    count(
        distinct case
            when include_primary_summary = 1
                then organism_standardized
        end
    ) as primary_standardized_organisms

from workspace.micro_dev.int_mapped_cohort_culture_organism

group by cohort_id

order by cohort_id;


-- ------------------------------------------------------------
-- 2. Most frequent source labels that remain unmapped.
--
-- This helps prioritize future terminology review without
-- automatically assigning biological identities.
-- ------------------------------------------------------------

select
    cohort_id,
    organism_source,
    count(*) as culture_organism_rows,
    count(distinct patient_key) as patients

from workspace.micro_dev.int_mapped_cohort_culture_organism

where mapping_status = 'unmapped'

group by
    cohort_id,
    organism_source

order by
    cohort_id,
    culture_organism_rows desc;


-- ------------------------------------------------------------
-- 3. Detect mapping collisions within a culture.
--
-- A collision occurs when more than one distinct source
-- organism label from the same culture maps to the same
-- standardized organism.
--
-- These must be reviewed before collapsing to a standardized
-- culture-organism grain.
-- ------------------------------------------------------------

select
    cohort_id,
    culture_key,
    organism_standardized,

    count(distinct organism_source) as source_label_count,

    array_sort(
        collect_set(organism_source)
    ) as source_labels

from workspace.micro_dev.int_mapped_cohort_culture_organism

where include_primary_summary = 1

group by
    cohort_id,
    culture_key,
    organism_standardized

having count(distinct organism_source) > 1

order by
    source_label_count desc,
    cohort_id,
    organism_standardized;


-- ------------------------------------------------------------
-- 4. Summarize mapping collisions by cohort and standardized
--    organism.
-- ------------------------------------------------------------

with collisions as (

    select
        cohort_id,
        culture_key,
        organism_standardized

    from workspace.micro_dev.int_mapped_cohort_culture_organism

    where include_primary_summary = 1

    group by
        cohort_id,
        culture_key,
        organism_standardized

    having count(distinct organism_source) > 1

)

select
    cohort_id,
    organism_standardized,
    count(*) as culture_orders_with_multiple_source_labels

from collisions

group by
    cohort_id,
    organism_standardized

order by
    culture_orders_with_multiple_source_labels desc,
    cohort_id,
    organism_standardized;


-- ------------------------------------------------------------
-- 5. Verify that every organism selected for the primary
--    summary has a standardized identity.
--
-- Expected result: zero rows.
-- ------------------------------------------------------------

select
    organism_source,
    organism_standardized,
    include_primary_summary,
    mapping_status

from workspace.micro_dev.int_mapped_cohort_culture_organism

where include_primary_summary = 1
  and organism_standardized is null;