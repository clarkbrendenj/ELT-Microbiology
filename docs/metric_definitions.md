# Metric Definitions

## Purpose and scope

This document defines the source population, analytical grains, organism mappings, resistance phenotypes, deduplication policies, susceptibility denominators, and reporting exclusions used in the **Clinical Microbiology Analytics Lakehouse** portfolio project.

The source is the **Stanford Antibiotic Resistance Microbiology Dataset (ARMD), release `2025-04-11`**. The pipeline uses the source's categorical antimicrobial susceptibility testing (AST) interpretations. It does not reconstruct minimum inhibitory concentrations (MICs), breakpoint versions, or unobserved isolate identities.

The output is a retrospective research summary designed to demonstrate reproducible microbiology data engineering and analysis. It is **not an official clinical antibiogram**, a validated CLSI M39 implementation, or clinical decision support. Clinical reporting references informed selected organism and antibiotic display decisions; they do not establish clinical equivalence.

## Source release and cohorts

| ARMD `culture_description` | `cohort_id` |
|---|---|
| `BLOOD` | `blood` |
| `URINE` | `urine` |
| `RESPIRATORY` | `respiratory` |

Cohorts are assigned by exact source values in `int_cohort_culture_organism`. No substring-based specimen classification is used.

Source timestamps are shifted. They support deterministic ordering within this dataset but must not be treated as actual clinical calendar dates. The analysis covers the supplied release, **not a calendar-year antibiogram period**.

## Core data grains

| Model | Analytical grain | Purpose |
|---|---|---|
| `fct_culture` | One culture order per source release/patient/encounter/order | Prevent long-format AST rows from inflating culture counts |
| `fct_culture_organism` | One source culture-organism combination | Preserve source organism identity without inventing an isolate ID |
| `int_susceptibility_reconciliation` | One culture-organism–antibiotic endpoint | Classify repeated AST records as resolved, missing, or conflicting |
| `fct_susceptibility` | One unambiguous culture-organism–antibiotic endpoint | Provide resolved source interpretations for analysis |
| `int_culture_organism_phenotype` | One source culture-organism combination | Add independently derived resistance phenotype statuses |
| `int_reporting_culture_organism` | One culture/reporting organism/reporting phenotype | Consolidate source labels **after** assigning phenotype |
| `int_overall_first_reporting_isolate` | One first culture per release/cohort/patient/reporting organism | Define the conventional overall-organism population |
| `int_overall_first_reporting_susceptibility` | One overall first-culture–antibiotic endpoint | Reconcile AST across source labels on that selected culture |

ARMD does not include a verified isolate identifier. Keys created by dbt identify analytical records under the project's declared grains; they are not reconstructed biological isolate IDs.

## Source susceptibility reconciliation

### First-stage reconciliation

`int_susceptibility_reconciliation` groups repeated source records for a culture-organism–antibiotic endpoint.

| `resolution_status` | Rule | Analytical treatment |
|---|---|---|
| `resolved` | Repeated source rows agree on one non-null susceptibility category, with no missing-category rows in that source endpoint | Retain the interpretation; eligible for `fct_susceptibility` |
| `missing` | The endpoint exists but all recorded source interpretations are `NULL` | Preserve as missing |
| `conflict` | Source rows contain different non-null categories **or** a combination of a category and a `NULL` result | Preserve the conflict; do not select a winner |

The source-level implementation treats a `NULL` as a distinct recorded result state when comparing repeated rows. For example, `Susceptible` plus `NULL` for the **same source culture-organism–drug endpoint** is classified as a conflict. This conservative rule differs from the second-stage reconciliation of **different source organism records** on a reporting culture, described below. Both stages retain their unresolved-result counts for audit.

No "latest result," "most resistant," or similar tie-break is applied because the extract does not provide enough version history to defend such a choice.

### Second-stage reconciliation after source-label consolidation

A single selected reporting culture can contain several ARMD organism labels mapped to the same reporting organism. For example, a culture can have ordinary *S. aureus* and an MRSA-qualified source label, or multiple *P. aeruginosa* morphotypes.

