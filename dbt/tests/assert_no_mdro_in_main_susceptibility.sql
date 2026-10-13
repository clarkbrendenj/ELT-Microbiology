-- The main antibiogram must not have CRE/MDR P. aeruginosa as groups.
-- Also verify that stratified candidate source records were not classified
-- as CRE or MDR under their own source-level phenotype determination.
with forbidden_mart_categories as (
    select 'mart_forbidden_category' as violation,
           source_version, cohort_id, organism_reporting_group,
           reporting_phenotype, cast(null as string) as record_key
    from {{ ref('mart_susceptibility') }}
    where reporting_phenotype in ('cre', 'mdr_p_aeruginosa')
),
forbidden_stratified_sources as (
    select 'stratified_mdro_source' as violation,
           source_version, cohort_id, organism_reporting_group,
           reporting_phenotype,
           reporting_culture_organism_key as record_key
    from {{ ref('int_first_stratified_reporting_culture') }}
    where ast_cre_status = 'positive'
       or ast_mdr_p_aeruginosa_status = 'positive'
),
forbidden_overall_species as (
    select 'other_organism_overall' as violation,
           source_version, cohort_id, organism_reporting_group,
           reporting_phenotype, cast(null as string) as record_key
    from {{ ref('mart_susceptibility') }}
    where reporting_phenotype = 'overall'
      and organism_reporting_group <> 'Staphylococcus aureus'
)
select * from forbidden_mart_categories
union all select * from forbidden_stratified_sources
union all select * from forbidden_overall_species
