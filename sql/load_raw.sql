-- Create the raw table.
-- Source fields remain strings; data cleaning happens downstream.

CREATE TABLE IF NOT EXISTS workspace.micro_raw.raw_armd_cohort (
    anon_id                  STRING,
    pat_enc_csn_id_coded      STRING,
    order_proc_id_coded       STRING,
    order_time_jittered_utc   STRING,
    ordering_mode            STRING,
    culture_description      STRING,
    was_positive             STRING,
    organism                 STRING,
    antibiotic               STRING,
    susceptibility           STRING,

    -- Technical metadata added during ingestion.
    source_file              STRING,
    source_version           STRING,
    ingested_at              TIMESTAMP
)
USING DELTA;


-- Load the cultures CSV

COPY INTO workspace.micro_raw.raw_armd_cohort
FROM (
    SELECT
        *,
        _metadata.file_path AS source_file,
        '2025-04-11' AS source_version,
        current_timestamp() AS ingested_at
    FROM '/Volumes/workspace/micro_raw/landing/armd_2025_04_11/microbiology_cultures_cohort.csv'
)
FILEFORMAT = CSV
FORMAT_OPTIONS (
    'header' = 'true',
    'inferSchema' = 'false',
    'multiLine' = 'true',
    'quote' = '"',
    'escape' = '"',
    'mode' = 'FAILFAST'
);

-- ============================================================
-- Demographics: create the raw table
-- ============================================================

CREATE TABLE IF NOT EXISTS workspace.micro_raw.raw_armd_demographics (
    anon_id                  STRING,
    pat_enc_csn_id_coded      STRING,
    order_proc_id_coded       STRING,
    age                      STRING,
    gender                   STRING,

    source_file              STRING,
    source_version           STRING,
    ingested_at              TIMESTAMP
)
USING DELTA;


-- Load the demographics CSV.

COPY INTO workspace.micro_raw.raw_armd_demographics
FROM (
    SELECT
        *,
        _metadata.file_path AS source_file,
        '2025-04-11' AS source_version,
        current_timestamp() AS ingested_at
    FROM '/Volumes/workspace/micro_raw/landing/armd_2025_04_11/microbiology_cultures_demographics.csv'
)
FILEFORMAT = CSV
FORMAT_OPTIONS (
    'header' = 'true',
    'inferSchema' = 'false',
    'multiLine' = 'true',
    'quote' = '"',
    'escape' = '"',
    'mode' = 'FAILFAST'
);

-- ============================================================
-- Ward information: create the raw table
-- ============================================================

CREATE TABLE IF NOT EXISTS workspace.micro_raw.raw_armd_ward (
    anon_id                  STRING,
    pat_enc_csn_id_coded      STRING,
    order_proc_id_coded       STRING,
    order_time_jittered_utc   STRING,
    hosp_ward_IP             STRING,
    hosp_ward_OP             STRING,
    hosp_ward_ER             STRING,
    hosp_ward_ICU            STRING,

    source_file              STRING,
    source_version           STRING,
    ingested_at              TIMESTAMP
)
USING DELTA;


-- Load the ward-information CSV.

COPY INTO workspace.micro_raw.raw_armd_ward
FROM (
    SELECT
        *,
        _metadata.file_path AS source_file,
        '2025-04-11' AS source_version,
        current_timestamp() AS ingested_at
    FROM '/Volumes/workspace/micro_raw/landing/armd_2025_04_11/microbiology_cultures_ward_info.csv'
)
FILEFORMAT = CSV
FORMAT_OPTIONS (
    'header' = 'true',
    'inferSchema' = 'false',
    'multiLine' = 'true',
    'quote' = '"',
    'escape' = '"',
    'mode' = 'FAILFAST'
);