{#
  Optional shifted-date, exactly 12-month research reporting window.
  Set `analysis_window_start` in dbt_project.yml (or pass --vars).
  If absent, the entire source release is used for baseline comparison.
  The end date is EXCLUSIVE; patient-level ARMD date jitter remains a caveat.
#}
{% macro analysis_window_filter(timestamp_column) %}
    {% set start = var('analysis_window_start', none) %}
    {% if start is none or (start|string|trim) == '' %}
        true
    {% else %}
        (
            {{ timestamp_column }} >= cast(cast('{{ start }}' as date) as timestamp)
            and {{ timestamp_column }} < cast(add_months(cast('{{ start }}' as date), 12) as timestamp)
        )
    {% endif %}
{% endmacro %}

{% macro analysis_window_start_expr() %}
    {% set start = var('analysis_window_start', none) %}
    {% if start is none or (start|string|trim) == '' %}
        cast(null as date)
    {% else %}
        cast('{{ start }}' as date)
    {% endif %}
{% endmacro %}

{% macro analysis_window_end_expr() %}
    {% set start = var('analysis_window_start', none) %}
    {% if start is none or (start|string|trim) == '' %}
        cast(null as date)
    {% else %}
        add_months(cast('{{ start }}' as date), 12)
    {% endif %}
{% endmacro %}