Source organism records are **not excluded merely because their mappings collide**. Instead, the pipeline:

1. Assigns resistance phenotypes at the source culture-organism level.
2. Preserves the source keys and labels when consolidating culture/reporting-organism records.
3. For the overall first culture, combines source keys across its phenotype categories.
4. Reconciles each drug endpoint across those source keys.

In `int_overall_first_reporting_susceptibility`:

- Any already-conflicting source endpoint makes the combined endpoint `conflict`.
- Different resolved interpretations across source records make it `conflict`.
- One consistent resolved interpretation is retained, even if another source record for that drug is missing; this is tracked as `resolved_with_missing_source_endpoint`.
- With no resolved interpretation, the combined endpoint is `missing`.

No arbitrary source label is preferred in the overall-culture reconciliation.

## Source AST categories

The source interpretation values retained by the pipeline are:

- `Susceptible`
- `Resistant`
- `Intermediate`
- `Inconclusive`
- `Synergism`

SQL `NULL` represents a missing interpretation. **Only `Susceptible`, `Resistant`, and `Intermediate`** enter the categorized-result denominator of the susceptibility mart. Inconclusive, synergism, missing, conflicting, and untested endpoints are tracked separately.

These are **source-defined categories**. An `Intermediate` result is not silently recoded to `Resistant`, and categorical results are not reinterpreted with a new MIC breakpoint.

## Organism terminology and reporting scope

### Version-controlled mappings

`organism_mapping.csv` maps reviewed source labels to:

- `organism_standardized`: the reviewed analytical identity;
- `organism_reporting_group`: the grouping used for reporting, which need not always be a single species;
- `source_qualifier`: source terminology retained separately from species identity;
- `mapping_status` and `include_primary_summary`: explicit review and population-selection fields.

For example, `STAPH AUREUS {MRSA}` maps to `Staphylococcus aureus`, with its source MRSA qualifier preserved. That qualifier is **not** the definitive basis for the project's AST-derived MRSA classification.

Reviewed taxonomy decisions include retaining *Citrobacter koseri* and *C. farmeri* separately from *C. freundii* complex, and mapping historical `ZZZENTEROBACTER AEROGENES` to *Klebsiella aerogenes*. Unreviewed source labels remain unmapped rather than being assigned guessed identities.

The current mapping seed has **41 reviewed source-label entries**. Reporting scope reflects the reviewed mapping, the available drug panel, cohort eligibility, and explicit exclusions; it is not determined by organism frequency alone.

### Reporting organism groups

`organism_reporting_groups.csv` contains **20 reviewed reporting groups**, including *Escherichia coli*, *Klebsiella* and *Citrobacter* species or complexes, *Staphylococcus aureus*, CoNS (unspeciated), *Enterococcus* species (unspeciated), *Morganella morganii*, and *Stenotrophomonas maltophilia*. A reporting group may represent a species, species complex, or an intentionally pooled unspeciated category.

CoNS is pooled as **coagulase-negative staphylococci (unspeciated)**; its results are not labeled as species-specific *S. epidermidis* or *S. lugdunensis* susceptibility.

Some source organisms remain outside the primary reporting mart, including organisms requiring separate AST frameworks or species-specific interpretive review. Not appearing in the mart does not mean an organism is clinically insignificant.

### Gram classification

`organism_reporting_groups.csv` defines `gram_stain_group` at the **reporting-group** level:

- `gram_positive`
- `gram_negative`

Both final marts join this reference using their base reporting-organism field. A phenotype-specific name therefore inherits the Gram classification of its underlying organism. Gram status is descriptive metadata; it does not change source grain, patient eligibility, or susceptibility denominators.

## Resistance phenotype derivation

`int_culture_organism_phenotype` evaluates resistance from **reconciled categorical AST**, not solely from phrases embedded in source organism names. The source qualifier is kept for concordance review.

Each applicable phenotype is assigned one of:

