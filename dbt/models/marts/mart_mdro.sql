{{ config(materialized='table') }}

with reporting_records as (

    select *
    from {{ ref('int_reporting_culture_organism') }}

    where culture_time_shifted is not null

),

/* ---------------------------------------------------------
   CRE: one patient-level state per base reporting organism
   --------------------------------------------------------- */

cre_patient_status as (

    select
        source_version,
        cohort_id,
        patient_key,
        organism_reporting_group,

        case
            when max(
                case
                    when ast_cre_status = 'positive'
                        then 1
                    else 0
                end
            ) = 1
                then 'positive'

            when max(
                case
                    when ast_cre_status = 'not_evaluable'
                        then 1
                    else 0
                end
            ) = 1
                then 'not_evaluable'

            when max(
                case
                    when ast_cre_status = 'not_detected'
                        then 1
                    else 0
                end
            ) = 1
                then 'not_detected'

            else null
        end as phenotype_status

    from reporting_records

    where ast_cre_status <> 'not_applicable'

    group by
        source_version,
        cohort_id,
        patient_key,
        organism_reporting_group

),

cre_summary as (

    select
        source_version,
        cohort_id,

        organism_reporting_group
            as organism_base_name,

        'CRE' as mdro_phenotype,

        count(*) as denominator_count,

        sum(
            case
                when phenotype_status = 'positive'
                    then 1
                else 0
            end
        ) as positive_count,

        sum(
            case
                when phenotype_status = 'not_detected'
                    then 1
                else 0
            end
        ) as not_detected_count,

        sum(
            case
                when phenotype_status = 'not_evaluable'
                    then 1
                else 0
            end
        ) as not_evaluable_count

    from cre_patient_status

    group by
        source_version,
        cohort_id,
        organism_reporting_group

),

/* ---------------------------------------------------------
   MDR Pseudomonas aeruginosa
   --------------------------------------------------------- */

mdr_patient_status as (

    select
        source_version,
        cohort_id,
        patient_key,
        organism_reporting_group,

        case
            when max(
                case
                    when ast_mdr_p_aeruginosa_status = 'positive'
                        then 1
                    else 0
                end
            ) = 1
                then 'positive'

            when max(
                case
                    when ast_mdr_p_aeruginosa_status = 'not_evaluable'
                        then 1
                    else 0
                end
            ) = 1
                then 'not_evaluable'

            when max(
                case
                    when ast_mdr_p_aeruginosa_status = 'not_detected'
                        then 1
                    else 0
                end
            ) = 1
                then 'not_detected'

            else null
        end as phenotype_status

    from reporting_records

    where ast_mdr_p_aeruginosa_status <> 'not_applicable'

    group by
        source_version,
        cohort_id,
        patient_key,
        organism_reporting_group

),

mdr_summary as (

    select
        source_version,
        cohort_id,

        organism_reporting_group
            as organism_base_name,

        'MDR Pseudomonas aeruginosa'
            as mdro_phenotype,

        count(*) as denominator_count,

        sum(
            case
                when phenotype_status = 'positive'
                    then 1
                else 0
            end
        ) as positive_count,

        sum(
            case
                when phenotype_status = 'not_detected'
                    then 1
                else 0
            end
        ) as not_detected_count,

        sum(
            case
                when phenotype_status = 'not_evaluable'
                    then 1
                else 0
            end
        ) as not_evaluable_count

    from mdr_patient_status

    group by
        source_version,
        cohort_id,
        organism_reporting_group

),

combined as (

    select *
    from cre_summary

    union all

    select *
    from mdr_summary

),

final as (

    select

        {{ dbt_utils.generate_surrogate_key([
            'source_version',
            'cohort_id',
            'organism_base_name',
            'mdro_phenotype'
        ]) }} as mdro_mart_key,

        *,

        (
            positive_count
            + not_detected_count
        ) as evaluable_count,

        round(
            100.0
            * positive_count
            / nullif(denominator_count, 0),
            1
        ) as phenotype_pct,

        round(
            100.0
            * (
                positive_count
                + not_detected_count
            )
            / nullif(denominator_count, 0),
            1
        ) as evaluable_pct

    from combined

)

select *
from final