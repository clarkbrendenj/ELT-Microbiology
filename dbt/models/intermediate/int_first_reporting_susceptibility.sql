{{ config(materialized='table') }}

with first_reporting as (

    select
        first_reporting_isolate_key,
        reporting_culture_organism_key,

        source_version,
        cohort_id,
        patient_key,

        organism_reporting_group,
        organism_name,
        reporting_phenotype,

        source_organism_record_count,
        source_culture_organism_keys

    from {{ ref('int_first_reporting_isolate') }}

),

exploded_source_records as (

    select
        first_reporting_isolate_key,
        reporting_culture_organism_key,

        source_version,
        cohort_id,
        patient_key,

        organism_reporting_group,
        organism_name,
        reporting_phenotype,

        source_organism_record_count,

        explode(
            source_culture_organism_keys
        ) as culture_organism_key

    from first_reporting

),

source_endpoints as (

    select
        e.first_reporting_isolate_key,
        e.reporting_culture_organism_key,

        e.source_version,
        e.cohort_id,
        e.patient_key,

        e.organism_reporting_group,
        e.organism_name,
        e.reporting_phenotype,

        e.source_organism_record_count,
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
        first_reporting_isolate_key,
        reporting_culture_organism_key,

        source_version,
        cohort_id,
        patient_key,

        organism_reporting_group,
        organism_name,
        reporting_phenotype,

        antibiotic,

        count(*) as source_endpoint_row_count,

        count(
            distinct culture_organism_key
        ) as source_organisms_with_endpoint,

        sum(
            case
                when resolution_status = 'conflict'
                    then 1
                else 0
            end
        ) as source_conflict_count,

        sum(
            case
                when resolution_status = 'missing'
                    then 1
                else 0
            end
        ) as source_missing_count,

        count(
            distinct case
                when resolution_status = 'resolved'
                    then susceptibility
            end
        ) as distinct_resolved_result_count,

        array_sort(
            collect_set(
                case
                    when resolution_status = 'resolved'
                        then susceptibility
                end
            )
        ) as resolved_results,

        array_sort(
            collect_set(resolution_status)
        ) as source_resolution_statuses

    from source_endpoints

    group by
        first_reporting_isolate_key,
        reporting_culture_organism_key,

        source_version,
        cohort_id,
        patient_key,

        organism_reporting_group,
        organism_name,
        reporting_phenotype,

        antibiotic

),

reconciled as (

    select
        *,

        case
            /*
            An already-conflicting endpoint at the source-record
            level remains a conflict.
            */
            when source_conflict_count > 0
                then 'conflict'

            /*
            Different resolved interpretations across source
            organism records are also a conflict.
            */
            when distinct_resolved_result_count > 1
                then 'conflict'

            /*
            One consistent resolved interpretation is usable,
            even if another source record has an explicitly
            missing result.
            */
            when distinct_resolved_result_count = 1
                then 'resolved'

            /*
            No resolved interpretation, but at least one explicit
            missing source result.
            */
            when source_missing_count > 0
                then 'missing'

            else 'missing'
        end as resolution_status,

        case
            when source_conflict_count = 0
             and distinct_resolved_result_count = 1
                then element_at(
                    resolved_results,
                    1
                )

            else null
        end as susceptibility,

        case
            when source_conflict_count > 0
                then 'source_endpoint_conflict'

            when distinct_resolved_result_count > 1
                then 'discordant_source_results'

            when distinct_resolved_result_count = 1
             and source_missing_count > 0
                then 'resolved_with_missing_source_endpoint'

            when distinct_resolved_result_count = 1
                then 'resolved_consistent_result'

            when source_missing_count > 0
                then 'missing_only'

            else 'missing_only'
        end as reconciliation_reason

    from grouped

),

final as (

    select

        {{ dbt_utils.generate_surrogate_key([
            'first_reporting_isolate_key',
            'antibiotic'
        ]) }} as reporting_susceptibility_key,

        first_reporting_isolate_key,
        reporting_culture_organism_key,

        source_version,
        cohort_id,
        patient_key,

        organism_reporting_group,
        organism_name,
        reporting_phenotype,

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