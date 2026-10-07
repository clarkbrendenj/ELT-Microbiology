with source as (

    select *
    from {{ source('armd_raw', 'raw_armd_cohort') }}

),

staged as (

    select
        -- Source identifiers
        anon_id as patient_key,
        pat_enc_csn_id_coded as encounter_key,
        order_proc_id_coded as culture_order_key,

        -- Preserve the original timestamp text
        order_time_jittered_utc as order_time_jittered_utc_raw,

        -- Typed timestamp
        try_cast(order_time_jittered_utc as timestamp) as culture_time_shifted,

        -- Culture attributes
        nullif(trim(ordering_mode), 'Null') as ordering_mode,
        nullif(trim(culture_description), 'Null') as culture_description,

        try_cast(was_positive as integer) as was_positive,

        -- Microbiology results
        nullif(trim(organism), 'Null') as organism,
        nullif(trim(antibiotic), 'Null') as antibiotic,

        -- Preserve the source category before normalization
        susceptibility as susceptibility_raw,

        case
            when susceptibility = 'Null' then null
            else trim(susceptibility)
        end as susceptibility,

        -- Ingestion metadata
        source_file,
        source_version,
        ingested_at

    from source

)

select *
from staged