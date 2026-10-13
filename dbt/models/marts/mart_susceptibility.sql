{{ config(materialized='table') }}

-- Baseline organisms (base) and resistant phenotype categories are distinct
-- FIRST-WITHIN-CATEGORY populations, not exclusive patient populations.
-- Staph aureus is the sole unstratified 'overall' organism row, together
-- with separately first-selected MRSA and MSSA categories.
-- CRE/MDR P. aeruginosa observations never form a main reporting row.

with first_staph_overall as (
    select * from {{ ref('int_overall_first_reporting_isolate') }}
),
first_stratified as (
    select * from {{ ref('int_first_stratified_reporting_culture') }}
),
pairs as (
    select p.organism_reporting_group, p.cohort_id, p.antibiotic, p.pair_order
    from {{ ref('reportable_organism_antibiotic_pairs') }} p
    left join {{ ref('organism_antibiotic_exclusions') }} e
        on p.organism_reporting_group = e.organism_reporting_group
       and p.antibiotic = e.antibiotic
    where p.include_primary_dashboard = 1
      and p.review_status = 'reviewed'
      and e.organism_reporting_group is null
),
reporting_populations as (
    select
        overall_reporting_isolate_key as selected_reporting_isolate_key,
        source_version, cohort_id, patient_key, organism_reporting_group,
        organism_name, 'overall' as reporting_phenotype
    from first_staph_overall

    union all

    select
        first_stratified_reporting_culture_key as selected_reporting_isolate_key,
        source_version, cohort_id, patient_key, organism_reporting_group,
        organism_name, reporting_phenotype
    from first_stratified
),
reporting_endpoints as (
    select
        overall_reporting_isolate_key as selected_reporting_isolate_key,
        'overall' as reporting_phenotype,
        antibiotic, resolution_status, susceptibility, reconciliation_reason
    from {{ ref('int_overall_first_reporting_susceptibility') }}

    union all

    select
        first_stratified_reporting_culture_key as selected_reporting_isolate_key,
        reporting_phenotype,
        antibiotic, resolution_status, susceptibility, reconciliation_reason
    from {{ ref('int_first_stratified_reporting_susceptibility') }}
),
eligible_grid as (
    select
        f.selected_reporting_isolate_key,
        f.source_version, f.cohort_id, f.patient_key,
        f.organism_reporting_group, f.organism_name,
        f.reporting_phenotype, p.antibiotic, p.pair_order
    from reporting_populations f
    inner join pairs p
        on f.organism_reporting_group = p.organism_reporting_group
       and f.cohort_id = p.cohort_id
),
endpoint_status as (
    select g.*, r.resolution_status, r.susceptibility,
           r.reconciliation_reason
    from eligible_grid g
    left join reporting_endpoints r
        on g.selected_reporting_isolate_key = r.selected_reporting_isolate_key
       and g.reporting_phenotype = r.reporting_phenotype
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
    {{ analysis_window_start_expr() }} as analysis_window_start,
    {{ analysis_window_end_expr() }} as analysis_window_end_exclusive,
    g.gram_stain_group

from final f

left join {{ ref('organism_reporting_groups') }} g
    on f.organism_reporting_group = g.organism_reporting_group
