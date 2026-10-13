{{ config(materialized='view') }}

-- Shared culture-organism population before any patient-level deduplication.
-- Consolidate across phenotype labels on the SAME culture.
-- With an optional 12-month shifted-date filter, this model defines the
-- period-eligible research population for both susceptibility branches.

with reporting_rows as (

    select
        reporting_culture_organism_key,
        source_version,
        cohort_id,
        patient_key,
        culture_key,
        culture_time_shifted,
        organism_reporting_group,
        reporting_phenotype,
        source_culture_organism_keys,
        ast_cre_status,
        ast_esce_enterobacterales_status,
        ast_oxacillin_resistance_status,
        ast_vancomycin_resistance_status,
        ast_mdr_p_aeruginosa_status
    from {{ ref('int_reporting_culture_organism') }}
    where culture_time_shifted is not null
      and {{ analysis_window_filter('culture_time_shifted') }}

),

culture_organism as (

    select
        source_version,
        cohort_id,
        patient_key,
        organism_reporting_group,
        culture_key,
        min(culture_time_shifted) as culture_time_shifted,

        -- Source labels in different reporting phenotypes on one culture
        -- still belong to the same overall culture-organism observation.
        array_sort(array_distinct(flatten(
            collect_list(source_culture_organism_keys)
        ))) as source_culture_organism_keys,

        array_sort(collect_set(reporting_phenotype))
            as source_reporting_phenotypes,

        count(distinct reporting_culture_organism_key)
            as phenotype_records_on_culture,

        -- Keep phenotype evidence available on the selected overall record.
        -- Positive > not_evaluable > not_detected > not_applicable.
        max(case when ast_cre_status = 'positive' then 1 else 0 end)
            as any_cre_positive,

        max(case when ast_cre_status = 'not_evaluable' then 1 else 0 end)
            as any_cre_not_evaluable,

        max(case when ast_cre_status = 'not_detected' then 1 else 0 end)
            as any_cre_not_detected,

        max(case when ast_esce_enterobacterales_status = 'positive' then 1 else 0 end)
            as any_esce_positive,

        max(case when ast_esce_enterobacterales_status = 'not_evaluable' then 1 else 0 end)
            as any_esce_not_evaluable,

        max(case when ast_esce_enterobacterales_status = 'not_detected' then 1 else 0 end)
            as any_esce_not_detected,

        max(case when ast_oxacillin_resistance_status = 'positive' then 1 else 0 end)
            as any_oxacillin_positive,

        max(case when ast_oxacillin_resistance_status = 'not_evaluable' then 1 else 0 end)
            as any_oxacillin_not_evaluable,

        max(case when ast_oxacillin_resistance_status = 'not_detected' then 1 else 0 end)
            as any_oxacillin_not_detected,

        max(case when ast_vancomycin_resistance_status = 'positive' then 1 else 0 end)
            as any_vancomycin_positive,

        max(case when ast_vancomycin_resistance_status = 'not_evaluable' then 1 else 0 end)
            as any_vancomycin_not_evaluable,

        max(case when ast_vancomycin_resistance_status = 'not_detected' then 1 else 0 end)
            as any_vancomycin_not_detected,

        max(case when ast_mdr_p_aeruginosa_status = 'positive' then 1 else 0 end)
            as any_mdr_positive,

        max(case when ast_mdr_p_aeruginosa_status = 'not_evaluable' then 1 else 0 end)
            as any_mdr_not_evaluable,

        max(case when ast_mdr_p_aeruginosa_status = 'not_detected' then 1 else 0 end)
            as any_mdr_not_detected

    from reporting_rows
    group by
        source_version,
        cohort_id,
        patient_key,
        organism_reporting_group,
        culture_key

),

statused as (

    select
        *,
        case
            when any_cre_positive = 1 then 'positive'
            when any_cre_not_evaluable = 1 then 'not_evaluable'
            when any_cre_not_detected = 1 then 'not_detected'
            else 'not_applicable'
        end as ast_cre_status,

        case
            when any_esce_positive = 1 then 'positive'
            when any_esce_not_evaluable = 1 then 'not_evaluable'
            when any_esce_not_detected = 1 then 'not_detected'
            else 'not_applicable'
        end as ast_esce_enterobacterales_status,

        case
            when any_oxacillin_positive = 1 then 'positive'
            when any_oxacillin_not_evaluable = 1 then 'not_evaluable'
            when any_oxacillin_not_detected = 1 then 'not_detected'
            else 'not_applicable'
        end as ast_oxacillin_resistance_status,

        case
            when any_vancomycin_positive = 1 then 'positive'
            when any_vancomycin_not_evaluable = 1 then 'not_evaluable'
            when any_vancomycin_not_detected = 1 then 'not_detected'
            else 'not_applicable'
        end as ast_vancomycin_resistance_status,

        case
            when any_mdr_positive = 1 then 'positive'
            when any_mdr_not_evaluable = 1 then 'not_evaluable'
            when any_mdr_not_detected = 1 then 'not_detected'
            else 'not_applicable'
        end as ast_mdr_p_aeruginosa_status

    from culture_organism

)

select
    {{ dbt_utils.generate_surrogate_key([
        'source_version',
        'cohort_id',
        'culture_key',
        'organism_reporting_group'
    ]) }} as reporting_culture_observation_key,
    *
from statused
