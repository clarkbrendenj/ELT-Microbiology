{{ config(materialized='view') }}

select *
from {{ ref('int_standardized_culture_organism') }}

where mapping_resolution_status = 'collision'