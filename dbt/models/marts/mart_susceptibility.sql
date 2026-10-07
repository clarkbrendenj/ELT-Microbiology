{{ config(materialized='table') }}

with first_cultures as (

    select *
    from {{ ref('int_first_culture_organism') }}

),

pairs as (

    select
        organism_standardized,
        antibiotic,
        pair_order

    from {{ ref('reportable_organism_antibiotic_pairs') }}

    where include_primary_dashboard = 1
      and review_status = 'reviewed'

),

eligible_grid as (

    select
        f.source_version,
        f.cohort_id,
        f.patient_key,
        f.organism_standardized,
        f.culture_organism_key,
        p.antibiotic,
        p.pair_order

    from first_cultures f

    inner join pairs p
        on f.organism_standardized = p.organism_standardized

),

endpoint_status as (

    select
        g.*,

        r.resolution_status,
        r.susceptibility

    from eligible_grid g

    left join {{ ref('int_susceptibility_reconciliation') }} r
        on g.culture_organism_key = r.culture_organism_key
       and g.antibiotic = r.antibiotic

),

aggregated as (

    select
        source_version,
        cohort_id,
        organism_standardized,
        antibiotic,
        pair_order,

        count(*) as eligible_count,

        sum(
            case
                when resolution_status is not null then 1
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
                when resolution_status = 'missing' then 1
                else 0
            end
        ) as missing_result_count,

        sum(
            case
                when resolution_status = 'conflict' then 1
                else 0
            end
        ) as conflict_result_count,

        sum(
            case
                when resolution_status is null then 1
                else 0
            end
        ) as untested_count

    from endpoint_status

    group by
        source_version,
        cohort_id,
        organism_standardized,
        antibiotic,
        pair_order

),

final as (

    select
        {{ dbt_utils.generate_surrogate_key([
            'source_version',
            'cohort_id',
            'organism_standardized',
            'antibiotic'
        ]) }} as susceptibility_mart_key,

        *,

        round(
            100.0 * categorized_count / nullif(eligible_count, 0),
            1
        ) as categorized_result_coverage_pct,

        round(
            100.0 * susceptible_count / nullif(categorized_count, 0),
            1
        ) as susceptible_pct,

        round(
            100.0 * resistant_count / nullif(categorized_count, 0),
            1
        ) as resistant_pct,

        case
            when categorized_count >= 30
                then 'display'
            else 'insufficient_data'
        end as display_status

    from aggregated

)

select *
from final