-- ============================================================
-- Profile culture-organism grain and source organism vocabulary
--
-- Organism labels in this analysis are still the original
-- source labels. Terminology standardization will be handled
-- in a later mapping/dimension step.
-- ============================================================


-- ------------------------------------------------------------
-- 1. Validate fct_culture_organism grain.
-- ------------------------------------------------------------

select
    count(*) as culture_organism_rows,
    count(distinct culture_organism_key) as distinct_keys,
    count(distinct culture_key) as cultures_with_organisms,
    sum(
        case
            when has_repeated_antibiotic_records then 1
            else 0
        end
    ) as groups_with_repeated_antibiotic_records
from workspace.micro_dev.fct_culture_organism;


-- ------------------------------------------------------------
-- 2. Most frequently occurring source organism labels.
--
-- These are not yet standardized organism names.
-- ------------------------------------------------------------

select
    organism,
    count(*) as culture_count
from workspace.micro_dev.fct_culture_organism
group by organism
order by culture_count desc
limit 50;


-- ------------------------------------------------------------
-- 3. Count distinct source organism labels.
-- ------------------------------------------------------------

select
    count(distinct organism) as distinct_source_organism_names
from workspace.micro_dev.fct_culture_organism;


-- ------------------------------------------------------------
-- 4. Complete organism vocabulary for terminology review.
-- ------------------------------------------------------------

select
    organism,
    count(*) as culture_count
from workspace.micro_dev.fct_culture_organism
group by organism
order by organism;