WITH row_counts AS (

    SELECT
        'raw_armd_cohort' AS table_name,
        COUNT(*) AS actual_rows,
        2241050 AS expected_rows
    FROM workspace.micro_raw.raw_armd_cohort

    UNION ALL

    SELECT
        'raw_armd_demographics' AS table_name,
        COUNT(*) AS actual_rows,
        751075 AS expected_rows
    FROM workspace.micro_raw.raw_armd_demographics

    UNION ALL

    SELECT
        'raw_armd_ward' AS table_name,
        COUNT(*) AS actual_rows,
        751075 AS expected_rows
    FROM workspace.micro_raw.raw_armd_ward

)

SELECT
    table_name,
    actual_rows,
    expected_rows,
    actual_rows - expected_rows AS difference,
    CASE
        WHEN actual_rows = expected_rows THEN 'PASS'
        ELSE 'CHECK'
    END AS row_count_check
FROM row_counts
ORDER BY table_name;

SELECT *
FROM workspace.micro_raw.raw_armd_cohort
LIMIT 100;

SELECT *
FROM workspace.micro_raw.raw_armd_demographics
LIMIT 100;

SELECT *
FROM workspace.micro_raw.raw_armd_ward
LIMIT 100;