{{ config(materialized='table') }}

with organisms as (

    select *
    from {{ ref('int_mapped_cohort_culture_organism') }}

),

susceptibility as (

    select
        culture_organism_key,
        antibiotic,
        resolution_status,
        susceptibility

    from {{ ref('int_susceptibility_reconciliation') }}

),

organism_scope as (

    select
        o.*,

        -- CRE organism scope.
        case

            -- Proteus spp. and Morganella morganii use the CRE rule
            -- that excludes imipenem-based evidence.
            when
                o.organism_standardized = 'Morganella morganii'
                or upper(o.organism_source) like 'MORGANELLA MORGANII%'
                or o.organism_standardized like 'Proteus %'
                or upper(o.organism_source) like 'PROTEUS %'
                then 'proteus_morganella'

            -- Other reviewed NHSN CRE-eligible Enterobacterales.
            when
                o.organism_standardized like 'Citrobacter %'
                or upper(o.organism_source) like 'CITROBACTER %'
                or upper(o.organism_source) like 'ZZZCITROBACTER %'

                or o.organism_standardized like 'Enterobacter %'
                or upper(o.organism_source) like 'ENTEROBACTER %'

                or o.organism_standardized = 'Escherichia coli'
                or upper(o.organism_source) like 'ESCHERICHIA COLI%'

                or o.organism_standardized like 'Klebsiella %'
                or upper(o.organism_source) like 'KLEBSIELLA %'

                or o.organism_standardized = 'Serratia marcescens'
                or upper(o.organism_source) like 'SERRATIA MARCESCENS%'

                then 'standard'

            else null
        end as cre_rule_group,

        -- NHSN extended-spectrum cephalosporin-resistant
        -- Enterobacterales scope.
        case
            when
                o.organism_standardized in (
                    'Escherichia coli',
                    'Klebsiella aerogenes',
                    'Klebsiella oxytoca',
                    'Klebsiella pneumoniae'
                )

                or upper(o.organism_source) like 'ESCHERICHIA COLI%'
                or upper(o.organism_source) like 'KLEBSIELLA AEROGENES%'
                or upper(o.organism_source) like 'KLEBSIELLA OXYTOCA%'
                or upper(o.organism_source) like 'KLEBSIELLA PNEUMONIAE%'

                or o.organism_standardized like 'Enterobacter %'
                or upper(o.organism_source) like 'ENTEROBACTER %'

                then true
            else false
        end as esce_rule_eligible,

        case
            when o.organism_standardized = 'Staphylococcus aureus'
                then true
            else false
        end as oxacillin_rule_eligible,

        case
            when o.organism_standardized in (
                'Enterococcus faecalis',
                'Enterococcus faecium'
            )
                then true
            else false
        end as vre_rule_eligible,

        case
            when o.organism_standardized = 'Pseudomonas aeruginosa'
                then true
            else false
        end as mdr_p_aeruginosa_rule_eligible

    from organisms o

),

