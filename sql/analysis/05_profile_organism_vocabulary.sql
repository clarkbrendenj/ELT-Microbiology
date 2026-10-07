-- ============================================================
-- Profile source organism vocabulary
--
-- Source organism labels are retained as supplied by ARMD.
-- This analysis identifies high-frequency labels and possible
-- terminology variants before reviewed organism mappings are
-- introduced.
-- ============================================================


-- ------------------------------------------------------------
-- 1. Organism frequency by cohort.
-- ------------------------------------------------------------

select
    cohort_id,
    organism,
    count(*) as culture_organism_rows,
    count(distinct patient_key) as patients
from workspace.micro_dev.int_cohort_culture_organism
group by
    cohort_id,
    organism
order by
    cohort_id,
    culture_organism_rows desc;


-- ------------------------------------------------------------
-- 2. Overall organism frequency.
-- ------------------------------------------------------------

select
    organism,
    count(*) as culture_organism_rows,
    count(distinct culture_key) as culture_orders,
    count(distinct patient_key) as patients
from workspace.micro_dev.int_cohort_culture_organism
group by organism
order by culture_organism_rows desc;


-- ------------------------------------------------------------
-- 3. Identify labels containing qualifiers that may require
--    reviewed terminology decisions.
-- ------------------------------------------------------------

select
    organism,
    count(*) as culture_organism_rows
from workspace.micro_dev.int_cohort_culture_organism
where organism like '%SPECIES%'
   or organism like '%GROUP%'
   or organism like '%COMPLEX%'
   or organism like '%MUCOID%'
   or organism like '%CF%'
group by organism
order by culture_organism_rows desc;


-- ------------------------------------------------------------
-- 4. Count source organism labels by cohort.
-- ------------------------------------------------------------

select
    cohort_id,
    count(distinct organism) as distinct_source_organism_labels
from workspace.micro_dev.int_cohort_culture_organism
group by cohort_id
order by cohort_id;