| Status | Meaning |
|---|---|
| `positive` | Sufficient qualifying resistant/non-susceptible AST evidence |
| `not_detected` | Available defining AST supports absence under the project's rule |
| `not_evaluable` | Required evidence is incomplete, conflicting, or otherwise insufficient |
| `not_applicable` | Organism is outside the phenotype's defined scope |

When collapsing source records on a culture, status precedence is `positive` → `not_evaluable` → `not_detected` → `not_applicable`. `not_evaluable` is not equivalent to susceptible or phenotype-negative.

### CRE (carbapenem-resistant Enterobacterales)

The project applies a CDC/NHSN-inspired **AST-based phenotypic CRE rule** to reviewed eligible Enterobacterales groups, including relevant *Citrobacter*, *Enterobacter*, *Escherichia*, *Klebsiella*, *Serratia*, *Proteus*, and *Morganella* mappings.

A resolved `Resistant` result to a qualifying carbapenem establishes a positive phenotype. The standard reviewed endpoints include ertapenem, imipenem, meropenem, meropenem/vaborbactam, and imipenem/relebactam where present. For *Proteus* and *Morganella*, imipenem is excluded from the project's qualifying rule because of species-specific interpretive concerns.

A missing test, unresolved endpoint, or lack of a qualifying resistant result must not automatically be interpreted as demonstrated susceptibility. The ARMD extract does not provide molecular carbapenemase results for this analysis.

### Extended-spectrum cephalosporin-resistant Enterobacterales (ESCE-R)

The project uses an **ESCE-R AST phenotype**, not a confirmed ESBL producer designation. Applicable reviewed groups include *E. coli*, *K. aerogenes*, *K. oxytoca*, *K. pneumoniae*, and *Enterobacter* groups.

Qualifying agents are cefepime, ceftriaxone, cefotaxime, ceftazidime, ceftazidime/avibactam, and ceftolozane/tazobactam. A resolved `Resistant` interpretation for any qualifying agent establishes ESCE-R under this rule.

ESCE-R and CRE statuses are derived independently. For **mutually exclusive ESCE-R display**, CRE-positive cultures take precedence, so a CRE-positive first culture is not also listed in the ESCE-R subgroup. It still contributes to the **overall organism** susceptibility row.

The source does not contain an ESBL confirmatory screen, resistance gene, or numeric MIC values suitable for proving ESBL production or rebuilding breakpoints.

### Oxacillin-resistant *Staphylococcus aureus* (MRSA phenotype)

For reviewed *S. aureus*, resistance to oxacillin or cefoxitin is positive evidence for the oxacillin-resistant phenotype (`oxacillin_resistant`). The dashboard label is **methicillin resistant (MRSA)**. This is an AST-derived project classification, not an unverified copy of the source MRSA label.

The separate **methicillin susceptible (MSSA)** subgroup (`oxacillin_susceptible`) requires an unambiguous resolved `Susceptible` oxacillin/cefoxitin marker, no conflicting or non-susceptible defining marker, and the applicable phenotype status `not_detected`. A record with unknown defining AST is not automatically assigned to MSSA.

MRSA and MSSA are separate subsets of the same overall first-*S. aureus* population. Their counts need not sum to the overall total because unclassifiable records may remain.

### Vancomycin-resistant *Enterococcus* (VRE)

The VRE rule applies to reviewed *E. faecalis* and *E. faecium* only. A resolved `Resistant` vancomycin result is VRE-positive. Unspecified *Enterococcus* remains a separate reporting group and is not automatically assigned to either species-specific VRE subgroup.

### MDR *Pseudomonas aeruginosa*

The project's CDC/NHSN-derived MDR rule counts antimicrobial categories with a resolved `Intermediate` or `Resistant` result. The six reviewed categories are:

1. Extended-spectrum cephalosporins (including relevant antipseudomonal agents)
2. Fluoroquinolones
3. Tobramycin (aminoglycoside category)
4. Carbapenems
5. Piperacillin/tazobactam
6. Cefiderocol

