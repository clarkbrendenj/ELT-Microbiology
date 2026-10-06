{{ config(materialized='table', file_format='delta') }}

select
    1 as connection_check,
    current_timestamp() as checked_at

    # Run from the root of your ELT-Microbiology repository.
# Replace YOUR_CATALOG with your personal Databricks catalog name.

