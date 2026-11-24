---
name: sf-code-review
description: Review Salesforce code (Apex classes/triggers, LWC, Aura, Flow-invocable actions, SOQL, tests) and produce a review-notes-only HTML report. Use when asked to review, audit, or grade Salesforce code for quality, security, performance, bulkification, scalability, observability, complexity, or design patterns. Never modifies source.
---

# Salesforce Code Review → HTML review notes

**Output is review notes only.** Do not edit, fix, or reformat any source file. The only file you write is the HTML report.

## Procedure

1. **Scope.** Target = path/class named by the user; otherwise `force-app/`. Skip `node_modules`, `.sfdx`, `.sf`. List files with Glob (`*.cls`, `*.trigger`, `lwc/**`, `aura/**`, `flows`, `objects`).
2. **Measure.** Run `python3 -I .claude/skills/sf-code-review/scripts/complexity.py <scope>`. It returns per-method cyclomatic complexity (CC), length, params, and nesting. Treat as heuristic; confirm by reading the method.
2b. Run `python3 -I .claude/skills/sf-code-review/scripts/doc_check.py coverage <scope>` for comment coverage (feeds category 8).
3. **Read every in-scope file fully**, tests included. Cross-check callers with Grep (e.g. who calls a selector, trigger→handler chain).
4. **Evaluate against [checklist.md](checklist.md)**, covering all 12 categories. Cite real `file:line` evidence for each finding; never report from pattern-matching alone, so verify context (e.g. a SOQL in a loop that is actually bounded).
5. **Score** each category 0-10 and compute an overall grade (A ≥ 9, B ≥ 8, C ≥ 7, D ≥ 6, else F). Use 'N/A' where a category has no applicable code (e.g. LWC) and exclude it from the average.
6. **Write the HTML report** to `code-review-report.html` in the project root (or a path the user gives). Do not publish it or send it elsewhere unless asked.
7. **Reply** with the path, overall grade, and the top 3 blockers, in a few lines.

## Severity

- **Blocker**: security hole, data loss/corruption, governor-limit failure with realistic volumes, broken bulk handling.
- **Major**: likely production defect, significant scalability/perf cost, missing test coverage of core paths.
- **Minor**: maintainability, style, naming, comments.
- **Suggestion**: optional improvement or advanced pattern.
- **Good**: notable strength worth keeping (include some; reviews should be fair).

## Finding format

Each finding: `id`, category, severity, `file:line`, **what** (the issue), **why it matters** (the concrete failure mode or cost), **recommendation** (described in words or a short illustrative snippet. Do not apply it).

## HTML report requirements

Single self-contained file (inline CSS, no external assets, works offline, light+dark via `prefers-color-scheme`). Sections:

1. Header: project, scope, date, overall grade.
2. Executive summary (3-5 sentences) and counts by severity.
3. Scorecard: one row per category with score bar and finding count.
4. Complexity table: every method with CC > 5, sorted desc, flagged (CC 6-10 amber, >10 red; length > 50 lines or nesting > 3 flagged).
5. Findings grouped by category, sorted by severity, each in a card with the finding format above and a code excerpt of the offending lines (HTML-escape all code).
6. Strengths.
7. Prioritised action list (Blockers → Majors).
8. Method note: heuristics used and files not reviewed.

Escape all source text (`&`, `<`, `>`). Add a severity filter using plain `<details>` or a few lines of inline JS.

## Documentation mode
When asked to document or add comments (not review), follow [doc-standards.md](doc-standards.md) and the DOCUMENT-mode procedure in the `sf-code-reviewer` agent. Comments only, with backup and `doc_check.py verify` on every file.
