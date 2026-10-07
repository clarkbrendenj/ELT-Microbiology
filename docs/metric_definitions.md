# Metric Definitions

## Purpose

This document defines the analytical population, terminology mappings,
susceptibility denominators, exclusions, and reporting rules used in the
Clinical Microbiology Analytics Lakehouse portfolio project.

The project uses the Stanford Antibiotic Resistance Microbiology Dataset
(ARMD), release 2025-04-11.

The resulting susceptibility summaries are retrospective research
summaries built from source-defined susceptibility categories. They are
not an official clinical antibiogram and should not be interpreted as
CLSI M39-compliant reporting or clinical decision support.


## Source release

Source version:

`2025-04-11`

Source culture categories used in this project:

- `BLOOD`
- `URINE`
- `RESPIRATORY`

These values are mapped exactly to the analytical cohorts:

| Source value | Cohort |
|---|---|
| BLOOD | blood |
| URINE | urine |
| RESPIRATORY | respiratory |

No substring-based specimen classification is used.


## Culture grain

`fct_culture`

Grain:

> One culture order per source release, patient, encounter, and culture
> order identifier.

The culture table is derived independently of susceptibility-result rows
so that the long AST structure does not inflate culture counts.


## Culture-organism grain

`fct_culture_organism`

Grain:

> One source culture-organism combination.

ARMD does not provide a verified isolate identifier. Multiple source
organism records therefore must not automatically be interpreted as
distinct isolates or collapsed into a single isolate.


## Susceptibility endpoint reconciliation

`int_susceptibility_reconciliation`

Initial source grain:

> Culture-organism-antibiotic-result records.

For each culture-organism-antibiotic combination, results are classified
as follows.

### Resolved

Exactly one non-null susceptibility state is present.

The result is eligible for `fct_susceptibility`.

### Missing

The endpoint exists but contains no non-null susceptibility category.

### Conflict

More than one distinct result state is present for the same
culture-organism-antibiotic combination.

Conflicting endpoints are retained in the exception layer and excluded
from analytical susceptibility percentages.

No "most resistant", "latest", or other inferred result is selected
because the source does not contain sufficient result-version information
to justify such a rule.


## Source susceptibility categories

Source categories retained by the pipeline are:

- `Susceptible`
- `Resistant`
- `Intermediate`
- `Inconclusive`
- `Synergism`

SQL null represents a missing susceptibility result.

For the primary susceptibility summaries, only:

- Susceptible
- Resistant
- Intermediate

are included in the categorized-result denominator.

`Inconclusive`, `Synergism`, missing results, and conflicting results are
reported separately.


## Organism terminology

Source organism terminology is preserved unchanged in the upstream facts.

A version-controlled mapping seed provides a reviewed analytical
organism identity for a selected initial set of organisms.

Example:

`STAPH AUREUS {MRSA}`

maps analytically to:

`Staphylococcus aureus`

while retaining the source qualifier:

`MRSA`

Similarly, phenotype or morphotype information such as
`carbapenem_resistant`, `mucoid`, or `non_mucoid_cf` is retained
separately rather than discarded.

Unreviewed organism labels remain explicitly unmapped rather than being
assigned an inferred identity.


## Standardized culture-organism collisions

Multiple source organism records from the same culture can sometimes map
to the same standardized organism.

Examples include multiple Pseudomonas aeruginosa morphotypes or multiple
Staphylococcus aureus source labels within one culture.

Because the dataset does not contain a verified isolate identifier,
these cases are classified as mapping collisions.

For the primary analytical population:

- resolved standardized culture-organism records are eligible;
- mapping collisions are retained for data-quality reporting but excluded
  from the primary susceptibility denominator.

This prevents distinct source organism records from being silently
collapsed.


## Primary organism set

The initial reporting mart uses a deliberately reviewed subset of
standardized bacterial organisms rather than attempting to normalize the
entire source vocabulary.

The current set contains 12 standardized organisms.

This is a project reporting scope decision, not a claim that other
organisms are clinically unimportant.


## First eligible culture policy

`int_first_culture_organism`

The primary analysis uses:

> The first eligible culture-organism per patient, standardized organism,
> cohort, and source release.

Eligible records must:

1. belong to an explicitly defined cohort;
2. have a reviewed organism mapping selected for the reporting analysis;
3. have a resolved standardized culture-organism mapping;
4. contain a usable shifted culture timestamp.

Records are ordered by:

1. `culture_time_shifted`
2. `culture_key`

The first record is selected before checking which antibiotics were
tested or what susceptibility category was reported.

