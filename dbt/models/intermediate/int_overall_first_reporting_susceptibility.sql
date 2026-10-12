{{ config(materialized='table') }}

-- Reconcile AST for the selected overall culture-organism.
-- All source organism keys from that culture are included, even if
-- the reporting model assigned them to different phenotype categories.

with first_overall as (

    select
        overall_reporting_isolate_key,
        source_version,
        cohort_id,
        patient_key,
        organism_reporting_group,
        source_culture_organism_keys
    from {{ ref('int_overall_first_reporting_isolate') }}

),

exploded_source_records as (

    select
        overall_reporting_isolate_key,
        source_version,
        cohort_id,
        patient_key,
        organism_reporting_group,
        explode(source_culture_organism_keys) as culture_organism_key
    from first_overall

),

source_endpoints as (

    select
        e.overall_reporting_isolate_key,
        e.source_version,
        e.cohort_id,
        e.patient_key,
        e.organism_reporting_group,
        e.culture_organism_key,
        r.antibiotic,
        r.resolution_status,
        r.susceptibility
    from exploded_source_records e
    inner join {{ ref('int_susceptibility_reconciliation') }} r
        on e.culture_organism_key = r.culture_organism_key

),

grouped as (

    select
        overall_reporting_isolate_key,
        source_version,
        cohort_id,
        patient_key,
        organism_reporting_group,
        antibiotic,
        count(*) as source_endpoint_row_count,
        count(distinct culture_organism_key) as source_organisms_with_endpoint,

        sum(case when resolution_status = 'conflict' then 1 else 0 end)
            as source_conflict_count,
        sum(case when resolution_status = 'missing' then 1 else 0 end)
            as source_missing_count,

        count(distinct case
            when resolution_status = 'resolved' then susceptibility
        end) as distinct_resolved_result_count,

        array_sort(collect_set(case
            when resolution_status = 'resolved' then susceptibility
        end)) as resolved_results,

        array_sort(collect_set(resolution_status))
            as source_resolution_statuses

    from source_endpoints
    group by
        overall_reporting_isolate_key,
        source_version,
        cohort_id,
        patient_key,
        organism_reporting_group,
        antibiotic

),

reconciled as (

    select
        *,
        case
            -- Never arbitrate discordant or pre-conflicted AST endpoints.
            when source_conflict_count > 0
              or distinct_resolved_result_count > 1 then 'conflict'
            when distinct_resolved_result_count = 1 then 'resolved'
            else 'missing'
        end as resolution_status,

        case
            when source_conflict_count = 0
             and distinct_resolved_result_count = 1
                then element_at(resolved_results, 1)
            else null
        end as susceptibility,

        case
            when source_conflict_count > 0 then 'source_endpoint_conflict'
            when distinct_resolved_result_count > 1 then 'discordant_source_results'
            when distinct_resolved_result_count = 1
             and source_missing_count > 0
                then 'resolved_with_missing_source_endpoint'
            when distinct_resolved_result_count = 1
                then 'resolved_consistent_result'
            else 'missing_only'
        end as reconciliation_reason
    from grouped

),

final as (

    select
        {{ dbt_utils.generate_surrogate_key([
            'overall_reporting_isolate_key',
            'antibiotic'
        ]) }} as overall_reporting_susceptibility_key,

        overall_reporting_isolate_key,
        source_version,
        cohort_id,
        patient_key,
        organism_reporting_group,
        antibiotic,
        resolution_status,
        susceptibility,
        reconciliation_reason,
        source_endpoint_row_count,
        source_organisms_with_endpoint,
        source_conflict_count,
        source_missing_count,
        distinct_resolved_result_count,
        resolved_results,
        source_resolution_statuses
    from reconciled

)

select *
from final