endpoint_counts as (

    select
        o.culture_organism_key,

        /* ---------------------------------------------------------
           CRE
           --------------------------------------------------------- */

        sum(
            case
                when (
                    (
                        o.cre_rule_group = 'standard'
                        and s.antibiotic in (
                            'Ertapenem',
                            'Imipenem',
                            'Meropenem',
                            'Meropenem/Vaborbactam',
                            'Imipenem/Relebactam'
                        )
                    )
                    or
                    (
                        o.cre_rule_group = 'proteus_morganella'
                        and s.antibiotic in (
                            'Ertapenem',
                            'Meropenem',
                            'Meropenem/Vaborbactam'
                        )
                    )
                )
                and s.resolution_status = 'resolved'
                and s.susceptibility = 'Resistant'
                    then 1
                else 0
            end
        ) as cre_resistant_endpoint_count,

        sum(
            case
                when (
                    (
                        o.cre_rule_group = 'standard'
                        and s.antibiotic in (
                            'Ertapenem',
                            'Imipenem',
                            'Meropenem',
                            'Meropenem/Vaborbactam',
                            'Imipenem/Relebactam'
                        )
                    )
                    or
                    (
                        o.cre_rule_group = 'proteus_morganella'
                        and s.antibiotic in (
                            'Ertapenem',
                            'Meropenem',
                            'Meropenem/Vaborbactam'
                        )
                    )
                )
                and s.resolution_status = 'resolved'
                and s.susceptibility in (
                    'Susceptible',
                    'Intermediate'
                )
                    then 1
                else 0
            end
        ) as cre_non_resistant_endpoint_count,

        sum(
            case
                when (
                    (
                        o.cre_rule_group = 'standard'
                        and s.antibiotic in (
                            'Ertapenem',
                            'Imipenem',
                            'Meropenem',
                            'Meropenem/Vaborbactam',
                            'Imipenem/Relebactam'
                        )
                    )
                    or
                    (
                        o.cre_rule_group = 'proteus_morganella'
                        and s.antibiotic in (
                            'Ertapenem',
                            'Meropenem',
                            'Meropenem/Vaborbactam'
                        )
                    )
                )
                and (
                    s.resolution_status <> 'resolved'
                    or s.susceptibility is null
                    or s.susceptibility not in (
                        'Susceptible',
                        'Intermediate',
                        'Resistant'
                    )
                )
                    then 1
                else 0
            end
        ) as cre_non_evaluable_endpoint_count,

        /* ---------------------------------------------------------
           ESCE-R Enterobacterales
           --------------------------------------------------------- */

        sum(
            case
                when o.esce_rule_eligible
                 and s.antibiotic in (
                     'Cefepime',
                     'Ceftriaxone',
                     'Cefotaxime',
                     'Ceftazidime',
                     'Ceftazidime/Avibactam',
                     'Ceftolozane/Tazobactam'
                 )
                 and s.resolution_status = 'resolved'
                 and s.susceptibility = 'Resistant'
                    then 1
                else 0
            end
        ) as esce_resistant_endpoint_count,

        sum(
            case
                when o.esce_rule_eligible
                 and s.antibiotic in (
                     'Cefepime',
                     'Ceftriaxone',
                     'Cefotaxime',
                     'Ceftazidime',
                     'Ceftazidime/Avibactam',
                     'Ceftolozane/Tazobactam'
                 )
                 and s.resolution_status = 'resolved'
                 and s.susceptibility in (
                     'Susceptible',
                     'Intermediate'
                 )
                    then 1
                else 0
            end
        ) as esce_non_resistant_endpoint_count,

        sum(
            case
                when o.esce_rule_eligible
                 and s.antibiotic in (
                     'Cefepime',
                     'Ceftriaxone',
                     'Cefotaxime',
                     'Ceftazidime',
                     'Ceftazidime/Avibactam',
                     'Ceftolozane/Tazobactam'
                 )
                 and (
                     s.resolution_status <> 'resolved'
                     or s.susceptibility is null
                     or s.susceptibility not in (
                         'Susceptible',
                         'Intermediate',
                         'Resistant'
                     )
                 )
                    then 1
                else 0
            end
        ) as esce_non_evaluable_endpoint_count,

        /* ---------------------------------------------------------
           Oxacillin-resistant S. aureus
           --------------------------------------------------------- */

        sum(
            case
                when o.oxacillin_rule_eligible
                 and s.antibiotic in (
                     'Oxacillin',
                     'Cefoxitin'
                 )
                 and s.resolution_status = 'resolved'
                 and s.susceptibility = 'Resistant'
                    then 1
                else 0
            end
        ) as oxacillin_resistant_endpoint_count,

        sum(
            case
                when o.oxacillin_rule_eligible
                 and s.antibiotic in (
                     'Oxacillin',
                     'Cefoxitin'
                 )
                 and s.resolution_status = 'resolved'
                 and s.susceptibility in (
                     'Susceptible',
                     'Intermediate'
                 )
                    then 1
                else 0
            end
        ) as oxacillin_non_resistant_endpoint_count,

        sum(
            case
                when o.oxacillin_rule_eligible
                 and s.antibiotic in (
                     'Oxacillin',
                     'Cefoxitin'
                 )
                 and (
                     s.resolution_status <> 'resolved'
                     or s.susceptibility is null
                     or s.susceptibility not in (
                         'Susceptible',
                         'Intermediate',
                         'Resistant'
                     )
                 )
                    then 1
                else 0
            end
        ) as oxacillin_non_evaluable_endpoint_count,

        /* ---------------------------------------------------------
           VRE
           --------------------------------------------------------- */

        sum(
            case
                when o.vre_rule_eligible
                 and s.antibiotic = 'Vancomycin'
                 and s.resolution_status = 'resolved'
                 and s.susceptibility = 'Resistant'
                    then 1
                else 0
            end
        ) as vre_resistant_endpoint_count,

        sum(
            case
                when o.vre_rule_eligible
                 and s.antibiotic = 'Vancomycin'
                 and s.resolution_status = 'resolved'
                 and s.susceptibility in (
                     'Susceptible',
                     'Intermediate'
                 )
                    then 1
                else 0
            end
        ) as vre_non_resistant_endpoint_count,

        sum(
            case
                when o.vre_rule_eligible
                 and s.antibiotic = 'Vancomycin'
                 and (
                     s.resolution_status <> 'resolved'
                     or s.susceptibility is null
                     or s.susceptibility not in (
                         'Susceptible',
                         'Intermediate',
                         'Resistant'
                     )
                 )
                    then 1
                else 0
            end
        ) as vre_non_evaluable_endpoint_count,

        /* ---------------------------------------------------------
           MDR P. aeruginosa category evidence
           --------------------------------------------------------- */

        -- Extended-spectrum cephalosporins
        sum(
            case
                when o.mdr_p_aeruginosa_rule_eligible
                 and s.antibiotic in (
                     'Cefepime',
                     'Ceftazidime',
                     'Ceftazidime/Avibactam',
                     'Ceftolozane/Tazobactam'
                 )
                 and s.resolution_status = 'resolved'
                 and s.susceptibility in ('Intermediate', 'Resistant')
                    then 1
                else 0
            end
        ) as mdr_es_ceph_positive_count,

        sum(
            case
                when o.mdr_p_aeruginosa_rule_eligible
                 and s.antibiotic in (
                     'Cefepime',
                     'Ceftazidime',
                     'Ceftazidime/Avibactam',
                     'Ceftolozane/Tazobactam'
                 )
                 and s.resolution_status = 'resolved'
                 and s.susceptibility = 'Susceptible'
                    then 1
                else 0
            end
        ) as mdr_es_ceph_non_positive_count,

        sum(
            case
                when o.mdr_p_aeruginosa_rule_eligible
                 and s.antibiotic in (
                     'Cefepime',
                     'Ceftazidime',
                     'Ceftazidime/Avibactam',
                     'Ceftolozane/Tazobactam'
                 )
                 and (
                     s.resolution_status <> 'resolved'
                     or s.susceptibility is null
                     or s.susceptibility not in (
                         'Susceptible',
                         'Intermediate',
                         'Resistant'
                     )
                 )
                    then 1
                else 0
            end
        ) as mdr_es_ceph_non_evaluable_count,

        -- Fluoroquinolones
        sum(
            case
                when o.mdr_p_aeruginosa_rule_eligible
                 and s.antibiotic in (
                     'Ciprofloxacin',
                     'Levofloxacin'
                 )
                 and s.resolution_status = 'resolved'
                 and s.susceptibility in ('Intermediate', 'Resistant')
                    then 1
                else 0
            end
        ) as mdr_fq_positive_count,

        sum(
            case
                when o.mdr_p_aeruginosa_rule_eligible
                 and s.antibiotic in (
                     'Ciprofloxacin',
                     'Levofloxacin'
                 )
                 and s.resolution_status = 'resolved'
                 and s.susceptibility = 'Susceptible'
                    then 1
                else 0
            end
        ) as mdr_fq_non_positive_count,

        sum(
            case
                when o.mdr_p_aeruginosa_rule_eligible
                 and s.antibiotic in (
                     'Ciprofloxacin',
                     'Levofloxacin'
                 )
                 and (
                     s.resolution_status <> 'resolved'
                     or s.susceptibility is null
                     or s.susceptibility not in (
                         'Susceptible',
                         'Intermediate',
                         'Resistant'
                     )
                 )
                    then 1
                else 0
            end
        ) as mdr_fq_non_evaluable_count,

        -- Aminoglycosides: current NHSN rule uses Tobramycin
        sum(
            case
                when o.mdr_p_aeruginosa_rule_eligible
                 and s.antibiotic = 'Tobramycin'
                 and s.resolution_status = 'resolved'
                 and s.susceptibility in ('Intermediate', 'Resistant')
                    then 1
                else 0
            end
        ) as mdr_aminoglycoside_positive_count,

        sum(
            case
                when o.mdr_p_aeruginosa_rule_eligible
                 and s.antibiotic = 'Tobramycin'
                 and s.resolution_status = 'resolved'
                 and s.susceptibility = 'Susceptible'
                    then 1
                else 0
            end
        ) as mdr_aminoglycoside_non_positive_count,

        sum(
            case
                when o.mdr_p_aeruginosa_rule_eligible
                 and s.antibiotic = 'Tobramycin'
                 and (
                     s.resolution_status <> 'resolved'
                     or s.susceptibility is null
                     or s.susceptibility not in (
                         'Susceptible',
                         'Intermediate',
                         'Resistant'
                     )
                 )
                    then 1
                else 0
            end
        ) as mdr_aminoglycoside_non_evaluable_count,

        -- Carbapenems
        sum(
            case
                when o.mdr_p_aeruginosa_rule_eligible
                 and s.antibiotic in (
                     'Imipenem',
                     'Meropenem',
                     'Imipenem/Relebactam'
                 )
                 and s.resolution_status = 'resolved'
                 and s.susceptibility in ('Intermediate', 'Resistant')
                    then 1
                else 0
            end
        ) as mdr_carbapenem_positive_count,

        sum(
            case
                when o.mdr_p_aeruginosa_rule_eligible
                 and s.antibiotic in (
                     'Imipenem',
                     'Meropenem',
                     'Imipenem/Relebactam'
                 )
                 and s.resolution_status = 'resolved'
                 and s.susceptibility = 'Susceptible'
                    then 1
                else 0
            end
        ) as mdr_carbapenem_non_positive_count,

        sum(
            case
                when o.mdr_p_aeruginosa_rule_eligible
                 and s.antibiotic in (
                     'Imipenem',
                     'Meropenem',
                     'Imipenem/Relebactam'
                 )
                 and (
                     s.resolution_status <> 'resolved'
                     or s.susceptibility is null
                     or s.susceptibility not in (
                         'Susceptible',
                         'Intermediate',
                         'Resistant'
                     )
                 )
                    then 1
                else 0
            end
        ) as mdr_carbapenem_non_evaluable_count,

        -- Piperacillin/Tazobactam
        sum(
            case
                when o.mdr_p_aeruginosa_rule_eligible
                 and s.antibiotic = 'Piperacillin/Tazobactam'
                 and s.resolution_status = 'resolved'
                 and s.susceptibility in ('Intermediate', 'Resistant')
                    then 1
                else 0
            end
        ) as mdr_piptazo_positive_count,

        sum(
            case
                when o.mdr_p_aeruginosa_rule_eligible
                 and s.antibiotic = 'Piperacillin/Tazobactam'
                 and s.resolution_status = 'resolved'
                 and s.susceptibility = 'Susceptible'
                    then 1
                else 0
            end
        ) as mdr_piptazo_non_positive_count,

        sum(
            case
                when o.mdr_p_aeruginosa_rule_eligible
                 and s.antibiotic = 'Piperacillin/Tazobactam'
                 and (
                     s.resolution_status <> 'resolved'
                     or s.susceptibility is null
                     or s.susceptibility not in (
                         'Susceptible',
                         'Intermediate',
                         'Resistant'
                     )
                 )
                    then 1
                else 0
            end
        ) as mdr_piptazo_non_evaluable_count,

        -- Cefiderocol
        sum(
            case
                when o.mdr_p_aeruginosa_rule_eligible
                 and s.antibiotic = 'Cefiderocol'
                 and s.resolution_status = 'resolved'
                 and s.susceptibility in ('Intermediate', 'Resistant')
                    then 1
                else 0
            end
        ) as mdr_cefiderocol_positive_count,

        sum(
            case
                when o.mdr_p_aeruginosa_rule_eligible
                 and s.antibiotic = 'Cefiderocol'
                 and s.resolution_status = 'resolved'
                 and s.susceptibility = 'Susceptible'
                    then 1
                else 0
            end
        ) as mdr_cefiderocol_non_positive_count,

        sum(
            case
                when o.mdr_p_aeruginosa_rule_eligible
                 and s.antibiotic = 'Cefiderocol'
                 and (
                     s.resolution_status <> 'resolved'
                     or s.susceptibility is null
                     or s.susceptibility not in (
                         'Susceptible',
                         'Intermediate',
                         'Resistant'
                     )
                 )
                    then 1
                else 0
            end
        ) as mdr_cefiderocol_non_evaluable_count

    from organism_scope o

    left join susceptibility s
        on o.culture_organism_key = s.culture_organism_key

    group by
        o.culture_organism_key

),

