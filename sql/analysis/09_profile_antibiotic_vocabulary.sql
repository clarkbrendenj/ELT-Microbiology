-- ============================================================
-- Profile antibiotic vocabulary and candidate reportable pairs
--
-- The first eligible culture-organism has already been selected
-- independently of antibiotic testing and susceptibility result.
--
-- This analysis evaluates which antibiotics were tested for the
-- selected records and measures usable categorized-result
-- coverage before a reviewed organism-antibiotic reporting grid
-- is defined.
--
-- Categorized results are source categories:
--   Susceptible, Resistant, Intermediate
--
-- Inconclusive, Synergism, missing, and conflicting results are
-- counted separately and are not included in the categorized
-- denominator.
-- ============================================================


-- ------------------------------------------------------------
-- 1. Antibiotic vocabulary represented among selected
--    first culture-organism records.
-- ------------------------------------------------------------

select
    r.antibiotic,
    count(*) as endpoint_groups,
    count(distinct f.culture_organism_key) as culture_organisms,
    count(distinct f.patient_key) as patients

from workspace.micro_dev.int_first_culture_organism f

inner join workspace.micro_dev.int_susceptibility_reconciliation r
    on f.culture_organism_key = r.culture_organism_key

where r.antibiotic is not null

group by r.antibiotic

order by endpoint_groups desc, r.antibiotic;


-- ------------------------------------------------------------
-- 2. Blood-cohort organism-antibiotic coverage.
--
-- eligible_count:
--   first eligible culture-organisms for the organism
--
-- categorized_count:
--   Susceptible + Resistant + Intermediate
--
-- categorized_result_coverage_pct:
--   categorized_count / eligible_count
--
-- endpoint_groups counts all records where the antibiotic
-- appears, including missing/conflicting/other categories.
--
-- untested_count represents eligible records with no endpoint
-- for that antibiotic.
-- ------------------------------------------------------------

with eligible as (

    select
        cohort_id,
        organism_standardized,
        count(*) as eligible_count

    from workspace.micro_dev.int_first_culture_organism

    group by
        cohort_id,
        organism_standardized

),

endpoints as (

    select
        f.cohort_id,
        f.organism_standardized,
        r.antibiotic,

        count(*) as endpoint_groups,

        sum(
            case
                when r.resolution_status = 'resolved'
                 and r.susceptibility in (
                     'Susceptible',
                     'Resistant',
                     'Intermediate'
                 )
                    then 1
                else 0
            end
        ) as categorized_count,

        sum(
            case
                when r.resolution_status = 'resolved'
                 and r.susceptibility = 'Susceptible'
                    then 1
                else 0
            end
        ) as susceptible_count,

        sum(
            case
                when r.resolution_status = 'resolved'
                 and r.susceptibility = 'Resistant'
                    then 1
                else 0
            end
        ) as resistant_count,

        sum(
            case
                when r.resolution_status = 'resolved'
                 and r.susceptibility = 'Intermediate'
                    then 1
                else 0
            end
        ) as intermediate_count,

        sum(
            case
                when r.resolution_status = 'resolved'
                 and r.susceptibility = 'Inconclusive'
                    then 1
                else 0
            end
        ) as inconclusive_count,

        sum(
            case
                when r.resolution_status = 'resolved'
                 and r.susceptibility = 'Synergism'
                    then 1
                else 0
            end
        ) as synergism_count,

        sum(
            case
                when r.resolution_status = 'missing'
                    then 1
                else 0
            end
        ) as missing_result_count,

        sum(
            case
                when r.resolution_status = 'conflict'
                    then 1
                else 0
            end
        ) as conflict_result_count

    from workspace.micro_dev.int_first_culture_organism f

    inner join workspace.micro_dev.int_susceptibility_reconciliation r
        on f.culture_organism_key = r.culture_organism_key

    where r.antibiotic is not null

    group by
        f.cohort_id,
        f.organism_standardized,
        r.antibiotic

)

select
    e.organism_standardized,
    p.antibiotic,

    e.eligible_count,
    p.endpoint_groups,

    e.eligible_count - p.endpoint_groups
        as untested_count,

    p.categorized_count,
    p.susceptible_count,
    p.resistant_count,
    p.intermediate_count,

    p.inconclusive_count,
    p.synergism_count,
    p.missing_result_count,
    p.conflict_result_count,

    round(
        100.0 * p.categorized_count / e.eligible_count,
        1
    ) as categorized_result_coverage_pct

from endpoints p

inner join eligible e
    on p.cohort_id = e.cohort_id
   and p.organism_standardized = e.organism_standardized

where p.cohort_id = 'blood'

order by
    e.organism_standardized,
    p.categorized_count desc,
    p.antibiotic;


-- ------------------------------------------------------------
-- 3. Top 10 candidate antibiotics per blood organism based
--    only on categorized-result count.
--
-- This is a profiling aid, not an automatic rule for inclusion.
-- Final organism-antibiotic pairs will be explicitly reviewed.
-- ------------------------------------------------------------

with eligible as (

    select
        cohort_id,
        organism_standardized,
        count(*) as eligible_count

    from workspace.micro_dev.int_first_culture_organism

    where cohort_id = 'blood'

    group by
        cohort_id,
        organism_standardized

),

pair_counts as (

    select
        f.organism_standardized,
        r.antibiotic,

        count(
            case
                when r.resolution_status = 'resolved'
                 and r.susceptibility in (
                     'Susceptible',
                     'Resistant',
                     'Intermediate'
                 )
                    then 1
            end
        ) as categorized_count

    from workspace.micro_dev.int_first_culture_organism f

    inner join workspace.micro_dev.int_susceptibility_reconciliation r
        on f.culture_organism_key = r.culture_organism_key

    where f.cohort_id = 'blood'
      and r.antibiotic is not null

    group by
        f.organism_standardized,
        r.antibiotic

),

ranked as (

    select
        p.organism_standardized,
        p.antibiotic,
        e.eligible_count,
        p.categorized_count,

        round(
            100.0 * p.categorized_count / e.eligible_count,
            1
        ) as categorized_result_coverage_pct,

        row_number() over (
            partition by p.organism_standardized
            order by
                p.categorized_count desc,
                p.antibiotic
        ) as antibiotic_rank

    from pair_counts p

    inner join eligible e
        on p.organism_standardized = e.organism_standardized

)

select *
from ranked
where antibiotic_rank <= 10

order by
    organism_standardized,
    antibiotic_rank;


-- ------------------------------------------------------------
-- 4. Detect possible formatting variants in antibiotic labels.
--
-- Expected result may be zero rows. Any matches require manual
-- review before terminology mappings are introduced.
-- ------------------------------------------------------------

select
    lower(trim(antibiotic)) as normalized_label,
    count(distinct antibiotic) as source_label_count,
    array_sort(collect_set(antibiotic)) as source_labels

from workspace.micro_dev.int_susceptibility_reconciliation

where antibiotic is not null

group by lower(trim(antibiotic))

having count(distinct antibiotic) > 1

order by source_label_count desc, normalized_label;