Three or more positive categories establish MDR. Fewer than three positive categories are `not_detected` **only when the remaining unknown categories cannot raise the total to three**; otherwise the status is `not_evaluable`.

MDR *P. aeruginosa* is summarized in `mart_mdro`, not as a separate phenotype row in `mart_susceptibility`. The organism still contributes to the overall *P. aeruginosa* susceptibility population.

## Susceptibility population: first culture per patient and organism

The susceptibility mart selects a single overall first culture for each patient, specimen cohort, and reporting organism. The MDRO mart uses a **separate patient-level, across-observations policy**, defined in its own section below. Their denominators are not interchangeable.

### Overall first-culture selection

**Model:** `int_overall_first_reporting_isolate`

**Grain:** `source_version × cohort_id × patient_key × organism_reporting_group`.

The pipeline first combines reporting records for the **same culture and base organism**, including those assigned different resistance phenotypes. Then it selects exactly one culture per patient/cohort/reporting organism using:

1. Earliest available `culture_time_shifted`;
2. `culture_key` as deterministic tie-breaker.

Selection occurs before evaluating the chosen antibiotic's availability or S/R/I result. The **overall** population includes cultures with CRE, MDR, MRSA, VRE, and ESCE-R phenotypes. A patient can contribute to different specimen cohorts or different reporting organisms, but only once to a given overall patient/cohort/organism group in this release.

A phenotype-specific susceptibility subgroup is filtered **from these selected overall first cultures**. It is not independently re-deduplicated to the patient's first resistant culture.

### Subgroups derived from the overall population

The reporting mart evaluates each selected first culture's AST-derived phenotype classifications to produce the applicable resistance-specific subgroups. These subsets share the overall population's culture-selection rule. Patients are **not** independently reselected by phenotype, and subgroup counts are never added together to estimate an overall-organism denominator.

## Reviewed antibiotic-pair policy

### Cohort-specific allow-list

**Seed:** `reportable_organism_antibiotic_pairs.csv`

The approved pair key is:

`organism_reporting_group × cohort_id × antibiotic`.

Only rows with `review_status = 'reviewed'` and `include_primary_dashboard = 1` enter the reporting grid. `review_status = 'proposed'` and `include_primary_dashboard = 0` retain candidate drugs without publishing them. Specimen-specific drugs, including urinary agents, can be approved for urine without automatically appearing in blood or respiratory reporting.

The reviewed grid is constructed **before** joining AST endpoints. An approved antibiotic stays represented when an eligible organism was not tested for that drug, so testing coverage can be measured explicitly.

### Explicit exclusions override approvals

**Seed:** `organism_antibiotic_exclusions.csv`

The exclusion key is `organism_reporting_group × antibiotic`. It overrides the approved list **across all cohorts** for that organism–drug combination. Review reasons include:

| `exclusion_reason` | Meaning |
|---|---|
| `expected_resistant` | Expected/intrinsic-resistance phenotype makes routine display inappropriate |
| `ampc_reporting_suppression` | Project policy suppresses selected agents for reviewed inducible-AmpC-risk organisms |
| `inappropriate_surrogate` | Result is not appropriate for the proposed surrogate interpretation |
| `no_current_breakpoint` | No applicable current interpretive breakpoint for the reporting use |

These are **reporting suppressions**, not edits to the original organism, AST result, or phenotype calculation. A drug may remain in the source facts and downstream reconciliation while being omitted from the reporting mart.

The AmpC policy is deliberately more restrictive than simply displaying every available categorical AST result. In the validated approved-pair audit, ceftriaxone and piperacillin/tazobactam for *E. cloacae* complex account for **six approved cohort-specific pairs** that are omitted from the mart by design.

### Inactive proposals

The current seed retains **11 inactive proposed rows** pending more detailed review of source coverage, selective testing, or organism-specific interpretation. Their inactivity must not be presented as proof that the corresponding organism–drug combinations are intrinsically resistant or never clinically relevant.

## Susceptibility reporting mart

