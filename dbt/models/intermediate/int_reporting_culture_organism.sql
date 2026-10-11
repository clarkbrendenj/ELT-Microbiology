{{ config(materialized='view') }}

with phenotype as (

    select *
    from {{ ref('int_culture_organism_phenotype') }}

    where include_primary_summary = 1
      and mapping_status = 'reviewed'
      and organism_reporting_group is not null

),

categorized as (

    select
        *,

        /*
        Assign the reporting phenotype before any culture-level
        consolidation.

        CRE and MDR remain separate MDRO categories and therefore
        keep the base organism name.

        Oxacillin resistance, vancomycin resistance, and ESCE-R
        become distinct susceptibility-reporting organism categories.
        */
        case
            when is_cre = true
                then 'cre'

            when is_mdr_p_aeruginosa = true
                then 'mdr_p_aeruginosa'

            when is_oxacillin_resistant = true
                then 'oxacillin_resistant'

            when is_vancomycin_resistant = true
                then 'vancomycin_resistant'

            when is_esce_enterobacterales = true
                then 'esce_r'

            else 'base'
        end as reporting_phenotype,

        case
            when is_oxacillin_resistant = true
                then concat(
                    organism_reporting_group,
                    ' — oxacillin resistant'
                )

            when is_vancomycin_resistant = true
                then concat(
                    organism_reporting_group,
                    ' — vancomycin resistant'
                )

            when is_esce_enterobacterales = true
             and is_cre is not true
                then concat(
                    organism_reporting_group,
                    ' — extended-spectrum cephalosporin resistant'
                )

            else organism_reporting_group
        end as organism_name,

        case
            when is_cre = true
              or is_mdr_p_aeruginosa = true
                then false

            else true
        end as include_main_antibiogram,

        case
            when is_cre = true
                then 'cre'

            when is_mdr_p_aeruginosa = true
                then 'mdr_p_aeruginosa'

            else null
        end as main_exclusion_reason

    from phenotype

),

grouped as (

    select
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
        reporting_phenotype,
        organism_name,

        include_main_antibiogram,
        main_exclusion_reason,

        count(
            distinct culture_organism_key
        ) as source_organism_record_count,

        count(
            distinct organism_source
        ) as source_label_count,

        count(
            distinct organism_standardized
        ) as standardized_identity_count,

        array_sort(
            collect_set(culture_organism_key)
        ) as source_culture_organism_keys,

        array_sort(
            collect_set(organism_source)
        ) as source_labels,

        array_sort(
            collect_set(organism_standardized)
        ) as standardized_identities,

        array_sort(
            collect_set(source_qualifier)
        ) as source_qualifiers,

        /*
        Preserve phenotype status across any source records that
        legitimately collapse into the same reporting category.
        */

        max(
            case
                when ast_cre_status = 'positive'
                    then 1
                else 0
            end
        ) as any_cre_positive,

        max(
            case
                when ast_cre_status = 'not_evaluable'
                    then 1
                else 0
            end
        ) as any_cre_not_evaluable,

        max(
            case
                when ast_cre_status = 'not_detected'
                    then 1
                else 0
            end
        ) as any_cre_not_detected,

        max(
            case
                when ast_esce_enterobacterales_status = 'positive'
                    then 1
                else 0
            end
        ) as any_esce_positive,

        max(
            case
                when ast_esce_enterobacterales_status = 'not_evaluable'
                    then 1
                else 0
            end
        ) as any_esce_not_evaluable,

        max(
            case
                when ast_esce_enterobacterales_status = 'not_detected'
                    then 1
                else 0
            end
        ) as any_esce_not_detected,

        max(
            case
                when ast_oxacillin_resistance_status = 'positive'
                    then 1
                else 0
            end
        ) as any_oxacillin_positive,

        max(
            case
                when ast_oxacillin_resistance_status = 'not_evaluable'
                    then 1
                else 0
            end
        ) as any_oxacillin_not_evaluable,

        max(
            case
                when ast_oxacillin_resistance_status = 'not_detected'
                    then 1
                else 0
            end
        ) as any_oxacillin_not_detected,

        max(
            case
                when ast_vancomycin_resistance_status = 'positive'
                    then 1
                else 0
            end
        ) as any_vre_positive,

        max(
            case
                when ast_vancomycin_resistance_status = 'not_evaluable'
                    then 1
                else 0
            end
        ) as any_vre_not_evaluable,

        max(
            case
                when ast_vancomycin_resistance_status = 'not_detected'
                    then 1
                else 0
            end
        ) as any_vre_not_detected,

        max(
            case
                when ast_mdr_p_aeruginosa_status = 'positive'
                    then 1
                else 0
            end
        ) as any_mdr_positive,

        max(
            case
                when ast_mdr_p_aeruginosa_status = 'not_evaluable'
                    then 1
                else 0
            end
        ) as any_mdr_not_evaluable,

        max(
            case
                when ast_mdr_p_aeruginosa_status = 'not_detected'
                    then 1
                else 0
            end
        ) as any_mdr_not_detected,

        max(
            cast(source_designated_cre as integer)
        ) as any_source_designated_cre,

        max(
            cast(source_designated_mrsa as integer)
        ) as any_source_designated_mrsa,

        max(
            cast(source_designated_vre as integer)
        ) as any_source_designated_vre

    from categorized

    group by
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
        reporting_phenotype,
        organism_name,

        include_main_antibiogram,
        main_exclusion_reason

),

