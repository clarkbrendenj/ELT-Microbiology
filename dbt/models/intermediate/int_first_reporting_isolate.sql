{{ config(materialized='table') }}

with eligible as (

    select
        reporting_culture_organism_key,

        source_version,
        patient_key,
        encounter_key,
        culture_order_key,

        cohort_id,
        culture_key,
        culture_time_shifted,
        culture_description,
        was_positive,

        organism_reporting_group,
        organism_name,
        reporting_phenotype,

        include_main_antibiogram,
        main_exclusion_reason,

        source_organism_record_count,
        source_label_count,
        standardized_identity_count,

        source_culture_organism_keys,
        source_labels,
        standardized_identities,
        source_qualifiers,

        ast_cre_status,
        ast_esce_enterobacterales_status,
        ast_oxacillin_resistance_status,
        ast_vancomycin_resistance_status,
        ast_mdr_p_aeruginosa_status,

        is_cre,
        is_esce_enterobacterales,
        is_oxacillin_resistant,
        is_vancomycin_resistant,
        is_mdr_p_aeruginosa,

        source_designated_cre,
        source_designated_mrsa,
        source_designated_vre

    from {{ ref('int_reporting_culture_organism') }}

    where culture_time_shifted is not null

),

ranked as (

    select
        *,

        row_number() over (
            partition by
                source_version,
                cohort_id,
                patient_key,
                organism_reporting_group,
                reporting_phenotype

            order by
                culture_time_shifted,
                culture_key,
                reporting_culture_organism_key
        ) as reporting_isolate_rank

    from eligible

),

final as (

    select

        {{ dbt_utils.generate_surrogate_key([
            'source_version',
            'cohort_id',
            'patient_key',
            'organism_reporting_group',
            'reporting_phenotype'
        ]) }} as first_reporting_isolate_key,

        reporting_culture_organism_key,

        source_version,
        patient_key,
        encounter_key,
        culture_order_key,

        cohort_id,
        culture_key,
        culture_time_shifted,
        culture_description,
        was_positive,

        organism_reporting_group,
        organism_name,
        reporting_phenotype,

        include_main_antibiogram,
        main_exclusion_reason,

        source_organism_record_count,
        source_label_count,
        standardized_identity_count,

        source_culture_organism_keys,
        source_labels,
        standardized_identities,
        source_qualifiers,

        ast_cre_status,
        ast_esce_enterobacterales_status,
        ast_oxacillin_resistance_status,
        ast_vancomycin_resistance_status,
        ast_mdr_p_aeruginosa_status,

        is_cre,
        is_esce_enterobacterales,
        is_oxacillin_resistant,
        is_vancomycin_resistant,
        is_mdr_p_aeruginosa,

        source_designated_cre,
        source_designated_mrsa,
        source_designated_vre,

        reporting_isolate_rank

    from ranked

    where reporting_isolate_rank = 1

)

select *
from final