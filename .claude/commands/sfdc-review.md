---
description: Review Salesforce code into an HTML notes report, or add header/method comments with --document
argument-hint: "[--document] [path or class name] (default: force-app/)"
---

Use the `sf-code-reviewer` subagent and follow the `sf-code-review` skill.

Arguments: $ARGUMENTS (if there is no path, use `force-app/`).

**If the arguments contain `--document`:** run the agent in DOCUMENT mode on the given path. Add class headers and method comments only, following `doc-standards.md`. Back up each file, verify each edit is comment-only with `doc_check.py verify`, and report coverage before and after. Do not change any code.

**Otherwise (REVIEW mode):**
- Review notes only. Do not edit, format, fix, or deploy anything.
- Cover all 12 checklist categories, including cyclomatic complexity and comment coverage.
- Write the report to `code-review-report.html` in the project root.
- When the agent finishes, report the path, overall grade and top 3 blockers, then run `open code-review-report.html`.