**Model:** `mart_susceptibility`

**Grain:**

`source_version × cohort_id × organism_reporting_group × reporting_phenotype × antibiotic`.

`organism_name` is the display label. `organism_reporting_group` is the base identity used to join the approved pair and Gram-reference seeds. `reporting_phenotype` identifies either the conventional overall population or a selected subgroup.

### Reporting categories

| `reporting_phenotype` | Population |
|---|---|
| `overall` | Earliest culture per patient/cohort/base organism, **including all resistance phenotypes** |
| `esce_r` | ESCE-R-positive subset of those overall first cultures, excluding CRE-positive cultures by display precedence |
| `oxacillin_resistant` | AST-derived MRSA subset of overall first *S. aureus* cultures |
| `oxacillin_susceptible` | AST-supported MSSA subset of overall first *S. aureus* cultures |
| `vancomycin_resistant` | VRE subset of overall first *E. faecalis* or *E. faecium* cultures |

The `overall` population includes CRE-positive and MDR *P. aeruginosa* cultures where applicable. These resistance phenotypes are also described in the separate patient-level `mart_mdro` summary. They are not published as additional susceptibility subgroups in this mart.

The published subgroup denominator cannot exceed its corresponding overall denominator. Some subgroups can overlap in conceptual resistance status, but they are not summed to construct the overall population.

### Counts and identities

| Field | Definition |
|---|---|
| `susceptibility_mart_key` | Deterministic key for one row at the mart grain |
| `eligible_count` | Number of selected overall first cultures in that organism/cohort, or selected first cultures meeting the row's subgroup definition |
| `tested_endpoint_count` | Eligible cultures with an AST endpoint for the antibiotic, regardless of whether it was resolved |
| `untested_count` | Eligible cultures with no recorded endpoint for that antibiotic |
| `categorized_count` | Resolved endpoints labeled `Susceptible`, `Intermediate`, or `Resistant` |
| `susceptible_count` | Resolved `Susceptible` endpoints |
| `intermediate_count` | Resolved `Intermediate` endpoints |
| `resistant_count` | Resolved `Resistant` endpoints |
| `inconclusive_count` | Resolved `Inconclusive` endpoints |
| `synergism_count` | Resolved `Synergism` endpoints |
| `missing_result_count` | Endpoints classified `missing` after reconciliation |
| `conflict_result_count` | Endpoints classified `conflict` after reconciliation |
| `gram_stain_group` | Reference-data classification of the base reporting group |
| `pair_order` | Review-defined ordering of antibiotic rows in the reporting panel |

The required row-level reconciliations are:

```text
eligible_count = tested_endpoint_count + untested_count

categorized_count = susceptible_count + intermediate_count + resistant_count

tested_endpoint_count = categorized_count + inconclusive_count
                      + synergism_count + missing_result_count
                      + conflict_result_count
```

