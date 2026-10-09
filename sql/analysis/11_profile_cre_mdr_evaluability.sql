-- ============================================================
-- Profile CRE and MDR evaluability
--
-- This file evaluates whether the ARMD source contains enough
-- organism and susceptibility information to apply the accepted
-- phenotypic CRE and MDR Pseudomonas aeruginosa rules.
--
-- No phenotype classifications are written to production models
-- at this stage.
-- ============================================================


-- ------------------------------------------------------------
-- 1. Audit source organism labels eligible for CRE evaluation.
--
-- Purpose:
-- Identify every source label that would be assigned to a
-- CRE-eligible organism group before formalizing the mapping
-- in a version-controlled seed.
--
-- This CASE statement is temporary profiling logic. It will not
-- become the final production mapping without review.
-- ------------------------------------------------------------

with source_organisms as (

    select
        cohort_id,
        organism_source,

        count(*) as culture_organism_rows,
        count(distinct patient_key) as patients

    from workspace.micro_dev.int_mapped_cohort_culture_organism

    group by
        cohort_id,
        organism_source

),

classified as (

    select
        cohort_id,
        organism_source,
        culture_organism_rows,
        patients,

        case

            -- Current and phenotype-qualified E. coli labels.
            when organism_source like 'ESCHERICHIA COLI%'
                then 'Escherichia coli'

            -- Historical and current Klebsiella aerogenes labels.
            -- This condition must come before the broad
            -- Enterobacter and Klebsiella conditions.
            when organism_source = 'ZZZENTEROBACTER AEROGENES'
              or organism_source like 'KLEBSIELLA AEROGENES%'
                then 'Klebsiella aerogenes'

            -- Other Klebsiella source labels.
            when organism_source like 'KLEBSIELLA %'
                then 'Klebsiella spp.'

            -- Enterobacter source labels other than historical
            -- Enterobacter aerogenes.
            when organism_source like 'ENTEROBACTER %'
                then 'Enterobacter spp.'

            -- Citrobacter source labels, including historical
            -- labels beginning with ZZZ.
            when organism_source like 'CITROBACTER %'
              or organism_source like 'ZZZCITROBACTER %'
                then 'Citrobacter spp.'

            -- Only Serratia marcescens is included under the
            -- accepted CRE phenotype scope.
            when organism_source like 'SERRATIA MARCESCENS%'
                then 'Serratia marcescens'

            -- Proteus species, including historical labels.
            when organism_source like 'PROTEUS %'
              or organism_source like 'ZZZPROTEUS %'
                then 'Proteus spp.'

            -- Morganella scope is limited to M. morganii.
            when organism_source = 'MORGANELLA MORGANII'
                then 'Morganella morganii'

        end as cre_organism_group

    from source_organisms

)

select
    cohort_id,
    cre_organism_group,
    organism_source,
    culture_organism_rows,
    patients

from classified

where cre_organism_group is not null

order by
    cohort_id,
    cre_organism_group,
    culture_organism_rows desc,
    organism_source;