mdr_category_status as (

    select
        o.*,
        e.* except (culture_organism_key),

        case
            when not o.mdr_p_aeruginosa_rule_eligible
                then 'not_applicable'
            when e.mdr_es_ceph_positive_count > 0
                then 'positive'
            when e.mdr_es_ceph_non_evaluable_count > 0
                then 'not_evaluable'
            when e.mdr_es_ceph_non_positive_count > 0
                then 'observed_non_positive'
            else 'not_tested'
        end as mdr_es_ceph_status,

        case
            when not o.mdr_p_aeruginosa_rule_eligible
                then 'not_applicable'
            when e.mdr_fq_positive_count > 0
                then 'positive'
            when e.mdr_fq_non_evaluable_count > 0
                then 'not_evaluable'
            when e.mdr_fq_non_positive_count > 0
                then 'observed_non_positive'
            else 'not_tested'
        end as mdr_fq_status,

        case
            when not o.mdr_p_aeruginosa_rule_eligible
                then 'not_applicable'
            when e.mdr_aminoglycoside_positive_count > 0
                then 'positive'
            when e.mdr_aminoglycoside_non_evaluable_count > 0
                then 'not_evaluable'
            when e.mdr_aminoglycoside_non_positive_count > 0
                then 'observed_non_positive'
            else 'not_tested'
        end as mdr_aminoglycoside_status,

        case
            when not o.mdr_p_aeruginosa_rule_eligible
                then 'not_applicable'
            when e.mdr_carbapenem_positive_count > 0
                then 'positive'
            when e.mdr_carbapenem_non_evaluable_count > 0
                then 'not_evaluable'
            when e.mdr_carbapenem_non_positive_count > 0
                then 'observed_non_positive'
            else 'not_tested'
        end as mdr_carbapenem_status,

        case
            when not o.mdr_p_aeruginosa_rule_eligible
                then 'not_applicable'
            when e.mdr_piptazo_positive_count > 0
                then 'positive'
            when e.mdr_piptazo_non_evaluable_count > 0
                then 'not_evaluable'
            when e.mdr_piptazo_non_positive_count > 0
                then 'observed_non_positive'
            else 'not_tested'
        end as mdr_piptazo_status,

        case
            when not o.mdr_p_aeruginosa_rule_eligible
                then 'not_applicable'
            when e.mdr_cefiderocol_positive_count > 0
                then 'positive'
            when e.mdr_cefiderocol_non_evaluable_count > 0
                then 'not_evaluable'
            when e.mdr_cefiderocol_non_positive_count > 0
                then 'observed_non_positive'
            else 'not_tested'
        end as mdr_cefiderocol_status

    from organism_scope o

    inner join endpoint_counts e
        on o.culture_organism_key = e.culture_organism_key

),

