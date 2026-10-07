with source as (

    select *
    from {{ source('armd_raw', 'raw_armd_ward') }}

),

staged as (

    select
        -- Identifiers
        anon_id as patient_key,
        pat_enc_csn_id_coded as encounter_key,
        order_proc_id_coded as culture_order_key,

        -- Preserve timestamp text and create typed version
        order_time_jittered_utc as order_time_jittered_utc_raw,
        try_cast(order_time_jittered_utc as timestamp) as culture_time_shifted,

        -- Care-setting indicators
        try_cast(hosp_ward_IP as integer) as hosp_ward_ip,
        try_cast(hosp_ward_OP as integer) as hosp_ward_op,
        try_cast(hosp_ward_ER as integer) as hosp_ward_er,
        try_cast(hosp_ward_ICU as integer) as hosp_ward_icu,

        -- Ingestion metadata
        source_file,
        source_version,
        ingested_at

    from source

)

select *
from staged