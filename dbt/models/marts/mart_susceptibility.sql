{{ config(materialized='table') }}

-- Conventional organism-level susceptibility: select the earliest culture
-- per patient/cohort/reporting organism regardless of resistance phenotype.
-- Phenotype-specific rows below are SUBSETS OF THIS SAME SELECTED POPULATION,
-- not separately selected "first positive phenotype" observations.
-- CRE and MDR records are included in the overall organism denominator.
-- The independent MDRO prevalence mart retains its own any-positive policy.

with first_overall as (

    select *
    from {{ ref('int_overall_first_reporting_isolate') }}

),

pairs as (

    select
        p.organism_reporting_group,
        p.cohort_id,
        p.antibiotic,
        p.pair_order
    from {{ ref('reportable_organism_antibiotic_pairs') }} p
    left join {{ ref('organism_antibiotic_exclusions') }} e
        on p.organism_reporting_group = e.organism_reporting_group
       and p.antibiotic = e.antibiotic
    where p.include_primary_dashboard = 1
      and p.review_status = 'reviewed'
      and e.organism_reporting_group is null

),

-- Label MSSA only if the overall isolate has a clean, resolved,
-- susceptible oxacillin/cefoxitin marker (not just absence of R).
-- The original categorical ARMD AST cannot reconstruct numeric MICs.
mssa_markers as (

    select
        overall_reporting_isolate_key,
        max(case
            when resolution_status = 'resolved'
             and susceptibility = 'Susceptible' then 1
            else 0
        end) as any_susceptible_marker,
        max(case
            when resolution_status <> 'resolved'
              or susceptibility <> 'Susceptible' then 1
            else 0
        end) as any_non_susceptible_marker
    from {{ ref('int_overall_first_reporting_susceptibility') }}
    where antibiotic in ('Oxacillin', 'Cefoxitin')
    group by overall_reporting_isolate_key

),

reporting_populations as (

    -- All organism-level records: exactly one selected first culture
    -- per patient/cohort/reporting organism.
    select
        overall_reporting_isolate_key,
        source_version,
        cohort_id,
        patient_key,
        organism_reporting_group,
        organism_reporting_group as organism_name,
        'overall' as reporting_phenotype
    from first_overall

    union all

    -- Resistance-specific summaries use only the selected overall culture.
    -- CRE gets display precedence over ESCE-R, as in the original project
    -- hierarchy. CRE still contributes to the organism's OVERALL row.
    select
        overall_reporting_isolate_key,
        source_version,
        cohort_id,
        patient_key,
        organism_reporting_group,
        concat(organism_reporting_group,
               ' — extended-spectrum cephalosporin resistant') as organism_name,
        'esce_r' as reporting_phenotype
    from first_overall
    where ast_esce_enterobacterales_status = 'positive'
      and ast_cre_status <> 'positive'

    union all

    select
        overall_reporting_isolate_key,
        source_version,
        cohort_id,
        patient_key,
        organism_reporting_group,
        concat(organism_reporting_group, ' — methicillin resistant (MRSA)')
            as organism_name,
        'oxacillin_resistant' as reporting_phenotype
    from first_overall
    where organism_reporting_group = 'Staphylococcus aureus'
      and ast_oxacillin_resistance_status = 'positive'

    union all

    -- MSSA is supported only by an unambiguous susceptible marker.
    -- An unknown/Intermediate phenotype must not be called MSSA.
    select
        f.overall_reporting_isolate_key,
        f.source_version,
        f.cohort_id,
        f.patient_key,
        f.organism_reporting_group,
        concat(f.organism_reporting_group,
               ' — methicillin susceptible (MSSA)') as organism_name,
        'oxacillin_susceptible' as reporting_phenotype
    from first_overall f
    inner join mssa_markers m
        on f.overall_reporting_isolate_key = m.overall_reporting_isolate_key
    where f.organism_reporting_group = 'Staphylococcus aureus'
      and f.ast_oxacillin_resistance_status = 'not_detected'
      and m.any_susceptible_marker = 1
      and m.any_non_susceptible_marker = 0

    union all

    select
        overall_reporting_isolate_key,
        source_version,
        cohort_id,
        patient_key,
        organism_reporting_group,
        concat(organism_reporting_group, ' — vancomycin resistant')
            as organism_name,
        'vancomycin_resistant' as reporting_phenotype
    from first_overall
    where ast_vancomycin_resistance_status = 'positive'
      and organism_reporting_group in (
          'Enterococcus faecalis',
          'Enterococcus faecium'
      )

),

