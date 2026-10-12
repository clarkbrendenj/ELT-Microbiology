# Pipeline validation notebooks

Run these notebooks in numerical order using the VS Code notebook kernel configured for Databricks Connect. The `%sql` cells query `workspace.micro_dev` and `workspace.micro_raw` in the user's Databricks workspace; they are not dbt model files and do not accept `{{ ref(...) }}` syntax.

Notebook 08 has been renamed from `08_profile_resistance_phenotype_evaluability.ipynb` to `08_develop_resistance_phenotype_rules.ipynb`.

The SQL and output shown here are from the uploaded working notebooks. Existing output was preserved **only where the SQL cell is unchanged**. New or corrected SQL does not have saved results and requires execution against Databricks. A pre-exclusion 337-row mart result and an obsolete/unclean exclusion-seed preview were removed. The exploratory grouping of *Citrobacter koseri* and *C. farmeri* into the *C. freundii* complex was replaced with the current reviewed reporting-group mapping.

Before publishing to GitHub, run the full dbt build, then use **Restart Kernel and Run All** for each notebook from 01 through 12. Verify the results and check for unexecuted or failed cells. The static notebook checks here do not replace running them against the actual Databricks tables.

The display-policy layer changes which reviewed organism–drug pairs appear in `mart_susceptibility`; it does not rewrite ARMD's source AST and does not affect `mart_mdro` resistance-phenotype definitions. The reporting policies in this portfolio are project decisions and do not claim full clinical antibiogram guideline compliance.