This prevents antibiotic availability or susceptibility result from
determining which culture enters the analytical population.

This is a research-project deduplication policy and is not presented as
an annual clinical-antibiogram rule.


## Reviewed organism-antibiotic pairs

The reporting mart uses the version-controlled seed:

`reportable_organism_antibiotic_pairs.csv`

Only explicitly reviewed organism-antibiotic pairs are included.

Pair selection is a project reporting decision based on the source
vocabulary and observed availability of categorized results. It is not
presented as a CLSI-recommended testing or reporting panel.

The eligible organism-antibiotic grid is created before susceptibility
results are joined so that reviewed pairs remain represented even when
an antibiotic was not tested.


## Susceptibility reporting mart

`mart_susceptibility`

Grain:

> One source release × cohort × standardized organism × reviewed
> antibiotic pair.

The mart contains counts for eligibility, testing, susceptibility
categories, exclusions, coverage, and display status.


## Eligible count

`eligible_count`

Number of first eligible culture-organism records for a given:

- source release
- cohort
- standardized organism

The same eligible count is used for every reviewed antibiotic for that
organism within the cohort.


## Tested endpoint count

`tested_endpoint_count`

Number of eligible culture-organism records for which an endpoint for the
reviewed antibiotic exists in the source data.

Therefore:

`tested_endpoint_count + untested_count = eligible_count`


## Untested count

`untested_count`

Number of eligible culture-organism records for which no endpoint exists
for the reviewed antibiotic.


## Categorized count

`categorized_count`

Number of resolved endpoints whose source susceptibility category is:

- Susceptible
- Resistant
- Intermediate

Therefore:

`categorized_count = susceptible_count + resistant_count + intermediate_count`


## Categorized-result coverage

`categorized_result_coverage_pct`

Calculated as:

`100 × categorized_count / eligible_count`

This measures the proportion of the eligible analytical population with
a usable S/R/I result for that organism-antibiotic pair.

It should not be interpreted as susceptibility.


## Susceptible percentage

`susceptible_pct`

Calculated as:

`100 × susceptible_count / categorized_count`

Only source categories of Susceptible, Resistant, and Intermediate are
included in the denominator.


## Resistant-category percentage

`resistant_pct`

Calculated as:

`100 × resistant_count / categorized_count`

This represents the proportion of categorized source results explicitly
labeled `Resistant`.

It does not reinterpret Intermediate or other source categories as
Resistant.


## Other result states

The mart separately retains:

- `intermediate_count`
- `inconclusive_count`
- `synergism_count`
- `missing_result_count`
- `conflict_result_count`
- `untested_count`

These categories remain visible so that exclusions from susceptibility
percentages can be reconciled.


## Display threshold

`display_status`

Susceptibility percentages are designated for display when:

`categorized_count >= 30`

Otherwise:

`display_status = insufficient_data`

The 30-record threshold is a conservative project presentation rule and
is not a claim of guideline compliance.

A true 0% susceptibility value is therefore distinct from a pair with
too few categorized results to display.


## Example validation

For the 2025-04-11 release, the blood Escherichia coli / ceftriaxone
endpoint contains:

| Metric | Count |
|---|---:|
| Eligible first cultures | 3,021 |
| Tested endpoints | 3,020 |
| Untested | 1 |
| Categorized S/R/I | 3,015 |
| Susceptible | 2,542 |
| Resistant | 464 |
| Intermediate | 9 |
| Missing | 1 |
| Conflict | 4 |

The reconciliations are:

`3,020 tested + 1 untested = 3,021 eligible`

and:

`2,542 susceptible + 464 resistant + 9 intermediate = 3,015 categorized`

and:

`3,015 categorized + 1 missing + 4 conflict = 3,020 tested`

Resulting descriptive metrics are:

- Categorized-result coverage: **99.8%**
- Susceptible: **84.3%**
- Resistant category: **15.4%**


## Interpretation limitations

The dataset is a de-identified retrospective research extract.

Culture times are shifted and are used for within-dataset ordering rather
than interpretation as real calendar dates.

Testing is not random. Antibiotic coverage varies across organisms,
cohorts, and source records.

Organism terminology reflects source-system labels, and only explicitly
reviewed mappings are standardized.

The source does not provide sufficient information to reliably distinguish
all multiple isolates, result revisions, or organism morphotypes.

Susceptibility categories are used as supplied by the source. MIC values
and contemporary breakpoint reinterpretation are not reconstructed.

Differences between cohorts are descriptive and should not be interpreted
as treatment effects or general hospital resistance rates.