mdr_counts as (

    select
        *,

        (
            case when mdr_es_ceph_status = 'positive' then 1 else 0 end
            + case when mdr_fq_status = 'positive' then 1 else 0 end
            + case when mdr_aminoglycoside_status = 'positive' then 1 else 0 end
            + case when mdr_carbapenem_status = 'positive' then 1 else 0 end
            + case when mdr_piptazo_status = 'positive' then 1 else 0 end
            + case when mdr_cefiderocol_status = 'positive' then 1 else 0 end
        ) as mdr_positive_category_count,

        (
            case
                when mdr_es_ceph_status in (
                    'not_evaluable',
                    'not_tested'
                ) then 1 else 0
            end

            + case
                when mdr_fq_status in (
                    'not_evaluable',
                    'not_tested'
                ) then 1 else 0
            end

            + case
                when mdr_aminoglycoside_status in (
                    'not_evaluable',
                    'not_tested'
                ) then 1 else 0
            end

            + case
                when mdr_carbapenem_status in (
                    'not_evaluable',
                    'not_tested'
                ) then 1 else 0
            end

            + case
                when mdr_piptazo_status in (
                    'not_evaluable',
                    'not_tested'
                ) then 1 else 0
            end

            + case
                when mdr_cefiderocol_status in (
                    'not_evaluable',
                    'not_tested'
                ) then 1 else 0
            end
        ) as mdr_unknown_category_count

    from mdr_category_status

),

