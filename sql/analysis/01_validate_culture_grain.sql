-- ============================================================
-- Validate fct_culture grain
--
-- Expected grain:
-- One row per culture order within an ARMD source version.
--
-- The source microbiology table is long-form and contains
-- multiple rows per culture order, so source row count should
-- not be interpreted as culture count.
-- ============================================================


-- ------------------------------------------------------------
-- 1. Confirm one row per culture and inspect order-level
--    conflicts.
-- ------------------------------------------------------------

select
    count(*) as culture_rows,
    count(distinct culture_key) as distinct_culture_keys,
    sum(
        case
            when has_order_level_conflict then 1
            else 0
        end
    ) as culture_orders_with_conflicts
from workspace.micro_dev.fct_culture;


-- ------------------------------------------------------------
-- 2. Examine how many long-form source rows contribute to
--    each culture order.
-- ------------------------------------------------------------

select
    source_row_count,
    count(*) as culture_orders
from workspace.micro_dev.fct_culture
group by source_row_count
order by source_row_count;


-- ------------------------------------------------------------
-- 3. Reconcile source/staging/fact row counts.
-- ------------------------------------------------------------

select
    'raw_armd_cohort' as model_name,
    count(*) as row_count
from workspace.micro_raw.raw_armd_cohort

union all

select
    'stg_armd_cohort',
    count(*)
from workspace.micro_dev.stg_armd_cohort

union all

select
    'fct_culture',
    count(*)
from workspace.micro_dev.fct_culture;