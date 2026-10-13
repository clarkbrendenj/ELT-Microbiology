-- The reported first cultures must lie in the selected window.
-- In full-release mode this assertion always passes.
with selected as (
    select culture_time_shifted
    from {{ ref('int_overall_first_reporting_isolate') }}
    union all
    select culture_time_shifted
    from {{ ref('int_first_stratified_reporting_culture') }}
)
select * from selected
where not ({{ analysis_window_filter('culture_time_shifted') }})
