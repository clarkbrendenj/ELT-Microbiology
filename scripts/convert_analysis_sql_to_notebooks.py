from pathlib import Path
import re

import nbformat
import sqlparse


SOURCE_DIR = Path("sql/analysis")
OUTPUT_DIR = Path("notebooks/analysis")

OUTPUT_DIR.mkdir(parents=True, exist_ok=True)


def title_from_filename(path: Path) -> str:
    """
    Convert:
        03_validate_susceptibility_reconciliation.sql

    to:
        Validate Susceptibility Reconciliation
    """
    name = re.sub(r"^\d+_", "", path.stem)
    return name.replace("_", " ").title()


def comments_to_markdown(lines: list[str]) -> str:
    """
    Convert leading SQL comments into readable Markdown.
    Decorative separator lines are removed.
    """
    markdown_lines = []

    for line in lines:
        stripped = line.strip()

        if not stripped:
            markdown_lines.append("")
            continue

        if stripped.startswith("--"):
            text = stripped[2:].strip()

            # Ignore separator lines such as:
            # ------------------------------------
            # ====================================
            if text and set(text) <= {"-", "="}:
                continue

            markdown_lines.append(text)

    # Remove excessive blank lines.
    markdown = "\n".join(markdown_lines).strip()
    markdown = re.sub(r"\n{3,}", "\n\n", markdown)

    return markdown


def split_comment_and_sql(statement: str):
    """
    Separate the leading comment block from the SQL statement.
    Comments appearing inside the SQL remain in the SQL cell.
    """
    lines = statement.strip().splitlines()

    comment_lines = []

    while lines:
        stripped = lines[0].strip()

        if stripped.startswith("--") or stripped == "":
            comment_lines.append(lines.pop(0))
        else:
            break

    markdown = comments_to_markdown(comment_lines)
    sql = "\n".join(lines).strip()

    return markdown, sql


def convert_file(sql_path: Path):
    text = sql_path.read_text(encoding="utf-8")

    notebook = nbformat.v4.new_notebook()

    notebook.metadata["kernelspec"] = {
        "display_name": ".venv-dbx",
        "language": "python",
        "name": "python3",
    }

    notebook.metadata["language_info"] = {
        "name": "python"
    }

    cells = []

    # Notebook title
    cells.append(
        nbformat.v4.new_markdown_cell(
            f"# {title_from_filename(sql_path)}\n\n"
            f"Converted from `{sql_path.as_posix()}`."
        )
    )

    # Split the SQL file into individual statements.
    statements = sqlparse.split(text)

    for statement in statements:
        markdown, sql = split_comment_and_sql(statement)

        if markdown:
            cells.append(
                nbformat.v4.new_markdown_cell(markdown)
            )

        if sql:
            cells.append(
                nbformat.v4.new_code_cell(
                    "%sql\n" + sql
                )
            )

    notebook["cells"] = cells

    output_path = OUTPUT_DIR / f"{sql_path.stem}.ipynb"

    nbformat.write(notebook, output_path)

    print(
        f"Created {output_path} "
        f"({len(statements)} SQL statements)"
    )


def main():
    sql_files = sorted(SOURCE_DIR.glob("*.sql"))

    if not sql_files:
        print(f"No SQL files found in {SOURCE_DIR}")
        return

    for sql_path in sql_files:
        convert_file(sql_path)

    print()
    print(
        f"Converted {len(sql_files)} analysis files "
        f"to {OUTPUT_DIR}"
    )


if __name__ == "__main__":
    main()