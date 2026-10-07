{{ config(materialized='view') }}

select *
from {{ ref('int_susceptibility_reconciliation') }}

where resolution_status <> 'resolved'