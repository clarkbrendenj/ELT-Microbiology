# Project Notebooks

## Source exploration

`source_exploration/01_explore_armd.ipynb`

Profiles the downloaded ARMD files, source schemas, category values,
missingness, repeated records, and candidate grains before warehouse
modeling.

## Pipeline validation

`pipeline_validation/`

Contains executable validation notebooks for the dbt pipeline. These
notebooks verify culture and susceptibility grains, exception handling,
cohort assignment, terminology mapping, patient-level deduplication,
and reporting-mart reconciliation.

## Descriptive analysis

`descriptive_analysis/`

Reserved for analyses built from tested dbt marts, including
susceptibility and multidrug-resistant-organism summaries.

## Modeling

`modeling/`

Reserved for the retrospective resistance-prediction workflow,
including cohort construction, feature engineering, evaluation,
calibration, and model limitations.