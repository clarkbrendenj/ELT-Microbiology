{{ config(materialized='table') }}

-- One shared reconciliation rule with two deliberately different grains:
-- 'overall'    = all source organism records on a Staph aureus culture;
-- 'stratified' = source records WITHIN a single reporting phenotype on a
--                culture (base / ESCE-R / VRE / oxacillin-resistant).
-- Never mix these sources when assigning drug results to a phenotype row.

with eligible_phenotype_groups as (
    select
        reporting_culture_organism_key,
        source_version,
        cohort_id,
        patient_key,
        organism_reporting_group,
        source_culture_organism_keys
    from {{ ref('int_reporting_culture_organism') }}
    where culture_time_shifted is not null
      and {{ analysis_window_filter('culture_time_shifted') }}
      and reporting_phenotype in (
          'base', 'esce_r', 'oxacillin_resistant', 'vancomycin_resistant'
      )
),

ast_groups as (
    select
        'overall' as ast_scope,
        reporting_culture_observation_key as reporting_source_key,
        source_version, cohort_id, patient_key, organism_reporting_group,
        source_culture_organism_keys
    from {{ ref('int_culture_reporting_observation') }}
    where organism_reporting_group = 'Staphylococcus aureus'

    union all

    select
        'stratified' as ast_scope,
        reporting_culture_organism_key as reporting_source_key,
        source_version, cohort_id, patient_key, organism_reporting_group,
        source_culture_organism_keys
    from eligible_phenotype_groups
),

exploded as (
    select
        ast_scope, reporting_source_key, source_version,
        cohort_id, patient_key, organism_reporting_group,
        explode(source_culture_organism_keys) as culture_organism_key
    from ast_groups
),

source_endpoints as (
    select
        e.ast_scope, e.reporting_source_key, e.source_version,
        e.cohort_id, e.patient_key, e.organism_reporting_group,
        e.culture_organism_key,
        r.antibiotic, r.resolution_status, r.susceptibility
    from exploded e
    inner join {{ ref('int_susceptibility_reconciliation') }} r
        on e.culture_organism_key = r.culture_organism_key
),

grouped as (
    select
        ast_scope, reporting_source_key, source_version,
        cohort_id, patient_key, organism_reporting_group, antibiotic,
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
        ast_scope, reporting_source_key, source_version,
        cohort_id, patient_key, organism_reporting_group, antibiotic
),

reconciled as (
    select
        *,
        case
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
)

select
    {{ dbt_utils.generate_surrogate_key([
        'ast_scope', 'reporting_source_key', 'antibiotic'
    ]) }} as reporting_culture_susceptibility_key,
    *
from reconciled
