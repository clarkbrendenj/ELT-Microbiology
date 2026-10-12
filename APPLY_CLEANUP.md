# Retired reporting-model cleanup package

**Purpose:** remove the obsolete phenotype-first production branch and
two misleading `include_main_antibiogram` / `main_exclusion_reason`
fields **without changing either current reporting mart**.

## Contents

Files in this ZIP mirror repository-relative paths. Replace:

- `dbt/models/intermediate/int_reporting_culture_organism.sql`
- `dbt/models/intermediate/_intermediate__models.yml`
- `notebooks/pipeline validation/07_profile_antibiotic_vocabulary.ipynb`
- `notebooks/pipeline validation/10_validate_first_reporting_isolate.ipynb`
- `notebooks/pipeline validation/12_validate_mdro_mart.ipynb`
- `docs/metric_definitions.md`

**Then delete** these two retired dbt models from your Git working tree:

- `dbt/models/intermediate/int_first_reporting_isolate.sql`
- `dbt/models/intermediate/int_first_reporting_susceptibility.sql`

The ZIP deliberately does **not** include placeholders for the deleted SQL.
Leave the current `int_overall_*` models and both mart SQL files untouched.

## Safe execution sequence (PowerShell, from repository root)

1. Check the working tree and create a branch before replacing files:

   ```powershell
   git status --short
   git switch -c cleanup/retired-reporting-models
   ```

2. Copy the six replacement files from the ZIP into their corresponding
   folders (or extract at the repository root after reviewing changes).
   The notebook directory name has a **space**: `pipeline validation`.

3. Verify no current SQL or notebook still relies on the retired branch:

   ```powershell
   git grep -n -E "int_first_reporting_isolate|int_first_reporting_susceptibility|include_main_antibiogram|main_exclusion_reason" -- dbt/models 'notebooks/pipeline validation' docs
   ```

   **Expected after replacing but before deleting:** only the two old SQL
   files should be listed. Then remove those files. `APPLY_CLEANUP.md` is
   temporary package guidance; it need not be committed to the repository.

   ```powershell
   git rm dbt/models/intermediate/int_first_reporting_isolate.sql
   git rm dbt/models/intermediate/int_first_reporting_susceptibility.sql
   ```

   Run the grep command again. **Expected: no matches in tracked files.**
   Historical text discussing the *method* is intentionally preserved.

4. Parse and fully rebuild from the `dbt` directory:

   ```powershell
   cd dbt
   ..\.venv\Scripts\dbt.exe parse
   ..\.venv\Scripts\dbt.exe build
   ..\.venv\Scripts\dbt.exe ls --resource-type model --output name
   ```

   **Expected:** 17 registered models (previously 19), fewer associated
   schema tests, and zero failed/skipped/warning dbt results. The exact
   test count depends on the remaining installed project configuration.

5. Rerun the three updated notebooks 07, 10, and 12. Their outputs are
   intentionally cleared because some SQL queries and methodological
   descriptions changed. Notebook 10 must find zero selection/source-key/
   AST integrity errors; Notebook 12 must find only `pass` reconstruction
   rows. Notebook 07 now audits the **11 inactive proposed pairs** using
   the overall first-culture population, not the former phenotype-first
   groups. Export old candidate-coverage files only if separately needed.

6. Compare reporting marts with a pre-cleanup snapshot. Prior to this
   cleanup, the validated susceptibility mart had **455 rows** (305
   `overall`, 150 subgroup) and the MDRO mart had **31 rows**. These counts
   are useful smoke tests **not full equivalence checks**. For stronger
   evidence, compare the full data contents or a reproducible checksum
   of each table before and after applying this package.

7. Inspect changes, and commit only after successful validation:

   ```powershell
   cd ..
   git diff HEAD --check
   git diff HEAD --stat
   git status --short
   ```

## Design notes

- The **old flags** indicated a deprecated CRE/MDR exclusion rule. They
  are removed from the intermediate view; the current overall mart never
  used them. Existing fields `reporting_phenotype` and `ast_*_status`
  remain intact. The intermediate value `base` is **not** the current
  susceptibility-mart `overall` population.
- Notebook 10 reconstructs historical phenotype-first **counts** from
  culture-level data, preserving a valuable explanation of the redesign.
  It no longer materializes or tests the deleted phenotype-first AST model.
- `mart_mdro` takes its inputs directly from
  `int_reporting_culture_organism` and classifies a patient using evidence
  from **all** eligible cultures; the revised Notebook 12 follows that
  same rule and verifies positive/not-detected/not-evaluable counts.
- `fct_susceptibility`, `int_susceptibility_exceptions`, demographics, and
  ward staging are **not** removed. They serve source-level/QA purposes
  even if not direct inputs to the two reporting marts.
- Deleting a local dbt model does not automatically DROP its already
  materialized table from Databricks. If desired, clean up obsolete
  warehouse tables **only after** a successful build and validation.
- **Out of scope:** source-level `Susceptible + NULL` reconciliation policy,
  the long phenotype-classification model, and repo-wide path/README
  cleanup. They deserve separate changes with independent regression
  checks; no clinical logic is silently changed here.

The included files have been structurally checked locally. No Databricks
SQL execution or dbt full build has been performed in this environment.
