{{ config(materialized='table') }}

-- All source S. aureus records on the patient's first eligible culture
-- contribute to OVERALL AST, independent of MRSA/MSSA qualification.

select
    {{ dbt_utils.generate_surrogate_key([
        'f.overall_reporting_isolate_key', 'c.antibiotic'
    ]) }} as overall_reporting_susceptibility_key,
    f.overall_reporting_isolate_key,
    f.source_version, f.cohort_id, f.patient_key,
    f.organism_reporting_group, c.antibiotic,
    c.resolution_status, c.susceptibility, c.reconciliation_reason,
    c.source_endpoint_row_count, c.source_organisms_with_endpoint,
    c.source_conflict_count, c.source_missing_count,
    c.distinct_resolved_result_count, c.resolved_results,
    c.source_resolution_statuses
from {{ ref('int_overall_first_reporting_isolate') }} f
inner join {{ ref('int_culture_reporting_susceptibility') }} c
    on f.reporting_culture_observation_key = c.reporting_source_key
   and c.ast_scope = 'overall'