statused as (

    select
        *,

        case
            when any_cre_positive = 1
                then 'positive'
            when any_cre_not_evaluable = 1
                then 'not_evaluable'
            when any_cre_not_detected = 1
                then 'not_detected'
            else 'not_applicable'
        end as ast_cre_status,

        case
            when any_esce_positive = 1
                then 'positive'
            when any_esce_not_evaluable = 1
                then 'not_evaluable'
            when any_esce_not_detected = 1
                then 'not_detected'
            else 'not_applicable'
        end as ast_esce_enterobacterales_status,

        case
            when any_oxacillin_positive = 1
                then 'positive'
            when any_oxacillin_not_evaluable = 1
                then 'not_evaluable'
            when any_oxacillin_not_detected = 1
                then 'not_detected'
            else 'not_applicable'
        end as ast_oxacillin_resistance_status,

        case
            when any_vre_positive = 1
                then 'positive'
            when any_vre_not_evaluable = 1
                then 'not_evaluable'
            when any_vre_not_detected = 1
                then 'not_detected'
            else 'not_applicable'
        end as ast_vancomycin_resistance_status,

        case
            when any_mdr_positive = 1
                then 'positive'
            when any_mdr_not_evaluable = 1
                then 'not_evaluable'
            when any_mdr_not_detected = 1
                then 'not_detected'
            else 'not_applicable'
        end as ast_mdr_p_aeruginosa_status

    from grouped

),

final as (

    select

        {{ dbt_utils.generate_surrogate_key([
            'source_version',
            'cohort_id',
            'culture_key',
            'organism_reporting_group',
            'reporting_phenotype'
        ]) }} as reporting_culture_organism_key,

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

        case
            when ast_cre_status = 'positive'
                then true
            when ast_cre_status = 'not_detected'
                then false
            else null
        end as is_cre,

        case
            when ast_esce_enterobacterales_status = 'positive'
                then true
            when ast_esce_enterobacterales_status = 'not_detected'
                then false
            else null
        end as is_esce_enterobacterales,

        case
            when ast_oxacillin_resistance_status = 'positive'
                then true
            when ast_oxacillin_resistance_status = 'not_detected'
                then false
            else null
        end as is_oxacillin_resistant,

        case
            when ast_vancomycin_resistance_status = 'positive'
                then true
            when ast_vancomycin_resistance_status = 'not_detected'
                then false
            else null
        end as is_vancomycin_resistant,

        case
            when ast_mdr_p_aeruginosa_status = 'positive'
                then true
            when ast_mdr_p_aeruginosa_status = 'not_detected'
                then false
            else null
        end as is_mdr_p_aeruginosa,

        any_source_designated_cre = 1
            as source_designated_cre,

        any_source_designated_mrsa = 1
            as source_designated_mrsa,

        any_source_designated_vre = 1
            as source_designated_vre

    from statused

)

select *
from final