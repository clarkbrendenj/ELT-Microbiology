{{ config(materialized='view') }}

-- Phenotype-specific candidate records. The ordinary/base category is NOT
-- independently asserted to be wild-type or susceptible: an AST phenotype
-- may be not_evaluable. CRE and MDR P. aeruginosa are excluded from ALL
-- main antibiogram source groups, but remain available to mart_mdro.
-- Staph aureus is exceptional: its unstratified overall is reported
-- separately, and its only stratified categories are MRSA and MSSA.

with eligible as (
    select *
    from {{ ref('int_reporting_culture_organism') }}
    where culture_time_shifted is not null
      and {{ analysis_window_filter('culture_time_shifted') }}
),

mssa_markers as (
    select
        reporting_source_key,
        max(case
            when resolution_status = 'resolved'
             and susceptibility = 'Susceptible'
                then 1 else 0
        end) as any_susceptible_marker,
        max(case
            when resolution_status <> 'resolved'
              or coalesce(susceptibility, '') <> 'Susceptible'
                then 1 else 0
        end) as any_other_marker
    from {{ ref('int_culture_reporting_susceptibility') }}
    where ast_scope = 'stratified'
      and antibiotic in ('Oxacillin', 'Cefoxitin')
    group by reporting_source_key
),

candidate_labels as (
    -- Standard organism category, independently deduplicated from its
    -- ESCE-R or VRE category. No S. aureus base row is published.
    select r.reporting_culture_organism_key,
           r.reporting_phenotype, r.organism_reporting_group as organism_name
    from eligible r
    where r.reporting_phenotype = 'base'
      and r.organism_reporting_group <> 'Staphylococcus aureus'

    union all

    select r.reporting_culture_organism_key,
           r.reporting_phenotype,
           concat(r.organism_reporting_group, ' — ESCE-R') as organism_name
    from eligible r
    where r.reporting_phenotype = 'esce_r'
      and r.ast_cre_status <> 'positive'

    union all

    select r.reporting_culture_organism_key,
           r.reporting_phenotype,
           concat(r.organism_reporting_group, ' — VRE') as organism_name
    from eligible r
    where r.reporting_phenotype = 'vancomycin_resistant'
      and r.organism_reporting_group in (
          'Enterococcus faecalis', 'Enterococcus faecium'
      )

    union all

    select r.reporting_culture_organism_key,
           r.reporting_phenotype,
           concat(r.organism_reporting_group, ' — MRSA') as organism_name
    from eligible r
    where r.reporting_phenotype = 'oxacillin_resistant'
      and r.organism_reporting_group = 'Staphylococcus aureus'

    union all

    select r.reporting_culture_organism_key,
           'oxacillin_susceptible' as reporting_phenotype,
           concat(r.organism_reporting_group, ' — MSSA') as organism_name
    from eligible r
    inner join mssa_markers m
        on r.reporting_culture_organism_key = m.reporting_source_key
    where r.reporting_phenotype = 'base'
      and r.organism_reporting_group = 'Staphylococcus aureus'
      and r.ast_oxacillin_resistance_status = 'not_detected'
      and m.any_susceptible_marker = 1
      and m.any_other_marker = 0
)

select
    r.reporting_culture_organism_key,
    r.source_version, r.cohort_id, r.patient_key,
    r.organism_reporting_group, r.culture_key,
    r.culture_time_shifted, r.source_culture_organism_keys,
    r.ast_cre_status, r.ast_esce_enterobacterales_status,
    r.ast_oxacillin_resistance_status, r.ast_vancomycin_resistance_status,
    r.ast_mdr_p_aeruginosa_status,
    c.reporting_phenotype, c.organism_name
from candidate_labels c
inner join eligible r
    on c.reporting_culture_organism_key = r.reporting_culture_organism_key