phenotype_status as (

    select
        *,

        case
            when cre_rule_group is null
                then 'not_applicable'

            when cre_resistant_endpoint_count > 0
                then 'positive'

            when cre_non_evaluable_endpoint_count > 0
                then 'not_evaluable'

            when cre_non_resistant_endpoint_count > 0
                then 'not_detected'

            else 'not_evaluable'
        end as ast_cre_status,

        case
            when not esce_rule_eligible
                then 'not_applicable'

            when esce_resistant_endpoint_count > 0
                then 'positive'

            when esce_non_evaluable_endpoint_count > 0
                then 'not_evaluable'

            when esce_non_resistant_endpoint_count > 0
                then 'not_detected'

            else 'not_evaluable'
        end as ast_esce_enterobacterales_status,

        case
            when not oxacillin_rule_eligible
                then 'not_applicable'

            when oxacillin_resistant_endpoint_count > 0
                then 'positive'

            when oxacillin_non_evaluable_endpoint_count > 0
                then 'not_evaluable'

            when oxacillin_non_resistant_endpoint_count > 0
                then 'not_detected'

            else 'not_evaluable'
        end as ast_oxacillin_resistance_status,

        case
            when not vre_rule_eligible
                then 'not_applicable'

            when vre_resistant_endpoint_count > 0
                then 'positive'

            when vre_non_evaluable_endpoint_count > 0
                then 'not_evaluable'

            when vre_non_resistant_endpoint_count > 0
                then 'not_detected'

            else 'not_evaluable'
        end as ast_vancomycin_resistance_status,

        case
            when not mdr_p_aeruginosa_rule_eligible
                then 'not_applicable'

            when mdr_positive_category_count >= 3
                then 'positive'

            when (
                mdr_positive_category_count
                + mdr_unknown_category_count
            ) < 3
                then 'not_detected'

            else 'not_evaluable'
        end as ast_mdr_p_aeruginosa_status

    from mdr_counts

),