eligible_grid as (

    select
        f.overall_reporting_isolate_key,
        f.source_version,
        f.cohort_id,
        f.patient_key,
        f.organism_reporting_group,
        f.organism_name,
        f.reporting_phenotype,
        p.antibiotic,
        p.pair_order
    from reporting_populations f
    inner join pairs p
        on f.organism_reporting_group = p.organism_reporting_group
       and f.cohort_id = p.cohort_id

),

endpoint_status as (

    select
        g.*,

        r.resolution_status,
        r.susceptibility,
        r.reconciliation_reason

    from eligible_grid g

    left join {{ ref('int_overall_first_reporting_susceptibility') }} r
        on g.overall_reporting_isolate_key
         = r.overall_reporting_isolate_key
       and g.antibiotic = r.antibiotic

),

aggregated as (

    select
        source_version,
        cohort_id,

        organism_reporting_group,
        organism_name,
        reporting_phenotype,

        antibiotic,
        pair_order,

        count(*) as eligible_count,

        sum(
            case
                when resolution_status is not null
                    then 1
                else 0
            end
        ) as tested_endpoint_count,

        sum(
            case
                when resolution_status = 'resolved'
                 and susceptibility in (
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
                when resolution_status = 'resolved'
                 and susceptibility = 'Susceptible'
                    then 1
                else 0
            end
        ) as susceptible_count,

        sum(
            case
                when resolution_status = 'resolved'
                 and susceptibility = 'Resistant'
                    then 1
                else 0
            end
        ) as resistant_count,

        sum(
            case
                when resolution_status = 'resolved'
                 and susceptibility = 'Intermediate'
                    then 1
                else 0
            end
        ) as intermediate_count,

        sum(
            case
                when resolution_status = 'resolved'
                 and susceptibility = 'Inconclusive'
                    then 1
                else 0
            end
        ) as inconclusive_count,

        sum(
            case
                when resolution_status = 'resolved'
                 and susceptibility = 'Synergism'
                    then 1
                else 0
            end
        ) as synergism_count,

        sum(
            case
                when resolution_status = 'missing'
                    then 1
                else 0
            end
        ) as missing_result_count,

        sum(
            case
                when resolution_status = 'conflict'
                    then 1
                else 0
            end
        ) as conflict_result_count,

        sum(
            case
                when resolution_status is null
                    then 1
                else 0
            end
        ) as untested_count

    from endpoint_status

    group by
        source_version,
        cohort_id,

        organism_reporting_group,
        organism_name,
        reporting_phenotype,

        antibiotic,
        pair_order

),

final as (

    select

        {{ dbt_utils.generate_surrogate_key([
            'source_version',
            'cohort_id',
            'organism_reporting_group',
            'reporting_phenotype',
            'antibiotic'
        ]) }} as susceptibility_mart_key,

        *,

        round(
            100.0
            * categorized_count
            / nullif(eligible_count, 0),
            1
        ) as categorized_result_coverage_pct,

        round(
            100.0
            * susceptible_count
            / nullif(categorized_count, 0),
            1
        ) as susceptible_pct,

        round(
            100.0
            * resistant_count
            / nullif(categorized_count, 0),
            1
        ) as resistant_pct,

        case
            when categorized_count >= 30
                then 'display'
            else 'insufficient_data'
        end as display_status

    from aggregated

)

select
    f.*,
    g.gram_stain_group

from final f

left join {{ ref('organism_reporting_groups') }} g
    on f.organism_reporting_group = g.organism_reporting_group