The same `eligible_count` is used for every **approved, nonsuppressed drug** within an organism/cohort/**reporting phenotype** population. It can differ across phenotypes; no antibiotic-specific first-isolate selection is applied.

### Percentages

All percentages are calculated from the relevant mart row's counts and rounded to one decimal place.

| Field | Formula | Interpretation |
|---|---|---|
| `categorized_result_coverage_pct` | `100 × categorized_count / eligible_count` | Proportion of the eligible population with interpretable S/I/R AST for this drug; **not** a susceptibility rate |
| `susceptible_pct` | `100 × susceptible_count / categorized_count` | Proportion of interpretable source results labeled susceptible |
| `resistant_pct` | `100 × resistant_count / categorized_count` | Proportion explicitly labeled resistant; intermediate is not reclassified |

Rates with no usable denominator are null rather than fabricated zeroes. Selective antimicrobial testing may make `susceptible_pct` unrepresentative of the full eligible organism population even when the categorized count meets the display threshold.

### Display threshold

`display_status = 'display'` when `categorized_count >= 30`; otherwise it is `insufficient_data`.

The mart retains insufficient-data rows for audit; the Tableau reporting view should suppress or clearly mark their susceptibility percentages. The threshold is a **project display policy**, not certification of CLSI M39 compliance. A genuine 0% susceptibility differs from an insufficiently tested combination.

## MDRO reporting mart

**Model:** `mart_mdro`

The MDRO mart reports **CRE** and **MDR *P. aeruginosa*** independently of the conventional susceptibility table.

**Grain:** `source_version × cohort_id × organism_base_name × mdro_phenotype`.

Its patient-level denominator is constructed from the reviewed base-organism population **across eligible culture observations in the release**, not only from the patient's selected first overall culture and not by summing phenotype-specific categories.

For each CRE or MDR *P. aeruginosa* calculation, the model excludes culture records where the phenotype status is `not_applicable`, groups the remaining records by source version, cohort, patient, and base reporting organism, and assigns **one patient-level status**. Precedence across eligible observations is:

1. `positive` if **any** observation is positive;
2. otherwise `not_evaluable` if **any** observation is not evaluable;
3. otherwise `not_detected` if any observation supports not detected.

A patient therefore contributes at most once to each cohort/base-organism/MDRO analysis, even with multiple cultures or phenotype-qualified source labels. This is an **any-positive-across-observations** metric, not a first-isolate measure or an incidence rate.

| Field | Definition |
|---|---|
| `denominator_count` | Eligible distinct patient/base-organism groups for the MDRO phenotype and cohort |
| `positive_count` | Patient groups classified positive for the specified phenotype |
| `not_detected_count` | Patient groups with evidence supporting `not_detected` and no positive evidence |
| `not_evaluable_count` | Patient groups without sufficient positive or negative evidence |
| `evaluable_count` | `positive_count + not_detected_count` |
| `phenotype_pct` | `round(100 × positive_count / denominator_count, 1)`; percentage of all eligible patient groups classified phenotype-positive |
| `evaluable_pct` | `round(100 × evaluable_count / denominator_count, 1)`; percentage of eligible patient groups with a determinate positive or not-detected status |
| `gram_stain_group` | Base-organism Gram classification from the same reference seed |

Required reconciliations:

```text
denominator_count = positive_count + not_detected_count + not_evaluable_count

evaluable_count = positive_count + not_detected_count
```

Both `phenotype_pct` and `evaluable_pct` use **`denominator_count`**, which includes `not_evaluable_count`. Consequently, `evaluable_pct` reports **AST phenotype evaluability/ascertainment**, not the percentage that is phenotype-positive among evaluable patients. The SQL does **not** calculate `100 × positive_count / evaluable_count` as a separate mart field.

Division is protected by `nullif(denominator_count, 0)`, and the two percentages are rounded to one decimal place. These MDRO measures are distinct from `mart_susceptibility`'s S/I/R percentages and should be labeled separately in Tableau.

## Worked susceptibility example

**ARMD release:** `2025-04-11`  
**Cohort:** `blood`  
**Organism:** *Escherichia coli*  
**Antibiotic:** ceftriaxone

These counts come from the `overall` organism row and its ESCE-R subgroup in `mart_susceptibility`.

| Metric | Overall *E. coli* | ESCE-R subgroup |
|---|---:|---:|
| `eligible_count` | 3,022 | 467 |
| `categorized_count` | 3,016 | 466 |
| `susceptible_count` | 2,542 | 1 |
| `resistant_count` | 465 | 461 |
| `intermediate_count` | 9 | 4 |
| `categorized_result_coverage_pct` | 99.8% | 99.8% |
| `susceptible_pct` | 84.3% | 0.2% |
| `resistant_pct` | 15.4% | 98.9% |

For the overall row:

```text
2,542 susceptible + 465 resistant + 9 intermediate = 3,016 categorized

100 × 2,542 / 3,016 = 84.3% susceptible (rounded)
```

The ESCE-R row represents a **subset of the selected overall first cultures**, not a second set of independently selected first resistant cultures. Counts from the two rows must not be added to estimate the overall population.

## Validation and reproducibility

The pipeline uses dbt schema tests and independent SQL assertions for:

- Unique source and mart keys, non-null identifiers, and reviewed reference-data vocabulary;
- Overall earliest-culture selection and unique patient/cohort/organism groups;
- Reconciled AST endpoint uniqueness and consistent null/result status;
- Reconciliation of eligible, tested, categorized, missing, conflict, and untested counts;
- Overall mart denominators reconstructed from `int_overall_first_reporting_isolate`;
- Phenotype-subgroup denominators bounded by corresponding overall rows;
- Approved cohort-specific antibiotic pairs and exclusion overrides;
- Complete, consistent Gram classifications;
- MDRO numerator and denominator reconstruction from the separate MDRO population.

The principal custom dbt assertions are:

- `assert_overall_susceptibility_denominator`
- `assert_subgroup_denominators_within_overall`
- `assert_no_suppressed_or_unapproved_pairs`

The related validation notebooks are `10_validate_first_reporting_isolate.ipynb`, `11_validate_mart_susceptibility.ipynb`, and `12_validate_mdro_mart.ipynb`, with upstream grain, terminology, and phenotype validation in notebooks 01–09.

### Validated release snapshot

The latest full dbt regression build completed successfully: **205 successful operations, 0 warnings, 0 errors, 0 skips** (17 models, 4 seeds, 184 data tests).

| Component | Validated current count |
|---|---:|
| Reviewed organism-mapping seed rows | 41 |
| Organism/Gram reference seed rows | 20 |
| Approved active organism–drug–cohort seed rows | 311 |
| Inactive proposed pair seed rows | 11 |
| Organism–drug exclusion seed rows | 33 |
| Overall first-culture records | 85,818 |
| Overall reconciled AST endpoints | 1,033,825 |
| `mart_susceptibility` rows | 455 |
| Overall organism–drug–cohort mart rows | 305 |
| Phenotype-subgroup mart rows | 150 |
| Active approved pairs omitted through documented AmpC suppression | 6 |

These are dataset-release and model-version validation results, **not invariant expectations for future source releases**. The final mart will change if the source, organism mappings, reviewed panels, exclusions, or phenotype rules change.

## Interpretation limitations

- **Not a clinical antibiogram.** The project uses selected reporting conventions but has not established full CLSI M39/M100 compliance, clinical laboratory authorization, or clinical decision-support validity.
- **No verified isolate identifier.** An analytical culture/reporting-organism key is not proof that multiple biological isolates have been resolved.
- **Shifted dates and project period.** The release does not represent an unshifted calendar-year institutional antibiogram. First-culture selection is a documented project policy within cohort and release.
- **Source-provided S/I/R.** MICs, original testing methods, breakpoint editions, confirmatory AST, and resistance genes cannot be reconstructed from the available categorical fields.
- **Phenotypes are derived, not diagnoses.** ESCE-R is not equivalent to confirmed ESBL; CRE, MRSA, VRE, and MDR classifications depend on the qualifying AST present in the source.
- **Incomplete and selective testing.** Missing drugs, conflicts, and selectively tested agents can bias susceptibility percentages. `categorized_result_coverage_pct` should be interpreted alongside `%S`.
- **Mixed taxonomic detail.** Reporting groups include species, complexes, and unspeciated categories. Their pooled rates should not be interpreted as species-specific susceptibility distributions.
- **Specimen cohort stratification.** Blood, respiratory, and urine analyses are distinct; a patient can appear in more than one cohort. Cohort results should not be added without a new deduplication policy.
- **MDRO rates use another denominator.** `mart_mdro` uses patient-level phenotype status across observations; `mart_susceptibility` uses the selected first culture. Their counts and percentages must not be directly equated.
- **Reporting controls are explicit project decisions.** An excluded organism–drug pair is not necessarily untested, intrinsically resistant, or inappropriate in every clinical circumstance.

Differences across cohorts are descriptive and should not be interpreted as treatment effects or estimates of resistance rates in a general hospital population.
