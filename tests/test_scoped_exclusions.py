"""Offline integration checks for the actual reporting-grid SQL and scoped seed.

Run from the repository root: python -m unittest discover -s tests -v
These fixtures exercise relational logic without connecting to Databricks.
"""
import csv
from pathlib import Path
import re
import sqlite3
import unittest

ROOT = Path(__file__).resolve().parents[1]


def sql_text(relative_path):
    text = (ROOT / relative_path).read_text(encoding='utf-8-sig')
    text = re.sub(r"\{\{\s*config\(.*?\)\s*\}\}", '', text, flags=re.S)
    return re.sub(r"\{\{\s*ref\('([^']+)'\)\s*\}\}", r'\1', text)


def seed(name):
    with (ROOT / 'dbt/seeds' / (name + '.csv')).open(encoding='utf-8-sig', newline='') as handle:
        return list(csv.DictReader(handle))


class ScopedExclusionTests(unittest.TestCase):
    def setUp(self):
        self.db = sqlite3.connect(':memory:')
        self.addCleanup(self.db.close)
        for name in ['organism_antibiotic_exclusions', 'reportable_organism_antibiotic_pairs']:
            rows = seed(name)
            fields = list(rows[0])
            self.db.execute(f'create table {name} (' + ', '.join(f'{x} text' for x in fields) + ')')
            self.db.executemany(f'insert into {name} values (' + ','.join('?' for _ in fields) + ')',
                                [tuple(row[x] for x in fields) for row in rows])
        self.db.executescript('''
            create table int_overall_first_reporting_isolate (
                overall_reporting_isolate_key text, source_version text, cohort_id text,
                patient_key text, organism_reporting_group text, organism_name text
            );
            create table int_first_stratified_reporting_culture (
                first_stratified_reporting_culture_key text, source_version text, cohort_id text,
                patient_key text, organism_reporting_group text, organism_name text,
                reporting_phenotype text
            );
            create table int_overall_first_reporting_susceptibility (
                overall_reporting_isolate_key text, antibiotic text, resolution_status text,
                susceptibility text, reconciliation_reason text
            );
            create table int_first_stratified_reporting_susceptibility (
                first_stratified_reporting_culture_key text, reporting_phenotype text,
                antibiotic text, resolution_status text, susceptibility text, reconciliation_reason text
            );
            create table mart_susceptibility (
                source_version text, cohort_id text, organism_reporting_group text,
                reporting_phenotype text, antibiotic text, eligible_count integer
            );
        ''')
        groups = {
            'Staphylococcus aureus': ['overall','oxacillin_resistant','oxacillin_susceptible'],
            'Escherichia coli': ['base','esce_r'],
            'Klebsiella oxytoca': ['base','esce_r'],
            'Klebsiella pneumoniae': ['base','esce_r'],
            'Enterobacter cloacae complex': ['base','esce_r'],
            'Enterococcus faecium': ['base','vancomycin_resistant'],
            'Enterococcus faecalis': ['base','vancomycin_resistant'],
        }
        for organism, phenotypes in groups.items():
            for cohort in ['blood','respiratory','urine']:
                for phenotype in phenotypes:
                    for patient in ['p1','p2']:
                        key = '|'.join([organism,cohort,phenotype,patient])
                        row = (key,'release',cohort,patient,organism,organism)
                        if phenotype == 'overall':
                            self.db.execute('insert into int_overall_first_reporting_isolate values (?,?,?,?,?,?)', row)
                        else:
                            self.db.execute('insert into int_first_stratified_reporting_culture values (?,?,?,?,?,?,?)',row+(phenotype,))

    def grid(self):
        # Execute the actual model's CTEs through eligible_grid, before AST aggregation.
        prefix = sql_text('dbt/models/marts/mart_susceptibility.sql').split('endpoint_status as (',1)[0].rstrip()
        self.assertTrue(prefix.endswith(','))
        query = prefix[:-1] + '''
            select source_version, cohort_id, organism_reporting_group,
                   reporting_phenotype, antibiotic, count(*)
            from eligible_grid
            group by source_version, cohort_id, organism_reporting_group,
                     reporting_phenotype, antibiotic
        '''
        return self.db.execute(query).fetchall()

    def populate_mart(self):
        self.db.executemany('insert into mart_susceptibility values (?,?,?,?,?,?)', self.grid())

    def assertion_rows(self, name):
        return self.db.execute(sql_text('dbt/tests/' + name + '.sql')).fetchall()

    def test_seed_scopes_unique_and_explicit(self):
        rows = seed('organism_antibiotic_exclusions')
        fields = ['organism_reporting_group','cohort_id','reporting_phenotype','antibiotic']
        self.assertEqual(len(rows),len({tuple(x[k] for k in fields) for x in rows}))
        for row in rows:
            self.assertIn(row['cohort_id'],['*','blood','respiratory','urine'])
            self.assertIn(row['reporting_phenotype'],['*','base','esce_r','overall','oxacillin_resistant','oxacillin_susceptible','vancomycin_resistant'])
            self.assertTrue(all(row[k] for k in fields+['exclusion_reason','review_basis']))

    def test_mrsa_exclusions_preserve_overall_and_mssa(self):
        rows = [x for x in self.grid() if x[2]=='Staphylococcus aureus' and x[4]=='Oxacillin']
        self.assertEqual({(x[1],x[3]) for x in rows},
                         {(c,p) for c in ['blood','respiratory','urine'] for p in ['overall','oxacillin_susceptible']})
        self.assertTrue(all(x[5]==2 for x in rows))

    def test_esce_rules_preserve_base(self):
        rows = [x for x in self.grid() if x[2]=='Escherichia coli' and x[4] in ['Ampicillin','Ceftriaxone']]
        self.assertEqual({(x[1],x[3],x[4]) for x in rows},
                         {(c,'base',d) for c in ['blood','respiratory','urine'] for d in ['Ampicillin','Ceftriaxone']})

    def test_exclusion_does_not_expand_to_unlisted_cohort(self):
        rows = [x for x in self.grid() if x[2]=='Klebsiella pneumoniae' and x[4]=='Piperacillin/Tazobactam']
        self.assertEqual({(x[1],x[3]) for x in rows},
                         {('blood','base'),('respiratory','base'),('urine','base'),('urine','esce_r')})

    def test_daptomycin_excludes_both_reviewed_faecium_categories(self):
        rows = [x for x in self.grid() if x[1]=='blood' and x[4]=='Daptomycin']
        self.assertFalse(any(x[2]=='Enterococcus faecium' for x in rows))
        self.assertTrue(any(x[2]=='Enterococcus faecalis' and x[3]=='base' for x in rows))

    def test_existing_broad_rules_still_apply(self):
        rows = [x for x in self.grid() if x[2]=='Enterobacter cloacae complex']
        self.assertTrue(rows)
        self.assertFalse(any(x[4] in ['Ceftriaxone','Piperacillin/Tazobactam'] for x in rows))

    def test_overlapping_rules_do_not_multiply_or_change_retained_rows(self):
        before = sorted(self.grid())
        self.db.execute('''insert into organism_antibiotic_exclusions
            select organism_reporting_group,'blood','esce_r',antibiotic,
                   exclusion_reason,review_basis,notes
            from organism_antibiotic_exclusions
            where organism_reporting_group='Enterobacter cloacae complex' and antibiotic='Ceftriaxone'
        ''')
        self.assertEqual(before,sorted(self.grid()))

    def test_current_assertions_accept_correct_scoped_grid(self):
        self.populate_mart()
        self.assertEqual([],self.assertion_rows('assert_no_suppressed_or_unapproved_pairs'))
        self.assertEqual([],self.assertion_rows('assert_reporting_mart_population_complete'))
        self.assertEqual([],self.assertion_rows('assert_scoped_exclusions_have_approved_pairs'))

    def test_assertions_reject_reintroduced_excluded_row(self):
        self.populate_mart()
        self.db.execute("insert into mart_susceptibility values ('release','blood','Staphylococcus aureus','oxacillin_resistant','Oxacillin',2)")
        rows = self.assertion_rows('assert_no_suppressed_or_unapproved_pairs')
        self.assertEqual(1,len(rows))
        self.assertEqual('explicitly_excluded',rows[0][-1])
        self.assertEqual(1,len(self.assertion_rows('assert_reporting_mart_population_complete')))

    def test_completeness_rejects_overbroad_removal(self):
        self.populate_mart()
        self.db.execute("delete from mart_susceptibility where cohort_id='blood' and organism_reporting_group='Staphylococcus aureus' and reporting_phenotype='overall' and antibiotic='Oxacillin'")
        rows = self.assertion_rows('assert_reporting_mart_population_complete')
        self.assertEqual(1,len(rows))
        self.assertEqual('overall',rows[0][3])

    def test_completeness_rejects_changed_denominator(self):
        self.populate_mart()
        self.db.execute("update mart_susceptibility set eligible_count=99 where cohort_id='blood' and organism_reporting_group='Staphylococcus aureus' and reporting_phenotype='overall' and antibiotic='Oxacillin'")
        self.assertEqual(1,len(self.assertion_rows('assert_reporting_mart_population_complete')))

    def test_scoped_rule_requires_approved_pair(self):
        self.db.execute("insert into organism_antibiotic_exclusions values ('Escherichia coli','blood','base','Misspelled drug','project_panel_exclusion','fixture','fixture')")
        self.assertEqual(1,len(self.assertion_rows('assert_scoped_exclusions_have_approved_pairs')))


if __name__ == '__main__':
    unittest.main()
