{{ config(materialized='table') }}

-- Only the source organism records within the selected phenotype category
-- contribute AST to this row. Do not merge a source ESCE-R strain's AST
-- with the base source label when both appear on one culture.

select
    {{ dbt_utils.generate_surrogate_key([
        'f.first_stratified_reporting_culture_key', 'c.antibiotic'
    ]) }} as first_stratified_reporting_susceptibility_key,
    f.first_stratified_reporting_culture_key,
    f.source_version, f.cohort_id, f.patient_key,
    f.organism_reporting_group, f.reporting_phenotype,
    c.antibiotic, c.resolution_status, c.susceptibility,
    c.reconciliation_reason, c.source_endpoint_row_count,
    c.source_organisms_with_endpoint, c.source_conflict_count,
    c.source_missing_count, c.distinct_resolved_result_count,
    c.resolved_results, c.source_resolution_statuses
from {{ ref('int_first_stratified_reporting_culture') }} f
inner join {{ ref('int_culture_reporting_susceptibility') }} c
    on f.reporting_culture_organism_key = c.reporting_source_key
   and c.ast_scope = 'stratified'