final as (

    select
        *,

        case
            when ast_cre_status = 'positive' then true
            when ast_cre_status = 'not_detected' then false
            else null
        end as is_cre,

        case
            when ast_esce_enterobacterales_status = 'positive' then true
            when ast_esce_enterobacterales_status = 'not_detected' then false
            else null
        end as is_esce_enterobacterales,

        case
            when ast_oxacillin_resistance_status = 'positive' then true
            when ast_oxacillin_resistance_status = 'not_detected' then false
            else null
        end as is_oxacillin_resistant,

        case
            when ast_vancomycin_resistance_status = 'positive' then true
            when ast_vancomycin_resistance_status = 'not_detected' then false
            else null
        end as is_vancomycin_resistant,

        case
            when ast_mdr_p_aeruginosa_status = 'positive' then true
            when ast_mdr_p_aeruginosa_status = 'not_detected' then false
            else null
        end as is_mdr_p_aeruginosa,

        (
            lower(
                coalesce(source_qualifier, '')
            ) = 'carbapenem_resistant'
            or upper(organism_source) like '%CARBAPENEM RESISTANT%'
        ) as source_designated_cre,

        (
            upper(
                coalesce(source_qualifier, '')
            ) = 'MRSA'
            or upper(organism_source) like '%MRSA%'
        ) as source_designated_mrsa,

        (
            lower(
                coalesce(source_qualifier, '')
            ) = 'vancomycin_resistant'
            or upper(organism_source) like '%VANCO RESISTANT%'
        ) as source_designated_vre

    from phenotype_status

)

select *
from final