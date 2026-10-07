with source as (

    select *
    from {{ source('armd_raw', 'raw_armd_demographics') }}

),

staged as (

    select
        -- Identifiers
        anon_id as patient_key,
        pat_enc_csn_id_coded as encounter_key,
        order_proc_id_coded as culture_order_key,

        -- Preserve original values
        age as age_raw,
        gender as gender_raw,

        -- Standardized missing values
        nullif(trim(age), 'Null') as age,
        nullif(trim(gender), 'Null') as gender,

        -- Ingestion metadata
        source_file,
        source_version,
        ingested_at

    from source

)

select *
from staged